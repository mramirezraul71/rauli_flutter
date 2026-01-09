import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';

class RauliApp extends StatelessWidget {
  const RauliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAULI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FFF)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const DashboardScreen(),
    );
  }
}
