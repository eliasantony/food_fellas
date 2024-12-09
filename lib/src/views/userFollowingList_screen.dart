import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_fellas/src/views/profile_screen.dart';

class FollowingListScreen extends StatelessWidget {
  final String userId;
  final String displayName;

  FollowingListScreen({required this.userId, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('$displayName\'s Following'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('following')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error fetching following list'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final following = snapshot.data!.docs;

          if (following.isEmpty) {
            return Center(child: Text('Not following anyone yet.'));
          }

          // Rearrange the list to put the current user on top if applicable
          List<DocumentSnapshot> sortedFollowing = following;

          if (currentUser != null) {
            sortedFollowing = List<DocumentSnapshot>.from(following);
            sortedFollowing.sort((a, b) {
              String aUid = (a.data() as Map<String, dynamic>)['uid'];
              String bUid = (b.data() as Map<String, dynamic>)['uid'];

              if (aUid == currentUser.uid) {
                return -1; // a comes before b
              } else if (bUid == currentUser.uid) {
                return 1; // b comes before a
              } else {
                return 0;
              }
            });
          }

          return ListView.builder(
            itemCount: sortedFollowing.length,
            itemBuilder: (context, index) {
              final followingData =
                  sortedFollowing[index].data() as Map<String, dynamic>;
              String followingId = followingData['uid'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followingId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasError) {
                    return ListTile(title: Text('Error loading user'));
                  }
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(title: Text('Loading...'));
                  }
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  return UserFollowingListItem(userData: userData);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class UserFollowingListItem extends StatefulWidget {
  final Map<String, dynamic> userData;

  UserFollowingListItem({required this.userData});

  @override
  _UserFollowingListItemState createState() => _UserFollowingListItemState();
}

class _UserFollowingListItemState extends State<UserFollowingListItem> {
  bool isFollowing = true;

  void _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String profileUserId = widget.userData['uid'];

    final followerDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(profileUserId)
        .collection('followers')
        .doc(currentUser.uid);

    final followingDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(profileUserId);

    if (isFollowing) {
      // Unfollow
      await followingDoc.delete();
      await followerDoc.delete();
    } else {
      // Follow
      await followerDoc.set({
        'uid': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await followingDoc.set({
        'uid': profileUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      isFollowing = !isFollowing;
    });

    // Haptic feedback
    HapticFeedback.selectionClick();

    // Show snackbar message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFollowing ? 'Followed user' : 'Unfollowed user'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: widget.userData['uid']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: _navigateToProfile,
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(widget.userData['photo_url'] ?? ''),
        backgroundColor: Colors.transparent,
      ),
      title: name(),
      subtitle: subtitle(),
      trailing: widget.userData['uid'] != FirebaseAuth.instance.currentUser?.uid
          ? Tooltip(
              message: isFollowing
                  ? 'Unfollow ${widget.userData['display_name']}'
                  : 'Follow ${widget.userData['display_name']}',
              child: IconButton(
                iconSize: 24,
                icon: isFollowing
                    ? Icon(Icons.person_remove_rounded)
                    : Icon(Icons.person_add_rounded),
                color: isFollowing ? Colors.red[600] : Colors.green[600],
                onPressed: _toggleFollow,
              ),
            )
          : null,
    );
  }

  Widget name() {
    return Row(
      children: [
        Text(
          widget.userData['display_name'] ?? 'User',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        if (widget.userData['uid'] == FirebaseAuth.instance.currentUser?.uid)
          Text(
            ' (You)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
      ],
    );
  }

  Widget subtitle() {
    return Row(
      children: [
        Text(
          'Recipes: ${widget.userData['recipesCount'] ?? 0}',
          style: TextStyle(fontSize: 14),
        ),
        SizedBox(width: 4),
        Text(
          '(${widget.userData['averageRating']?.toStringAsFixed(1) ?? 'N/A'}',
          style: TextStyle(fontSize: 14),
        ),
        Icon(
          Icons.star,
          size: 16,
          color: Colors.amber,
        ),
        Text(
          ')',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
