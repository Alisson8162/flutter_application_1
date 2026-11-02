const { query } = require('../config/database');

// BUG CORRIGIDO: a busca de profissionais (usada tanto na tela do cliente ao
// escolher o tipo de serviço quanto em /professionals/search) comparava
// `p.especialidade = $1` byte a byte. O app envia o slug do serviço em
// minúsculo e sem acento (ex.: "mecanico", "guincho"), enquanto o cadastro
// do profissional grava o valor do dropdown com acento e maiúscula inicial
// (ex.: "Mecânico", "Guincho") - ou seja, a comparação NUNCA batia e a busca
// sempre retornava zero profissionais, para qualquer especialidade.
//
// A normalização abaixo (minúsculas + remoção de acentos via `translate`)
// resolve isso sem precisar da extensão `unaccent` do Postgres (que exige
// privilégio de superuser em muitos provedores gerenciados).
const NORMALIZE_SQL = (expr) =>
  `lower(translate(${expr}, 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ', 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'))`;

class Professional {
  constructor(data) {
    this.id = data.id;
    this.user_id = data.user_id;
    this.especialidade = data.especialidade;
    this.tipo_veiculo_atendido = data.tipo_veiculo_atendido;
    this.valor_base = data.valor_base;
    this.valor_km = data.valor_km;
    this.conta_ativa = data.conta_ativa;
    this.avaliacao_media = data.avaliacao_media;
    this.total_avaliacoes = data.total_avaliacoes;
    this.disponivel = data.disponivel;
    this.documentacao_aprovada = data.documentacao_aprovada;
    this.current_latitude = data.current_latitude;
    this.current_longitude = data.current_longitude;
    this.location_updated_at = data.location_updated_at;
    this.created_at = data.created_at;
  }

  static async create(data) {
    const { user_id, especialidade, tipo_veiculo_atendido, valor_base, valor_km } = data;

    const result = await query(
      `INSERT INTO professionals (user_id, especialidade, tipo_veiculo_atendido, valor_base, valor_km)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [user_id, especialidade, tipo_veiculo_atendido, Number(valor_base) || 0, Number(valor_km) || 0]
    );
    return result.rows[0].id;
  }

  static async findByUserId(userId) {
    const result = await query('SELECT * FROM professionals WHERE user_id = $1', [userId]);
    return result.rows[0] ? new Professional(result.rows[0]) : null;
  }

  static async findById(id) {
    const result = await query('SELECT * FROM professionals WHERE id = $1', [id]);
    return result.rows[0] ? new Professional(result.rows[0]) : null;
  }

  // Buscar profissionais disponíveis e aprovados por especialidade/localização
  static async findBySpecialtyAndLocation(especialidade, estado, cidade) {
    let sql = `
      SELECT p.*, u.name, u.phone, u.foto_url, a.latitude AS home_latitude, a.longitude AS home_longitude
      FROM professionals p
      JOIN users u ON p.user_id = u.id
      LEFT JOIN addresses a ON u.id = a.user_id
      WHERE p.disponivel = TRUE AND p.documentacao_aprovada = TRUE
    `;
    const params = [];

    if (especialidade) {
      params.push(especialidade);
      sql += ` AND ${NORMALIZE_SQL('p.especialidade')} = ${NORMALIZE_SQL(`$${params.length}`)}`;
    }

    if (estado && cidade) {
      params.push(estado);
      sql += ` AND a.estado = $${params.length}`;
      params.push(cidade);
      sql += ` AND a.cidade = $${params.length}`;
    }

    const result = await query(sql, params);
    return result.rows;
  }

  // Buscar profissionais disponíveis próximos de um ponto (todos, filtro de
  // distância feito em memória pelo controller usando calculateDistanceKm)
  static async findAvailableWithLocation(especialidade) {
    let sql = `
      SELECT p.*, u.name, u.phone, u.foto_url
      FROM professionals p
      JOIN users u ON p.user_id = u.id
      WHERE p.disponivel = TRUE
        AND p.documentacao_aprovada = TRUE
        AND p.current_latitude IS NOT NULL
        AND p.current_longitude IS NOT NULL
    `;
    const params = [];
    if (especialidade) {
      params.push(especialidade);
      sql += ` AND ${NORMALIZE_SQL('p.especialidade')} = ${NORMALIZE_SQL(`$${params.length}`)}`;
    }
    const result = await query(sql, params);
    return result.rows;
  }

  // Usado pelo painel administrativo: profissionais com documentação ainda
  // não aprovada, já com nome/telefone/email do usuário.
  static async findPendingApproval() {
    const result = await query(
      `SELECT p.*, u.name, u.email, u.phone, u.cpf, u.created_at AS user_created_at,
              ps.status AS subscription_status, ps.current_period_end AS subscription_period_end
       FROM professionals p
       JOIN users u ON p.user_id = u.id
       LEFT JOIN professional_subscriptions ps ON ps.professional_id = p.id
       WHERE p.documentacao_aprovada = FALSE
       ORDER BY u.created_at ASC`
    );
    return result.rows;
  }

  async update(updates) {
    const allowedFields = [
      'especialidade',
      'tipo_veiculo_atendido',
      'valor_base',
      'valor_km',
      'conta_ativa',
      'disponivel',
      'documentacao_aprovada',
      'avaliacao_media',
      'total_avaliacoes',
    ];

    const fields = [];
    const values = [];
    let i = 1;

    Object.keys(updates).forEach((key) => {
      if (allowedFields.includes(key) && updates[key] !== undefined) {
        fields.push(`${key} = $${i}`);
        values.push(updates[key]);
        i += 1;
      }
    });

    if (fields.length === 0) return;

    values.push(this.id);

    const result = await query(
      `UPDATE professionals SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
      values
    );

    if (result.rows[0]) {
      Object.assign(this, new Professional(result.rows[0]));
    }
  }

  // Atualiza a localização em tempo real do profissional (usada pelo app
  // enquanto ele está online/disponível ou durante uma corrida em curso)
  async updateLocation(latitude, longitude) {
    const result = await query(
      `UPDATE professionals
       SET current_latitude = $1, current_longitude = $2, location_updated_at = CURRENT_TIMESTAMP
       WHERE id = $3 RETURNING *`,
      [latitude, longitude, this.id]
    );
    if (result.rows[0]) {
      Object.assign(this, new Professional(result.rows[0]));
    }
  }

  // Recalcula avaliação média e total após uma nova review
  async recalculateRating() {
    const result = await query(
      `SELECT COALESCE(AVG(nota), 0) AS media, COUNT(*) AS total
       FROM reviews WHERE professional_id = $1`,
      [this.id]
    );
    const { media, total } = result.rows[0];
    await this.update({
      avaliacao_media: Number(media).toFixed(2),
      total_avaliacoes: Number(total),
    });
  }

  // Ganhos do profissional (soma de corridas concluídas), agrupado por período
  static async getEarningsSummary(professionalUserId) {
    const totalsResult = await query(
      `SELECT
         COALESCE(SUM(final_price), 0) AS total_geral,
         COUNT(*) AS total_corridas
       FROM rides
       WHERE driver_id = $1 AND status = 'completed'`,
      [professionalUserId]
    );

    const todayResult = await query(
      `SELECT COALESCE(SUM(final_price), 0) AS total_hoje, COUNT(*) AS corridas_hoje
       FROM rides
       WHERE driver_id = $1 AND status = 'completed' AND completed_at::date = CURRENT_DATE`,
      [professionalUserId]
    );

    const weekResult = await query(
      `SELECT COALESCE(SUM(final_price), 0) AS total_semana, COUNT(*) AS corridas_semana
       FROM rides
       WHERE driver_id = $1 AND status = 'completed'
         AND completed_at >= date_trunc('week', CURRENT_DATE)`,
      [professionalUserId]
    );

    return {
      total_geral: Number(totalsResult.rows[0].total_geral),
      total_corridas: Number(totalsResult.rows[0].total_corridas),
      total_hoje: Number(todayResult.rows[0].total_hoje),
      corridas_hoje: Number(todayResult.rows[0].corridas_hoje),
      total_semana: Number(weekResult.rows[0].total_semana),
      corridas_semana: Number(weekResult.rows[0].corridas_semana),
    };
  }
}

module.exports = Professional;
