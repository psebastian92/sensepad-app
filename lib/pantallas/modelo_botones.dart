import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../sensepad_estado.dart';

// ============================================================
// MODELO DE BOTONES
// ============================================================
//
// Es el mismo modelo que el wizard de la web (usuario-menu.jsp):
//
//   - 3 botones configurables (BTN1, BTN2 y BTN3).
//   - Cada botón tiene UN tipo: dir, call o msg.
//   - Un tipo no se puede repetir en dos botones.
//   - Cada botón tiene hasta MAX_OPCIONES opciones.
//
// Datos de cada opción según el tipo:
//   dir  -> apodo, dirección                    (2 datos)
//   call -> apodo, contacto, teléfono           (3 datos)
//   msg  -> apodo, contacto, teléfono, mensaje  (4 datos)
//
// Se guarda en el celular (SharedPreferences) como JSON,
// con las mismas claves que usa el JS de la web
// (type, items, n, f, c, tel, txt).
//
// Además se guarda en el servidor (ConfigBotonesServlet), asociada
// al dispositivo, para no perderla si se cambia de celular.

/// Servlet que guarda y devuelve la configuración en la base.
const String CONFIG_BOTONES_URL =
    'https://appsjavatest.fatimarem.edu.ar/sensepad/ConfigBotonesServlet';

// El id de la botonera sale de idDispositivoBotonera()
// (sensepad_estado.dart): SensePad_001 para la botonera original,
// SensePad_002 para la que se llama Sense002, etc.
//
// La configuración es de la cuenta de Google ('cuentaId', lo guarda
// la pantalla de bienvenida al iniciar sesión). La primera vez, el
// servidor vincula la botonera a esa cuenta.

/// Cuántas opciones puede tener cada botón.
const int MAX_OPCIONES = 4;

/// Cuántos botones se configuran (BTN1, BTN2 y BTN3).
const int CANT_BOTONES = 3;

const String TIPO_DIR = 'dir';
const String TIPO_CALL = 'call';
const String TIPO_MSG = 'msg';

const List<String> TIPOS = [TIPO_DIR, TIPO_CALL, TIPO_MSG];

const Map<String, String> NOMBRE_TIPO = {
  TIPO_DIR: 'Direcciones',
  TIPO_CALL: 'Llamadas',
  TIPO_MSG: 'Mensajes',
};

const Map<String, String> DESCRIPCION_TIPO = {
  TIPO_DIR: 'Lleva con Google Maps a una dirección',
  TIPO_CALL: 'Llama a un contacto',
  TIPO_MSG: 'Manda un WhatsApp con un texto fijo',
};


// ------------------------------------------------------------
// UNA OPCIÓN DENTRO DE UN BOTÓN
// ------------------------------------------------------------

class OpcionBoton {
  String apodo;     // n   -> lo que dice la botonera
  String direccion; // f   -> solo dir
  String contacto;  // c   -> call y msg
  String telefono;  // tel -> call y msg
  String texto;     // txt -> solo msg

  OpcionBoton({
    this.apodo = '',
    this.direccion = '',
    this.contacto = '',
    this.telefono = '',
    this.texto = '',
  });

  Map<String, dynamic> toJson() => {
        'n': apodo,
        'f': direccion,
        'c': contacto,
        'tel': telefono,
        'txt': texto,
      };

  factory OpcionBoton.fromJson(Map<String, dynamic> j) => OpcionBoton(
        apodo: '${j['n'] ?? ''}',
        direccion: '${j['f'] ?? ''}',
        contacto: '${j['c'] ?? ''}',
        telefono: '${j['tel'] ?? ''}',
        texto: '${j['txt'] ?? ''}',
      );

  /// Texto corto para mostrar debajo del apodo.
  String descripcion(String? tipo) {
    switch (tipo) {
      case TIPO_DIR:
        return direccion;
      case TIPO_CALL:
        return contacto.isEmpty ? telefono : '$contacto · $telefono';
      case TIPO_MSG:
        final quien = contacto.isEmpty ? telefono : contacto;
        return '$quien · "$texto"';
      default:
        return '';
    }
  }
}


// ------------------------------------------------------------
// UN BOTÓN
// ------------------------------------------------------------

class ConfigBoton {
  String? tipo; // null = botón vacío
  List<OpcionBoton> opciones;

  ConfigBoton({this.tipo, List<OpcionBoton>? opciones})
      : opciones = opciones ?? [];

  Map<String, dynamic> toJson() => {
        'type': tipo,
        'items': opciones.map((o) => o.toJson()).toList(),
      };

  factory ConfigBoton.fromJson(Map<String, dynamic> j) {
    final tipo = j['type'];
    final items = j['items'];

    return ConfigBoton(
      tipo: TIPOS.contains(tipo) ? tipo as String : null,
      opciones: items is List
          ? items
              .whereType<Map>()
              .map((m) => OpcionBoton.fromJson(Map<String, dynamic>.from(m)))
              .take(MAX_OPCIONES)
              .toList()
          : [],
    );
  }
}


// ------------------------------------------------------------
// GUARDAR Y CARGAR
// ------------------------------------------------------------

class AlmacenBotones {
  static const String _clave = 'configBotones';

  /// Avisa cada vez que se guarda una configuración nueva.
  /// La pantalla de la botonera lo escucha para recargar los botones.
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  static List<ConfigBoton> vacia() =>
      List.generate(CANT_BOTONES, (_) => ConfigBoton());

  static Future<List<ConfigBoton>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave);

    if (guardado == null) {
      return _migrarDireccionesViejas(prefs);
    }

    try {
      final lista = jsonDecode(guardado) as List;

      final botones = lista
          .whereType<Map>()
          .map((m) => ConfigBoton.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      while (botones.length < CANT_BOTONES) {
        botones.add(ConfigBoton());
      }

      return botones.take(CANT_BOTONES).toList();
    } catch (_) {
      return vacia();
    }
  }

  static Future<void> guardar(List<ConfigBoton> botones) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _clave,
      jsonEncode(botones.map((b) => b.toJson()).toList()),
    );

    // Queda marcado hasta que el servidor confirme.
    await prefs.setBool(_clavePendiente, true);

    // La botonera recarga en el momento.
    cambios.value++;

    // Se sube sin esperar, para no trabar la pantalla.
    _encolarSubida();
  }


  // ----------------------------------------------------------
  // SERVIDOR
  // ----------------------------------------------------------
  //
  // Reglas:
  //   - Cada vez que se guarda, se sube al servidor.
  //   - Si la subida falla, queda "pendiente" y se reintenta
  //     la próxima vez que arranca la app.
  //   - Al arrancar: si el servidor tiene configuración, se usa
  //     esa (caso celular nuevo). Si está vacío y el celular tiene
  //     algo, se sube (primera vez).
  //
  // Formato: una línea por opción, 8 campos separados por |
  //   boton|orden|tipo|apodo|contacto|telefono|direccion|mensaje

  static const String _clavePendiente = 'configBotonesPendiente';
  static const Duration _espera = Duration(seconds: 8);

  /// Último problema con el servidor (vacío si salió bien).
  /// Lo muestra el log de la pantalla de la botonera.
  static String ultimoAviso = '';

  // Datos que van en cada pedido. null = no hay sesión de Google.
  static Future<Map<String, String>?> _identidad() async {
    final prefs = await SharedPreferences.getInstance();
    final cuenta = prefs.getString('cuentaId');
    if (cuenta == null || cuenta.isEmpty) return null;
    return {
      'id_dispositivo': await idDispositivoBotonera(),
      'id_cuenta': cuenta,
    };
  }

  // Las subidas van de a una, para que no lleguen desordenadas.
  static Future<void> _cola = Future.value();

  static void _encolarSubida() {
    _cola = _cola.then((_) async {
      try {
        await _subirLoGuardado();
      } catch (e) {
        debugPrint('Error subiendo config: $e');
      }
    });
  }

  /// Sube lo que está guardado en el celular en este momento.
  static Future<bool> _subirLoGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final botones = await cargar();

    final datos = await _identidad();
    if (datos == null) {
      ultimoAviso = 'Sin sesión de Google: la config queda solo en el celular';
      await prefs.setBool(_clavePendiente, true);
      return false;
    }

    try {
      final r = await http.post(
        Uri.parse(CONFIG_BOTONES_URL),
        body: {
          ...datos,
          'config': _aTexto(botones),
        },
      ).timeout(_espera);

      if (r.statusCode == 200 && r.body.trim() == 'OK') {
        await prefs.setBool(_clavePendiente, false);
        ultimoAviso = '';
        debugPrint('Config botones subida al servidor');
        return true;
      }

      ultimoAviso = _mensajeError(r.body);
      debugPrint('Servidor rechazó config: ${r.statusCode} ${r.body}');
    } catch (e) {
      ultimoAviso = 'Sin conexión con el servidor';
      debugPrint('No se pudo subir config: $e');
    }

    await prefs.setBool(_clavePendiente, true);
    return false;
  }

  /// Se llama al arrancar la app.
  /// Devuelve true si trajo del servidor una configuración distinta
  /// a la del celular (hay que volver a cargar los botones).
  static Future<bool> sincronizar() async {
    final prefs = await SharedPreferences.getInstance();

    final datos = await _identidad();
    if (datos == null) {
      ultimoAviso = 'Sin sesión de Google: la config queda solo en el celular';
      return false;
    }

    // 1. Si quedó algo sin subir, primero se sube.
    if (prefs.getBool(_clavePendiente) ?? false) {
      final subio = await _subirLoGuardado();
      if (!subio) return false; // sin servidor: sigue lo del celular
    }

    // 2. Se trae lo del servidor.
    String? texto;
    try {
      final uri = Uri.parse(CONFIG_BOTONES_URL).replace(
        queryParameters: datos,
      );
      final r = await http.get(uri).timeout(_espera);

      if (r.statusCode != 200) {
        ultimoAviso = _mensajeError(utf8.decode(r.bodyBytes));
        debugPrint('Servidor config: ${r.statusCode} ${r.body}');
        return false;
      }
      texto = utf8.decode(r.bodyBytes).trim();
      ultimoAviso = '';
    } catch (e) {
      ultimoAviso = 'Sin conexión con el servidor';
      debugPrint('No se pudo traer config: $e');
      return false;
    }
    if (texto == null) return false;

    final locales = await cargar();

    // 3. Servidor vacío: si el celular tiene algo, se sube.
    if (texto.isEmpty) {
      if (_aTexto(locales).isNotEmpty) {
        await _subirLoGuardado();
      }
      return false;
    }

    // 4. Servidor con datos: se usan, salvo que sean iguales.
    final remotos = _desdeTexto(texto);
    if (_aTexto(remotos) == _aTexto(locales)) return false;

    await prefs.setString(
      _clave,
      jsonEncode(remotos.map((b) => b.toJson()).toList()),
    );
    return true;
  }

  /// Se llama al cerrar sesión: la config de una cuenta
  /// no tiene que pasar a la siguiente que entre en este celular.
  static Future<void> olvidarLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
    await prefs.remove(_clavePendiente);
    await prefs.remove('direcciones');
    await prefs.remove('nombresDirecciones');
  }

  // "ERROR|dispositivo vinculado a otra cuenta" -> el texto.
  static String _mensajeError(String cuerpo) {
    final t = cuerpo.trim();
    return t.startsWith('ERROR|') ? t.substring(6) : 'Error del servidor';
  }

  // Botones -> líneas de texto para el servidor.
  static String _aTexto(List<ConfigBoton> botones) {
    final lineas = <String>[];

    for (var i = 0; i < botones.length; i++) {
      final b = botones[i];
      if (b.tipo == null) continue;

      for (var j = 0; j < b.opciones.length; j++) {
        final o = b.opciones[j];
        lineas.add([
          '${i + 1}',
          '${j + 1}',
          b.tipo!,
          _limpiar(o.apodo),
          _limpiar(o.contacto),
          _limpiar(o.telefono),
          _limpiar(o.direccion),
          _limpiar(o.texto),
        ].join('|'));
      }
    }

    return lineas.join('\n');
  }

  // Líneas del servidor -> botones.
  static List<ConfigBoton> _desdeTexto(String texto) {
    final botones = vacia();

    for (final linea in texto.split('\n')) {
      final c = linea.trim().split('|');
      if (c.length != 8) continue;

      final boton = int.tryParse(c[0]) ?? 0;
      final tipo = c[2];
      if (boton < 1 || boton > CANT_BOTONES || !TIPOS.contains(tipo)) {
        continue;
      }

      final b = botones[boton - 1];
      b.tipo = tipo;
      if (b.opciones.length >= MAX_OPCIONES) continue;

      b.opciones.add(OpcionBoton(
        apodo: c[3],
        contacto: c[4],
        telefono: c[5],
        direccion: c[6],
        texto: c[7],
      ));
    }

    return botones;
  }

  // El | y los saltos de línea romperían el formato.
  static String _limpiar(String s) =>
      s.replaceAll('|', '/').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  // Si había direcciones guardadas con el sistema anterior
  // ('direcciones' y 'nombresDirecciones'), las pasa al botón 1.
  static List<ConfigBoton> _migrarDireccionesViejas(
    SharedPreferences prefs,
  ) {
    final botones = vacia();

    final dirs = prefs.getStringList('direcciones') ?? [];
    final nombres = prefs.getStringList('nombresDirecciones') ?? [];

    if (dirs.isNotEmpty) {
      botones[0].tipo = TIPO_DIR;

      for (var i = 0; i < dirs.length && i < MAX_OPCIONES; i++) {
        final nombre =
            i < nombres.length && nombres[i].trim().isNotEmpty
                ? nombres[i]
                : dirs[i];

        botones[0].opciones.add(
              OpcionBoton(apodo: nombre, direccion: dirs[i]),
            );
      }
    }

    return botones;
  }
}