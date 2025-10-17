import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/LoginScreen.dart';
import 'screens/DashboardScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bmgpiypezsejajmejxba.supabase.co',
    anonKey:
        '<prefer publishable key instead of anon key for mobile and desktop apps>',
  );

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => DashboardScreen(),
      ),
    ],
  );

  runApp(MyApp(router: router));
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({required this.router, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      title: 'Tools Audit App',
      debugShowCheckedModeBanner: false,
    );
  }
}
