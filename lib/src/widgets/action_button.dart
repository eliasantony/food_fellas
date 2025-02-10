// action_button.dart
import 'package:flutter/material.dart';

@immutable
class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;

  const ActionButton({
    Key? key,
    this.onPressed,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Material(
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        elevation: 4,
        child: IconButton(
          onPressed: onPressed,
          icon: icon,
          color: Colors.white,
        ),
      ),
    );
  }
}
