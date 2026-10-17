class RankChartItem {
  const RankChartItem({
    required this.rankId,
    required this.rankName,
    required this.coverUrl,
    this.topSongs = const [],
    this.groupName = '',
  });

  final int rankId;
  final String rankName;
  final String coverUrl;
  final List<String> topSongs;
  final String groupName;

  String get cleanName =>
      rankName.replaceAll('酷狗', '').replaceAll('官方', '').trim();
}
