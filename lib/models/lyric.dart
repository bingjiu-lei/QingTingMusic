enum LyricTimingSource { exact, line }

class LyricWord {
  const LyricWord({
    required this.offset,
    required this.duration,
    required this.text,
  });

  final Duration offset;
  final Duration duration;
  final String text;
}

class LyricLine {
  const LyricLine({
    required this.time,
    required this.text,
    this.duration = Duration.zero,
    this.words = const [],
    this.translation,
    this.transliteration,
    this.timingSource = LyricTimingSource.line,
  });

  final Duration time;
  final String text;
  final Duration duration;
  final List<LyricWord> words;
  final String? translation;
  final String? transliteration;
  final LyricTimingSource timingSource;

  bool get hasExactTiming =>
      timingSource == LyricTimingSource.exact && words.isNotEmpty;

  LyricLine copyWith({String? translation, String? transliteration}) {
    return LyricLine(
      time: time,
      text: text,
      duration: duration,
      words: words,
      translation: translation ?? this.translation,
      transliteration: transliteration ?? this.transliteration,
      timingSource: timingSource,
    );
  }
}

class LyricCandidate {
  const LyricCandidate({required this.id, required this.accessKey});

  final String id;
  final String accessKey;
}
