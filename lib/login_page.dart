import 'package:assignment/main.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_dashboard.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

//_LoginPageState mean private class
class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  //Why this not put in the build because build need to recall many time

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //Scaffold provide (AppBar,Body,BottomNavigationBar,FloatingButton)
      appBar: AppBar(title: Text("Login")),
      body: Column(
        children: [
          TextField(
            controller: usernameController,
            decoration: InputDecoration(labelText: "ID"),
          ),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(labelText: "Password"),
            obscureText: true,
          ),
          ElevatedButton(
            onPressed: () async {
              final supabase = Supabase.instance.client;

              String id = usernameController.text;
              String password = passwordController.text;

              final admin = await supabase
                  .from('admin')
                  .select()
                  .eq('id', id)
                  .eq('password', password)
                  .maybeSingle();

              if (admin != null) {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminDashboard(),
                  ),
                );
                return;
              }

              final resident = await supabase
                  .from('residence')
                  .select()
                  .eq('id', id)
                  .eq('password', password)
                  .maybeSingle();

              if (resident != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyHomePage(title: "Home"),
                  ),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Login Failed")));
              }
            },
            child: Text("Login"),
          ),
        ],
      ),
    );
  }
}
