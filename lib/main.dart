import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ChatDashboardScreen.dart';

const supabaseUrl = 'https://xgttjcpvjweueoaeufac.supabase.co';
const supabaseKey = 'sb_publishable_jO5Lkks7maYrgqJp3IA-3g_04wY0JRb';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Change currentUser here for emulator 1 vs 2
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatDashboardScreen(currentUser: 'User1'),
    );
  }
}