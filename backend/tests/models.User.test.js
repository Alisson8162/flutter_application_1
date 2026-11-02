jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const { query } = require('../config/database');
const User = require('../models/User');

describe('User model', () => {
  test('create() insere na tabela users com os campos corretos', async () => {
    query.mockResolvedValueOnce({ rows: [{ id: 'user-1' }] });

    const id = await User.create({
      role: 'cliente',
      name: 'Maria Silva',
      email: 'maria@example.com',
      phone: '11999999999',
      cpf: '52998224725',
      password: 'senha123',
    });

    expect(id).toBe('user-1');
    expect(query).toHaveBeenCalledTimes(1);

    const [sql, params] = query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO users/i);
    expect(params[1]).toBe('Maria Silva'); // name
    expect(params[2]).toBe('maria@example.com'); // email
    // A senha nunca deve ser gravada em texto puro - deve ser um hash bcrypt
    expect(params[5]).not.toBe('senha123');
    expect(params[5]).toMatch(/^\$2[aby]\$/);
  });

  test('update() grava na tabela users (regressão do bug original que gravava em addresses)', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'user-1', name: 'Maria Silva', email: 'maria@example.com' }],
    });

    const user = new User({ id: 'user-1', name: 'Maria Silva', email: 'maria@example.com' });
    await user.update({ name: 'Maria Souza' });

    expect(query).toHaveBeenCalledTimes(1);
    const [sql] = query.mock.calls[0];

    // A regressão que motivou este teste: o UPDATE tinha como alvo a tabela
    // `addresses` em vez de `users`.
    expect(sql).toMatch(/UPDATE users SET/i);
    expect(sql).not.toMatch(/UPDATE addresses/i);
  });

  test('update() ignora campos não permitidos', async () => {
    query.mockResolvedValueOnce({ rows: [{ id: 'user-1' }] });

    const user = new User({ id: 'user-1' });
    await user.update({ name: 'Novo Nome', id: 'outro-id-malicioso', role: 'admin' });

    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain('name = $1');
    expect(sql).not.toContain('id =');
    expect(sql).not.toContain('role =');
    expect(params).toEqual(['Novo Nome', 'user-1']);
  });

  test('update() não faz query nenhuma quando não há campos válidos', async () => {
    const user = new User({ id: 'user-1' });
    await user.update({ campo_invalido: 'x' });
    expect(query).not.toHaveBeenCalled();
  });
});
