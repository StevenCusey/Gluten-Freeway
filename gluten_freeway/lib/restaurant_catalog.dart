import 'package:flutter/material.dart';
import 'package:gluten_freeway/login_page.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongo_db_connection.dart';
import 'add_review.dart';
import 'edit_review.dart';
import 'navigation.dart';

class RestaurantCatalog extends StatefulWidget {
  final String loggedInUsername;

  RestaurantCatalog({required this.loggedInUsername});

  @override
  _RestaurantCatalogState createState() => _RestaurantCatalogState();
}

class _RestaurantCatalogState extends State<RestaurantCatalog> {
  List<Map<String, dynamic>> restaurants = [];
  Map<String, List<Map<String, dynamic>>> restaurantReviews = {};
  Map<String, double> restaurantRatings = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRestaurants();
  }

  /// Fetches restaurant and review data from MongoDB
  Future<void> fetchRestaurants() async {
    try {
      var db = await mongo.Db.create(mongoDbConnectionString);
      await db.open();
      var restaurantCollection = db.collection(restaurantsCollection);
      var reviewCollection = db.collection(reviewsCollection);

      var fetchedRestaurants = await restaurantCollection.find().toList();
      Map<String, List<Map<String, dynamic>>> fetchedReviews = {};
      Map<String, double> fetchedRatings = {};

      for (var restaurant in fetchedRestaurants) {
        String restaurantId = restaurant["_id"].toHexString();

        // Fetch all reviews for the restaurant
        var reviews = await reviewCollection.find({"restaurantId": restaurantId}).toList();
        fetchedReviews[restaurantId] = reviews;

        // Calculate the average star rating
        if (reviews.isNotEmpty) {
          double avgRating = reviews
                  .map((review) => review["reviewStars"] as num)
                  .reduce((a, b) => a + b) /
              reviews.length;
          fetchedRatings[restaurantId] = avgRating;
        } else {
          fetchedRatings[restaurantId] = 0.0; // No reviews, default to 0
        }
      }

      await db.close();
      setState(() {
        restaurants = fetchedRestaurants;
        restaurantReviews = fetchedReviews;
        restaurantRatings = fetchedRatings;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching restaurants: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteReview(String reviewId) async {
    try {
      var db = await mongo.Db.create(mongoDbConnectionString);
      await db.open();
      var reviewCollection = db.collection(reviewsCollection);

      await reviewCollection.deleteOne({"_id": mongo.ObjectId.parse(reviewId)});

      await db.close();
      fetchRestaurants(); // Refresh the UI after deletion

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Review deleted successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      print("Error deleting review: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete review"), backgroundColor: Colors.red),
      );
    }
  }

  void logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  void goToMapView() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NavigationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: logout,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green, width: 2),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              ),
              child: Text(
                "Logout",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text("Restaurant Catalog", style: TextStyle(color: Colors.white)),
            OutlinedButton(
              onPressed: goToMapView,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green, width: 2),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              ),
              child: Text(
                "Map View",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : restaurants.isEmpty
              ? Center(child: Text("No restaurants found."))
              : ListView.builder(
                  padding: EdgeInsets.all(10),
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    var restaurant = restaurants[index];
                    var restaurantId = restaurant["_id"].toHexString();
                    var reviews = restaurantReviews[restaurantId] ?? [];
                    double avgRating = restaurantRatings[restaurantId] ?? 0.0;

                    bool userHasReviewed = reviews.any((review) =>
                        review["reviewUser"] == widget.loggedInUsername);

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ExpansionTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              restaurant["restaurantname"] ?? "Unknown",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "⭐ ${avgRating.toStringAsFixed(1)}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          "Recommended: ${restaurant["recommendedfood"] ?? "Not available"}",
                          style: TextStyle(fontSize: 16),
                        ),
                        children: [
                          ...reviews.map((review) {
                            return ListTile(
                              title: Text(
                                "${review["reviewUser"]} - ${review["reviewStars"]}⭐",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(review["reviewText"] ?? ""),
                            );
                          }).toList(),
                          if (userHasReviewed)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    var userReview = reviews.firstWhere(
                                      (review) => review["reviewUser"] == widget.loggedInUsername,
                                    );

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditReviewPage(
                                          reviewId: userReview["_id"].toHexString(),
                                          restaurantId: restaurantId,
                                          restaurantName: restaurant["restaurantname"],
                                          username: widget.loggedInUsername,
                                          initialRating: userReview["reviewStars"],
                                          initialReviewText: userReview["reviewText"],
                                        ),
                                      ),
                                    ).then((_) => fetchRestaurants());
                                  },
                                  child: Text("Edit Review", style: TextStyle(color: Colors.green)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.green, width: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    var userReview = reviews.firstWhere(
                                      (review) => review["reviewUser"] == widget.loggedInUsername,
                                    );

                                    deleteReview(userReview["_id"].toHexString());
                                  },
                                  child: Text("Delete Review", style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red, width: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  ),
                                ),
                              ],
                            )
                          else
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddReviewPage(
                                      restaurantId: restaurantId,
                                      restaurantName: restaurant["restaurantname"],
                                      username: widget.loggedInUsername,
                                    ),
                                  ),
                                ).then((_) => fetchRestaurants());
                              },
                              child: Text("Add Review", style: TextStyle(color: Colors.green)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.green, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
