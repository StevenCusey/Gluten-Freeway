import 'package:flutter/material.dart';
import 'login_page.dart';
import 'registration_page.dart'; // Import the registration page
import 'restaurant_catalog.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gluten Freeway',
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/register': (context) => RegistrationPage(), 
      },
    );
  }
}
