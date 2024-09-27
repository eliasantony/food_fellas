import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShoppingListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping List'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('shoppingList')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error fetching shopping list'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!.docs;

          List<DocumentSnapshot> activeItems = [];
          List<DocumentSnapshot> doneItems = [];

          for (var item in items) {
            if ((item['status'] ?? 'active') == 'active') {
              activeItems.add(item);
            } else {
              doneItems.add(item);
            }
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Active Items
                ListTile(
                  title: Text('Active Items'),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: activeItems.length,
                  itemBuilder: (context, index) {
                    final itemData =
                        activeItems[index].data() as Map<String, dynamic>;
                    return CheckboxListTile(
                      title: Text(
                          '${itemData['item']} (${itemData['amount']} ${itemData['unit']})'),
                      value: false,
                      onChanged: (value) {
                        // Move item to 'done'
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('shoppingList')
                            .doc(activeItems[index].id)
                            .update({'status': 'done'});
                      },
                    );
                  },
                ),
                Divider(),
                // Done Items
                ListTile(
                  title: Text('Done Items'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      // Delete all done items
                      _clearDoneItems(user.uid, doneItems);
                    },
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: doneItems.length,
                  itemBuilder: (context, index) {
                    final itemData =
                        doneItems[index].data() as Map<String, dynamic>;
                    return CheckboxListTile(
                      title: Text(
                        '${itemData['item']} (${itemData['amount']} ${itemData['unit']})',
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      value: true,
                      onChanged: (value) {
                        // Move item back to 'active'
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('shoppingList')
                            .doc(doneItems[index].id)
                            .update({'status': 'active'});
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _clearDoneItems(String userId, List<DocumentSnapshot> doneItems) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var item in doneItems) {
      batch.delete(item.reference);
    }
    await batch.commit();
  }
}
