import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool showSettingsButton;

  const LocationDialog({
    super.key,
    required this.title,
    required this.message,
    this.showSettingsButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel"),
        ),
        if (showSettingsButton)
          TextButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            child: Text("Open Settings"),
          ),
      ],
    );
  }
}
