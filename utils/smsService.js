// Em produção, usar Twilio ou outro serviço SMS
const sendSMS = async (to, message) => {
  try {
    console.log(`[SMS Simulado] Para: ${to}, Mensagem: ${message}`);
    
    // Implementação real com Twilio:
    /*
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;
    const client = require('twilio')(accountSid, authToken);

    await client.messages.create({
      body: message,
      from: process.env.TWILIO_PHONE_NUMBER,
      to: to
    });
    */
    
    return true;
  } catch (error) {
    console.error('Erro ao enviar SMS:', error);
    return false;
  }
};

module.exports = { sendSMS };