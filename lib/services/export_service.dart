import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../core/format.dart';
import '../data/models.dart';
import 'paths.dart';

/// 다른 앱(1번·3번 앱)이 읽을 수 있게 사진+사연을 폴더로 내보냅니다.
class ExportService {
  final AppPaths paths;
  ExportService(this.paths);

  String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_').trim();

  Future<Directory> _bundle(Directory base, Item item, DateTime now) async {
    final dir = Directory(p.join(base.path, '${now.millisecondsSinceEpoch}_${_safe(item.name)}'));
    await dir.create(recursive: true);
    if (item.photoPath != null) {
      final src = File(paths.abs(item.photoPath!));
      if (await src.exists()) await src.copy(p.join(dir.path, '사진.jpg'));
    }
    final text = StringBuffer()
      ..writeln('물건: ${item.name}')
      ..writeln('종류: ${item.kind}')
      ..writeln('자리: ${[item.room, item.spot].where((s) => s.isNotEmpty).join(' / ')}')
      ..writeln('등록일: ${dateKo(item.createdAt)}')
      ..writeln()
      ..writeln('사연:')
      ..writeln(item.story.isEmpty ? '(없음)' : item.story);
    await File(p.join(dir.path, '사연.txt')).writeAsString(text.toString());
    await File(p.join(dir.path, 'info.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'name': item.name,
        'kind': item.kind,
        'room': item.room,
        'spot': item.spot,
        'story': item.story,
        'description': item.description,
        'decision': item.decision?.code,
        'registeredAt': item.createdAt.toIso8601String(),
        'exportedAt': now.toIso8601String(),
      }),
    );
    return dir;
  }

  /// 사연 녹음 → 1번 앱용 폴더
  Future<Directory> exportStory(Item item, DateTime now) => _bundle(paths.exportStories, item, now);

  /// 디지털로 남기고 버리기 → 3번 앱용 폴더
  Future<Directory> exportDigitalKeep(Item item, DateTime now) => _bundle(paths.exportDigital, item, now);

  /// 사연·디지털 기록 폴더(사진·사연.txt·info.json)를 zip 파일 하나로 묶습니다.
  /// 안드로이드는 저장 화면에 파일 하나만 넘길 수 있어 폴더 대신 이 파일을 앱 밖에 저장합니다.
  /// 이름 예: 사연_여행 기념품.zip (폴더 옆, 같은 내보내기 폴더 안)
  Future<File> zipBundle(Directory dir, {required String label, required String itemName}) async {
    final archive = Archive();
    final folder = _safe('${label}_$itemName');
    for (final e in dir.listSync().whereType<File>()) {
      final bytes = await e.readAsBytes();
      archive.addFile(ArchiveFile('$folder/${p.basename(e.path)}', bytes.length, bytes));
    }
    final out = File(p.join(dir.parent.path, '$folder.zip'));
    await out.writeAsBytes(ZipEncoder().encode(archive));
    return out;
  }

  Future<File> exportReport(String text, DateTime now) async {
    final f = File(p.join(paths.exportReports.path, '문제신고_${now.millisecondsSinceEpoch}.txt'));
    await f.writeAsString(text);
    return f;
  }
}
