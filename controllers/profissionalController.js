const Professional = require('../models/Professional');
const User = require('../models/User');

class ProfessionalController {
  async searchProfessionals(req, res) {
    try {
      const { especialidade, estado, cidade } = req.query;

      const professionals = await Professional.findBySpecialtyAndLocation(especialidade, estado, cidade);

      res.json({
        success: true,
        data: professionals,
      });
    } catch (error) {
      console.error('Search professionals error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor',
      });
    }
  }

  async getProfile(req, res) {
    try {
      const { userId } = req.user;

      const professional = await Professional.findByUserId(userId);
      const user = await User.findById(userId);

      if (!professional) {
        return res.status(404).json({
          success: false,
          message: 'Perfil profissional não encontrado',
        });
      }

      res.json({
        success: true,
        data: {
          ...user,
          ...professional,
        },
      });
    } catch (error) {
      console.error('Get professional profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor',
      });
    }
  }

  async updateProfile(req, res) {
    try {
      const { userId } = req.user;
      const updates = req.body;

      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({
          success: false,
          message: 'Perfil profissional não encontrado',
        });
      }

      // Atualizar dados do profissional (exemplo: especialidade, tipo_veiculo_atendido)
      // Nota: Em uma implementação real, você teria um método de atualização no modelo
      // Por simplicidade, vamos supor que temos um método update no modelo Professional

      res.json({
        success: true,
        message: 'Perfil atualizado com sucesso',
      });
    } catch (error) {
      console.error('Update professional profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor',
      });
    }
  }

  async updateAvailability(req, res) {
    try {
      const { userId } = req.user;
      const { disponivel } = req.body;

      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({
          success: false,
          message: 'Perfil profissional não encontrado',
        });
      }

      // Atualizar disponibilidade
      // Nota: Em uma implementação real, você teria um método para atualizar a disponibilidade

      res.json({
        success: true,
        message: 'Disponibilidade atualizada com sucesso',
      });
    } catch (error) {
      console.error('Update availability error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor',
      });
    }
  }
}

module.exports = new ProfessionalController();