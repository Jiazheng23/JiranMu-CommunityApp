/*import 'package:assignment/main.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';

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
  void dispose(){
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold( //Scaffold provide (AppBar,Body,BottomNavigationBar,FloatingButton)
      appBar: AppBar(title: Text("Login")),
      body: Column(
        children: [
          TextField(controller: usernameController, decoration: InputDecoration(labelText: "Username")),
          TextField(controller: passwordController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
          ElevatedButton(onPressed: (){
            Navigator.push(context,
                MaterialPageRoute(
                  builder: (context) => MyHomePage(title: "Home",),
                ),
            );
          },
            child: Text("Login"),
          ),
        ],
      ),
    );
  }
}*/