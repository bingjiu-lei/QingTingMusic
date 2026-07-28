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

class LyricProgressFrame {
  const LyricProgressFrame({required this.progress, required this.velocity});

  final double progress;
  final double velocity;
}

LyricProgressFrame resolveLyricProgress(LyricLine line, Duration position) {
  final elapsed = position - line.time;
  if (elapsed <= Duration.zero) {
    return const LyricProgressFrame(progress: 0, velocity: 0);
  }

  if (!line.hasExactTiming) {
    if (line.duration <= Duration.zero) {
      return const LyricProgressFrame(progress: 0, velocity: 0);
    }
    final durationSeconds =
        line.duration.inMicroseconds / Duration.microsecondsPerSecond;
    return LyricProgressFrame(
      progress: (elapsed.inMicroseconds / line.duration.inMicroseconds).clamp(
        0.0,
        1.0,
      ),
      velocity: durationSeconds > 0 ? 1 / durationSeconds : 0,
    );
  }

  final totalCharacters = line.words.fold<int>(
    0,
    (total, word) => total + word.text.runes.length,
  );
  if (totalCharacters == 0) {
    return const LyricProgressFrame(progress: 0, velocity: 0);
  }

  var completedCharacters = 0.0;
  for (final word in line.words) {
    final characterCount = word.text.runes.length;
    final wordEnd = word.offset + word.duration;
    if (elapsed >= wordEnd) {
      completedCharacters += characterCount;
      continue;
    }
    if (elapsed <= word.offset || word.duration <= Duration.zero) {
      return LyricProgressFrame(
        progress: completedCharacters / totalCharacters,
        velocity: 0,
      );
    }

    final localProgress =
        (elapsed - word.offset).inMicroseconds / word.duration.inMicroseconds;
    final durationSeconds =
        word.duration.inMicroseconds / Duration.microsecondsPerSecond;
    return LyricProgressFrame(
      progress:
          (completedCharacters +
              characterCount * localProgress.clamp(0.0, 1.0)) /
          totalCharacters,
      velocity: durationSeconds > 0
          ? characterCount / totalCharacters / durationSeconds
          : 0,
    );
  }

  return const LyricProgressFrame(progress: 1, velocity: 0);
}

class LyricCandidate {
  const LyricCandidate({required this.id, required this.accessKey});

  final String id;
  final String accessKey;
}
