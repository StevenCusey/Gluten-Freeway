import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:bcrypt/bcrypt.dart'; // Import bcrypt package
import 'mongo_db_connection.dart'; // Import connection details

class RegistrationPage extends StatelessWidget {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Function to validate email format
  bool validateEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Function to validate password
  bool validatePassword(String password) {
    final passwordRegex =
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{6,20}$');
    return passwordRegex.hasMatch(password);
  }

  // Function to validate username
  bool validateUsername(String username) {
    return username.length >= 6 && username.length <= 20;
  }

  // Function to register a user
  Future<void> registerUser(String username, String email, String password) async {
    try {
      print("Connecting to MongoDB...");
      var db = await mongo.Db.create(mongoDbConnectionString);
      await db.open();
      print("Connected to MongoDB.");

      var collection = db.collection(usersCollection);
      print("Collection reference obtained.");

      // Check if the username or email already exists
      var existingUser = await collection.findOne(mongo.where.eq('username', username));
      var existingEmail = await collection.findOne(mongo.where.eq('email', email));

      if (existingUser != null || existingEmail != null) {
        await db.close();
        throw Exception("Username or Email already exists. Please use another.");
      }

      // Hash the password using bcrypt
      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      var result = await collection.insertOne({
        "username": username,
        "email": email,
        "password": hashedPassword, // Store the hashed password in the database
      });

      if (result.isSuccess) {
        print("User registered successfully.");
      } else {
        print("Failed to register user.");
        throw Exception("Failed to register user.");
      }

      await db.close();
      print("Connection closed.");
    } catch (e) {
      print("Error during registration: $e");
      throw Exception("Registration failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Register"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/');
                },
                child: Text(
                  "Already have an account? Click here!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 20),
              Image.asset(
                'assets/GlutenFreewayDemoLogo.png',
                height: 100,
              ),
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
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
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
                  String email = emailController.text.trim();
                  String password = passwordController.text.trim();

                  if (username.isEmpty || email.isEmpty || password.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Please fill in all fields."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (!validateUsername(username)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Username must be between 6 and 20 characters."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (!validateEmail(email)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Please enter a valid email address."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (!validatePassword(password)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Password must be 6-20 characters long and include at least one uppercase letter, one lowercase letter, and one number."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    await registerUser(username, email, password);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("User Registered Successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );

                    usernameController.clear();
                    emailController.clear();
                    passwordController.clear();
                  } catch (e) {
                    String errorMessage = e.toString();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          errorMessage.contains("Username or Email already exists")
                              ? "Username or Email already exists. Please use another."
                              : "Registration failed: $errorMessage",
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(
                  "Register Account",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.green, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
