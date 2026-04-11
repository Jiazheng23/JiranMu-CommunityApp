import 'package:assignment/main.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_dashboard.dart';
import 'package:geolocator/geolocator.dart';
import 'location.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

//_LoginPageState mean private class
class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  //Why this not put in the build because build need to recall many time

  // Inside your LoginPage State class
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permissions are permanently denied.');
    }

    // ONLY AFTER PERMISSION IS GRANTED, you can get the position
    final position = await Geolocator.getCurrentPosition();
    print(position);
  }

  @override
  void initState() {
    super.initState();
    // Delay the call so it doesn't block the initial app build
    Future.delayed(Duration.zero, () => _checkLocationPermission());
  }

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
                await updateLocation('admin', id);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminDashboard(user: admin),
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
                await updateLocation('residence', id);
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
