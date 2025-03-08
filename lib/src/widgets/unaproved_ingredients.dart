import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/src/models/ingredient.dart';

class UnapprovedIngredientsTab extends StatefulWidget {
  @override
  _UnapprovedIngredientsTabState createState() =>
      _UnapprovedIngredientsTabState();
}

class _UnapprovedIngredientsTabState extends State<UnapprovedIngredientsTab> {
  late Stream<QuerySnapshot> _unapprovedIngredientsStream;
  bool _isApprovingAll = false; // Track approval status

  @override
  void initState() {
    super.initState();
    _unapprovedIngredientsStream = FirebaseFirestore.instance
        .collection('ingredients')
        .where('approved', isEqualTo: false)
        .snapshots();
  }

  /// Approves a single ingredient
  void _approveIngredient(String docId, String name, String category) async {
    try {
      await FirebaseFirestore.instance
          .collection('ingredients')
          .doc(docId)
          .update({'approved': true, 'ingredientName': name, 'category': category});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingredient approved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve ingredient: $e')),
      );
    }
  }

  /// Deletes a single ingredient
  void _deleteIngredient(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ingredients')
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingredient deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete ingredient: $e')),
      );
    }
  }

  /// Opens a dialog to edit an ingredient before approving it
  void _editIngredientDialog(DocumentSnapshot doc) {
    TextEditingController nameController =
        TextEditingController(text: doc['ingredientName']);
    String selectedCategory = doc['category']; // Store selected category

    List<String> categoryOptions = [
      'Vegetable',
      'Fruit',
      'Grain',
      'Protein',
      'Dairy',
      'Spice & Seasoning',
      'Fat & Oil',
      'Herb',
      'Seafood',
      'Condiment',
      'Nuts & Seeds',
      'Legume',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Ingredient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Ingredient Name'),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(labelText: 'Category'),
                items: categoryOptions.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    selectedCategory = newValue;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Save & Approve'),
              onPressed: () {
                _approveIngredient(doc.id, nameController.text, selectedCategory);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "Approve All" Button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _isApprovingAll ? null : _approveAllIngredients,
            icon: Icon(Icons.check_circle_outline),
            label: _isApprovingAll
                ? CircularProgressIndicator()
                : Text("Approve All"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        // List of Unapproved Ingredients
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _unapprovedIngredientsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final ingredients = snapshot.data!.docs;

              if (ingredients.isEmpty) {
                return Center(child: Text('No unapproved ingredients.'));
              }

              return ListView.builder(
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  final doc = ingredients[index];
                  final ingredient = Ingredient.fromDocumentSnapshot(doc);

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      title: Text(ingredient.ingredientName),
                      subtitle: Text('Category: ${ingredient.category}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editIngredientDialog(doc),
                          ),
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () => _approveIngredient(doc.id, ingredient.ingredientName, ingredient.category),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Approves all unapproved ingredients
  void _approveAllIngredients() async {
    setState(() {
      _isApprovingAll = true; // Show loading indicator
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('ingredients')
          .where('approved', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'approved': true});
      }

      await batch.commit(); // Execute all updates in one transaction

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${querySnapshot.docs.length} ingredients approved.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve all ingredients: $e')),
      );
    }

    setState(() {
      _isApprovingAll = false; // Remove loading indicator
    });
  }

  /// Shows a confirmation dialog before deleting an ingredient.
  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Ingredient'),
          content: Text('Are you sure you want to delete this ingredient?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                _deleteIngredient(docId);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
