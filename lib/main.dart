import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/event/screen/event_calendar_screen.dart';

const supabaseUrl = 'https://xgttjcpvjweueoaeufac.supabase.co';
const supabaseKey = 'sb_publishable_jO5Lkks7maYrgqJp3IA-3g_04wY0JRb';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  // --- TOGGLE TEST ACCOUNT HERE ---

  // 1. FOR ADMIN TESTING (Uncomment to use):
  const testEmail = 'wongkz-wm23@student.tarc.edu.my';
  const testPass  = '8888';

  // 2. FOR RESIDENT TESTING (Uncomment to use):
   //const testEmail = 'wongkz2003@gmail.com';
   //const testPass  = '888888';

  // -------------------------------

  try {
    await Supabase.instance.client.auth.signInWithPassword(
      email: testEmail,
      password: testPass,
    );
    // This helps you keep track in the console
    debugPrint("✅ System: Auto-logged in as $testEmail");
  } catch (e) {
    debugPrint("❌ Auto-login error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFAD8762), // Matches your 'cork' theme
      ),
      home: const EventCalendarScreen(),
    );
  }
}