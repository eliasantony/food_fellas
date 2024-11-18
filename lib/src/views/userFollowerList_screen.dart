import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FollowersListScreen extends StatelessWidget {
  final String userId;
  final String displayName;

  FollowersListScreen({required this.userId, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('$displayName\'s Followers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('followers')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error fetching followers'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final followers = snapshot.data!.docs;

          if (followers.isEmpty) {
            return Center(child: Text('No followers yet.'));
          }

          // Rearrange the list to put the current user on top if they are a follower
          List<DocumentSnapshot> sortedFollowers = followers;

          if (currentUser != null) {
            sortedFollowers = List<DocumentSnapshot>.from(followers);
            sortedFollowers.sort((a, b) {
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
            itemCount: sortedFollowers.length,
            itemBuilder: (context, index) {
              final followerData =
                  sortedFollowers[index].data() as Map<String, dynamic>;
              String followerId = followerData['uid'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followerId)
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

                  return UserFollowerListItem(userData: userData);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class UserFollowerListItem extends StatefulWidget {
  final Map<String, dynamic> userData;

  UserFollowerListItem({required this.userData});

  @override
  _UserFollowerListItemState createState() => _UserFollowerListItemState();
}

class _UserFollowerListItemState extends State<UserFollowerListItem> {
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  void _checkIfFollowing() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String profileUserId = widget.userData['uid'];

    final followerDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(profileUserId)
        .collection('followers')
        .doc(currentUser.uid);

    final followerSnapshot = await followerDoc.get();
    setState(() {
      isFollowing = followerSnapshot.exists;
    });
  }

  void _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String profileUserId = widget.userData['uid'];

    final followerDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(profileUserId)
        .collection('followers')
        .doc(currentUser.uid);

    if (isFollowing) {
      // Unfollow
      await followerDoc.delete();
    } else {
      // Follow
      await followerDoc.set({
        'uid': currentUser.uid,
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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(widget.userData['photo_url'] ?? ''),
      ),
      title: Text(
        widget.userData['display_name'] ?? 'User',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        'Recipes: ${widget.userData['recipesCount'] ?? 0} • Avg. Rating: ${widget.userData['averageRating']?.toStringAsFixed(1) ?? 'N/A'}',
        style: TextStyle(fontSize: 14),
      ),
      trailing: widget.userData['uid'] != FirebaseAuth.instance.currentUser?.uid
        ? Tooltip(
          message: isFollowing
            ? 'Unfollow ${widget.userData['display_name']}'
            : 'Follow ${widget.userData['display_name']}',
          child: IconButton(
            iconSize: 24,
            icon: isFollowing
              ? Icon(Icons.person_add_disabled_rounded)
              : Icon(Icons.person_add_rounded),
            color: isFollowing ? Colors.red[600] : Colors.green[600],
            onPressed: _toggleFollow,
          ),
          )
        : null,
    );
  }
}
