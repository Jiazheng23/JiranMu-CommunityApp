import 'dart:async';
import 'package:assignment/resident/resident_login_page.dart';
import 'package:assignment/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://xgttjcpvjweueoaeufac.supabase.co';
const supabaseKey = 'sb_publishable_jO5Lkks7maYrgqJp3IA-3g_04wY0JRb';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  // await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isHandlingRecovery = false;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          final event = data.event;

          if (event == AuthChangeEvent.passwordRecovery && !_isHandlingRecovery) {
            _isHandlingRecovery = true;

            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const ResetPasswordPage(),
              ),
                  (route) => false,
            );
          }
        });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'JiranMu',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F3EE),
      ),
      home: const ResidentLoginPage(),
    );
  }
}