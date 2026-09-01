import 'package:flutter/material.dart';

import 'screens/med_list_screen.dart';

void main() => runApp(const PillPalApp());

class PillPalApp extends StatelessWidget {
  const PillPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PillPal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D6B),
        useMaterial3: true,
      ),
      home: const MedListScreen(),
    );
  }
}
