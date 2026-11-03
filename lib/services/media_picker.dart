import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/logger.dart';

class PickedFile {
  final String path;
  final Uint8List bytes;
  PickedFile(this.path, this.bytes);
  String get ext {
    final i = path.lastIndexOf('.');
    return i < 0 ? '.jpg' : path.substring(i).toLowerCase();
  }
}

/// 사진·영상 고르기. 카메라가 없으면 파일 넣기로 대신. 테스트에서는 가짜로 바꿔 끼움.
abstract class MediaPicker {
  bool get hasCamera;
  Future<PickedFile?> takePhoto();
  Future<List<PickedFile>> pickPhotos();
  Future<String?> takeVideo();
  Future<String?> pickVideo();
  Future<String?> pickBackupFile();
  Future<String?> chooseSaveFolder();
}

class DeviceMediaPicker implements MediaPicker {
  final _picker = ImagePicker();

  @override
  bool get hasCamera => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<PickedFile?> _read(XFile? x) async => x == null ? null : PickedFile(x.path, await x.readAsBytes());

  @override
  Future<PickedFile?> takePhoto() async {
    try {
      return await _read(await _picker.pickImage(source: ImageSource.camera, maxWidth: 3000, maxHeight: 3000, imageQuality: 92));
    } catch (e) {
      log.warn('사진 찍기 실패: $e');
      return null;
    }
  }

  @override
  Future<List<PickedFile>> pickPhotos() async {
    try {
      final list = await _picker.pickMultiImage(maxWidth: 3000, maxHeight: 3000, imageQuality: 92, limit: 30);
      return [for (final x in list) PickedFile(x.path, await x.readAsBytes())];
    } catch (e) {
      log.warn('사진 고르기 실패: $e');
      return [];
    }
  }

  @override
  Future<String?> takeVideo() async {
    try {
      return (await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 1)))?.path;
    } catch (e) {
      log.warn('영상 찍기 실패: $e');
      return null;
    }
  }

  @override
  Future<String?> pickVideo() async {
    try {
      return (await _picker.pickVideo(source: ImageSource.gallery))?.path;
    } catch (e) {
      log.warn('영상 고르기 실패: $e');
      return null;
    }
  }

  @override
  Future<String?> pickBackupFile() async {
    try {
      final f = await openFile(acceptedTypeGroups: [const XTypeGroup(label: '백업 파일', extensions: ['binugi'])]);
      return f?.path;
    } catch (e) {
      log.warn('백업 파일 고르기 실패: $e');
      return null;
    }
  }

  @override
  Future<String?> chooseSaveFolder() async {
    if (Platform.isAndroid || Platform.isIOS) return null;
    try {
      return await getDirectoryPath(confirmButtonText: '여기에 저장');
    } catch (_) {
      return null;
    }
  }
}
