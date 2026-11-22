import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'modelo_botones.dart';
import '/tema.dart';

// ============================================================
// CONFIGURAR BOTONES
// ============================================================
//
// Es el wizard de usuario-menu.jsp pasado a la app.
// Tiene tres pantallas:
//
//   PantallaConfigBotones -> la lista de los 3 botones
//   PantallaEditarBoton   -> tipo y opciones de un botón
//   PantallaOpcion        -> formulario de una opción
//
// Los cambios se guardan solos en el celular.

PreferredSizeWidget _barraSP() => AppBar(
      backgroundColor: C.cream,
      elevation: 0,
      title: const Marca(),
      iconTheme: const IconThemeData(color: C.navy),
    );

TextStyle _estiloTitulo() => GoogleFonts.manrope(
    fontSize: 16.8, fontWeight: FontWeight.w700, color: C.navy);

TextStyle _estiloDetalle() =>
    GoogleFonts.manrope(fontSize: 14, color: C.navySoft);

TextStyle _estiloSeccion() => GoogleFonts.manrope(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: C.coralDeep);

IconData _iconoTipo(String? tipo) {
  switch (tipo) {
    case TIPO_DIR:
      return Icons.place_outlined;
    case TIPO_CALL:
      return Icons.call_outlined;
    case TIPO_MSG:
      return Icons.chat_outlined;
    default:
      return Icons.radio_button_unchecked;
  }
}

ButtonStyle _estiloBotonPrincipal() => FilledButton.styleFrom(
      backgroundColor: C.navy,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
    );


// ============================================================
// 1. LISTA DE BOTONES
// ============================================================

class PantallaConfigBotones extends StatefulWidget {
  const PantallaConfigBotones({super.key});

  @override
  State<PantallaConfigBotones> createState() => _PantallaConfigBotonesState();
}

class _PantallaConfigBotonesState extends State<PantallaConfigBotones> {
  List<ConfigBoton>? botones;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cargados = await AlmacenBotones.cargar();
    if (!mounted) return;
    setState(() => botones = cargados);
  }

  Future<void> _abrir(int i) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEditarBoton(botones: botones!, indice: i),
      ),
    );
    if (mounted) setState(() {});
  }

  String _resumen(ConfigBoton b) {
    if (b.tipo == null) return 'Sin configurar';
    final nombre = NOMBRE_TIPO[b.tipo]!;
    if (b.opciones.isEmpty) return '$nombre · todavía sin opciones';
    return '$nombre · ${b.opciones.map((o) => o.apodo).join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final lista = botones;

    return TemaSP(
      child: Scaffold(
        appBar: _barraSP(),
        body: lista == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(24), children: [
                CabeceraPagina(
                  eyebrow: 'Configuración',
                  titulo: 'Tus ',
                  tituloCoral: 'botones',
                  subtitulo: 'Cada tipo va en un solo botón y cada botón '
                      'tiene hasta $MAX_OPCIONES opciones.',
                ),
                for (var i = 0; i < lista.length; i++)
                  _Tarjeta(
                    icono: _iconoTipo(lista[i].tipo),
                    titulo: 'Botón ${i + 1}',
                    detalle: _resumen(lista[i]),
                    onTap: () => _abrir(i),
                    trailing:
                        const Icon(Icons.chevron_right, color: C.navySoft),
                  ),
                const _Tarjeta(
                  icono: Icons.check_circle_outline,
                  titulo: 'Botón 5',
                  detalle: 'Confirma la opción que se eligió',
                ),
              ]),
      ),
    );
  }
}


// ============================================================
// 2. EDITAR UN BOTÓN
// ============================================================

class PantallaEditarBoton extends StatefulWidget {
  final List<ConfigBoton> botones;
  final int indice;

  const PantallaEditarBoton({
    super.key,
    required this.botones,
    required this.indice,
  });

  @override
  State<PantallaEditarBoton> createState() => _PantallaEditarBotonState();
}

class _PantallaEditarBotonState extends State<PantallaEditarBoton> {
  ConfigBoton get boton => widget.botones[widget.indice];

  Future<void> _guardar() async {
    setState(() {});
    await AlmacenBotones.guardar(widget.botones);
  }

  // Devuelve qué otro botón ya usa ese tipo (-1 si ninguno).
  int _botonQueUsa(String tipo) {
    for (var i = 0; i < widget.botones.length; i++) {
      if (i != widget.indice && widget.botones[i].tipo == tipo) return i;
    }
    return -1;
  }

  Future<bool> _confirmar(String titulo, String texto, String accion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _elegirTipo(String tipo) async {
    if (boton.tipo == tipo) return;

    // Cambiar el tipo borra las opciones (igual que en la web).
    if (boton.opciones.isNotEmpty) {
      final n = boton.opciones.length;
      final ok = await _confirmar(
        '¿Cambiar el tipo?',
        'Se van a borrar ${n == 1 ? "la opción" : "las $n opciones"} '
            'de este botón.',
        'Cambiar',
      );
      if (!ok) return;
    }

    boton.tipo = tipo;
    boton.opciones.clear();
    await _guardar();
  }

  Future<void> _vaciar() async {
    final ok = await _confirmar(
      '¿Dejar el botón vacío?',
      'Se borran el tipo y todas sus opciones.',
      'Vaciar',
    );
    if (!ok) return;

    boton.tipo = null;
    boton.opciones.clear();
    await _guardar();
  }

  Future<void> _editarOpcion([int? i]) async {
    final tipo = boton.tipo;
    if (tipo == null) return;

    final resultado = await Navigator.push<OpcionBoton>(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaOpcion(
          tipo: tipo,
          inicial: i == null ? null : boton.opciones[i],
        ),
      ),
    );

    if (resultado == null) return;

    if (i == null) {
      boton.opciones.add(resultado);
    } else {
      boton.opciones[i] = resultado;
    }
    await _guardar();
  }

  Future<void> _mover(int i, int delta) async {
    final j = i + delta;
    if (j < 0 || j >= boton.opciones.length) return;

    final opcion = boton.opciones.removeAt(i);
    boton.opciones.insert(j, opcion);
    await _guardar();
  }

  Future<void> _borrar(int i) async {
    final ok = await _confirmar(
      '¿Borrar la opción?',
      'Se borra "${boton.opciones[i].apodo}".',
      'Borrar',
    );
    if (!ok) return;

    boton.opciones.removeAt(i);
    await _guardar();
  }

  Widget _tarjetaTipo(String tipo) {
    final otro = _botonQueUsa(tipo);
    final ocupado = otro != -1;
    final elegido = boton.tipo == tipo;

    return Semantics(
      selected: elegido,
      child: _Tarjeta(
        icono: _iconoTipo(tipo),
        titulo: NOMBRE_TIPO[tipo]!,
        detalle: ocupado
            ? 'Ya está en el botón ${otro + 1}'
            : DESCRIPCION_TIPO[tipo]!,
        resaltada: elegido,
        atenuada: ocupado,
        onTap: ocupado ? null : () => _elegirTipo(tipo),
        trailing: elegido
            ? const Icon(Icons.check_circle, color: C.coralDeep)
            : null,
      ),
    );
  }

  Widget _filaOpcion(int i) {
    final opcion = boton.opciones[i];
    final ultima = boton.opciones.length - 1;

    return _Tarjeta(
      icono: _iconoTipo(boton.tipo),
      titulo: '${i + 1}. ${opcion.apodo}',
      detalle: opcion.descripcion(boton.tipo),
      onTap: () => _editarOpcion(i),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Subir',
          icon: const Icon(Icons.arrow_upward),
          color: C.navy,
          onPressed: i > 0 ? () => _mover(i, -1) : null,
        ),
        IconButton(
          tooltip: 'Bajar',
          icon: const Icon(Icons.arrow_downward),
          color: C.navy,
          onPressed: i < ultima ? () => _mover(i, 1) : null,
        ),
        IconButton(
          tooltip: 'Borrar',
          icon: const Icon(Icons.delete_outline),
          color: C.coralDeep,
          onPressed: () => _borrar(i),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tipo = boton.tipo;
    final opciones = boton.opciones;

    return TemaSP(
      child: Scaffold(
        appBar: _barraSP(),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          CabeceraPagina(
            eyebrow: 'Botón ${widget.indice + 1}',
            titulo: 'Qué ',
            tituloCoral: 'hace',
            subtitulo: 'Los cambios se guardan solos.',
          ),
          Text('TIPO', style: _estiloSeccion()),
          const SizedBox(height: 10),
          for (final t in TIPOS) _tarjetaTipo(t),
          if (tipo != null) ...[
            const SizedBox(height: 16),
            Text(
              'OPCIONES (${opciones.length} DE $MAX_OPCIONES)',
              style: _estiloSeccion(),
            ),
            const SizedBox(height: 4),
            Text('La botonera las lee en este orden.', style: _estiloDetalle()),
            const SizedBox(height: 12),
            if (opciones.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Todavía no hay opciones.', style: _estiloDetalle()),
              ),
            for (var i = 0; i < opciones.length; i++) _filaOpcion(i),
            if (opciones.length < MAX_OPCIONES)
              FilledButton.icon(
                onPressed: () => _editarOpcion(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar opción'),
                style: _estiloBotonPrincipal(),
              )
            else
              Text(
                'Llegaste al máximo de $MAX_OPCIONES opciones.',
                style: _estiloDetalle(),
              ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: _vaciar,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Dejar el botón vacío'),
                style: TextButton.styleFrom(foregroundColor: C.coralDeep),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}


// ============================================================
// 3. FORMULARIO DE UNA OPCIÓN
// ============================================================

class PantallaOpcion extends StatefulWidget {
  final String tipo;
  final OpcionBoton? inicial;

  const PantallaOpcion({super.key, required this.tipo, this.inicial});

  @override
  State<PantallaOpcion> createState() => _PantallaOpcionState();
}

class _PantallaOpcionState extends State<PantallaOpcion> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController apodo;
  late final TextEditingController direccion;
  late final TextEditingController contacto;
  late final TextEditingController telefono;
  late final TextEditingController texto;

  bool get esDir => widget.tipo == TIPO_DIR;
  bool get esMsg => widget.tipo == TIPO_MSG;

  @override
  void initState() {
    super.initState();
    final o = widget.inicial;
    apodo = TextEditingController(text: o?.apodo ?? '');
    direccion = TextEditingController(text: o?.direccion ?? '');
    contacto = TextEditingController(text: o?.contacto ?? '');
    telefono = TextEditingController(text: o?.telefono ?? '');
    texto = TextEditingController(text: o?.texto ?? '');
  }

  @override
  void dispose() {
    apodo.dispose();
    direccion.dispose();
    contacto.dispose();
    telefono.dispose();
    texto.dispose();
    super.dispose();
  }

  String? _obligatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Completá este campo' : null;

  String? _validarTelefono(String? v) {
    final digitos = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) return 'Completá el teléfono';
    if (digitos.length < 8) return 'El número parece incompleto';
    return null;
  }

  void _listo() {
    if (!_form.currentState!.validate()) return;

    Navigator.pop(
      context,
      OpcionBoton(
        apodo: apodo.text.trim(),
        direccion: esDir ? direccion.text.trim() : '',
        contacto: esDir ? '' : contacto.text.trim(),
        telefono: esDir ? '' : telefono.text.trim(),
        texto: esMsg ? texto.text.trim() : '',
      ),
    );
  }

  Widget _campo({
    required String etiqueta,
    required String ayuda,
    required TextEditingController controlador,
    String? Function(String?)? validador,
    TextInputType? teclado,
    int lineas = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controlador,
          validator: validador,
          keyboardType: teclado,
          maxLines: lineas,
          textCapitalization: teclado == TextInputType.phone
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          style: GoogleFonts.manrope(fontSize: 16, color: C.navy),
          decoration: InputDecoration(
            labelText: etiqueta,
            hintText: ayuda,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.borderStrong, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.borderStrong, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.coralDeep, width: 2.5),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return TemaSP(
      child: Scaffold(
        appBar: _barraSP(),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            CabeceraPagina(
              eyebrow: NOMBRE_TIPO[widget.tipo]!,
              titulo: widget.inicial == null ? 'Nueva ' : 'Editar ',
              tituloCoral: 'opción',
              subtitulo: 'El apodo es lo que dice la botonera en voz alta.',
            ),
            _campo(
              etiqueta: 'Escribi un apodo',
              ayuda: 'Ej: Casa, Mamá, Escuela',
              controlador: apodo,
              validador: _obligatorio,
            ),
            if (esDir)
              _campo(
                etiqueta: 'Escribir Dirección',
                ayuda: 'Ej: Av. Rivadavia 5000, CABA',
                controlador: direccion,
                validador: _obligatorio,
                teclado: TextInputType.streetAddress,
              )
            else ...[
              _campo(
                etiqueta: 'Nombre del contacto (opcional)',
                ayuda: 'Ej: María López',
                controlador: contacto,
                teclado: TextInputType.name,
              ),
              _campo(
                etiqueta: 'Escribir el numero de tel',
                ayuda: 'Ej: 11 2345 6789',
                controlador: telefono,
                validador: _validarTelefono,
                teclado: TextInputType.phone,
              ),
            ],
            if (esMsg)
              _campo(
                etiqueta: 'Escribir mensaje para guardar',
                ayuda: 'Ej: Ya salí, llego en 20 minutos',
                controlador: texto,
                validador: _obligatorio,
                lineas: 3,
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _listo,
              style: _estiloBotonPrincipal(),
              child: const Text('Guardar opción'),
            ),
          ]),
        ),
      ),
    );
  }
}


// ============================================================
// TARJETA (misma forma que .w-opt)
// ============================================================

class _Tarjeta extends StatelessWidget {
  final IconData icono;
  final String titulo, detalle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool resaltada;
  final bool atenuada;

  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.onTap,
    this.trailing,
    this.resaltada = false,
    this.atenuada = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Opacity(
          opacity: atenuada ? 0.5 : 1,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: resaltada ? C.coralDeep : C.borderStrong,
                    width: resaltada ? 2.5 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: C.creamDim,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icono, color: C.coralDeep, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo, style: _estiloTitulo()),
                          if (detalle.isNotEmpty)
                            Text(detalle,
                                style: _estiloDetalle(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                        ]),
                  ),
                  if (trailing != null) trailing!,
                ]),
              ),
            ),
          ),
        ),
      );
}