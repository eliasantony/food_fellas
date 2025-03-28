import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PhotoViewScreen extends StatelessWidget {
  final String imageUrl;

  PhotoViewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Adjust the velocity threshold as needed.
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 500) {
            Navigator.pop(context);
          }
        },
        child: Center(
          child: PhotoView(
            imageProvider: imageUrl.startsWith('http')
                ? CachedNetworkImageProvider(imageUrl)
                : AssetImage(imageUrl) as ImageProvider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
    );
  }
}
