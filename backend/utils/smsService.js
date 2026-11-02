// Serviço de SMS. Usa Twilio quando as credenciais estiverem configuradas no
// .env; caso contrário, simula o envio via console (útil em desenvolvimento).

const isConfigured = () =>
  Boolean(
    process.env.TWILIO_ACCOUNT_SID &&
      process.env.TWILIO_AUTH_TOKEN &&
      process.env.TWILIO_PHONE_NUMBER
  );

const sendSMS = async (to, message) => {
  if (!isConfigured()) {
    console.log(`[SMS Simulado] Para: ${to} | Mensagem: ${message}`);
    return true;
  }

  try {
    // eslint-disable-next-line global-require
    const twilio = require('twilio');
    const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

    await client.messages.create({
      body: message,
      from: process.env.TWILIO_PHONE_NUMBER,
      to,
    });

    return true;
  } catch (error) {
    console.error('Erro ao enviar SMS:', error);
    return false;
  }
};

module.exports = { sendSMS };
