import 'package:flutter/material.dart';

class SortingModal extends StatefulWidget {
  final String? initialSortField;
  final bool initialIsAscending;
  final Function(String?, bool) onApply;

  SortingModal({
    this.initialSortField,
    required this.initialIsAscending,
    required this.onApply,
  });

  @override
  _SortingModalState createState() => _SortingModalState();
}

class _SortingModalState extends State<SortingModal> {
  String? sortField;
  late bool isAscending;

  @override
  void initState() {
    super.initState();
    sortField = widget.initialSortField;
    isAscending = widget.initialIsAscending;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // ... style as needed
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('Sort By'),
            trailing: DropdownButton<String>(
              value: sortField,
              hint: Text('Select Field'),
              items: [
                DropdownMenuItem(value: 'name', child: Text('Name')),
                DropdownMenuItem(value: 'createdAt', child: Text('Time Created')),
                DropdownMenuItem(value: 'averageRating', child: Text('Rating')),
                DropdownMenuItem(value: 'totalTime', child: Text('Total Time')),
                DropdownMenuItem(value: 'ingredientsCount', child: Text('Number of Ingredients')),
              ],
              onChanged: (value) {
                setState(() {
                  sortField = value;
                });
              },
            ),
          ),
          ListTile(
            title: Text('Order'),
            trailing: DropdownButton<bool>(
              value: isAscending,
              items: [
                DropdownMenuItem(value: true, child: Text('Ascending')),
                DropdownMenuItem(value: false, child: Text('Descending')),
              ],
              onChanged: (value) {
                setState(() {
                  isAscending = value!;
                });
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onApply(sortField, isAscending);
            },
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }
}
