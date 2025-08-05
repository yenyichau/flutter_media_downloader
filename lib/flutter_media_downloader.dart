import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_downloader/file_name_format.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';

class MediaDownload {
  static const MethodChannel _channel = MethodChannel('custom_notifications');

  Future<void> downloadMedia(
    BuildContext context,
    String url, [
    String? location,
    String? fileName,
  ]) async {
    await requestPermission();

    _showToast("Preparing...");

    final HttpClient httpClient = HttpClient();

    try {
      final Uri uri = Uri.parse(url);
      final HttpClientRequest request = await httpClient.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final Uint8List bytes =
            await consolidateHttpClientResponseBytes(response);
        final baseStorage = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();

        final String fileExtension = FileNameFormat().fileNameExtension(url);
        final String nameWithoutExtension =
            FileNameFormat().fileNameWithOutExtension(url);
        final String finalFileName =
            "${fileName ?? nameWithoutExtension}.$fileExtension";

        File file;

        if (Platform.isAndroid) {
          if (location == null || location.isEmpty) {
            file = File('${baseStorage?.path}/$finalFileName');
          } else {
            file = File('$location/$finalFileName');
          }

          await file.writeAsBytes(bytes);

          await downloadFile(
            url,
            fileName ?? nameWithoutExtension,
            finalFileName,
            file.path,
          );

          _showToast("Downloaded successfully");

          if (kDebugMode) {
            print('PDF Downloaded successfully. Path: ${file.path}');
          }
        } else if (Platform.isIOS) {
          if (location == null || location.isEmpty) {
            final documents = await getApplicationDocumentsDirectory();
            file = File('${documents.path}/$finalFileName');
          } else {
            file = File('$location/$finalFileName');
          }

          await file.writeAsBytes(bytes);
          await openMediaFile(file.path);

          _showToast("Downloaded successfully");

          if (kDebugMode) {
            print('PDF Downloaded successfully. Path: ${file.path}');
          }
        } else {
          debugPrint('Unsupported Platform');
          _showToast("Unsupported Platform");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
        _showToast("Error: $e");
      }
    } finally {
      httpClient.close();
    }
  }

  Future<void> downloadFile(
    String url,
    String title,
    String description,
    String filePath,
  ) async {
    try {
      await _channel.invokeMethod('downloadFile', {
        'url': url,
        'title': title,
        'description': description,
        'filePath': filePath,
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error downloading file: ${e.message}');
        _showToast("Error downloading file: ${e.message}");
      }
    }
  }

  Future<void> openMediaFile(String filePath) async {
    const platform = MethodChannel('showCustomNotification');
    try {
      final result = await platform.invokeMethod('openMediaFile', {
        'filePath': filePath,
      });
      if (result) {
        if (kDebugMode) print('Media file opened successfully');
      } else {
        if (kDebugMode) print('Failed to open media file');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error opening media file: ${e.message}');
      }
    }
  }

  Future<void> requestPermission() async {
    final PermissionStatus status = await Permission.storage.request();
    final PermissionStatus notificationStatus =
        await Permission.notification.request();

    if (!status.isGranted || !notificationStatus.isGranted) {
      if (status.isPermanentlyDenied ||
          notificationStatus.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  Future<void> showCustomNotification(
    String titleMessage,
    String bodyMessage,
  ) async {
    const platform = MethodChannel('showCustomNotification');
    try {
      await platform.invokeMethod('showCustomNotification', {
        'title': titleMessage,
        'body': bodyMessage,
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error invoking native method: $e");
      }
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }
}
