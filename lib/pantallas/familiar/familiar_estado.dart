
import 'package:flutter/material.dart';

import '../../tema.dart';

// ============================================================
// DATOS FIJOS PARA LA FERIA
// ============================================================

const int NIVEL_BATERIA = 75;
const bool ESTA_CARGANDO = false;
const String ESTADO_CONEXION = 'conectado';

// ============================================================

class EstadoSensePad {
  final int? nivel;
  final bool cargando;
  final String conexion;
  final int segundosDesde;

  const EstadoSensePad({
    required this.nivel,
    required this.cargando,
    required this.conexion,
    required this.segundosDesde,
  });

  bool get desactualizado =>
      conexion == 'conectado' && segundosDesde > 600;
}

// ============================================================

String haceCuanto(int s) {
  if (s < 60) return 'hace instantes';
  if (s < 3600) return 'hace ${s ~/ 60} min';
  if (s < 86400) return 'hace ${s ~/ 3600} h';

  final d = s ~/ 86400;
  return d == 1 ? 'hace 1 día' : 'hace $d días';
}

// ============================================================

String textoNivel(int n) {
  if (n >= 100) return 'Completa';
  if (n >= 75) return 'Alta';
  if (n >= 50) return 'Media';
  if (n >= 25) return 'Baja, conviene cargarla';

  return 'Muy baja, cargar pronto';
}

// ============================================================
// FAMILIAR - ESTADO
// ============================================================

class FamiliarEstado extends StatefulWidget {
  const FamiliarEstado({super.key});

  @override
  State<FamiliarEstado> createState() => _FamiliarEstadoState();
}

class _FamiliarEstadoState extends State<FamiliarEstado> {

  // VALORES FIJOS PARA LA DEMOSTRACIÓN

  final EstadoSensePad _estado = const EstadoSensePad(
    nivel: NIVEL_BATERIA,
    cargando: ESTA_CARGANDO,
    conexion: ESTADO_CONEXION,
    segundosDesde: 0,
  );

  @override
  Widget build(BuildContext context) {
    final e = _estado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const CabeceraPagina(
          eyebrow: 'Dispositivo',
          titulo: 'Estado del ',
          tituloCoral: 'SensePad',
          subtitulo: 'Batería y conexión.',
        ),

        // TARJETA DE BATERÍA

        TarjetaSP(
          titulo: 'Batería',
          icono: _iconoBateria(e),
          child: _bateria(e),
        ),

        // TARJETA DE CONEXIÓN

        TarjetaSP(
          titulo: 'Conexión',
          icono: _iconoConexion(e),
          child: _conexion(e),
        ),
      ],
    );
  }

  // ==========================================================
  // BATERÍA
  // ==========================================================

  Widget _bateria(EstadoSensePad? e) {

    if (e == null) {
      return const Text('Sin datos de batería.');
    }

    if (e.cargando) {
      return _dato(
        'Cargando',
        'Conectado al cargador.',
      );
    }

    if (e.nivel == null) {
      return const Text('Sin dato de batería.');
    }

    return _dato(
      '${e.nivel} %',
      '${textoNivel(e.nivel!)} · ${haceCuanto(e.segundosDesde)}',
    );
  }

  IconData _iconoBateria(EstadoSensePad? e) {

    if (e == null) {
      return Icons.battery_unknown_outlined;
    }

    if (e.cargando) {
      return Icons.battery_charging_full_outlined;
    }

    final n = e.nivel;

    if (n == null) return Icons.battery_unknown_outlined;
    if (n >= 100) return Icons.battery_full;
    if (n >= 75) return Icons.battery_5_bar;
    if (n >= 50) return Icons.battery_4_bar;
    if (n >= 25) return Icons.battery_2_bar;

    return Icons.battery_alert;
  }

  // ==========================================================
  // CONEXIÓN
  // ==========================================================

  Widget _conexion(EstadoSensePad? e) {

    if (e == null) {
      return const Text('Sin datos.');
    }

    final hace = haceCuanto(e.segundosDesde);

    if (e.conexion == 'standby') {
      return _dato(
        'Modo ahorro',
        'Sin uso desde $hace. Se activa al apretar cualquier botón.',
      );
    }

    if (e.conexion == 'desconectado') {
      return _dato(
        'Desconectado',
        'Se perdió la conexión con el teléfono del usuario $hace.',
      );
    }

    if (e.desactualizado) {
      return _dato(
        'Sin datos recientes',
        'El teléfono del usuario no informa desde $hace. Puede estar sin internet.',
      );
    }

    return _dato(
      'Conectado',
      'Funcionando normalmente.',
    );
  }

  IconData _iconoConexion(EstadoSensePad? e) {

    if (e == null) return Icons.bluetooth;

    if (e.conexion == 'standby') {
      return Icons.bedtime_outlined;
    }

    if (e.conexion == 'desconectado') {
      return Icons.bluetooth_disabled;
    }

    if (e.desactualizado) {
      return Icons.cloud_off_outlined;
    }

    return Icons.bluetooth_connected;
  }

  // ==========================================================
  // WIDGET COMÚN
  // ==========================================================

  Widget _dato(String principal, String detalle) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          principal,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 4),

        Text(detalle),
      ],
    );
  }
}
