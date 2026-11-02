// Design system compartilhado do app — cores, tipografia e raios usados em
// todas as telas. Centralizar aqui evita repetir Color(0x...) espalhados
// pelo código e garante que qualquer tela nova já nasça consistente com o
// padrão visual (escuro, denso, acentos de cor por contexto — verde para
// cliente, âmbar para profissional).
//
// Nenhuma lógica de negócio vive aqui, apenas aparência.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Fundo
  static const bg = Color(0xFF0A0B0D);
  static const surface = Color(0xFF17181D);
  static const surfaceElevated = Color(0xFF1E2027);
  static const border = Color(0xFF24262E);

  // Texto
  static const textPrimary = Color(0xFFF5F6F7);
  static const textDim = Color(0xFFAAB0BC);
  static const textFaint = Color(0xFF6B7280);

  // Acentos
  static const green = Color(0xFF22C55E);
  static const greenDim = Color(0xFF16321F);
  static const amber = Color(0xFFF5A623);
  static const amberDim = Color(0xFF3A3320);
  static const red = Color(0xFFF87171);
  static const redDim = Color(0xFF3A1F1F);
  static const blue = Color(0xFF4F9DFF);

  /// Cor de destaque conforme o papel do usuário (cliente = verde,
  /// profissional = âmbar), usada em botões, seleção de papel e progresso.
  static Color roleAccent(bool isProfissional) => isProfissional ? amber : green;
  static Color roleAccentDim(bool isProfissional) => isProfissional ? amberDim : greenDim;
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static BorderRadius get smBr => BorderRadius.circular(sm);
  static BorderRadius get mdBr => BorderRadius.circular(md);
  static BorderRadius get lgBr => BorderRadius.circular(lg);
}

class AppText {
  AppText._();

  static TextStyle _base(double size, FontWeight w, Color c, {double? letterSpacing}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, letterSpacing: letterSpacing);

  static TextStyle display(Color c) => _base(30, FontWeight.w800, c, letterSpacing: -0.4);
  static TextStyle h1(Color c) => _base(24, FontWeight.w800, c, letterSpacing: -0.3);
  static TextStyle h2(Color c) => _base(18, FontWeight.w700, c);
  static TextStyle body(Color c) => _base(14.5, FontWeight.w400, c);
  static TextStyle bodyMedium(Color c) => _base(14.5, FontWeight.w600, c);
  static TextStyle caption(Color c) => _base(12.5, FontWeight.w500, c);
  static TextStyle button(Color c) => _base(15, FontWeight.w700, c);
}

/// Fundo padrão das telas de autenticação: imagem + overlay escuro, igual em
/// todas para dar sensação de app único (mesmo truque usado hoje, só que
/// centralizado).
class AuthBackground extends StatelessWidget {
  final Widget child;
  final double overlayOpacity;
  const AuthBackground({super.key, required this.child, this.overlayOpacity = 0.72});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/imagem/imagem.png', fit: BoxFit.cover),
        Container(color: AppColors.bg.withOpacity(overlayOpacity)),
        child,
      ],
    );
  }
}
