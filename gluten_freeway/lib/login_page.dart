import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart'; // Import bcrypt
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongo_db_connection.dart';
import 'restaurant_catalog.dart';

class LoginPage extends StatelessWidget {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  

Future<bool> authenticateUser(String username, String password) async {
  try {
    var db = await mongo.Db.create(mongoDbConnectionString);
    await db.open();

    var collection = db.collection(usersCollection);
    var user = await collection.findOne({"username": username});

    await db.close();

    if (user == null) return false; // No user found

    String hashedPassword = user["password"]; // Retrieve hashed password

    // Verify input password against stored hashed password
    return BCrypt.checkpw(password, hashedPassword);
  } catch (e) {
    print("Error during authentication: $e");
    throw Exception("Login failed: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/register');
              },
              child: Text(
                "Don't have an account?\nRegister here!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 20),
            Image.asset('assets/GlutenFreewayDemoLogo.png', height: 100),
            SizedBox(height: 20),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 20),
            OutlinedButton(
              onPressed: () async {
                String username = usernameController.text.trim();
                String password = passwordController.text.trim();

                if (username.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Please enter both username and password."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  bool isAuthenticated = await authenticateUser(
                    username,
                    password,
                  );

                  if (isAuthenticated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Login Successful!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantCatalog(loggedInUsername: username),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Invalid username or password."),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Login failed: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                'Log In',
                style: TextStyle(color: Colors.green, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                side: BorderSide(color: Colors.green, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
