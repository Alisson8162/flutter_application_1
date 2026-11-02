const { validateCPF, calculateDistanceKm, generateNumericCode } = require('../utils/helpers');

describe('validateCPF', () => {
  test('aceita um CPF válido conhecido', () => {
    // CPF de teste válido segundo o algoritmo de dígitos verificadores
    expect(validateCPF('529.982.247-25')).toBe(true);
    expect(validateCPF('52998224725')).toBe(true);
  });

  test('rejeita CPF com todos os dígitos iguais', () => {
    expect(validateCPF('111.111.111-11')).toBe(false);
  });

  test('rejeita CPF com dígito verificador incorreto', () => {
    expect(validateCPF('529.982.247-26')).toBe(false);
  });

  test('rejeita CPF com tamanho incorreto', () => {
    expect(validateCPF('123456')).toBe(false);
  });

  test('rejeita valores vazios/nulos', () => {
    expect(validateCPF('')).toBe(false);
    expect(validateCPF(null)).toBe(false);
    expect(validateCPF(undefined)).toBe(false);
  });
});

describe('calculateDistanceKm', () => {
  test('retorna 0 para o mesmo ponto', () => {
    expect(calculateDistanceKm(-23.55, -46.63, -23.55, -46.63)).toBeCloseTo(0, 5);
  });

  test('calcula a distância aproximada entre São Paulo e Rio de Janeiro (~360km)', () => {
    // São Paulo: -23.5505, -46.6333 | Rio de Janeiro: -22.9068, -43.1729
    const distance = calculateDistanceKm(-23.5505, -46.6333, -22.9068, -43.1729);
    expect(distance).toBeGreaterThan(300);
    expect(distance).toBeLessThan(420);
  });
});

describe('generateNumericCode', () => {
  test('gera um código com o número de dígitos solicitado', () => {
    const code = generateNumericCode(4);
    expect(code).toHaveLength(4);
    expect(/^\d+$/.test(code)).toBe(true);
  });

  test('gera um código de 6 dígitos quando solicitado', () => {
    const code = generateNumericCode(6);
    expect(code).toHaveLength(6);
  });
});
