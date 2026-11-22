import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'tema.dart';
import 'sensepad_estado.dart';
import 'pantallas/modelo_botones.dart';
import 'pantallas/bienvenida.dart';
import 'pantallas/usuario_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';


// ============================================================
// CONFIGURACIÓN
// ============================================================

const String SERVLET_URL =
    'https://appsjavatest.fatimarem.edu.ar/sensepad/ConfigServlet';

const String RECIBIR_UBI_URL =
    'https://appsjavatest.fatimarem.edu.ar/sensepad/RecibirUbi';

const String RECIBIR_SOS_URL =
    'https://appsjavatest.fatimarem.edu.ar/sensepad/RecibirSOS';

const String NOMBRE_BOTONERA = 'SensePad';

const String SERVICE_UUID =
    '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

const String BUTTON_UUID =
    'beb5483e-36e1-4688-b7f5-ea07361b26a8';

const String CONFIG_UUID =
    '12345678-1234-1234-1234-123456789abc';


// ============================================================
// FOREGROUND SERVICE
// ============================================================

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(
    BotoneraTaskHandler(),
  );
}


// ============================================================
// TASK HANDLER
// ============================================================

class BotoneraTaskHandler extends TaskHandler {

  BluetoothDevice? dispositivo;

  BluetoothCharacteristic? caracteristica;

  StreamSubscription? scanSubscription;

  StreamSubscription? valueSubscription;

  StreamSubscription? connectionSubscription;

  bool conectando = false;

  bool conectado = false;

  bool escaneando = false;

  // Modo especial de búsqueda del SensePad.
  bool modoBusqueda = false;

  // La desconexión posterior a STANDBY|true es esperada.
  bool desconexionPorStandby = false;

  DateTime? ultimoEvento;

  String ultimoBoton = '';

  // Nombre Bluetooth de la botonera de este celular.
  String nombreBle = NOMBRE_BOTONERA;


  // ----------------------------------------------------------
  // INICIO DEL SERVICIO
  // ----------------------------------------------------------

  @override
  Future<void> onStart(
    DateTime timestamp,
    TaskStarter starter,
  ) async {

    FlutterForegroundTask.sendDataToMain(
      'SERVICIO SENSEPAD INICIADO',
    );

    try {
      nombreBle = await nombreBleBotonera();
      EstadoSensePadReporter.instancia.idDispositivo =
          await idDispositivoBotonera();
    } catch (e) {
      FlutterForegroundTask.sendDataToMain(
        'No se pudo leer la botonera elegida: $e',
      );
    }

    FlutterForegroundTask.sendDataToMain(
      'Botonera de este celular: $nombreBle '
      '(${EstadoSensePadReporter.instancia.idDispositivo})',
    );

    await conectarBluetooth();
  }


  // ----------------------------------------------------------
  // EVENTO REPETITIVO
  // ----------------------------------------------------------

  @override
  void onRepeatEvent(
    DateTime timestamp,
  ) {
    // No necesitamos hacer nada acá.
    //
    // El Bluetooth funciona mediante las
    // notificaciones de la característica.
  }


  // ----------------------------------------------------------
  // RECIBIR DATOS DESDE LA APP
  // ----------------------------------------------------------

  @override
  void onReceiveData(
    Object data,
  ) {

    final mensaje =
        data.toString();

    if (mensaje == 'reconectar') {
      FlutterForegroundTask.sendDataToMain(
        'Solicitud de reconexión recibida',
      );
      reconectar();
      return;
    }

    if (mensaje == 'BUSCAR_INICIAR') {
      modoBusqueda = true;
      desconexionPorStandby = false;

      FlutterForegroundTask.sendDataToMain(
        'MODO_BUSQUEDA',
      );

      if (conectado && caracteristica != null) {
        _enviarComando('BUSCAR_INICIAR');
      } else if (escaneando) {
        // Reinicia el escaneo usando baja latencia.
        try {
          FlutterBluePlus.stopScan();
        } catch (_) {}
        escaneando = false;
        conectando = false;
        conectarBluetooth();
      } else if (!conectando) {
        // Si ya está conectando, el método de conexión enviará
        // BUSCAR_INICIAR apenas termine de habilitar Notify.
        conectarBluetooth();
      }
      return;
    }

    if (mensaje == 'BUSCAR_DETENER') {
      modoBusqueda = false;

      if (conectado && caracteristica != null) {
        _enviarComando('BUSCAR_DETENER');
      }

      FlutterForegroundTask.sendDataToMain(
        'BUSQUEDA_DETENIDA_LOCAL',
      );
      return;
    }

    if (mensaje == 'PEDIR_BATERIA' ||
        mensaje == 'PEDIR_TIEMPO') {
      _enviarComando(mensaje);
      return;
    }
  }


  // ----------------------------------------------------------
  // BUSCAR BLUETOOTH
  // ----------------------------------------------------------

  Future<void> conectarBluetooth() async {

    if (conectando || conectado) {
      return;
    }

    conectando = true;

    escaneando = true;

    FlutterForegroundTask.sendDataToMain(
      'Buscando $nombreBle...',
    );

    try {

      await FlutterBluePlus.stopScan();

      await scanSubscription?.cancel();

      scanSubscription =
          FlutterBluePlus.scanResults.listen(
        (resultados) async {

          for (final resultado
              in resultados) {

            // Primero el nombre que anuncia ahora (advName).
            // platformName puede ser uno viejo que Android
            // guardó en caché antes de cambiar el firmware.
            final nombre =
                resultado.advertisementData.advName.isNotEmpty
                    ? resultado
                        .advertisementData
                        .advName
                    : resultado.device.platformName;

            FlutterForegroundTask
                .sendDataToMain(
              'Dispositivo encontrado: $nombre',
            );

            if (nombre ==
                nombreBle) {

              if (!escaneando) {
                return;
              }

              escaneando = false;

              await FlutterBluePlus
                  .stopScan();

              await scanSubscription
                  ?.cancel();

              scanSubscription = null;

              await _conectarDispositivo(
                resultado.device,
              );

              return;
            }
          }
        },
      );
         await FlutterBluePlus.startScan(
          timeout: Duration(seconds: modoBusqueda ? 60 : 15),
          androidScanMode: modoBusqueda
            ? AndroidScanMode.lowLatency
             : AndroidScanMode.lowPower,
          );
      await Future.delayed(
        Duration(seconds: modoBusqueda ? 61 : 16),
      );

      if (!conectado) {

        escaneando = false;

        await FlutterBluePlus.stopScan();

        FlutterForegroundTask
            .sendDataToMain(
          'No se encontró $nombreBle',
        );

        conectando = false;

        await Future.delayed(
          const Duration(seconds: 3),
        );

        if (!conectado) {
          conectarBluetooth();
        }
      }

    } catch (e) {

      FlutterForegroundTask.sendDataToMain(
        'Error Bluetooth: $e',
      );

      conectando = false;

      escaneando = false;

      await Future.delayed(
        const Duration(seconds: 3),
      );

      conectarBluetooth();
    }
  }


  // ----------------------------------------------------------
  // CONECTAR DISPOSITIVO
  // ----------------------------------------------------------

  Future<void> _conectarDispositivo(
    BluetoothDevice device,
  ) async {

    try {

      FlutterForegroundTask.sendDataToMain(
        'Conectando a $nombreBle...',
      );

      dispositivo = device;

      await device.connect(
        timeout:
            const Duration(seconds: 15),
        autoConnect: false,
      );

      FlutterForegroundTask.sendDataToMain(
        'Bluetooth conectado',
      );

      final servicios =
          await device.discoverServices();

      BluetoothCharacteristic?
          encontrada;

      for (final servicio
          in servicios) {

        if (servicio.uuid
                .toString()
                .toLowerCase() ==
            SERVICE_UUID.toLowerCase()) {

          for (final c
              in servicio.characteristics) {

            if (c.uuid
                    .toString()
                    .toLowerCase() ==
                BUTTON_UUID.toLowerCase()) {

              encontrada = c;

              break;
            }
          }
        }

        if (encontrada != null) {
          break;
        }
      }

      if (encontrada == null) {

        FlutterForegroundTask
            .sendDataToMain(
          'No se encontró la característica de botones',
        );

        await device.disconnect();

        conectando = false;

        await Future.delayed(
          const Duration(seconds: 2),
        );

        conectarBluetooth();

        return;
      }

      caracteristica = encontrada;

      // Primero dejamos preparado el stream y luego activamos Notify.
      await valueSubscription?.cancel();

      valueSubscription = caracteristica!
          .onValueReceived
          .listen((bytes) {
        if (bytes.isEmpty) return;

        final mensaje =
            String.fromCharCodes(bytes).trim();

        if (mensaje.isEmpty) return;

        recibirBoton(mensaje);
      });

      if (caracteristica!.properties.notify) {
        await caracteristica!.setNotifyValue(true);
      }

      conectado = true;
      conectando = false;

      // El firmware espera BUSCAR_INICIAR dentro de los primeros 2 s.
      if (modoBusqueda) {
        await _enviarComando('BUSCAR_INICIAR');
      }

      await EstadoSensePadReporter.instancia.alConectar(caracteristica!);

      FlutterForegroundTask.sendDataToMain(
        'CONECTADO',
      );

      await connectionSubscription
          ?.cancel();

      connectionSubscription =
          device.connectionState.listen(
        (estado) async {

          if (estado ==
              BluetoothConnectionState
                  .disconnected) {

            EstadoSensePadReporter.instancia.alDesconectar();

            conectado = false;
            conectando = false;
            caracteristica = null;

            await valueSubscription?.cancel();
            valueSubscription = null;

            if (desconexionPorStandby) {
              // Desconexión normal: no registrar pérdida ni avisar al familiar.
              desconexionPorStandby = false;
            } else {
              FlutterForegroundTask.sendDataToMain(
                'Botonera desconectada',
              );
            }

            await Future.delayed(
              const Duration(seconds: 2),
            );

            conectarBluetooth();
          }
        },
      );

    } catch (e) {

      FlutterForegroundTask
          .sendDataToMain(
        'Error al conectar: $e',
      );

      conectado = false;

      conectando = false;

      try {
        await device.disconnect();
      } catch (_) {}

      await Future.delayed(
        const Duration(seconds: 3),
      );

      conectarBluetooth();
    }
  }


  // ----------------------------------------------------------
  // RECIBIR BOTÓN
  // ----------------------------------------------------------

  void recibirBoton(
    String mensaje,
  ) {
    EstadoSensePadReporter.instancia.alRecibir(mensaje);
    // Mensajes de control del firmware: no son pulsaciones normales.
    if (mensaje == 'STANDBY|true') {
      desconexionPorStandby = true;
      FlutterForegroundTask.sendDataToMain('STANDBY');
      return;
    }

    if (mensaje.startsWith('BUSQUEDA|')) {
      final estado = mensaje.substring('BUSQUEDA|'.length).trim();

      if (estado == 'true') {
        FlutterForegroundTask.sendDataToMain('BUSQUEDA_INICIADA');
      } else if (estado == 'encontrado') {
        modoBusqueda = false;
        FlutterForegroundTask.sendDataToMain('BUSQUEDA_ENCONTRADO');
      } else if (estado == 'tiempo') {
        modoBusqueda = false;
        FlutterForegroundTask.sendDataToMain('BUSQUEDA_TIEMPO');
      } else if (estado == 'app') {
        modoBusqueda = false;
        FlutterForegroundTask.sendDataToMain('BUSQUEDA_DETENIDA');
      }
      return;
    }

    if (mensaje.startsWith('BATERIA|') ||
        mensaje.startsWith('TIEMPO|') ||
        mensaje.startsWith('STANDBY|')) {
      FlutterForegroundTask.sendDataToMain(mensaje);
      return;
    }

    // El resto de mensajes se considera una pulsación física.
    final ahora = DateTime.now();

    if (ultimoBoton == mensaje &&
        ultimoEvento != null &&
        ahora.difference(ultimoEvento!).inMilliseconds < 2000) {
      FlutterForegroundTask.sendDataToMain(
        'Ignorado (debounce): $mensaje',
      );
      return;
    }

    ultimoBoton = mensaje;
    ultimoEvento = ahora;

    FlutterForegroundTask.sendDataToMain(
      'RECIBIDO: $mensaje',
    );
  }

  Future<void> _enviarComando(String comando) async {
    final c = caracteristica;
    if (!conectado || c == null) {
      FlutterForegroundTask.sendDataToMain(
        'No se pudo enviar $comando: SensePad no conectado',
      );
      return;
    }

    try {
      await c.write(
        comando.codeUnits,
        withoutResponse:
            !c.properties.write &&
            c.properties.writeWithoutResponse,
      );

      FlutterForegroundTask.sendDataToMain(
        'COMANDO_ENVIADO: $comando',
      );
    } catch (e) {
      FlutterForegroundTask.sendDataToMain(
        'Error enviando $comando: $e',
      );
    }
  }


  // ----------------------------------------------------------
  // RECONEXIÓN
  // ----------------------------------------------------------

  Future<void> reconectar() async {

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    try {
      await valueSubscription?.cancel();
    } catch (_) {}

    try {
      await connectionSubscription
          ?.cancel();
    } catch (_) {}

    valueSubscription = null;

    connectionSubscription = null;

    if (dispositivo != null) {

      try {
        await dispositivo!.disconnect();
      } catch (_) {}
    }

    dispositivo = null;

    caracteristica = null;

    conectado = false;

    conectando = false;

    escaneando = false;
    desconexionPorStandby = false;

    ultimoBoton = '';

    ultimoEvento = null;

    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    conectarBluetooth();
  }


  // ----------------------------------------------------------
  // DESTRUIR SERVICIO
  // ----------------------------------------------------------

  @override
  Future<void> onDestroy(
    DateTime timestamp,
  ) async {

    FlutterForegroundTask
        .sendDataToMain(
      'SERVICIO SENSEPAD DETENIDO',
    );

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    try {
      await scanSubscription?.cancel();
    } catch (_) {}

    try {
      await valueSubscription?.cancel();
    } catch (_) {}

    try {
      await connectionSubscription
          ?.cancel();
    } catch (_) {}

    try {
      await dispositivo?.disconnect();
    } catch (_) {}
  }


  @override
  void onNotificationButtonPressed(
    String id,
  ) {}


  @override
  void onNotificationPressed() {

    FlutterForegroundTask.launchApp('/');
  }


  @override
  void onNotificationDismissed() {}
}


// ============================================================
// MAIN
// ============================================================

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask
      .initCommunicationPort();

  await WakelockPlus.enable();

  final prefs =
      await SharedPreferences
          .getInstance();

  final nombre =
      prefs.getString(
    'nombreBotonera',
  );

  // Si ya entró como usuario con su cuenta de Google,
  // la app abre directo en la botonera y se conecta sola.
  final abrirBotonera =
      prefs.getString('cuentaId') != null &&
      prefs.getString('modoInicio') == 'usuario';

  runApp(

    WithForegroundTask(

      child: AppBotonera(
        tieneNombre:
            nombre != null,
        abrirBotonera:
            abrirBotonera,
      ),
    ),
  );
}


// ============================================================
// APP
// ============================================================

class AppBotonera
    extends StatelessWidget {

  final bool tieneNombre;

  final bool abrirBotonera;

  const AppBotonera({
    super.key,
    required this.tieneNombre,
    this.abrirBotonera = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {

    return MaterialApp(

      debugShowCheckedModeBanner:
          false,

      title: 'SensePad',

      theme: ThemeData(
        brightness:
            Brightness.dark,

        colorScheme:
            ColorScheme.dark(),

        scaffoldBackgroundColor:
            const Color(
          0xFF0D1117,
        ),
      ),

      home: abrirBotonera
          ? const PantallaBotonera()
          : const PantallaBienvenida(),
        
    );
  }
}


// ============================================================
// PANTALLA EXTRAVÍO / BÚSQUEDA
// ============================================================

class PantallaExtravio extends StatefulWidget {
  const PantallaExtravio({super.key});

  @override
  State<PantallaExtravio> createState() => _PantallaExtravioState();
}

class _PantallaExtravioState extends State<PantallaExtravio> {
  final FlutterTts tts = FlutterTts();

  String estado = 'Preparando búsqueda...';
  bool buscando = true;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('es-AR');
    FlutterForegroundTask.addTaskDataCallback(_recibirEvento);
    _iniciarBusqueda();
  }

  Future<void> _iniciarBusqueda() async {
    try {
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      final activo = await FlutterForegroundTask.isRunningService;

      if (!activo) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'sensepad_service',
            channelName: 'SensePad',
            channelDescription: 'Servicio de conexión Bluetooth de SensePad',
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
          ),
          iosNotificationOptions: const IOSNotificationOptions(
            showNotification: false,
            playSound: false,
          ),
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.repeat(5000),
            autoRunOnBoot: false,
            allowWakeLock: true,
            allowWifiLock: true,
          ),
        );

        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'SensePad',
          notificationText: 'Buscando tu SensePad',
          callback: startCallback,
        );

        await Future.delayed(const Duration(milliseconds: 800));
      }

      FlutterForegroundTask.sendDataToTask('BUSCAR_INICIAR');

      if (mounted) {
        setState(() {
          estado = 'Conectando con SensePad...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          estado = 'No se pudo iniciar la búsqueda. Revisá Bluetooth.';
          buscando = false;
        });
      }
    }
  }

  void _recibirEvento(Object data) {
    final mensaje = data.toString();

    if (!mounted) return;

    if (mensaje == 'BUSQUEDA_INICIADA') {
      setState(() {
        estado = '¡Búsqueda activa! Seguí el sonido del SensePad.';
      });
    } else if (mensaje == 'BUSQUEDA_ENCONTRADO') {
      if (_cerrando) return;
      _cerrando = true;
      setState(() {
        estado = 'SensePad encontrado';
        buscando = false;
      });
      tts.speak('SensePad encontrado').then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else if (mensaje == 'BUSQUEDA_TIEMPO') {
      setState(() {
        estado = 'La búsqueda finalizó automáticamente.';
        buscando = false;
      });
      tts.speak('La búsqueda finalizó');
    } else if (mensaje == 'BUSQUEDA_DETENIDA' ||
        mensaje == 'BUSQUEDA_DETENIDA_LOCAL') {
      setState(() {
        estado = 'Búsqueda detenida.';
        buscando = false;
      });
    } else if (mensaje == 'MODO_BUSQUEDA') {
      setState(() {
        estado = 'Buscando SensePad...';
        buscando = true;
      });
    }
  }

  void _detenerBusqueda() {
    FlutterForegroundTask.sendDataToTask('BUSCAR_DETENER');
    if (mounted) {
      setState(() {
        estado = 'Deteniendo búsqueda...';
        buscando = false;
      });
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_recibirEvento);
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extravío'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                buscando ? Icons.bluetooth_searching : Icons.bluetooth,
                size: 76,
                color: const Color(0xFFD4956A),
              ),
              const SizedBox(height: 24),
              const Text(
                'Buscar SensePad',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                estado,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              if (buscando)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _detenerBusqueda,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Detener búsqueda'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// PANTALLA INICIO
// ============================================================

class PantallaInicio
    extends StatefulWidget {

  const PantallaInicio({
    super.key,
  });

  @override
  State<PantallaInicio>
      createState() =>
          _PantallaInicioState();
}


class _PantallaInicioState
    extends State<PantallaInicio> {

  final TextEditingController
      controlador =
      TextEditingController();


  Future<void> guardarNombre() async {

    final nombre =
        controlador.text.trim();

    if (nombre.isEmpty) {
      return;
    }

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      'nombreBotonera',
      nombre,
    );

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,

      MaterialPageRoute(
        builder: (_) =>
            const PantallaBotonera(),
      ),
    );
  }


  @override
  Widget build(
    BuildContext context,
  ) {

    return TemaSP(
      child: Scaffold(

        backgroundColor: SP.cream,

        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // ── Brand mark + nombre ──
                  const BrandMark(size: 64),

                  const SizedBox(height: 16),

                  const SensePadMark(size: 30),

                  const SizedBox(height: 20),

                  const Text(
                    'Ingresá el nombre de tu botonera',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SP.navySoft,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Campo de texto ──
                  TextField(
                    controller: controlador,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => guardarNombre(),
                    style: const TextStyle(
                      color: SP.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Ej: Sense002',
                      prefixIcon: Icon(Icons.badge_outlined, color: SP.coral),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Continuar ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: guardarNombre,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Continuar'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: SP.coral,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ============================================================
// PANTALLA BOTONERA
// ============================================================

class PantallaBotonera
    extends StatefulWidget {

  const PantallaBotonera({
    super.key,
  });

  @override
  State<PantallaBotonera>
      createState() =>
          _PantallaBotoneraState();
}


class _PantallaBotoneraState
    extends State<PantallaBotonera> {
  // ==============================
  // MENÚS DE LOS BOTONES (BTN1, BTN2 y BTN3)
  // Se cargan desde "Configurar botones".
  // ==============================
  List<ConfigBoton> botones = [];

  // Qué botón tiene el menú abierto (0, 1 o 2). -1 = ninguno.
  int menuActivo = -1;

  // Qué opción está elegida en ese menú. -1 = ninguna.
  int indiceOpcion = -1;

  Map<String, List<String>>
      config = {};

  String estado =
      'Iniciando...';

  String log = '';

  final tts =
      FlutterTts();

  DateTime? ultimoEvento;

  String ultimoBoton = '';

  bool conectando = false;

  bool conectado = false;

  bool servicioIniciado = false;

  bool yaHabloConectado = false;

  // Último estado de batería anunciado por voz.
  String ultimoEstadoBateria = '';


  // ----------------------------------------------------------
  // INIT
  // ----------------------------------------------------------

  @override
  void initState() {

    super.initState();

    tts.setLanguage(
      'es-AR',
    );

    FlutterForegroundTask
        .addTaskDataCallback(
      recibirDatosServicio,
    );

    // Cada vez que se guarda la configuración de botones
    // (desde cualquier pantalla), se recarga acá al instante.
    AlmacenBotones.cambios.addListener(
      cargarBotones,
    );

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        iniciar();
      },
    );
  }


  // ----------------------------------------------------------
  // INICIAR
  // ----------------------------------------------------------

 
Future<void> iniciar() async {
  await cargarNombreBotonera();
  await pedirPermisos();
  await cargarBotones();
  sincronizarBotones(); // sin await: no demora la conexión BLE
  await descargarConfig();
  await iniciarServicio();
  await reconectarServicio();
}


  // ----------------------------------------------------------
  // CARGAR BOTONES (lo que se guardó en "Configurar botones")
  // ----------------------------------------------------------

  Future<void> cargarBotones() async {

    final cargados =
        await AlmacenBotones.cargar();

    if (!mounted) return;

    setState(() {
      botones = cargados;
    });

    for (var i = 0; i < botones.length; i++) {
      agregarLog(
        'BTN${i + 1}: '
        '${botones[i].tipo ?? "sin tipo"} '
        '(${botones[i].opciones.length} opciones)',
      );
    }
  }


  // ----------------------------------------------------------
  // SINCRONIZAR BOTONES CON EL SERVIDOR
  // Si en el servidor hay otra configuración (celular nuevo),
  // la trae y vuelve a cargar los botones.
  // ----------------------------------------------------------

  Future<void> sincronizarBotones() async {

    final cambio =
        await AlmacenBotones.sincronizar();

    final aviso = AlmacenBotones.ultimoAviso;

    agregarLog(
      cambio
          ? 'Config de botones traída del servidor'
          : aviso.isNotEmpty
              ? 'Config de botones: $aviso'
              : 'Config de botones al día',
    );

    if (cambio) {
      await cargarBotones();
    }
  }


  // ----------------------------------------------------------
  // CARGAR NOMBRE
  // ----------------------------------------------------------

  Future<void>
      cargarNombreBotonera() async {

    final prefs =
        await SharedPreferences
            .getInstance();

    final nombre =
        prefs.getString(
      'nombreBotonera',
    );

    agregarLog(
      'Nombre guardado: '
      '${nombre ?? "ninguno"}',
    );
  }


  // ----------------------------------------------------------
  // PERMISOS
  // ----------------------------------------------------------

  Future<void> pedirPermisos() async {

    agregarLog(
      'Solicitando permisos...',
    );

    await Permission
        .bluetoothScan
        .request();

    await Permission
        .bluetoothConnect
        .request();

    await Permission
        .locationWhenInUse
        .request();

    await Permission
        .phone
        .request();

    await Permission
        .notification
        .request();

    if (!await FlutterForegroundTask.canDrawOverlays) {
        agregarLog("Pididneod exclusion de bateria");

        await FlutterForegroundTask
        .openSystemAlertWindowSettings();
      };

    if (!await FlutterForegroundTask
      .isIgnoringBatteryOptimizations) {

      agregarLog(
      'Pidiendo exclusión de batería...',
      );

      await FlutterForegroundTask
        .requestIgnoreBatteryOptimization();
      }

    agregarLog(
      'Permisos terminados.',
    );
  }


  // ----------------------------------------------------------
  // CONFIGURAR SERVICIO
  // ----------------------------------------------------------

  Future<void>
      inicializarServicio() async {

    FlutterForegroundTask.init(

      androidNotificationOptions:
          AndroidNotificationOptions(

        channelId:
            'sensepad_service',

        channelName:
            'SensePad',

        channelDescription:
            'Servicio de conexión Bluetooth de SensePad',

        channelImportance:
            NotificationChannelImportance.LOW,

        priority:
            NotificationPriority.LOW,

      ),
      
      iosNotificationOptions:
          const IOSNotificationOptions(
        showNotification:
            false,

        playSound:
            false,
      ),

      foregroundTaskOptions:
           ForegroundTaskOptions(

        eventAction: ForegroundTaskEventAction.repeat(5000),

        autoRunOnBoot:
            false,

        allowWakeLock:
            true,

        allowWifiLock:
            true,
      ),
    );
  }


  // ----------------------------------------------------------
  // INICIAR SERVICIO
  // ----------------------------------------------------------

  Future<void>
      iniciarServicio() async {

    if (servicioIniciado) {
      return;
    }

    agregarLog(
      'PASO 3: iniciando servicio...',
    );

    await inicializarServicio();

    final activo =
        await FlutterForegroundTask
            .isRunningService;

    agregarLog(
      '¿Servicio activo?: $activo',
    );

    if (!activo) {

      agregarLog(
        'Llamando a startService()...',
      );

      try {

        await FlutterForegroundTask
            .startService(

          serviceId: 256,

          notificationTitle:
              'SensePad',

          notificationText:
              'SensePad está conectado',

          callback:
              startCallback,
        );

        agregarLog(
          'startService() terminó correctamente.',
        );

      } catch (e) {

        agregarLog(
          'ERROR startService(): $e',
        );

        return;
      }
    }

    await Future.delayed(
      const Duration(seconds: 3),
    );

    final sigueActivo =
        await FlutterForegroundTask
            .isRunningService;

    agregarLog(
      'Servicio después de iniciar: '
      '${sigueActivo ? "ACTIVO" : "NO ACTIVO"}',
    );

    if (sigueActivo) {

      servicioIniciado = true;

      agregarLog(
        'PASO 4: servicio solicitado.',
      );
    }
  }


  // ----------------------------------------------------------
  // DESCARGAR CONFIG
  // ----------------------------------------------------------

  Future<void> descargarConfig() async {

    try {

      agregarLog(
        'Descargando configuración...',
      );

      final respuesta =
          await http.get(
        Uri.parse(
          SERVLET_URL,
        ),
      );

      if (respuesta.statusCode ==
          200) {

        final nuevasConfig =
            <String, List<String>>{};

        final lineas =
            respuesta.body.split(
          '\n',
        );

        for (final linea
            in lineas) {

          final texto =
              linea.trim();

          if (texto.isEmpty) {
            continue;
          }

          final partes =
              texto.split('|');

          if (partes.length >= 2) {

            nuevasConfig[
                'BTN${partes[0]}'
            ] = [

              partes[1],

              partes.length > 2
                  ? partes
                      .sublist(2)
                      .join('|')
                  : '',
            ];
          }
        }

        setState(() {

          config =
              nuevasConfig;
        });

        agregarLog(
          'Configuración descargada.',
        );

      } else {

        agregarLog(
          'Error HTTP: '
          '${respuesta.statusCode}',
        );
      }

    } catch (e) {

      agregarLog(
        'Error descargando config: $e',
      );

      await Future.delayed(
        const Duration(seconds: 5),
      );

      if (mounted) {
        descargarConfig();
      }
    }
  }


  // ----------------------------------------------------------
  // DATOS DEL SERVICIO
  // ----------------------------------------------------------

  void recibirDatosServicio(
    Object data,
  ) {

    final mensaje =
        data.toString();

    agregarLog(
      mensaje,
    );


    // --------------------------------------------------------
    // BATERÍA (anuncio por voz)
    // --------------------------------------------------------

    if (mensaje.startsWith('BATERIA|')) {
      anunciarBateria(mensaje);
      return;
    }


    // --------------------------------------------------------
    // CONECTADO
    // --------------------------------------------------------

    if (mensaje ==
        'CONECTADO') {

      setState(() {

        estado =
            'Botonera conectada';

        conectado = true;

        conectando = false;
      });

      if (!yaHabloConectado) {

        yaHabloConectado = true;

        tts.speak(
          'Botonera conectada',
        );
      }

      return;
    }


    // --------------------------------------------------------
    // DESCONECTADO
    // --------------------------------------------------------

    if (mensaje ==
        'Botonera desconectada') {

      setState(() {

        estado =
            'Botonera desconectada';

        conectado = false;

        conectando = false;
      });

      return;
    }


    // --------------------------------------------------------
    // RECIBIDO
    // --------------------------------------------------------

    if (mensaje.startsWith(
      'RECIBIDO:',
    )) {

      final boton =
          mensaje
              .substring(
                'RECIBIDO:'.length,
              )
              .trim();

      ejecutarAccion(
        boton,
      );

      return;
    }


    // --------------------------------------------------------
    // BUSCANDO
    // --------------------------------------------------------

    if (mensaje.contains(
      'Buscando',
    )) {

      setState(() {

        estado =
            'Buscando botonera...';

        conectando = true;
      });

      return;
    }


    // --------------------------------------------------------
    // CONECTANDO
    // --------------------------------------------------------

    if (mensaje.contains(
      'Conectando',
    )) {

      setState(() {

        estado =
            'Conectando...';

        conectando = true;
      });

      return;
    }
  }


  // ----------------------------------------------------------
  // RECONEXIÓN
  // ----------------------------------------------------------

  Future<void>
      reconectarServicio() async {

    if (!servicioIniciado) {

      await iniciarServicio();
    }

    agregarLog(
      'Solicitando reconexión...',
    );

    FlutterForegroundTask
        .sendDataToTask(
      'reconectar',
    );
  }


  // ----------------------------------------------------------
  // DESPERTAR PANTALLA
  // ----------------------------------------------------------

  Future<void> despertarPantalla() async {

    agregarLog('Despertando pantalla...');

    try {

      FlutterForegroundTask.wakeUpScreen();

      FlutterForegroundTask.launchApp('/');

    } catch (e) {

      agregarLog(
        'Error despertando pantalla: $e',
      );
    }

    // Tiempo para que la pantalla prenda
    // y la app pase al frente

    await Future.delayed(
      const Duration(milliseconds: 800),
    );
  }


  // ----------------------------------------------------------
  // EJECUTAR ACCIÓN
  // ----------------------------------------------------------

  Future<void> ejecutarAccion(
    String boton,
  ) async {

    final ahora =
        DateTime.now();


    // --------------------------------------------------------
    // DEBOUNCE
    // --------------------------------------------------------

    if (ultimoBoton ==
            boton &&
        ultimoEvento != null &&
        ahora
                .difference(
                  ultimoEvento!,
                )
                .inMilliseconds <
            2000) {

      agregarLog(
        'Ignorado (debounce): $boton',
      );

      return;
    }

    ultimoBoton =
        boton;

    ultimoEvento =
        ahora;


    // ==============================
    // BTN1, BTN2, BTN3 - MENÚS
    // Si el botón tiene un tipo en "Configurar botones",
    // abre su menú. Si no, usa la config del servidor.
    // ==============================
    final indiceMenu =
        indiceDeBoton(boton);

    if (indiceMenu != -1 &&
        botones[indiceMenu].tipo != null) {
      await manejarMenu(indiceMenu);
      return;
    }
    // ==============================
    // BTN4 - SOS
    // ==============================
    if (boton == 'BTN4') {
      await enviarSOS();
      return;
     } 

    // ==============================
    // BTN5 - CONFIRMAR OPCIÓN
    // ==============================
    if (boton == 'BTN5') {
      await confirmarOpcion();
      return;
    }


    // --------------------------------------------------------
    // CONFIG DEL SERVIDOR
    // --------------------------------------------------------

    final datos =
        config[boton];

    if (datos == null) {

      agregarLog(
        'Botón sin configuración: $boton',
      );

      return;
    }

    final tipo =
        datos[0];

    final valor =
        datos[1];


    agregarLog(
      'Ejecutando '
      '$boton -> $tipo -> $valor',
    );


    // --------------------------------------------------------
    // DESPERTAR PANTALLA
    // --------------------------------------------------------

    await despertarPantalla();


    // --------------------------------------------------------
    // SWITCH
    // --------------------------------------------------------

    switch (tipo) {

      case 'maps':

        abrirMaps(
          valor,
        );

        break;


      case 'llamar':

        llamar(
          valor,
        );

        break;


      case 'whatsapp':

        enviarWhatsapp(
          valor,
        );

        break;


      case 'mensaje':

        enviarMensaje(
          valor,
        );

        break;


      case 'ubicacion':

        enviarUbicacion(
          valor,
        );

        break;


      default:

        agregarLog(
          'Tipo desconocido: $tipo',
        );
    }
  }

  // ============================================================
  // MENÚS DE LOS BOTONES
  // ============================================================

  // 'BTN1' -> 0, 'BTN2' -> 1, 'BTN3' -> 2. Otro -> -1.
  int indiceDeBoton(String boton) {

    const nombres = ['BTN1', 'BTN2', 'BTN3'];

    final i = nombres.indexOf(boton);

    if (i >= botones.length) {
      return -1;
    }

    return i;
  }


  Future<void> manejarMenu(int i) async {

    final cfg = botones[i];

    final nombre =
        NOMBRE_TIPO[cfg.tipo] ?? 'Opciones';

    if (cfg.opciones.isEmpty) {
      menuActivo = -1;
      indiceOpcion = -1;

      await tts.speak(
        '$nombre, todavía no hay opciones configuradas',
      );
      return;
    }

    // Primera pulsación (o venía de otro botón): entrar al menú.
    if (menuActivo != i) {
      menuActivo = i;
      indiceOpcion = -1;

      final n = cfg.opciones.length;

      await tts.speak(
        '$nombre, $n ${n == 1 ? "opción" : "opciones"}',
      );
      return;
    }

    // Pulsaciones siguientes: recorrer las opciones.
    indiceOpcion =
        (indiceOpcion + 1) % cfg.opciones.length;

    await tts.speak(
      cfg.opciones[indiceOpcion].apodo,
    );
  }


  Future<void> confirmarOpcion() async {

    if (menuActivo < 0 ||
        menuActivo >= botones.length ||
        indiceOpcion < 0 ||
        indiceOpcion >= botones[menuActivo].opciones.length) {

      await tts.speak(
        'Primero elegí una opción con los botones uno, dos o tres',
      );
      return;
    }

    final tipo =
        botones[menuActivo].tipo;

    final opcion =
        botones[menuActivo].opciones[indiceOpcion];

    menuActivo = -1;
    indiceOpcion = -1;

    agregarLog(
      'Confirmado: $tipo -> ${opcion.apodo}',
    );

    await despertarPantalla();

    switch (tipo) {

      case TIPO_DIR:
        await abrirMaps(opcion.direccion);
        break;

      case TIPO_CALL:
        await llamar(opcion.telefono);
        break;

      case TIPO_MSG:
        await tts.speak(
          'Enviando mensaje a ${opcion.apodo}',
        );
        await abrirWhatsapp(
          opcion.telefono,
          texto: opcion.texto,
        );
        break;
    }
  }
  // ----------------------------------------------------------
  // MAPS
  // ----------------------------------------------------------

  Future<void> abrirMaps(
    String destino,
    ) async {
 
    await tts.speak(
     'Navegando a $destino',
    );

     final url = Uri.parse(
     'google.navigation:q=${Uri.encodeComponent(destino)}',
    );

   agregarLog(
    'Abriendo Google Maps: $url',
   );

   try {

     final resultado = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
     );

    agregarLog(
      'Resultado Maps: $resultado',
     );

     } catch (e) {

    agregarLog(
      'Error abriendo Maps: $e',
     );
    }
  }


  // ----------------------------------------------------------
  // LLAMAR
  // ----------------------------------------------------------

  Future<void> llamar(
    String numero,
  ) async {

    await tts.speak(
      'Llamando',
    );

    try {

      await FlutterPhoneDirectCaller
          .callNumber(
        numero,
      );

      agregarLog(
        'Llamando a $numero',
      );

    } catch (e) {

      agregarLog(
        'Error llamando: $e',
      );
    }
  }


  // ----------------------------------------------------------
  // WHATSAPP
  // ----------------------------------------------------------

  // Deja solo los dígitos del número (sin +, espacios ni guiones).
  String limpiarNumero(String numero) {

    var n = numero.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // Saca el 00 inicial
    if (n.startsWith('00')) {
      n = n.substring(2);
    }

    // Si tiene 10 dígitos (código de área + número),
    // asume Argentina móvil
    if (n.length == 10) {
      n = '549$n';
    }

    return n;
  }


  // Separa "+549...|mensaje" en (numero, mensaje)
  (String, String?) separarValor(String valor) {

    final i = valor.indexOf('|');

    if (i == -1) {
      return (valor.trim(), null);
    }

    final numero =
        valor.substring(0, i).trim();

    final texto =
        valor.substring(i + 1).trim();

    return (numero, texto.isEmpty ? null : texto);
  }


  // Abre WhatsApp directo en la app; si falla, prueba con wa.me
  Future<void> abrirWhatsapp(
    String numero, {
    String? texto,
  }) async {

    final n = limpiarNumero(numero);

    final textoParam = texto != null
        ? '&text=${Uri.encodeComponent(texto)}'
        : '';

    final appUrl = Uri.parse(
      'whatsapp://send?phone=$n$textoParam',
    );

    final webUrl = Uri.parse(
      'https://wa.me/$n'
      '${texto != null ? '?text=${Uri.encodeComponent(texto)}' : ''}',
    );

    agregarLog(
      'WhatsApp número limpio: $n',
    );

    try {

      final ok = await launchUrl(
        appUrl,
        mode: LaunchMode.externalApplication,
      );

      agregarLog(
        'Resultado WhatsApp app: $ok',
      );

      if (ok) {
        return;
      }

    } catch (e) {

      agregarLog(
        'Falló whatsapp://: $e',
      );
    }

    try {

      final ok = await launchUrl(
        webUrl,
        mode: LaunchMode.externalApplication,
      );

      agregarLog(
        'Resultado WhatsApp web: $ok',
      );

    } catch (e) {

      agregarLog(
        'Error abriendo WhatsApp: $e',
      );
    }
  }


  Future<void> enviarWhatsapp(
    String valor,
  ) async {

    await tts.speak(
      'Enviando WhatsApp',
    );

    final (numero, texto) =
        separarValor(valor);

    await abrirWhatsapp(
      numero,
      texto: texto,
    );
  }


  // ----------------------------------------------------------
  // UBICACIÓN
  // ----------------------------------------------------------

  Future<void> enviarUbicacion(
    String valor,
  ) async {

    await tts.speak(
      'Enviando ubicación',
    );

    final (numero, _) =
        separarValor(valor);

    try {

      final posicion =
          await obtenerPosicionActual();

      if (posicion == null) {
        return;
      }

      final lat =
          posicion.latitude;

      final lng =
          posicion.longitude;

      final link =
          'https://www.google.com/maps/search/?api=1'
          '&query=$lat,$lng';


      await enviarUbicacionAlServidor(
        lat,
        lng,
      );


      final mensaje =
          'Mi ubicación actual: $link';

      await abrirWhatsapp(
        numero,
        texto: mensaje,
      );

      agregarLog(
        'Ubicación enviada.',
      );

    } catch (e) {

      agregarLog(
        'Error enviando ubicación: $e',
      );
    }
  }


  // ----------------------------------------------------------
  // OBTENER UBICACIÓN
  // ----------------------------------------------------------

  Future<Position?>
      obtenerPosicionActual() async {

    final servicioActivo =
        await Geolocator
            .isLocationServiceEnabled();

    if (!servicioActivo) {

      agregarLog(
        'GPS desactivado.',
      );

      return null;
    }

    var permiso =
        await Geolocator
            .checkPermission();

    if (permiso ==
        LocationPermission.denied) {

      permiso =
          await Geolocator
              .requestPermission();
    }

    if (permiso ==
            LocationPermission.denied ||
        permiso ==
            LocationPermission.deniedForever) {

      agregarLog(
        'Permiso de ubicación denegado.',
      );

      return null;
    }

    return await Geolocator
        .getCurrentPosition();
  }


  // ----------------------------------------------------------
  // ENVIAR UBICACIÓN AL SERVIDOR
  // ----------------------------------------------------------

  Future<void>
      enviarUbicacionAlServidor(
    double lat,
    double lng,
  ) async {

    try {

      final url =
          Uri.parse(
        '$RECIBIR_UBI_URL'
        '?lat=$lat&lng=$lng',
      );

      final respuesta =
          await http.get(
        url,
      );

      agregarLog(
        'Servidor ubicación: '
        '${respuesta.statusCode}',
      );

    } catch (e) {

      agregarLog(
        'Error servidor ubicación: $e',
      );
    }
  }
  // ----------------------------------------------------------
  // SOS
  // ----------------------------------------------------------

   Future<void> enviarSOS() async {

     await tts.speak('Enviando alerta de emergencia');

     agregarLog('BTN4 activado · enviando SOS...');

     String lat = '';
     String lng = '';
     String zona = 'Sin zona';

    // Si el GPS falla o tarda, el SOS se manda igual.
     try {

       final posicion = await obtenerPosicionActual()
           .timeout(const Duration(seconds: 8));

       if (posicion != null) {
         lat = posicion.latitude.toString();
         lng = posicion.longitude.toString();
         zona = 'Lat ${posicion.latitude.toStringAsFixed(4)}, '
                'Lng ${posicion.longitude.toStringAsFixed(4)}';
       }

    } catch (e) {
      agregarLog('SOS sin ubicación: $e');
    }

    try {

      final url = Uri.parse(
        '$RECIBIR_SOS_URL'
        '?id=SP-001&lat=$lat&lng=$lng'
        '&zona=${Uri.encodeComponent(zona)}',
      );

      final respuesta = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (respuesta.statusCode == 200) {
        agregarLog('SOS enviado correctamente');
        await tts.speak('Alerta enviada');
      } else {
        agregarLog('Error SOS: ${respuesta.statusCode}');
        await tts.speak('No se pudo enviar la alerta');
      }

    } catch (e) {
      agregarLog('Fallo enviando SOS: $e');
      await tts.speak('No se pudo enviar la alerta');
    }
  }

  // ----------------------------------------------------------
  // MENSAJE
  // ----------------------------------------------------------

  Future<void> enviarMensaje(
    String numero,
  ) async {

    await tts.speak(
      'Enviando mensaje',
    );

    final url =
        Uri.parse(
      'sms:$numero',
    );

    if (await canLaunchUrl(
      url,
    )) {

      await launchUrl(
        url,
      );
    }
  }


  // ----------------------------------------------------------
  // CAMBIAR NOMBRE
  // ----------------------------------------------------------

  Future<void>
      borrarNombreBotonera() async {

    try {

      await FlutterForegroundTask
          .stopService();

    } catch (_) {}

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.remove(
      'nombreBotonera',
    );

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,

      MaterialPageRoute(
        builder: (_) =>
            const PantallaInicio(),
      ),
    );
  }


  // ----------------------------------------------------------
  // ANUNCIAR BATERÍA
  // ----------------------------------------------------------

  // Habla solo cuando cambia el estado de la batería.
  void anunciarBateria(String mensaje) {

    final partes = mensaje.split('|');

    if (partes.length < 2) {
      return;
    }

    String estadoNuevo;
    int nivel = -1;

    if (partes[1] == 'cargando') {
      estadoNuevo = 'cargando';
    } else {
      nivel = int.tryParse(
            partes[1].replaceFirst('nivel=', ''),
          ) ??
          -1;
      estadoNuevo = 'nivel$nivel';
    }

    if (estadoNuevo == ultimoEstadoBateria) {
      return;
    }

    final antes = ultimoEstadoBateria;
    ultimoEstadoBateria = estadoNuevo;

    if (estadoNuevo == 'cargando') {
      tts.speak('Cargador conectado');
    } else if (antes == 'cargando') {
      tts.speak(
        'Cargador desconectado. Batería al $nivel por ciento',
      );
    } else if (nivel == 25) {
      tts.speak('Batería baja');
    } else if (nivel == 0) {
      tts.speak('Batería muy baja, cargar pronto');
    }
  }


  // ----------------------------------------------------------
  // AGREGAR LOG
  // ----------------------------------------------------------

  void agregarLog(
    String mensaje,
  ) {

    print(mensaje);

    if (!mounted) {
      return;
    }

    setState(() {

      log +=
          '$mensaje\n';
    });
  }


  // ----------------------------------------------------------
  // LIMPIAR LOG
  // ----------------------------------------------------------

  void limpiarLog() {

    setState(() {

      log = '';
    });
  }


  // ----------------------------------------------------------
  // DISPOSE
  // ----------------------------------------------------------

  @override
  void dispose() {

    AlmacenBotones.cambios.removeListener(
      cargarBotones,
    );

    // NO detenemos el servicio.
    //
    // Esto permite que SensePad continúe
    // funcionando cuando la app queda
    // en segundo plano.

    FlutterForegroundTask
        .removeTaskDataCallback(
      recibirDatosServicio,
    );

    tts.stop();

    super.dispose();
  }


  // ----------------------------------------------------------
  // INTERFAZ
  // ----------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {

    // Texto de la pastilla de estado, según cómo venga la conexión.
    final String etiquetaEstado = conectado
        ? 'Conectado'
        : (conectando ? 'Buscando' : 'Sin conexión');

    // "Atrás" minimiza la app en lugar de cerrar esta pantalla:
    // acá vive la lógica de los botones, si se cierra dejan de andar.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          FlutterForegroundTask.minimizeApp();
        }
      },
      child: TemaSP(
      child: Scaffold(

        backgroundColor: SP.cream,

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

            child: Column(
              children: [

                // ── Barra superior: Menú ──
                // El menú se abre ENCIMA de esta pantalla,
                // así la botonera sigue funcionando.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UsuarioMenu(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu,
                        color: SP.navy, size: 20),
                    label: const Text(
                      'Menú',
                      style: TextStyle(
                        color: SP.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(color: SP.border, width: 1.5),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Brand mark + nombre ──
                const BrandMark(size: 60),

                const SizedBox(height: 14),

                const SensePadMark(size: 28),

                const SizedBox(height: 10),

                // ── Pastilla de conexión (verde si conectado, coral si no) ──
                Eyebrow(etiquetaEstado, coral: !conectado),

                const SizedBox(height: 8),

                // ── Estado actual ──
                Text(
                  estado,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SP.navySoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 18),

                // ── Botones de acción ──
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: reconectarServicio,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reconectar'),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: SP.coral,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: borrarNombreBotonera,
                       
                        label: const Text(
                          'Cambiar nombre',
                          style: TextStyle(color: SP.navy),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          side: const BorderSide(color: SP.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: limpiarLog,
                  
                    label: const Text(
                      'Limpiar log',
                      style: TextStyle(color: SP.navy),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: SP.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Log de conexión (tarjeta navy con texto cream) ──
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SP.navy,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SP.navySoft, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Etiqueta del log con puntito coral
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: SP.coral,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'LOG DE CONEXIÓN',
                              style: TextStyle(
                                color: SP.cream,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Contenido del log
                        Expanded(
                          child: SingleChildScrollView(
                            reverse: true,
                            child: Text(
                              log.isEmpty ? 'Sin eventos todavía.' : log,
                              style: const TextStyle(
                                color: SP.cream,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}