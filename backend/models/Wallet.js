const { query } = require('../config/database');

class Wallet {
  constructor(data) {
    this.id = data.id;
    this.user_id = data.user_id;
    this.balance = Number(data.balance);
    this.created_at = data.created_at;
    this.updated_at = data.updated_at;
  }

  static async findOrCreateForUser(userId) {
    let result = await query('SELECT * FROM wallets WHERE user_id = $1', [userId]);
    if (!result.rows[0]) {
      // Corrida rara: duas requisições simultâneas tentando criar a
      // carteira do mesmo usuário pela primeira vez. Se acontecer, a
      // segunda tentativa de INSERT falha por UNIQUE(user_id); nesse caso
      // simplesmente relemos a linha que a primeira já criou.
      try {
        result = await query('INSERT INTO wallets (user_id) VALUES ($1) RETURNING *', [userId]);
      } catch (error) {
        if (error.code === '23505') {
          result = await query('SELECT * FROM wallets WHERE user_id = $1', [userId]);
        } else {
          throw error;
        }
      }
    }
    return new Wallet(result.rows[0]);
  }

  static async credit(userId, amount, { description, rideId, stripePaymentIntentId } = {}) {
    const wallet = await Wallet.findOrCreateForUser(userId);
    const result = await query(
      `UPDATE wallets SET balance = balance + $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
      [amount, wallet.id]
    );
    await query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id, stripe_payment_intent_id)
       VALUES ($1, 'credit', $2, $3, $4, $5)`,
      [wallet.id, amount, description || null, rideId || null, stripePaymentIntentId || null]
    );
    return new Wallet(result.rows[0]);
  }

  // O `AND balance >= $1` no UPDATE é o que garante atomicidade de verdade
  // (evita duas requisições simultâneas debitando mais do que o saldo
  // permite) - a checagem de `wallet.balance` acima é só para devolver uma
  // mensagem de erro amigável no caso comum (não-concorrente).
  static async debit(userId, amount, { description, rideId } = {}) {
    const wallet = await Wallet.findOrCreateForUser(userId);
    if (wallet.balance < amount) {
      return { success: false, message: 'Saldo insuficiente na carteira' };
    }

    const result = await query(
      `UPDATE wallets SET balance = balance - $1, updated_at = NOW()
       WHERE id = $2 AND balance >= $1 RETURNING *`,
      [amount, wallet.id]
    );
    if (!result.rows[0]) {
      return { success: false, message: 'Saldo insuficiente na carteira' };
    }

    await query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
       VALUES ($1, 'debit', $2, $3, $4)`,
      [wallet.id, amount, description || null, rideId || null]
    );

    return { success: true, wallet: new Wallet(result.rows[0]) };
  }

  static async findTransactions(userId, { limit = 50 } = {}) {
    const wallet = await Wallet.findOrCreateForUser(userId);
    const safeLimit = Math.min(200, Math.max(1, Number(limit) || 50));
    const result = await query(
      `SELECT * FROM wallet_transactions WHERE wallet_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [wallet.id, safeLimit]
    );
    return result.rows;
  }
}

module.exports = Wallet;
