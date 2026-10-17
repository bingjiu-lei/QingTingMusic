import 'search_catalog_item.dart';

class ArtistGroup {
  const ArtistGroup(this.title, this.artists);

  final String title;
  final List<SearchCatalogItem> artists;
}

class ArtistDirectory {
  const ArtistDirectory(this.groups);

  final List<ArtistGroup> groups;

  List<String> get letters => groups
      .map((group) => group.title)
      .where((title) => RegExp(r'^[A-Z]$').hasMatch(title))
      .toList();

  List<SearchCatalogItem> artistsFor(String letter) {
    final selected = letter == '全部'
        ? groups
        : groups.where((group) => group.title == letter);
    final seen = <String>{};
    return [
      for (final group in selected)
        for (final artist in group.artists)
          if (seen.add(artist.id)) artist,
    ];
  }
}
