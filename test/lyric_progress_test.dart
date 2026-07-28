import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/models/lyric.dart';

void main() {
  test('exact lyric progress follows the active word timing', () {
    const line = LyricLine(
      time: Duration(seconds: 10),
      text: '真心对待',
      duration: Duration(seconds: 2),
      timingSource: LyricTimingSource.exact,
      words: [
        LyricWord(
          offset: Duration.zero,
          duration: Duration(milliseconds: 400),
          text: '真心',
        ),
        LyricWord(
          offset: Duration(milliseconds: 600),
          duration: Duration(milliseconds: 1200),
          text: '对待',
        ),
      ],
    );

    final firstWord = resolveLyricProgress(
      line,
      const Duration(seconds: 10, milliseconds: 200),
    );
    expect(firstWord.progress, closeTo(0.25, 0.0001));
    expect(firstWord.velocity, closeTo(1.25, 0.0001));

    final gap = resolveLyricProgress(
      line,
      const Duration(seconds: 10, milliseconds: 500),
    );
    expect(gap.progress, closeTo(0.5, 0.0001));
    expect(gap.velocity, 0);

    final secondWord = resolveLyricProgress(
      line,
      const Duration(seconds: 11, milliseconds: 200),
    );
    expect(secondWord.progress, closeTo(0.75, 0.0001));
    expect(secondWord.velocity, closeTo(1 / 2.4, 0.0001));
  });

  test('line-timed lyric progress remains linear', () {
    const line = LyricLine(
      time: Duration(seconds: 2),
      text: '只有整句时间',
      duration: Duration(seconds: 4),
    );

    final frame = resolveLyricProgress(line, const Duration(seconds: 3));
    expect(frame.progress, 0.25);
    expect(frame.velocity, 0.25);
  });
}
