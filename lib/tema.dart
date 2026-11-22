import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// PALETA (de styles.css)
// ============================================================
class SP {
  static const navy = Color(0xFF1E3048);
  static const navySoft = Color(0xFF2C4460);
  static const coral = Color(0xFFC4715A);
  static const coralDeep = Color(0xFFA85940);
  static const cream = Color(0xFFFAF5F0);
  static const creamDim = Color(0xFFF1E9E1);
  static const ink = Color(0xFF2A2420);
  static const ok = Color(0xFF3F7D5C);
  static const danger = Color(0xFFB3382C);

  static const borderSoft = Color(0x141E3048); // 8%
  static const borderMid = Color(0x1F1E3048); // 12%
  static const borderStrong = Color(0x381E3048); // 22%

  /// Borde por defecto de botones y tarjetas con contorno.
  static const border = borderStrong;

  static const coralTint = Color(0x1AC4715A); // 10%
  static const coralTint2 = Color(0x59C4715A); // 35%
  static const okTint = Color(0x1A3F7D5C);
  static const okTint2 = Color(0x663F7D5C);
}

/// Compatibilidad: las pantallas que ya escriben `C.navy` siguen andando.
class C {
  static const navy = SP.navy;
  static const navySoft = SP.navySoft;
  static const coral = SP.coral;
  static const coralDeep = SP.coralDeep;
  static const cream = SP.cream;
  static const creamDim = SP.creamDim;
  static const ink = SP.ink;
  static const ok = SP.ok;
  static const danger = SP.danger;

  static const borderSoft = SP.borderSoft;
  static const borderMid = SP.borderMid;
  static const borderStrong = SP.borderStrong;
  static const border = SP.border;

  static const coralTint = SP.coralTint;
  static const coralTint2 = SP.coralTint2;
  static const okTint = SP.okTint;
  static const okTint2 = SP.okTint2;
}

/// Tipografía serif (títulos) = DM Serif Display
TextStyle serif(double size, {Color color = SP.navy, bool italic = false}) =>
    GoogleFonts.dmSerifDisplay(
      fontSize: size,
      color: color,
      height: 1.2,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );

ThemeData temaSensePad() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: SP.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SP.coral,
        primary: SP.coral,
        onPrimary: Colors.white,
        surface: SP.cream,
      ),
      textTheme: GoogleFonts.manropeTextTheme()
          .apply(bodyColor: SP.ink, displayColor: SP.navy),

      // Botón principal coral, alto cómodo para uso con poca visión.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: SP.coral,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // Botón secundario blanco con borde.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: SP.navy,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: SP.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: SP.cream,
        foregroundColor: SP.navy,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: SP.navy,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SP.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SP.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SP.coral, width: 2),
        ),
      ),
    );

/// Envuelve una pantalla con el tema claro de SensePad
/// (así no se mezcla con el tema oscuro del MaterialApp).
class TemaSP extends StatelessWidget {
  final Widget child;
  const TemaSP({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Theme(data: temaSensePad(), child: child);
}

// ============================================================
// WIDGETS COMUNES
// ============================================================

/// .brand-mark (cuadrado navy con punto coral)
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SP.navy,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Stack(children: [
        Positioned(
          top: size * 0.19,
          right: size * 0.19,
          child: Container(
            width: dot,
            height: dot,
            decoration:
                const BoxDecoration(color: SP.coral, shape: BoxShape.circle),
          ),
        ),
      ]),
    );
  }
}

/// Solo el texto "SensePad" (Sense navy + Pad coral), al tamaño que se pida.
class SensePadMark extends StatelessWidget {
  final double size;
  const SensePadMark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) => RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.manrope(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: SP.navy,
            height: 1.15,
          ),
          children: [
            const TextSpan(text: 'Sense'),
            TextSpan(
              text: 'Pad',
              style: GoogleFonts.manrope(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: SP.coral,
                height: 1.15,
              ),
            ),
          ],
        ),
      );
}

/// .brand (marca + "SensePad")
class Marca extends StatelessWidget {
  const Marca({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(),
          SizedBox(width: 12),
          SensePadMark(size: 17.6),
        ],
      );
}

/// .eyebrow (pastilla con punto)
class Eyebrow extends StatelessWidget {
  final String texto;
  final bool coral;
  const Eyebrow(this.texto, {super.key, this.coral = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: SP.borderStrong),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: coral ? SP.coral : SP.ok, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            texto.toUpperCase(),
            style: GoogleFonts.manrope(
                fontSize: 12.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: SP.navySoft),
          ),
        ]),
      );
}

/// .page-head (eyebrow + título serif + subtítulo)
class CabeceraPagina extends StatelessWidget {
  final String eyebrow;
  final String titulo;
  final String? tituloCoral; // parte en <em>
  final String subtitulo;
  const CabeceraPagina({
    super.key,
    required this.eyebrow,
    required this.titulo,
    this.tituloCoral,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(eyebrow),
          const SizedBox(height: 18),
          RichText(
            text: TextSpan(style: serif(32), children: [
              TextSpan(text: titulo),
              if (tituloCoral != null)
                TextSpan(
                    text: tituloCoral,
                    style: serif(32, color: SP.coral, italic: true)),
            ]),
          ),
          const SizedBox(height: 6),
          Text(subtitulo,
              style: GoogleFonts.manrope(fontSize: 16, color: SP.navySoft)),
        ]),
      );
}

/// .card
class TarjetaSP extends StatelessWidget {
  final String? titulo;
  final IconData? icono;
  final Widget child;
  const TarjetaSP({super.key, this.titulo, this.icono, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: SP.borderSoft),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (titulo != null) ...[
            Row(children: [
              if (icono != null) ...[
                Icon(icono, size: 20, color: SP.coral),
                const SizedBox(width: 10),
              ],
              Text(titulo!,
                  style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: SP.navy)),
            ]),
            const SizedBox(height: 16),
          ],
          child,
        ]),
      );
}

/// .opt-btn (botón grande coral / secundario)
class BotonSP extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback onPressed;
  final bool secundario;
  const BotonSP(this.texto,
      {super.key,
      required this.onPressed,
      this.icono,
      this.secundario = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: icono != null ? Icon(icono, size: 20) : const SizedBox.shrink(),
          label: Text(texto,
              style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: secundario ? Colors.white : SP.coral,
            foregroundColor: secundario ? SP.navy : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: secundario ? SP.borderStrong : Colors.transparent,
                  width: 1.5),
            ),
          ),
        ),
      );
}