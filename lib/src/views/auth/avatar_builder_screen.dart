import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_peeps/open_peeps.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AvatarBuilderScreen extends StatefulWidget {
  @override
  _AvatarBuilderScreenState createState() => _AvatarBuilderScreenState();
}

class _AvatarBuilderScreenState extends State<AvatarBuilderScreen> {
  PeepAtom selectedFace = Face.atoms.first;
  PeepAtom selectedHead = Head.atoms.first;
  PeepAtom selectedFacialHair = FacialHair.atoms.first;
  PeepAtom selectedAccessory = Accessories.atoms.first;

  Color backgroundColor = Colors.green;
  final ScreenshotController screenshotController = ScreenshotController();

  // Categories for the grid
  List<String> categories = ['Face', 'Hair', 'Facial Hair', 'Accessories'];
  String selectedCategory = 'Face';

  // Current atoms displayed in the grid
  List<PeepAtom> currentAtoms = Face.atoms;

  PeepAtom get selectedAtom {
    switch (selectedCategory) {
      case 'Face':
        return selectedFace;
      case 'Hair':
        return selectedHead;
      case 'Facial Hair':
        return selectedFacialHair;
      case 'Accessories':
        return selectedAccessory;
      default:
        return selectedFace;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Avatar Creator'),
      ),
      body: Column(
        children: [
          // Avatar Preview with Screenshot
          Screenshot(
            controller: screenshotController,
            child: SizedBox(
              height: 200.0,
              child: Center(
                child: PeepAvatar.fromAtoms(
                  face: selectedFace,
                  head: selectedHead,
                  facialHair: selectedFacialHair,
                  accessory: selectedAccessory,
                  backgroundColor: backgroundColor,
                  size: 160.0,
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          buildColorPicker(),
          SizedBox(height: 20),
          // Category Selector Row
          buildCategorySelector(),
          // Grid View for selecting atoms
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 5.0,
                  mainAxisSpacing: 5.0,
                ),
                itemCount: currentAtoms.length,
                itemBuilder: (context, index) {
                  PeepAtom atom = currentAtoms[index];
                  bool isSelected =
                      selectedAtom == atom; // Check if the atom is selected
                  return GestureDetector(
                    onTap: () => _onAtomSelected(atom),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.transparent,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: PeepImage(
                          peepAtom: atom,
                          size: (selectedCategory == 'Face' ||
                                  selectedCategory == 'Accessories')
                              ? 96
                              : 64, // Adjust size based on category
                        ), // Display the image of the atom
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              Uint8List? capturedImage = await screenshotController.capture();
              if (capturedImage != null) {
                Navigator.pop(context, capturedImage);
              }
            },
            child: Text('Use Avatar'),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget buildCategorySelector() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: categories.map((category) {
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = category;
                _updateCurrentAtoms(); // Update grid view when category is changed
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selectedCategory == category
                        ? Colors.blue
                        : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color:
                      selectedCategory == category ? Colors.blue : Colors.black,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _updateCurrentAtoms() {
    switch (selectedCategory) {
      case 'Face':
        currentAtoms = Face.atoms;
        break;
      case 'Hair':
        currentAtoms = Head.atoms;
        break;
      case 'Facial Hair':
        currentAtoms = FacialHair.atoms;
        break;
      case 'Accessories':
        currentAtoms = Accessories.atoms;
        break;
    }
  }

  void _onAtomSelected(PeepAtom atom) {
    setState(() {
      switch (selectedCategory) {
        case 'Face':
          selectedFace = atom;
          break;
        case 'Hair':
          selectedHead = atom;
          break;
        case 'Facial Hair':
          selectedFacialHair = atom;
          break;
        case 'Accessories':
          selectedAccessory = atom;
          break;
      }
    });
  }

  Widget buildColorPicker() {
    return ElevatedButton(
      onPressed: () {
        pickBackgroundColor();
      },
      child: Text('Pick Background Color'),
    );
  }

  void pickBackgroundColor() {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = backgroundColor;

        return AlertDialog(
          title: Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: backgroundColor,
              onColorChanged: (color) {
                tempColor = color;
              },
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            ElevatedButton(
              child: Text('Done'),
              onPressed: () {
                setState(() {
                  backgroundColor = tempColor;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
