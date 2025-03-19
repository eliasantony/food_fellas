import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:food_fellas/src/widgets/expandableFAB.dart'; // if needed for your other widgets

class OverlayExpandableFab extends StatefulWidget {
  final double distance;
  final List<Widget> children;
  final bool initialOpen;

  const OverlayExpandableFab({
    Key? key,
    this.initialOpen = false,
    required this.distance,
    required this.children,
  }) : super(key: key);

  @override
  _OverlayExpandableFabState createState() => _OverlayExpandableFabState();
}

class _OverlayExpandableFabState extends State<OverlayExpandableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  OverlayEntry? _overlayEntry;
  bool _open = false;
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _open = widget.initialOpen;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _open ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  /// Toggles the menu open/closed.
  void _toggle() {
    if (_open) {
      _controller.reverse();
      _removeOverlay();
    } else {
      _controller.forward();
      _showOverlay();
    }
    setState(() {
      _open = !_open;
    });
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context)!.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    // Get the FAB's global position and size.
    RenderBox renderBox =
        _fabKey.currentContext!.findRenderObject() as RenderBox;
    Offset fabPosition = renderBox.localToGlobal(Offset.zero);
    Size fabSize = renderBox.size;
    // Compute the center of the FAB.
    Offset fabCenter =
        fabPosition + Offset(fabSize.width / 2, fabSize.height / 2);

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Full-screen background to dismiss the overlay when tapped or swiped.
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggle,
                onVerticalDragEnd: (_) => _toggle(),
                onHorizontalDragEnd: (_) => _toggle(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                    color:
                        const Color.fromARGB(255, 63, 63, 63).withOpacity(0.5)),
              ),
            ),
            // The central close button that appears when expanded.
            Positioned(
              left: fabCenter.dx - 28, // 28 = half of the 56px diameter
              top: fabCenter.dy - 28,
              child: _buildTapToCloseFab(),
            ),
            // Container for the expanded buttons centered around the FAB.
            Positioned(
              left: fabCenter.dx - widget.distance,
              top: fabCenter.dy - widget.distance,
              width: widget.distance * 2,
              height: widget.distance * 2.3,
              child: _buildExpandingButtons(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpandingButtons() {
    List<Widget> buttons = [];
    List<double> angles;

    // For exactly 3 children, use fixed angles for a 120° arc:
    // 210° (left), 270° (center/up), and 330° (right).
    if (widget.children.length == 3) {
      angles = [210.0, 270.0, 330.0];
    } else {
      // Otherwise, spread them evenly over a 120° arc centered at 270°.
      final double arc = 120.0;
      final double startAngle = 270.0 - arc / 2;
      final double step =
          widget.children.length > 1 ? arc / (widget.children.length - 1) : 0;
      angles =
          List.generate(widget.children.length, (i) => startAngle + (i * step));
    }

    for (var i = 0; i < widget.children.length; i++) {
      Widget child = widget.children[i];
      // If the child is an ActionButton, wrap it so that its onPressed first dismisses the overlay.
      if (child is ActionButton) {
        final ActionButton actionBtn = child;
        child = ActionButton(
          onPressed: () {
            _toggle(); // Dismiss overlay.
            if (actionBtn.onPressed != null) {
              actionBtn.onPressed!();
            }
          },
          icon: actionBtn.icon,
        );
      }
      buttons.add(_ExpandingActionButton(
        directionInDegrees: angles[i],
        maxDistance: widget.distance,
        progress: _expandAnimation,
        child: child,
      ));
    }
    return Stack(
      children: buttons,
    );
  }

  /// The button shown at the center when the overlay is open.
  Widget _buildTapToCloseFab() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This FAB remains 56×56 so that the BottomAppBar notch is preserved.
    return SizedBox(
      key: _fabKey,
      width: 56,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: Colors.transparent,
          onPressed: _toggle,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _expandAnimation.value,
                child:
                    Icon(_open ? Icons.close : Icons.add, color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExpandingActionButton extends StatelessWidget {
  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  const _ExpandingActionButton({
    Key? key,
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double rad = directionInDegrees * (math.pi / 180.0);
    return AnimatedBuilder(
      animation: progress,
      builder: (context, childWidget) {
        // Compute the offset from the center based on the angle and progress.
        final offset = Offset.fromDirection(rad, progress.value * maxDistance);
        return Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: offset,
            child: FadeTransition(
              opacity: progress,
              child: childWidget,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
