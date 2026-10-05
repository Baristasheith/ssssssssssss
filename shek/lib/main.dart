import 'package:flutter/material.dart';

import 'screens/scanner_screen.dart';

void main() {
  runApp(const PriceLabelApp());
}

class PriceLabelApp extends StatelessWidget {
  const PriceLabelApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF176B5B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ماسح الأسعار',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          surface: const Color(0xFFF7F8F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE4E9E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seedColor, width: 1.5),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: ScannerScreen(),
      ),
    );
  }
}
