import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show PantallaExtravio;
import '../tema.dart';
import 'bienvenida.dart' show PantallaBienvenida;
import 'usuario_botones.dart';

// usuario-menu.jsp
// Desde acá se llega a las funciones principales del modo usuario.
// Se abre ENCIMA de la pantalla de la botonera, que queda debajo
// conectada y atendiendo los botones.
class UsuarioMenu extends StatelessWidget {
  const UsuarioMenu({super.key});

  // Vuelve a la bienvenida: corta el servicio y olvida el modo usuario.
  Future<void> _salirModoUsuario(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('modoInicio');

    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PantallaBienvenida()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TemaSP(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: C.cream,
          elevation: 0,
          title: const Marca(),
          iconTheme: const IconThemeData(color: C.navy),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const CabeceraPagina(
              eyebrow: 'Modo usuario',
              titulo: 'Tu ',
              tituloCoral: 'SensePad',
              subtitulo: 'Elegí qué querés hacer.',
            ),
            _Opcion(
              icono: Icons.bluetooth_connected,
              titulo: 'Conexión de la botonera',
              detalle: 'Volver a la pantalla de conexión',
              // La pantalla de la botonera ya está abierta debajo:
              // se vuelve a ella, no se abre otra.
              onTap: () => Navigator.pop(context),
            ),
            _Opcion(
              icono: Icons.touch_app_outlined,
              titulo: 'Configurar botones',
              detalle: '',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PantallaConfigBotones(),
                ),
              ),
            ),
            _Opcion(
              icono: Icons.bluetooth_searching,
              titulo: 'Extravío',
              detalle: 'Buscá tu SensePad',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PantallaExtravio(),
                ),
              ),
            ),
            _Opcion(
              icono: Icons.logout,
              titulo: 'Salir del modo usuario',
              detalle: 'Desconecta la botonera y vuelve al inicio',
              onTap: () => _salirModoUsuario(context),
            ),
          ],
        ),
      ),
    );
  }
}

// .w-opt
class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo, detalle;
  final VoidCallback onTap;

  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: C.borderStrong, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: C.creamDim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icono, color: C.coralDeep, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: GoogleFonts.manrope(
                            fontSize: 16.8,
                            fontWeight: FontWeight.w700,
                            color: C.navy,
                          ),
                        ),
                        Text(
                          detalle,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: C.navySoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}