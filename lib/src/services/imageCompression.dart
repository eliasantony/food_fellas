import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

Future<File> compressImagePreservingAspectRatio(File file) async {
  final int maxSizeInBytes = 2 * 1024 * 1024; // 2 MB threshold
  Uint8List originalBytes = await file.readAsBytes();

  // If the image is already under 2 MB, return it as is
  if (originalBytes.lengthInBytes <= maxSizeInBytes) {
    return file;
  }

  // Decode image to get dimensions
  img.Image? originalImage = img.decodeImage(originalBytes);
  if (originalImage == null) {
    throw Exception("Could not decode image");
  }

  int originalWidth = originalImage.width;
  int originalHeight = originalImage.height;

  // Start with no scaling
  double scale = 1.0;
  late List<int> compressedBytes;

  // Loop: reduce size until the file is under the 2 MB threshold.
  do {
    scale *= 0.9; // Reduce dimensions by 10%
    int newWidth = (originalWidth * scale).toInt();
    int newHeight = (originalHeight * scale).toInt();

    // Resize image using the computed dimensions (aspect ratio is preserved)
    img.Image resizedImage = img.copyResize(
      originalImage,
      width:
          newWidth, // only width is enough if you calculate new height based on the ratio
      height: newHeight,
    );

    // Adjust quality as needed (quality can be tuned between 1 and 100)
    compressedBytes = img.encodeJpg(resizedImage, quality: 80);

    // Break if scale becomes too small to avoid an infinite loop
    if (scale < 0.1) break;
  } while (compressedBytes.length > maxSizeInBytes);

  // Save the compressed image to a temporary file
  final tempDir = await getTemporaryDirectory();
  final targetPath =
      '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
  final compressedFile = File(targetPath);
  await compressedFile.writeAsBytes(compressedBytes);

  return compressedFile;
}
