// Widgets de UI reutilizáveis para as telas de autenticação/cadastro.
// Sem lógica de negócio: cada widget só recebe callbacks/controllers já
// prontos das telas que os usam.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Botão principal cheio, com estado de carregamento embutido.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  final Color? foreground;
  final double height;
  final IconData? icon;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color = AppColors.green,
    this.foreground,
    this.height = 54,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? const Color(0xFF06120A);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.5),
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
                  Text(label, style: AppText.button(fg)),
                ],
              ),
      ),
    );
  }
}

/// Botão secundário (contorno), usado para "Voltar" em fluxos com etapas.
class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  const AppOutlinedButton({super.key, required this.label, required this.onPressed, this.height = 54});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
        ),
        child: Text(label, style: AppText.button(AppColors.textPrimary)),
      ),
    );
  }
}

/// Campo de texto padrão (fundo sólido, ícone à esquerda opcional, ação à
/// direita opcional). Cobre tanto TextField simples quanto TextFormField
/// com validator.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? leading;
  final Widget? trailing;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool useFormField;
  final TextStyle? style;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.leading,
    this.trailing,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.useFormField = false,
    this.style,
  });

  InputDecoration get _decoration => InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(AppColors.textFaint),
        border: InputBorder.none,
        prefixIcon: leading != null
            ? Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: Icon(leading, color: AppColors.textFaint, size: 20),
              )
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.smBr,
        border: Border.all(color: AppColors.border),
      ),
      child: useFormField
          ? TextFormField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              validator: validator,
              style: style ?? AppText.body(AppColors.textPrimary),
              decoration: _decoration,
            )
          : TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: style ?? AppText.body(AppColors.textPrimary),
              decoration: _decoration,
            ),
    );
  }
}

/// Dropdown estilizado igual ao AppTextField, para manter consistência nas
/// telas de cadastro (especialidade, veículo, estado...).
class AppDropdownField<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;

  const AppDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.smBr,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.body(AppColors.textFaint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        ),
        dropdownColor: AppColors.surfaceElevated,
        iconEnabledColor: AppColors.textDim,
        value: value,
        validator: validator,
        style: AppText.body(AppColors.textPrimary),
        items: items
            .map((e) => DropdownMenuItem<T>(value: e, child: Text(labelBuilder(e), style: AppText.body(AppColors.textPrimary))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Cartão de seleção "Sou Cliente / Sou Profissional" com estado ativo.
class RoleOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const RoleOptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.14) : AppColors.surfaceElevated,
          borderRadius: AppRadius.mdBr,
          border: Border.all(color: selected ? activeColor : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? activeColor : AppColors.textDim, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppText.bodyMedium(selected ? activeColor : AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de progresso em barras, usado no cadastro por etapas.
class StepProgressBar extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final Color activeColor;
  const StepProgressBar({super.key, required this.totalSteps, required this.currentStep, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
                height: 4,
                decoration: BoxDecoration(
                  color: index <= currentStep ? activeColor : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text('Etapa ${currentStep + 1} de $totalSteps', style: AppText.caption(AppColors.textDim)),
      ],
    );
  }
}

/// Cabeçalho de marca usado no topo da tela de login.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.greenDim,
            borderRadius: AppRadius.smBr,
          ),
          child: const Icon(Icons.car_repair_rounded, color: AppColors.green, size: 22),
        ),
        const SizedBox(width: 12),
        Text('Fala Comigo', style: AppText.h2(AppColors.textPrimary)),
      ],
    );
  }
}
