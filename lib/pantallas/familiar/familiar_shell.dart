import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../tema.dart';
import 'familiar_inicio.dart';
import 'familiar_estado.dart';
import 'familiar_alarmas.dart';


// _header-usuario.jsp + _sidebar-familiar.jsp
// En el celu el sidebar pasa a ser una barra inferior (igual que
// tu CSS, que oculta el sidebar en pantallas chicas).
class FamiliarShell extends StatefulWidget {
  const FamiliarShell({super.key});

  @override
  State<FamiliarShell> createState() => _FamiliarShellState();
}

class _FamiliarShellState extends State<FamiliarShell> {
  int _i = 0;

  static const _paginas = <Widget>[
    FamiliarInicio(),
    FamiliarEstado(),
    FamiliarAlarmas(),
  ];

  @override
  Widget build(BuildContext context) {
    return TemaSP(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: C.cream,
          elevation: 0,
          iconTheme: const IconThemeData(color: C.navy),
          title: const Marca(),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('Panel familiar',
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700, color: C.navy)),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: C.borderSoft),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            children: [_paginas[_i]],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: C.cream,
          indicatorColor: C.navy,
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: Colors.white),
                label: 'Inicio'),
            NavigationDestination(
                icon: Icon(Icons.battery_charging_full_outlined),
                selectedIcon:
                    Icon(Icons.battery_charging_full, color: Colors.white),
                label: 'Estado'),
            NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications, color: Colors.white),
                label: 'Alarmas'),
            
          ],
        ),
      ),
    );
  }
}