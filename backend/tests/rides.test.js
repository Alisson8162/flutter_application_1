jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const { query } = require('../config/database');
const Ride = require('../models/Ride');

describe('Ride.findActiveForUser', () => {
  beforeEach(() => query.mockReset());

  test('retorna null quando não há corrida ativa', async () => {
    query.mockResolvedValueOnce({ rows: [] });
    const ride = await Ride.findActiveForUser('user-1', 'cliente');
    expect(ride).toBeNull();
  });

  test('inclui driver_name/driver_phone/client_name via join', async () => {
    query.mockResolvedValueOnce({
      rows: [{
        id: 'ride-1',
        client_id: 'cliente-1',
        driver_id: 'prof-1',
        status: 'accepted',
        driver_name: 'Carlos Motorista',
        driver_phone: '11999999999',
        client_name: 'Fulano Cliente',
      }],
    });

    const ride = await Ride.findActiveForUser('cliente-1', 'cliente');

    expect(ride.driver_name).toBe('Carlos Motorista');
    expect(ride.driver_phone).toBe('11999999999');
    expect(ride.client_name).toBe('Fulano Cliente');

    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain('r.client_id = $1');
    expect(sql).toContain("status IN ('pending','accepted','in_progress')");
    expect(params).toEqual(['cliente-1']);
  });

  test('usa a coluna driver_id quando role é profissional', async () => {
    query.mockResolvedValueOnce({ rows: [] });
    await Ride.findActiveForUser('prof-1', 'profissional');

    const [sql] = query.mock.calls[0];
    expect(sql).toContain('r.driver_id = $1');
  });
});
