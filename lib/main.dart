// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tools_audit_app_v2/screens/ExportExcelPage.dart';
import 'package:tools_audit_app_v2/screens/SignupPage.dart';
import 'screens/LoginScreen.dart';
import 'screens/DashboardScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/TechnicianToolsPage.dart';
import 'screens/TechniciansScreen.dart';
import 'screens/ManageTechnicianToolsScreen.dart';
import 'screens/AddNewToolPage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final supabaseURL = dotenv.env['supabaseURL'];
  final supabaseAnonKey = dotenv.env['supabaseAnonKey'];

  if (supabaseURL == null) {
    throw Exception("supabaseURL is missing in .env");
  }
  if (supabaseAnonKey == null) {
    throw Exception("supabaseAnonKey is missing in .env");
  }

  await Supabase.initialize(
    url: supabaseURL,
    anonKey: supabaseAnonKey,
    // print(supabaseURL);
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
          // Ensure state.extra is a Map
          final technician = state.extra as Map<String, dynamic>?;

          if (technician == null || technician['id'] == null) {
            return Scaffold(
              body: Center(child: Text('❌ No technician ID provided')),
            );
          }

          final technicianId = technician['id'].toString(); // convert to string

          return ManageTechnicianToolsScreen(
            technicianId: technicianId,
            technician:
                technician, // optional if your screen needs the full map
          );
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
      GoRoute(
        path: '/export-excel',
        //builder: (context, state) => const ExportExcelPage(),
        builder: (context, state) => const ExportOptionsPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
    ],
  );

  runApp(MyApp(router: router));
}

class MyApp extends StatefulWidget {
  final GoRouter router;
  const MyApp({required this.router, super.key});

  // Add this static method
  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system; // default

  // Change this method name from _toggleTheme to toggleTheme (remove underscore)
  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  // Add this getter
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: widget.router,
      title: 'Tools Audit App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF003E70), //blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003E70),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003E70),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
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
        useMaterial3: true,
      ),
      themeMode: _themeMode,
    );
  }
}
