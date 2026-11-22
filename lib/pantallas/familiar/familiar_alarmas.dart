import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../tema.dart';

const String _BASE = 'https://appsjavatest.fatimarem.edu.ar/sensepad';
const String _ID_DISPOSITIVO = 'SP-001';

const Color _rojoSOS = Color(0xFFB03A2E);
const Color _rojoClaro = Color(0xFFFBD8D1);

// ---------------------------------------------------------------
// MODELO
// ---------------------------------------------------------------

class _AlertaSOS {
  final int id;
  final DateTime activada;
  final double? lat;
  final double? lng;
  final bool atendida;
  final DateTime? atendidaEn;
  final String zona;

  _AlertaSOS({
    required this.id,
    required this.activada,
    required this.lat,
    required this.lng,
    required this.atendida,
    required this.atendidaEn,
    required this.zona,
  });

  bool get tieneGps => lat != null && lng != null;

  String get haceCuanto {
    final seg = DateTime.now().difference(activada).inSeconds;
    if (seg < 60) return 'hace ${seg < 0 ? 0 : seg} seg';
    if (seg < 3600) return 'hace ${seg ~/ 60} min';
    if (seg < 86400) return 'hace ${seg ~/ 3600} h';
    return 'hace ${seg ~/ 86400} días';
  }

  String get hora => _hora(activada);
}

String _dos(int n) => n.toString().padLeft(2, '0');

String _hora(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';

String _fechaHora(DateTime d) => '${_dos(d.day)}/${_dos(d.month)} ${_hora(d)}';

// ---------------------------------------------------------------
// PANTALLA
// ---------------------------------------------------------------

// familiar-alarmas.jsp
class FamiliarAlarmas extends StatefulWidget {
  const FamiliarAlarmas({super.key});

  @override
  State<FamiliarAlarmas> createState() => _FamiliarAlarmasState();
}

class _FamiliarAlarmasState extends State<FamiliarAlarmas> {
  List<_AlertaSOS> alertas = [];

  bool cargando = true;
  bool atendiendo = false;
  String? error;

  Timer? _timer;

  // La alerta activa es la más reciente sin atender.
  _AlertaSOS? get activa {
    for (final a in alertas) {
      if (!a.atendida) return a;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _cargar();
    // Refresco automático para que un SOS nuevo aparezca solo.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------
  // DATOS
  // -------------------------------------------------------------

  Future<void> _cargar() async {
    try {
      final r = await http
          .get(Uri.parse('$_BASE/ListaSOS?id=$_ID_DISPOSITIVO'))
          .timeout(const Duration(seconds: 8));

      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}');
      }

      final texto = r.body.trim();

      if (texto.startsWith('ERROR')) {
        throw Exception(texto);
      }

      final lista = <_AlertaSOS>[];

      if (texto != 'VACIO') {
        for (final linea in texto.split('\n')) {
          final a = _parsearLinea(linea.trim());
          if (a != null) lista.add(a);
        }
      }

      if (!mounted) return;
      setState(() {
        alertas = lista;
        error = null;
        cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'No se pudo conectar con el servidor.';
        cargando = false;
      });
    }
  }

  // id|activadaEpoch|lat|lng|atendida|atendidaEpoch|zona
  _AlertaSOS? _parsearLinea(String linea) {
    if (linea.isEmpty) return null;

    final p = linea.split('|');
    if (p.length < 6) return null;

    final id = int.tryParse(p[0]);
    if (id == null) return null;

    final act = int.tryParse(p[1]) ?? 0;
    final ate = int.tryParse(p[5]) ?? 0;

    final zona = p.length > 6 ? p.sublist(6).join('|').trim() : '';

    return _AlertaSOS(
      id: id,
      activada: act > 0
          ? DateTime.fromMillisecondsSinceEpoch(act)
          : DateTime.now(),
      lat: double.tryParse(p[2]),
      lng: double.tryParse(p[3]),
      atendida: p[4] == '1',
      atendidaEn:
          ate > 0 ? DateTime.fromMillisecondsSinceEpoch(ate) : null,
      zona: zona.isEmpty ? 'Ubicación aproximada' : zona,
    );
  }

  // -------------------------------------------------------------
  // ACCIONES
  // -------------------------------------------------------------

  Future<void> _abrirMapa(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      _aviso('No se pudo abrir el mapa.');
    }
  }

  Future<void> _atender(_AlertaSOS alerta) async {
    if (atendiendo) return;

    setState(() => atendiendo = true);

    try {
      final r = await http
          .post(
            Uri.parse('$_BASE/AtenderSOS'),
            body: {'id': alerta.id.toString(), 'app': '1'},
          )
          .timeout(const Duration(seconds: 8));

      if (r.statusCode == 200 && r.body.trim() == 'OK') {
        _aviso('Alerta marcada como atendida.');
        await _cargar();
      } else {
        _aviso('No se pudo marcar como atendida.');
      }
    } catch (_) {
      _aviso('Sin conexión. Intentá de nuevo.');
    }

    if (mounted) setState(() => atendiendo = false);
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final a = activa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CabeceraPagina(
          eyebrow: 'Avisos',
          titulo: 'Las ',
          tituloCoral: 'alarmas',
          subtitulo: 'Historial de alertas.',
        ),

        if (error != null) _bannerError(),

        if (a != null) _bannerSOS(a),

        TarjetaSP(
          titulo: 'Historial de alarmas',
          icono: Icons.notifications_outlined,
          child: _contenidoHistorial(),
        ),
      ],
    );
  }

  Widget _bannerError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(error!)),
          TextButton(
            onPressed: _cargar,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // Banner de emergencia (el que estaba en el inicio)
  Widget _bannerSOS(_AlertaSOS s) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB03A2E), Color(0xFF8B2E25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _rojoSOS.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: _rojoSOS, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SOS ACTIVADO ${s.haceCuanto.toUpperCase()}',
                  style: const TextStyle(
                    color: _rojoClaro,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'La persona presionó el botón de emergencia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hora de activación: ${s.hora}\n${s.zona}',
            style: const TextStyle(color: _rojoClaro, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (s.tieneGps)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirMapa(s.lat!, s.lng!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _rojoSOS,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver ubicación'),
                  ),
                ),
              if (s.tieneGps) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: atendiendo ? null : () => _atender(s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  icon: atendiendo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Atendida'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contenidoHistorial() {
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (alertas.isEmpty) {
      return const Text('Todavía no hubo ninguna alarma.');
    }

    return Column(
      children: [
        for (final a in alertas) _filaAlerta(a),
      ],
    );
  }

  Widget _filaAlerta(_AlertaSOS a) {
    final color = a.atendida ? Colors.grey : _rojoSOS;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_amber_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOS activado',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _fechaHora(a.activada),
                  style: const TextStyle(fontSize: 13),
                ),
                if (a.atendida && a.atendidaEn != null)
                  Text(
                    'Atendida ${_fechaHora(a.atendidaEn!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          if (a.tieneGps)
            IconButton(
              tooltip: 'Ver ubicación',
              onPressed: () => _abrirMapa(a.lat!, a.lng!),
              icon: const Icon(Icons.place_outlined),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              a.atendida ? 'Atendida' : 'Activa',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}