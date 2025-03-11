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

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
                'Are you sure you want to exit without saving your avatar?'),
            actions: [
              TextButton(
                child: const Text('Leave'),
                onPressed: () {
                  Navigator.pop(context, true); // Return true when leaving
                },
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, false); // Return false when canceling
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false, // Prevents immediate popping without confirmation
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          bool shouldExit = await _showExitConfirmationDialog(context);
          if (shouldExit) {
            Navigator.of(context).pop(); // Allow popping
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Avatar Creator'),
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
            const SizedBox(height: 10),
            buildColorPicker(),
            const SizedBox(height: 20),

            // Category Selector + GridView + Bottom Button in a Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[600]
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Category Selector
                    buildCategorySelectorContainer(),

                    // Grid View
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                          ),
                          itemCount: currentAtoms.length,
                          itemBuilder: (context, index) {
                            PeepAtom atom = currentAtoms[index];
                            bool isSelected = selectedAtom == atom;
                            return GestureDetector(
                              onTap: () => _onAtomSelected(atom),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[600]
                                      : Colors.transparent,
                                ),
                                child: Center(
                                  child: PeepImage(
                                    peepAtom: atom,
                                    size: (selectedCategory == 'Face' ||
                                            selectedCategory == 'Accessories')
                                        ? 96
                                        : 64,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Bottom Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Uint8List? capturedImage =
                              await screenshotController.capture();
                          if (capturedImage != null) {
                            Navigator.pop(context, capturedImage);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        label: Text(
                          'Use Avatar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps the Category Selector with rounded corners and padding.
  Widget buildCategorySelectorContainer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: categories.map((category) {
            bool isSelected = selectedCategory == category;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategory = category;
                  _updateCurrentAtoms();
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
    return ElevatedButton.icon(
      onPressed: () {
        pickBackgroundColor();
      },
      icon: Icon(Icons.color_lens),
      label: Text('Pick Background Color'),
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
