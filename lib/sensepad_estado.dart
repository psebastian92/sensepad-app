import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================

const String RECIBIR_ESTADO_URL =
    'https://appsjavatest.fatimarem.edu.ar/sensepad/RecibirEstado';

const String ID_DISPOSITIVO_ESTADO = 'SensePad_001';

// ============================================================
// QUÉ BOTONERA USA ESTE CELULAR
// ============================================================
//
// Sale del nombre que se escribe en la primera pantalla
// ("Ingresá el nombre de tu botonera"):
//
//   - "Sense" + 3 números (ej. Sense002): se busca la botonera
//     con ese nombre Bluetooth y en el servidor es SensePad_002.
//   - Cualquier otro nombre (celulares que ya tenían uno): se usa
//     la botonera original, nombre Bluetooth "SensePad", id SensePad_001.
//
// Los nombres tienen 8 letras, como "SensePad", porque el anuncio
// Bluetooth (con el UUID del servicio) no tiene lugar para más.

const String NOMBRE_BLE_ORIGINAL = 'SensePad';

final RegExp _nombreNumerado = RegExp(r'^sense(\d{3})$', caseSensitive: false);

Future<String> nombreBleBotonera() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // el servicio corre aparte; leer lo último
  final nombre = (prefs.getString('nombreBotonera') ?? '').trim();
  final m = _nombreNumerado.firstMatch(nombre);
  return m != null ? 'Sense${m.group(1)}' : NOMBRE_BLE_ORIGINAL;
}

Future<String> idDispositivoBotonera() async {
  final nombre = await nombreBleBotonera();
  return nombre == NOMBRE_BLE_ORIGINAL
      ? ID_DISPOSITIVO_ESTADO
      : 'SensePad_${nombre.substring(5)}';
}

// ============================================================

// Muestra el mensaje en la consola y en el log verde de la app.
void _log(String texto) {
  final linea = '[Estado] $texto';
  print(linea);
  try {
    FlutterForegroundTask.sendDataToMain(linea);
  } catch (_) {}
}

// Lleva el estado del SensePad (batería, standby, conexión)
// y lo informa al servidor para que lo vea el familiar.
class EstadoSensePadReporter {
  EstadoSensePadReporter._();
  static final EstadoSensePadReporter instancia = EstadoSensePadReporter._();

  // Lo completa el servicio al arrancar (idDispositivoBotonera).
  String idDispositivo = ID_DISPOSITIVO_ESTADO;

  int? nivelBateria;            // 100, 75, 50, 25, 0 o null
  bool cargando = false;
  bool enStandby = false;
  String estadoConexion = 'desconectado';   // conectado | standby | desconectado

  String? _ultimoEnviado;
  Timer? _latido;
  Timer? _esperaStandby;

  // ---------- 1. Cada mensaje que llega por BLE ----------

  void alRecibir(String mensaje) {
    final m = mensaje.trim();
    final partes = m.split('|');

    switch (partes.first) {
      case 'BATERIA':
        _log('recibió $m');
        if (partes.length > 1 && partes[1] == 'cargando') {
          cargando = true;
        } else {
          cargando = false;
          for (final p in partes.skip(1)) {
            if (p.startsWith('nivel=')) {
              nivelBateria = int.tryParse(p.substring(6));
            }
          }
        }
        _informar();
        break;

      case 'STANDBY':
        _log('recibió $m');
        enStandby = true;
        estadoConexion = 'standby';
        _latido?.cancel();
        _informar();
        break;
    }
  }

  // ---------- 2. Después de setNotifyValue(true) ----------

  Future<void> alConectar(BluetoothCharacteristic caracteristica) async {
    _log('conectado, pidiendo batería');

    enStandby = false;
    _esperaStandby?.cancel();

    try {
      await caracteristica.write(utf8.encode('PEDIR_BATERIA'));
    } catch (e) {
      _log('no se pudo pedir la batería: $e');
    }

    // Si en 3 s no llegó STANDBY|true, está despierto de verdad.
    _esperaStandby = Timer(const Duration(seconds: 3), () {
      if (enStandby) {
        _log('conexión breve de standby, no se informa');
        return;
      }

      estadoConexion = 'conectado';
      _informar();

      _latido?.cancel();
      _latido = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _informar(forzar: true),
      );
    });
  }

  // ---------- 3. Al desconectarse ----------
  // Devuelve true si fue una desconexión inesperada (posible pérdida).

  bool alDesconectar() {
    _esperaStandby?.cancel();
    _latido?.cancel();

    final inesperada = !enStandby;
    estadoConexion = inesperada ? 'desconectado' : 'standby';

    _log('desconexión (${inesperada ? 'inesperada' : 'por standby'})');

    _informar();
    return inesperada;
  }

  // ---------- Envío al servidor ----------

  Future<void> _informar({bool forzar = false}) async {
    final clave = '$estadoConexion|${nivelBateria ?? -1}|$cargando';

    if (!forzar && clave == _ultimoEnviado) return;   // sin cambios
    _ultimoEnviado = clave;

    final uri = Uri.parse(RECIBIR_ESTADO_URL).replace(queryParameters: {
      'dispositivo': idDispositivo,
      'nivel': '${nivelBateria ?? -1}',
      'cargando': cargando ? '1' : '0',
      'estado': estadoConexion,
    });

    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      _log('enviado $clave -> ${r.body.trim()}');
    } catch (e) {
      _log('no se pudo enviar $clave: $e');
      _ultimoEnviado = null;   // se reintenta en el próximo cambio
    }
  }
}