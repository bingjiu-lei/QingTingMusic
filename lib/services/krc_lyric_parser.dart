import 'dart:convert';
import 'dart:io';

import '../models/lyric.dart';

String decodeKrcBytes(List<int> bytes) {
  if (bytes.length <= 4) return '';
  const key = <int>[
    64,
    71,
    97,
    119,
    94,
    50,
    116,
    71,
    81,
    54,
    49,
    45,
    206,
    210,
    110,
    105,
  ];
  final encrypted = bytes.sublist(4);
  for (var index = 0; index < encrypted.length; index++) {
    encrypted[index] ^= key[index % key.length];
  }
  return utf8.decode(zlib.decode(encrypted));
}

class KrcLyricParser {
  const KrcLyricParser();

  List<LyricLine> parse(String content) {
    final language = _readLanguage(content);
    final lines = <LyricLine>[];
    final linePattern = RegExp(r'^\[(\d+),(\d+)\](.*)$');
    final wordPattern = RegExp(r'<(\d+),(\d+),[^>]*>([^<]*)');

    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final match = linePattern.firstMatch(raw.trim());
      if (match == null) continue;
      final body = match.group(3) ?? '';
      final words = <LyricWord>[
        for (final word in wordPattern.allMatches(body))
          if ((word.group(3) ?? '').isNotEmpty)
            LyricWord(
              offset: Duration(milliseconds: int.parse(word.group(1)!)),
              duration: Duration(milliseconds: int.parse(word.group(2)!)),
              text: word.group(3)!,
            ),
      ];
      final text = words.isEmpty
          ? body.replaceAll(wordPattern, '').trim()
          : words.map((word) => word.text).join().trim();
      if (text.isEmpty) continue;
      lines.add(
        LyricLine(
          time: Duration(milliseconds: int.parse(match.group(1)!)),
          duration: Duration(milliseconds: int.parse(match.group(2)!)),
          text: text,
          words: List.unmodifiable(words),
          timingSource: words.isEmpty
              ? LyricTimingSource.line
              : LyricTimingSource.exact,
        ),
      );
    }

    if (lines.isEmpty) return _parseLrc(content);
    return List.unmodifiable([
      for (var index = 0; index < lines.length; index++)
        lines[index].copyWith(
          translation: _lineAt(language.translation, index),
          transliteration: _lineAt(language.transliteration, index),
        ),
    ]);
  }

  ({List<String> translation, List<String> transliteration}) _readLanguage(
    String content,
  ) {
    final encoded = RegExp(
      r'^\[language:([^\]]+)\]$',
      multiLine: true,
    ).firstMatch(content)?.group(1);
    if (encoded == null || encoded.isEmpty) {
      return (translation: const [], transliteration: const []);
    }
    try {
      final json = jsonDecode(utf8.decode(base64Decode(encoded)));
      if (json is! Map) {
        return (translation: const [], transliteration: const []);
      }
      final translated = <String>[];
      final transliterated = <String>[];
      final entries = json['content'];
      if (entries is List) {
        for (final entry in entries.whereType<Map>()) {
          final target = entry['type']?.toString() == '1'
              ? translated
              : entry['type']?.toString() == '0'
              ? transliterated
              : null;
          if (target == null) continue;
          final lyricContent = entry['lyricContent'];
          if (lyricContent is! List) continue;
          target.addAll(lyricContent.map(_joinLanguageLine));
        }
      }
      return (translation: translated, transliteration: transliterated);
    } catch (_) {
      return (translation: const [], transliteration: const []);
    }
  }

  String _joinLanguageLine(Object? value) {
    if (value is List) return value.map((item) => item.toString()).join();
    return value?.toString() ?? '';
  }

  String? _lineAt(List<String> values, int index) {
    if (index >= values.length) return null;
    final value = values[index].trim();
    return value.isEmpty ? null : value;
  }

  List<LyricLine> _parseLrc(String content) {
    final lines = <LyricLine>[];
    final timeTag = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\]');
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final matches = timeTag.allMatches(rawLine).toList();
      if (matches.isEmpty) continue;
      final text = rawLine.replaceAll(timeTag, '').trim();
      if (text.isEmpty) continue;
      for (final match in matches) {
        final fraction = (match.group(3) ?? '0').padRight(3, '0');
        lines.add(
          LyricLine(
            time: Duration(
              minutes: int.parse(match.group(1)!),
              seconds: int.parse(match.group(2)!),
              milliseconds: int.parse(fraction.substring(0, 3)),
            ),
            text: text,
          ),
        );
      }
    }
    lines.sort((left, right) => left.time.compareTo(right.time));
    final enriched = <LyricLine>[];
    for (var i = 0; i < lines.length; i++) {
      final current = lines[i];
      final nextTime = i + 1 < lines.length
          ? lines[i + 1].time
          : current.time + const Duration(seconds: 6);
      var lineDuration = nextTime - current.time;
      if (lineDuration <= Duration.zero ||
          lineDuration > const Duration(seconds: 30)) {
        lineDuration = const Duration(seconds: 5);
      }
      enriched.add(current.copyWith(duration: lineDuration));
    }
    return List.unmodifiable(enriched);
  }
}
