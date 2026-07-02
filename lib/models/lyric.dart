class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

class LyricCandidate {
  const LyricCandidate({required this.id, required this.accessKey});

  final String id;
  final String accessKey;
}
