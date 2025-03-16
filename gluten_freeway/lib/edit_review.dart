import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongo_db_connection.dart';

class EditReviewPage extends StatefulWidget {
  final String reviewId;
  final String restaurantId;
  final String restaurantName;
  final String username;
  final int initialRating;
  final String initialReviewText;

  EditReviewPage({
    required this.reviewId,
    required this.restaurantId,
    required this.restaurantName,
    required this.username,
    required this.initialRating,
    required this.initialReviewText,
  });

  @override
  _EditReviewPageState createState() => _EditReviewPageState();
}

class _EditReviewPageState extends State<EditReviewPage> {
  late int _rating;
  TextEditingController _reviewTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _reviewTextController.text = widget.initialReviewText;
  }

  /// Updates the review in MongoDB
  Future<void> updateReview() async {
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
      var collection = db.collection("reviews");

      await collection.updateOne(
        mongo.where.id(mongo.ObjectId.parse(widget.reviewId)),
        mongo.modify.set("reviewStars", _rating).set("reviewText", reviewText),
      );

      await db.close();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Review updated successfully!"), backgroundColor: Colors.green),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error updating review: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update review: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// Builds the star rating selector
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
      appBar: AppBar(title: Text("Editing Review for ${widget.restaurantName}")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Update your rating:", style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            _buildStarRating(), // Star rating selector
            TextField(
              controller: _reviewTextController,
              maxLength: 200,
              decoration: InputDecoration(labelText: "Edit your review"),
            ),
            SizedBox(height: 10),
            OutlinedButton(
              onPressed: updateReview,
              child: Text("Update Review", style: TextStyle(color: Colors.green)),
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
