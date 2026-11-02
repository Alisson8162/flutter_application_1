describe('config/redis - fallback gracioso', () => {
  const ORIGINAL_ENV = process.env.REDIS_URL;

  afterEach(() => {
    process.env.REDIS_URL = ORIGINAL_ENV;
    jest.resetModules();
  });

  test('isConfigured() é false sem REDIS_URL definida', () => {
    delete process.env.REDIS_URL;
    jest.resetModules();
    const { isConfigured } = require('../config/redis');
    expect(isConfigured()).toBe(false);
  });

  test('getClient() retorna null sem REDIS_URL definida', () => {
    delete process.env.REDIS_URL;
    jest.resetModules();
    const { getClient } = require('../config/redis');
    expect(getClient()).toBeNull();
  });
});

describe('utils/rateLimitStore - fallback gracioso', () => {
  const ORIGINAL_ENV = process.env.REDIS_URL;

  afterEach(() => {
    process.env.REDIS_URL = ORIGINAL_ENV;
    jest.resetModules();
  });

  test('retorna undefined (store em memória padrão) sem Redis configurado', () => {
    delete process.env.REDIS_URL;
    jest.resetModules();
    const { createRateLimitStore } = require('../utils/rateLimitStore');
    expect(createRateLimitStore()).toBeUndefined();
  });
});

describe('config/sentry - fallback gracioso', () => {
  const ORIGINAL_ENV = process.env.SENTRY_DSN;

  afterEach(() => {
    process.env.SENTRY_DSN = ORIGINAL_ENV;
    jest.resetModules();
  });

  test('isConfigured() é false sem SENTRY_DSN definida', () => {
    delete process.env.SENTRY_DSN;
    jest.resetModules();
    const sentry = require('../config/sentry');
    expect(sentry.isConfigured()).toBe(false);
  });

  test('init() e captureException() não lançam sem DSN configurada', () => {
    delete process.env.SENTRY_DSN;
    jest.resetModules();
    const sentry = require('../config/sentry');
    expect(() => sentry.init()).not.toThrow();
    expect(() => sentry.captureException(new Error('teste'))).not.toThrow();
  });
});
