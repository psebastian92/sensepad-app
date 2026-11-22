import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '/tema.dart';
import '../main.dart' show PantallaBotonera;
import 'familiar/familiar_shell.dart';
import 'modelo_botones.dart';

// ============================================================
// CONFIG GOOGLE
// ============================================================

// Client ID tipo "Web" de Google Cloud (NO el de Android).
const String GOOGLE_WEB_CLIENT_ID =
    '367890286133-8ao58in9rnrrnc2ade8krih9cc82kkk2.apps.googleusercontent.com';

const String GOOGLE_LOGIN_URL =
    'https://appsjavatest.fatimarem.edu.ar/sensepad/GoogleLogin';

// bienvenida.jsp
class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  static bool _googleInicializado = false;

  String? _cuentaNombre;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarSesion();
  }

  Future<void> _cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _cuentaNombre = prefs.getString('cuentaNombre');
    });
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _loginGoogle() async {
    if (_cargando) return;
    setState(() => _cargando = true);

    try {
      if (!_googleInicializado) {
        await GoogleSignIn.instance.initialize(
          serverClientId: GOOGLE_WEB_CLIENT_ID,
        );
        _googleInicializado = true;
      }

      final cuenta = await GoogleSignIn.instance.authenticate();
      final idToken = cuenta.authentication.idToken;

      if (idToken == null) {
        _aviso('No se pudo obtener el token de Google.');
        return;
      }

      final r = await http.post(
        Uri.parse(GOOGLE_LOGIN_URL),
        body: {'idToken': idToken},
      );

      if (r.statusCode != 200) {
        debugPrint('Estado del servidor: ${r.statusCode}');
        debugPrint('Respuesta: ${r.body}');

         _aviso('Error ${r.statusCode}: ${r.body}');
         return;
      }

      // Respuesta: "id|nombre"
      final texto = r.body.trim();
      final i = texto.indexOf('|');
      final id = i == -1 ? texto : texto.substring(0, i);
      final nombre = i == -1 ? '' : texto.substring(i + 1);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cuentaId', id);
      await prefs.setString('cuentaNombre', nombre);

      if (!mounted) return;
      setState(() => _cuentaNombre = nombre);
    } on GoogleSignInException catch (e) {
      // Cancelado por el usuario u otro error de Google
      _aviso('Google: ${e.code.name} ${e.description ?? ''}');
    } catch (e) {
      _aviso('Error al iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // "Soy usuario" necesita la cuenta de Google: la botonera y
  // su configuración quedan vinculadas a esa cuenta.
  Future<bool> _exigirSesion() async {
    if (_cuentaNombre == null) {
      _aviso('Para usar tu SensePad, primero iniciá sesión con Google.');
      await _loginGoogle();
      if (_cuentaNombre == null) return false;
    }

    // La próxima vez que se abra la app, va directo a la botonera.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('modoInicio', 'usuario');
    return true;
  }

  Future<void> _cerrarSesion() async {
    try {
      if (_googleInicializado) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cuentaId');
    await prefs.remove('cuentaNombre');
    await prefs.remove('modoInicio');

    // La config de botones es de la cuenta: no pasa a la próxima.
    await AlmacenBotones.olvidarLocal();

    if (!mounted) return;
    setState(() => _cuentaNombre = null);
  }

  @override
  Widget build(BuildContext context) {
    return TemaSP(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: CustomScrollView(slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Marca(),
                        const Spacer(),
                        const Eyebrow('Aplicación SensePad'),
                        const SizedBox(height: 14),
                        Semantics(
                          header: true,
                          child: RichText(
                            text: TextSpan(style: serif(40), children: [
                              const TextSpan(text: 'Bienvenido a '),
                              TextSpan(
                                  text: 'SensePad.',
                                  style: serif(40, color: C.coral, italic: true)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Elegí cómo querés ingresar.',
                            style: GoogleFonts.manrope(
                                fontSize: 17.6, color: C.navySoft)),
                        const SizedBox(height: 24),
                        _BloqueGoogle(
                          nombre: _cuentaNombre,
                          cargando: _cargando,
                          onLogin: _loginGoogle,
                          onLogout: _cerrarSesion,
                        ),
                        const SizedBox(height: 24),
                        _TarjetaModo(
                          icono: Icons.home_outlined,
                          prefijo: 'Soy ',
                          resaltado: 'familiar',
                          descripcion:
                              'Ubicación, batería y alarmas del SensePad.',
                          cta: 'Entrar al panel →',
                          destino: const FamiliarShell(),
                        ),
                        const SizedBox(height: 18),
                        _TarjetaModo(
                          icono: Icons.touch_app_outlined, // ti-hand-finger
                          prefijo: 'Soy ',
                          resaltado: 'usuario',
                          descripcion:
                              'Configurar botones y extravío. Se ingresa con Google.',
                          cta: 'Conectar mi SensePad →',
                          destino: const PantallaBotonera(),
                          antesDeEntrar: _exigirSesion,
                          // La botonera queda como base de la app.
                          comoBase: true,
                        ),
                        const Spacer(),
                        Center(
                          child: Text(
                            '© 2026 SensePad · Tecnología asistiva con propósito.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                                fontSize: 14, color: C.navySoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// Botón "Continuar con Google" o "Hola, Nombre" + "Cerrar sesión"
class _BloqueGoogle extends StatelessWidget {
  final String? nombre;
  final bool cargando;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const _BloqueGoogle({
    required this.nombre,
    required this.cargando,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final conSesion = nombre != null;

    if (conSesion) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: C.borderSoft, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.account_circle_outlined, color: C.navy, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre!.isEmpty ? 'Sesión iniciada' : 'Hola, $nombre',
              style: GoogleFonts.manrope(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: C.navy),
            ),
          ),
          TextButton(
            onPressed: onLogout,
            child: Text('Cerrar sesión',
                style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: C.coralDeep)),
          ),
        ]),
      );
    }

    return Semantics(
      button: true,
      label: 'Continuar con Google',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: cargando ? null : onLogin,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: C.borderStrong, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cargando)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  const Icon(Icons.login, color: C.navy, size: 22),
                const SizedBox(width: 12),
                Text(
                  cargando ? 'Conectando...' : 'Continuar con Google',
                  style: GoogleFonts.manrope(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: C.navy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// .mode-card
class _TarjetaModo extends StatelessWidget {
  final IconData icono;
  final String prefijo, resaltado, descripcion, cta;
  final Widget destino;

  // Si devuelve false, no se entra (ej. no inició sesión).
  final Future<bool> Function()? antesDeEntrar;

  // true: el destino reemplaza a todas las pantallas (no se vuelve atrás).
  final bool comoBase;

  const _TarjetaModo({
    required this.icono,
    required this.prefijo,
    required this.resaltado,
    required this.descripcion,
    required this.cta,
    required this.destino,
    this.antesDeEntrar,
    this.comoBase = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$prefijo$resaltado. $descripcion',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final control = antesDeEntrar;
            if (control != null && !await control()) return;
            if (!context.mounted) return;
            final ruta = MaterialPageRoute(builder: (_) => destino);
            if (comoBase) {
              Navigator.pushAndRemoveUntil(context, ruta, (_) => false);
            } else {
              Navigator.push(context, ruta);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              border: Border.all(color: C.borderSoft, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: C.navy, borderRadius: BorderRadius.circular(18)),
                child: Stack(children: [
                  Center(child: Icon(icono, color: Colors.white, size: 30)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: C.coral, shape: BoxShape.circle),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(style: serif(24), children: [
                          TextSpan(text: prefijo),
                          TextSpan(
                              text: resaltado,
                              style: serif(24, color: C.coral, italic: true)),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text(descripcion,
                          style: GoogleFonts.manrope(
                              fontSize: 15.5, color: C.navySoft)),
                      const SizedBox(height: 8),
                      Text(cta,
                          style: GoogleFonts.manrope(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: C.coralDeep)),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}