const Stripe = require('stripe');
require('dotenv').config();

const isConfigured = () => Boolean(process.env.STRIPE_SECRET_KEY);

// Em desenvolvimento, sem chave configurada, o app funciona normalmente mas
// os endpoints de pagamento retornam erro claro em vez de derrubar o
// servidor na inicialização (evita crash caso o .env ainda não tenha as
// chaves da Stripe preenchidas).
const stripe = isConfigured() ? new Stripe(process.env.STRIPE_SECRET_KEY) : null;

module.exports = { stripe, isConfigured };
