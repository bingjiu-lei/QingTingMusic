import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/models/lyric.dart';
import 'package:qing_ting_music/services/krc_lyric_parser.dart';

void main() {
  test('decodes encrypted Kugou KRC payloads', () {
    const source = '[100,500]<0,500,0>晴听音乐';
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
    final compressed = zlib.encode(utf8.encode(source));
    final encrypted = <int>[
      ...ascii.encode('krc1'),
      for (var index = 0; index < compressed.length; index++)
        compressed[index] ^ key[index % key.length],
    ];

    expect(decodeKrcBytes(encrypted), source);
  });

  test('parses exact KRC timing with translation and transliteration', () {
    final language = base64Encode(
      utf8.encode(
        jsonEncode({
          'content': [
            {
              'type': 1,
              'lyricContent': [
                ['Hello'],
              ],
            },
            {
              'type': 0,
              'lyricContent': [
                ['ni', 'hao'],
              ],
            },
          ],
        }),
      ),
    );
    final result = const KrcLyricParser().parse(
      '[language:$language]\n[1000,900]<0,300,0>\u4f60<300,600,0>\u597d',
    );

    expect(result, hasLength(1));
    expect(result.single.text, '\u4f60\u597d');
    expect(result.single.timingSource, LyricTimingSource.exact);
    expect(result.single.words, hasLength(2));
    expect(result.single.translation, 'Hello');
    expect(result.single.transliteration, 'nihao');
  });

  test('keeps LRC as line timing instead of faking word timing', () {
    final result = const KrcLyricParser().parse(
      '[00:01.20]\u4e00\u6574\u53e5\u6b4c\u8bcd',
    );

    expect(result.single.time, const Duration(milliseconds: 1200));
    expect(result.single.timingSource, LyricTimingSource.line);
    expect(result.single.words, isEmpty);
  });
}
