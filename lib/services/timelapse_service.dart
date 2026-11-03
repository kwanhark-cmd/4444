import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'paths.dart';

/// 같은 자리에서 찍은 사진을 이어 움직이는 그림(GIF)으로 만듭니다. 마지막에 엔딩 크레딧.
class TimelapseService {
  final AppPaths paths;
  TimelapseService(this.paths);

  static Uint8List _build(List<Uint8List> frames, Uint8List? credits, int side) {
    final anim = img.Image(width: side, height: side ~/ 4 * 3, numChannels: 3);
    img.Image? first;
    img.Image fitFrame(Uint8List b) {
      final d = img.decodeImage(b)!;
      final f = img.copyResizeCropSquare(d, size: side);
      return img.copyCrop(f, x: 0, y: (side - side ~/ 4 * 3) ~/ 2, width: side, height: side ~/ 4 * 3);
    }

    for (final b in frames) {
      final f = fitFrame(b)..frameDuration = 700;
      if (first == null) {
        first = f;
      } else {
        first.addFrame(f);
      }
    }
    if (credits != null) {
      final c = img.copyResize(img.decodeImage(credits)!, width: side, height: side ~/ 4 * 3)..frameDuration = 2500;
      if (first == null) {
        first = c;
      } else {
        first.addFrame(c);
      }
    }
    return img.encodeGif(first ?? anim, repeat: 0);
  }

  /// [creditsPng]: 화면에서 그린 엔딩 크레딧 그림(선택)
  Future<File> makeGif(List<String> photoPaths, {Uint8List? creditsPng, required String spot, int side = 480}) async {
    if (photoPaths.isEmpty) throw ArgumentError('사진이 없어요');
    final frames = <Uint8List>[for (final path in photoPaths) await File(paths.abs(path)).readAsBytes()];
    final gif = await Isolate.run(() => _build(frames, creditsPng, side));
    final safe = spot.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final f = File(p.join(paths.exportTimelapse.path, '타임랩스_${safe}_${DateTime.now().millisecondsSinceEpoch}.gif'));
    await f.writeAsBytes(gif);
    return f;
  }
}
