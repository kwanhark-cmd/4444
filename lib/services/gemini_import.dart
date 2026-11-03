import '../data/models.dart';

/// 제미나이(또는 다른 곳)에서 정리한 글을 물건 목록으로 바꿉니다.
/// 예)  "- 커피 머신: 판매 (잘 작동함)"  "2. 낡은 의자 → 폐기"  "책상 / 지금 사용"
class ImportedLine {
  String name;
  Decision? decision;
  String note;
  String room;
  bool selected;
  ImportedLine({required this.name, this.decision, this.note = '', this.room = '', this.selected = true});
}

final _bullet = RegExp(r'^\s*(?:[-*•·▪◦]|\d+[.)]|[①-⑳])\s*');
final _roomHeader = RegExp(r'^\s*(?:#+\s*)?\[?([가-힣A-Za-z ]{1,10}(?:방|실|거실|주방|부엌|베란다|현관|창고|다용도실))\]?\s*:?\s*$');

Decision? _decisionIn(String s) {
  if (RegExp(r'폐기|버리|버림|처분|분리수거|나눔|기부').hasMatch(s)) return Decision.discard;
  if (RegExp(r'판매|팔기|팔아|중고|당근|번개').hasMatch(s)) return Decision.sell;
  if (RegExp(r'사용|쓰는|쓸 것|유지|남기|keep', caseSensitive: false).hasMatch(s)) return Decision.use;
  return null;
}

List<ImportedLine> parseImportText(String text) {
  final out = <ImportedLine>[];
  var room = '';
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    var line = raw.trim();
    if (line.isEmpty) continue;
    final h = _roomHeader.firstMatch(line);
    if (h != null) {
      room = h.group(1)!.trim();
      continue;
    }
    line = line.replaceFirst(_bullet, '').replaceAll('**', '').trim();
    if (line.isEmpty) continue;
    // 이름과 나머지 나누기  ":", "→", "->", "/", "-", "|"
    final parts = line.split(RegExp(r'\s*(?::|→|->|=>|\||/|\s-\s)\s*'));
    final name = parts.first.replaceAll(RegExp(r'[()\[\]]'), '').trim();
    if (name.isEmpty || name.length > 40) continue;
    final rest = parts.skip(1).join(' ').trim();
    var decision = _decisionIn(rest);
    var note = rest;
    final paren = RegExp(r'\(([^)]*)\)').firstMatch(line);
    if (paren != null) note = paren.group(1)!.trim();
    if (decision == null && parts.length == 1) {
      decision = _decisionIn(line);
    }
    // 헤더처럼 보이는 줄(분류 이름만 있는 줄)은 건너뜀
    if (RegExp(r'^(판매|폐기|사용|지금 쓰는 것)( 목록)?$').hasMatch(name)) continue;
    out.add(ImportedLine(name: name, decision: decision, note: note == rest && decision != null ? note.replaceAll(RegExp(r'판매|폐기|사용|지금 쓰는 것'), '').replaceAll(RegExp(r'[()]'), '').trim() : note, room: room));
  }
  return out;
}
