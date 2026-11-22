
import 'package:flutter/material.dart';

import '../../tema.dart';

const Color _coral = Color(0xFFD4956A);

class FamiliarInicio extends StatelessWidget {
  final VoidCallback? onIrAMapa;
  final VoidCallback? onIrAAlarmas;

  const FamiliarInicio({
    super.key,
    this.onIrAMapa,
    this.onIrAAlarmas,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CabeceraPagina(
          eyebrow: 'Panel familiar',
          titulo: 'Bienvenidos, ',
          tituloCoral: 'familia',
          subtitulo: 'Un espacio para acompañar y cuidar.',
        ),

        _introduccion(),

        TarjetaSP(
          titulo: '¿Qué podés hacer?',
          icono: Icons.dashboard_outlined,
          child: Column(
            children: [

              const SizedBox(height: 18),
              _funcion(
                icono: Icons.notifications_active_outlined,
                titulo: 'Consultar las alarmas',
                descripcion:
                    'Revisá las alertas y notificaciones generadas '
                    'por el dispositivo.',
              ),
              const SizedBox(height: 18),
              _funcion(
                icono: Icons.history_outlined,
                titulo: 'Acompañar y supervisar',
                descripcion:
                    'Utilizá las herramientas disponibles para '
                    'estar al tanto de la actividad del dispositivo.',
              ),
            ],
          ),
        ),

        TarjetaSP(
          titulo: 'Accesos rápidos',
          icono: Icons.apps_outlined,
          child: Row(
            children: [
            
              const SizedBox(width: 12),
              Expanded(
                child: _acceso(
                  icono: Icons.notifications_outlined,
                  titulo: 'Alarmas',
                  detalle: 'Ver alertas',
                  onTap: onIrAAlarmas,
                ),
              ),
            ],
          ),
        ),

        TarjetaSP(
          titulo: 'Nuestro propósito',
          icono: Icons.favorite_outline,
          child: const Text(
            'SensePad busca brindar mayor autonomía y seguridad '
            'a las personas mediante una botonera inteligente '
            'que permite realizar acciones de asistencia de forma '
            'sencilla. Este panel permite que familiares puedan '
            'acompañar y consultar la información disponible '
            'del dispositivo.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _introduccion() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _coral.withOpacity(0.28),
            _coral.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _coral.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.people_alt_outlined,
            color: _coral,
            size: 32,
          ),
          SizedBox(height: 14),
          Text(
            'Acompañar también es cuidar',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Este es el espacio destinado a familiares y personas '
            'de confianza. Desde aquí podés acceder a las funciones '
            'de seguimiento y consultar las alertas del SensePad.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _funcion({
    required IconData icono,
    required String titulo,
    required String descripcion,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _coral.withOpacity(0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icono,
            color: _coral,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                descripcion,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _acceso({
    required IconData icono,
    required String titulo,
    required String detalle,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icono,
                color: _coral,
                size: 26,
              ),
              const SizedBox(height: 10),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
