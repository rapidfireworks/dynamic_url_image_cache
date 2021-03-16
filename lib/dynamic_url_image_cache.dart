library dynamic_url_image_cache;

import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';

/// Stores your in cache after the first download.
///
/// The value of [imageId] and [imageUrl] cannot be null.
class DynamicUrlImageCache extends ImageProvider<DynamicUrlImageCache> {
  DynamicUrlImageCache({
    required this.imageId,
    required this.imageUrl,
    this.isCaching = true,
    this.scale = 1.0,
  });

  ///The id used to store the image file, is used in the path.
  final String imageId;

  ///The url used to download the first time.
  final String imageUrl;

  /// Enable or disable image caching
  final bool isCaching;

  /// Enable or disable image caching
  final double scale;

  Future<File> _imageFile() async {
    final dir = await getTemporaryDirectory();
    return File("${dir.path}/$imageId");
  }

  Future<Uint8List> _createImage() async {
    try {
      final uri = Uri.parse(imageUrl);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      if (bytes.length > 0) {
        final file = await _imageFile();
        file.writeAsBytesSync(bytes);
        return bytes;
      } else {
        return kTransparentImage;
      }
    } catch (e) {
      print(e);
      return kTransparentImage;
    }
  }

  Future<Uint8List> _findOrCreateImage() async {
    try {
      final file = await _findImage();
      return await file?.readAsBytes() ?? await _createImage();
    } catch (e) {
      print(e);
      return kTransparentImage;
    }
  }

  Future<Codec> _getImage() async {
    final bytes = await _findOrCreateImage();
    final paintingBinding = PaintingBinding.instance;
    if (paintingBinding is PaintingBinding) {
      return paintingBinding.instantiateImageCodec(bytes);
    } else {
      return instantiateImageCodec(bytes, allowUpscaling: false);
    }
  }

  Future<File?> _findImage() async {
    try {
      final file = await _imageFile();
      if (await file.exists()) {
        return file;
      } else {
        return null;
      }
    } catch (e) {
      print(e);
      return null;
    }
  }

  @override
  ImageStreamCompleter load(DynamicUrlImageCache key, decode) {
    return MultiFrameImageStreamCompleter(
        codec: key._getImage(),
        scale: key.scale,
        informationCollector: () sync* {
          yield DiagnosticsProperty<ImageProvider>(
              'Image provider: $this \n Image key: $key', this,
              style: DiagnosticsTreeStyle.errorProperty);
        });
  }

  @override
  Future<DynamicUrlImageCache> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<DynamicUrlImageCache>(this);
  }
}
