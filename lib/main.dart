import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/LoginScreen.dart';
import 'screens/DashboardScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/TechnicianToolsPage.dart';
import 'screens/TechniciansScreen.dart';
import 'screens/ManageTechnicianToolsScreen.dart';
import 'screens/AddNewToolPage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bmgpiypezsejajmejxba.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJtZ3BpeXBlenNlamFqbWVqeGJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA1OTAxNjMsImV4cCI6MjA3NjE2NjE2M30.d1We_aPd2ziXNTzhlL33utEn1edUFsGH05LeVUVEhvk',
  );

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => DashboardScreen(),
      ),
      GoRoute(
        path: '/techniciansPage',
        builder: (context, state) => TechniciansScreen(),
      ),
      GoRoute(
        path: '/view-tools',
        builder: (context, state) {
          final technician = state.extra as Map<String, dynamic>?;
          return ManageTechnicianToolsScreen(technician: technician);
        },
      ),
      GoRoute(
        path: '/add-tools',
        builder: (context, state) => const AddNewToolPage(),
      ),
      GoRoute(
        path: '/technician-tools',
        builder: (context, state) => const TechnicianToolsPage(),
      ),
    ],
  );

  runApp(MyApp(router: router));
}

class MyApp extends StatelessWidget {
  final supabase = Supabase.instance.client;
  final GoRouter router;
  MyApp({required this.router, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      title: 'Tools Audit App',
      debugShowCheckedModeBanner: false,

      // Light theme
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF003E70),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003E70),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003E70),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF003E70),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF003E70),
        ),
        useMaterial3: true,
      ),

      // 🌙 Dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003E70),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF001F3A),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF001F3A),
          selectedItemColor: Colors.lightBlueAccent,
          unselectedItemColor: Colors.white54,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.lightBlueAccent,
        ),
        useMaterial3: true,
      ),

      // Auto-switch based on system settings
      themeMode: ThemeMode.system,
    );
  }
}
