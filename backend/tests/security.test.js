jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const { generateSecretBase32, generateTOTP, verifyTOTP, buildOtpAuthUri } = require('../utils/totp');
const { query } = require('../config/database');
const User = require('../models/User');
const RevokedToken = require('../models/RevokedToken');

describe('TOTP (2FA)', () => {
  test('verifyTOTP aceita o código gerado no mesmo instante', () => {
    const secret = generateSecretBase32();
    const code = generateTOTP(secret);
    expect(verifyTOTP(secret, code)).toBe(true);
  });

  test('verifyTOTP rejeita código incorreto', () => {
    const secret = generateSecretBase32();
    const code = generateTOTP(secret);
    const wrongCode = code === '000000' ? '111111' : '000000';
    expect(verifyTOTP(secret, wrongCode)).toBe(false);
  });

  test('verifyTOTP rejeita entradas com formato inválido', () => {
    const secret = generateSecretBase32();
    expect(verifyTOTP(secret, '12')).toBe(false);
    expect(verifyTOTP(secret, 'abcdef')).toBe(false);
    expect(verifyTOTP(secret, '')).toBe(false);
    expect(verifyTOTP(secret, null)).toBe(false);
  });

  test('bate com o vetor de teste oficial da RFC 6238 (T=59s)', () => {
    // Segredo de teste da RFC 6238: ASCII "12345678901234567890" em Base32
    const rfcSecretBase32 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    const code = generateTOTP(rfcSecretBase32, 59 * 1000);
    // A RFC define o resultado de 8 dígitos como "94287082"; os 6 dígitos
    // finais (o que geramos, já que usamos 6 dígitos) devem ser "287082".
    expect(code).toBe('287082');
  });

  test('buildOtpAuthUri gera uma URI otpauth:// válida', () => {
    const secret = generateSecretBase32();
    const uri = buildOtpAuthUri(secret, 'user@example.com');
    expect(uri).toMatch(/^otpauth:\/\/totp\//);
    expect(uri).toContain(`secret=${secret}`);
    expect(uri).toContain('issuer=FalaComigo');
  });
});

describe('User - bloqueio por tentativas de login', () => {
  beforeEach(() => query.mockReset());

  test('registerFailedLogin incrementa tentativas sem bloquear antes do limite', async () => {
    query.mockResolvedValueOnce({ rows: [{ id: 'u1', failed_login_attempts: 2 }] });
    const user = new User({ id: 'u1', failed_login_attempts: 1 });

    await user.registerFailedLogin();

    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain('failed_login_attempts = $1');
    expect(sql).not.toContain('locked_until');
    expect(params[0]).toBe(2);
  });

  test('registerFailedLogin bloqueia a conta ao atingir o limite', async () => {
    query.mockResolvedValueOnce({ rows: [{ id: 'u1' }] });
    const user = new User({ id: 'u1', failed_login_attempts: User.LOCK_THRESHOLD - 1 });

    await user.registerFailedLogin();

    const [sql] = query.mock.calls[0];
    expect(sql).toContain('locked_until');
  });

  test('isLocked() reflete locked_until no futuro/passado', () => {
    const future = new Date(Date.now() + 60000);
    const past = new Date(Date.now() - 60000);

    expect(new User({ id: 'u1', locked_until: future }).isLocked()).toBe(true);
    expect(new User({ id: 'u1', locked_until: past }).isLocked()).toBe(false);
    expect(new User({ id: 'u1', locked_until: null }).isLocked()).toBe(false);
  });
});

describe('RevokedToken (blacklist de JWT)', () => {
  beforeEach(() => query.mockReset());

  test('revoke() não faz query quando jti é ausente (token antigo sem jti)', async () => {
    await RevokedToken.revoke(undefined, 'user-1', new Date());
    expect(query).not.toHaveBeenCalled();
  });

  test('revoke() insere na tabela revoked_tokens', async () => {
    query.mockResolvedValueOnce({ rows: [] });
    await RevokedToken.revoke('jti-123', 'user-1', new Date());

    const [sql, params] = query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO revoked_tokens/i);
    expect(params[0]).toBe('jti-123');
  });

  test('isRevoked() retorna true quando há linha correspondente', async () => {
    query.mockResolvedValueOnce({ rows: [{ jti: 'jti-123' }] });
    expect(await RevokedToken.isRevoked('jti-123')).toBe(true);
  });

  test('isRevoked() retorna false quando não há linha', async () => {
    query.mockResolvedValueOnce({ rows: [] });
    expect(await RevokedToken.isRevoked('jti-999')).toBe(false);
  });
});
