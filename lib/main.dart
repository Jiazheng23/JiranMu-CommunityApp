import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_page.dart';

const supabaseUrl = 'https://xgttjcpvjweueoaeufac.supabase.co';
const supabaseKey = 'sb_publishable_jO5Lkks7maYrgqJp3IA-3g_04wY0JRb';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JiranMu',
      theme: ThemeData(useMaterial3: true),
      home: const WelcomePage(),
    );
  }
}