import 'package:flutter/material.dart';

class AuthPromptDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const AuthPromptDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.onLogin,
    required this.onSignup,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(Icons.account_circle,
              color: Theme.of(context).colorScheme.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: onLogin,
          child: Text("Log In"),
        ),
        ElevatedButton(
          onPressed: onSignup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: Text("Sign Up",
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
      ],
    );
  }
}
