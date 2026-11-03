import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../core/errors.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../data/settings.dart';
import 'paths.dart';

/// 암호화된 백업 파일 만들기·복원 (사진 포함). AI 키는 넣지 않습니다.
class BackupService {
  final Repository repo;
  final AppPaths paths;
  BackupService(this.repo, this.paths);

  static const magic = 'BINUGI1';
  static const _mediaDirs = ['사진', '썸네일', '원본', '타임랩스사진'];
  static final _kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
  static final _aes = AesGcm.with256bits();

  Future<SecretKey> _key(String password, List<int> salt) => _kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  Future<Uint8List> createBytes(String password, {required String appVersion}) async {
    if (password.length < 4) throw UserFacingException('비밀번호는 4글자 이상으로 정해 주세요.');
    final dump = await repo.dumpAll();
    dump['settings'] = dump['settings']!.where((r) => !secretSettingKeys.contains(r['key'])).toList();
    final archive = Archive();
    final meta = utf8.encode(jsonEncode({'dataVersion': dataVersion, 'appVersion': appVersion, 'createdAt': DateTime.now().toIso8601String()}));
    archive.addFile(ArchiveFile('meta.json', meta.length, meta));
    final data = utf8.encode(jsonEncode(dump));
    archive.addFile(ArchiveFile('data.json', data.length, data));
    for (final d in _mediaDirs) {
      final dir = Directory(p.join(paths.root.path, d));
      if (!await dir.exists()) continue;
      await for (final f in dir.list()) {
        if (f is File) {
          final bytes = await f.readAsBytes();
          archive.addFile(ArchiveFile('$d/${p.basename(f.path)}', bytes.length, bytes));
        }
      }
    }
    final zip = ZipEncoder().encode(archive);
    final salt = SecretKeyData.random(length: 16).bytes;
    final box = await _aes.encrypt(zip, secretKey: await _key(password, salt));
    final b = BytesBuilder()
      ..add(utf8.encode(magic))
      ..add(salt)
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return b.toBytes();
  }

  Future<File> createFile(String password, {required String appVersion}) async {
    final bytes = await createBytes(password, appVersion: appVersion);
    final now = DateTime.now();
    final name = '비우기백업_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.millisecondsSinceEpoch % 100000}.binugi';
    final f = File(p.join(paths.backups.path, name));
    await f.writeAsBytes(bytes);
    return f;
  }

  /// 복원: 지금 자료를 백업 내용으로 바꿉니다. 데이터 버전이 낮으면 자동 변환.
  Future<void> restoreBytes(Uint8List bytes, String password) async {
    final m = utf8.encode(magic);
    if (bytes.length < m.length + 16 + 12 + 16 || utf8.decode(bytes.sublist(0, m.length), allowMalformed: true) != magic) {
      throw UserFacingException('이 앱의 백업 파일이 아니에요.');
    }
    var o = m.length;
    final salt = bytes.sublist(o, o += 16);
    final nonce = bytes.sublist(o, o += 12);
    final mac = bytes.sublist(o, o += 16);
    final cipher = bytes.sublist(o);
    List<int> zip;
    try {
      zip = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: await _key(password, salt),
      );
    } catch (_) {
      throw UserFacingException('비밀번호가 맞지 않아요.');
    }
    final archive = ZipDecoder().decodeBytes(zip);
    final metaFile = archive.findFile('meta.json');
    final dataFile = archive.findFile('data.json');
    if (metaFile == null || dataFile == null) throw UserFacingException('백업 파일이 망가졌어요.');
    final meta = jsonDecode(utf8.decode(metaFile.content)) as Map<String, dynamic>;
    final v = (meta['dataVersion'] as num?)?.toInt() ?? 1;
    if (v > dataVersion) throw UserFacingException('더 새 버전 앱에서 만든 백업이에요. 앱을 먼저 업데이트해 주세요.');
    final raw = jsonDecode(utf8.decode(dataFile.content)) as Map<String, dynamic>;
    final data = <String, List<Map<String, Object?>>>{
      for (final t in Repository.backupTables) t: ((raw[t] as List?) ?? const []).map((r) => Map<String, Object?>.from(r as Map)).toList(),
    };
    // 지금 기기의 AI 키는 지키기
    final keepSecrets = (await repo.dumpAll())['settings']!.where((r) => secretSettingKeys.contains(r['key'])).toList();
    data['settings'] = [...data['settings']!.where((r) => !secretSettingKeys.contains(r['key'])), ...keepSecrets];
    if (v < 2) {
      for (final row in data['items']!) {
        row.putIfAbsent('digital_keep', () => 0);
      }
    }
    await repo.restoreAll(data);
    for (final f in archive.files) {
      if (!f.isFile || !_mediaDirs.any((d) => f.name.startsWith('$d/'))) continue;
      final out = File(p.join(paths.root.path, f.name));
      if (!p.isWithin(paths.root.path, out.path)) continue;
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.content);
    }
  }
}
