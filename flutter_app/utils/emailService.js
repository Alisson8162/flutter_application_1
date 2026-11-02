const nodemailer = require('nodemailer');

// Configuração do transporter
const createTransporter = () => {
  return nodemailer.createTransporter({
    host: process.env.EMAIL_HOST || 'smtp.gmail.com',
    port: process.env.EMAIL_PORT || 587,
    secure: false,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASSWORD,
    },
  });
};

// Enviar email genérico
const sendEmail = async (to, subject, text, html = null) => {
  try {
    const transporter = createTransporter();
    
    const mailOptions = {
      from: `"FalaComigo" <${process.env.EMAIL_USER}>`,
      to,
      subject,
      text,
      html,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`✅ Email enviado: ${info.messageId}`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('❌ Erro ao enviar email:', error);
    return { success: false, error: error.message };
  }
};

// Email de verificação
const sendVerificationEmail = async (to, code) => {
  const subject = 'Verificação de Email - FalaComigo';
  const text = `Seu código de verificação é: ${code}`;
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #22c55e;">FalaComigo - Verificação de Email</h2>
      <p>Olá!</p>
      <p>Seu código de verificação é:</p>
      <div style="background: #f8f9fa; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 8px; color: #22c55e;">
        ${code}
      </div>
      <p>Este código expira em 10 minutos.</p>
      <p>Se você não solicitou este código, ignore este email.</p>
      <hr>
      <p style="color: #6c757d; font-size: 12px;">
        FalaComigo - Socorro Veicular<br>
        Sua segurança em primeiro lugar
      </p>
    </div>
  `;

  return await sendEmail(to, subject, text, html);
};

// Email de boas-vindas
const sendWelcomeEmail = async (to, name, role) => {
  const subject = `Bem-vindo ao FalaComigo - ${role === 'profissional' ? 'Profissional' : 'Cliente'}`;
  const text = `Olá ${name}, bem-vindo ao FalaComigo!`;
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #22c55e;">Bem-vindo ao FalaComigo!</h2>
      <p>Olá <strong>${name}</strong>,</p>
      <p>Seja muito bem-vindo(a) ao FalaComigo!</p>
      <p>Seu cadastro como <strong>${role === 'profissional' ? 'Profissional' : 'Cliente'}</strong> foi realizado com sucesso.</p>
      
      ${role === 'profissional' ? `
      <div style="background: #fff3cd; padding: 15px; border-radius: 5px; border-left: 4px solid #ffc107;">
        <p><strong>Status da documentação:</strong> Em análise</p>
        <p>Nossa equipe irá analisar seus documentos e em breve você poderá começar a atender.</p>
      </div>
      ` : ''}
      
      <p>Estamos aqui para ajudar! Em caso de dúvidas, entre em contato conosco.</p>
      <hr>
      <p style="color: #6c757d; font-size: 12px;">
        FalaComigo - Socorro Veicular<br>
        Sua segurança em primeiro lugar
      </p>
    </div>
  `;

  return await sendEmail(to, subject, text, html);
};

// Email de recuperação de senha
const sendPasswordResetEmail = async (to, resetToken) => {
  const resetUrl = `${process.env.FRONTEND_URL}/reset-password?token=${resetToken}`;
  const subject = 'Recuperação de Senha - FalaComigo';
  const text = `Para redefinir sua senha, acesse: ${resetUrl}`;
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #22c55e;">Recuperação de Senha</h2>
      <p>Recebemos uma solicitação para redefinir sua senha.</p>
      <p>Clique no botão abaixo para criar uma nova senha:</p>
      <div style="text-align: center; margin: 30px 0;">
        <a href="${resetUrl}" style="background: #22c55e; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
          Redefinir Senha
        </a>
      </div>
      <p>Se você não solicitou esta redefinição, ignore este email.</p>
      <p><strong>Este link expira em 1 hora.</strong></p>
      <hr>
      <p style="color: #6c757d; font-size: 12px;">
        FalaComigo - Socorro Veicular
      </p>
    </div>
  `;

  return await sendEmail(to, subject, text, html);
};

module.exports = {
  sendEmail,
  sendVerificationEmail,
  sendWelcomeEmail,
  sendPasswordResetEmail
};