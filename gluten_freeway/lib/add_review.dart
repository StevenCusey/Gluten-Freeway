import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongo_db_connection.dart';

class AddReviewPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String username;

  AddReviewPage({
    required this.restaurantId,
    required this.restaurantName,
    required this.username,
  });

  @override
  _AddReviewPageState createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  int _rating = 5; // Default to 5 stars
  TextEditingController _reviewTextController = TextEditingController();

  /// Inserts a review into MongoDB
  Future<void> submitReview() async {
    String reviewText = _reviewTextController.text.trim();

    if (reviewText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a review"), backgroundColor: Colors.red),
      );
      return;
    }

    if (reviewText.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Review must be 200 characters or less."), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      var db = await mongo.Db.create(mongoDbConnectionString);
      await db.open();
      var reviewCollection = db.collection("reviews");

      // Check if the user has already reviewed this restaurant
      var existingReview = await reviewCollection.findOne({
        "restaurantId": widget.restaurantId,
        "reviewUser": widget.username,
      });

      if (existingReview != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You have already reviewed this restaurant."), backgroundColor: Colors.red),
        );
        await db.close();
        return;
      }

      // Insert the new review
      await reviewCollection.insertOne({
        "restaurantId": widget.restaurantId,
        "reviewUser": widget.username,
        "reviewStars": _rating,
        "reviewText": reviewText,
      });

      await db.close();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Review added successfully!"), backgroundColor: Colors.green),
      );

      Navigator.pop(context); // Go back to restaurant catalog
    } catch (e) {
      print("Error submitting review: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit review: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// UI to show star rating selection
  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < _rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 30,
          ),
          onPressed: () {
            setState(() {
              _rating = index + 1; // Update rating when clicked
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Creating Review for ${widget.restaurantName}")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Rate this restaurant:", style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            _buildStarRating(), // Star rating selector
            TextField(
              controller: _reviewTextController,
              maxLength: 200,
              decoration: InputDecoration(labelText: "Write your review"),
            ),
            SizedBox(height: 10),
            OutlinedButton(
              onPressed: submitReview,
              child: Text("Submit Review", style: TextStyle(color: Colors.green)),
              style: OutlinedButton.styleFrom(
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
