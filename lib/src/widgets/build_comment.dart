import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_fellas/src/views/profile_screen.dart';

class BuildComment extends StatelessWidget {
  const BuildComment({
    super.key,
    required this.commentData,
    required this.rating,
  });

  final Map<String, dynamic> commentData;
  final double rating;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: InkWell(
        onTap: () {
          Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: commentData['userId']),
        ),
          );
        },
        child: Text(commentData['userName'] ?? 'Anonymous'),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rating > 0)
            RatingBarIndicator(
              rating: rating,
              itemBuilder: (context, index) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 16.0,
            ),
          Text(commentData['comment'] ?? ''),
        ],
      ),
      trailing: Text(
        commentData['timestamp'] != null
            ? (commentData['timestamp'] as Timestamp)
                .toDate()
                .toLocal()
                .toString()
                .split(' ')[0]
                .split('-')
                .reversed
                .join('.')
            : '',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}
