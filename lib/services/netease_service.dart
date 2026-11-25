import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/lyric.dart';
import '../models/song.dart';
import 'krc_lyric_parser.dart';

class NeteaseService {
  NeteaseService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Referer': 'https://music.163.com/',
                },
              ),
            );

  final Dio _dio;
  static const _lyricParser = KrcLyricParser();

  Map<String, dynamic>? _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// 检索云音乐公开单曲
  Future<List<Song>> search(
    String keyword, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final response = await _dio.get<dynamic>(
        'https://music.163.com/api/cloudsearch/pc',
        queryParameters: {
          's': trimmed,
          'type': 1, // 单曲
          'offset': (page - 1) * pageSize,
          'total': true,
          'limit': 50, // 多拉取以便过滤 VIP 后仍有充裕的免费可播歌曲
        },
      );

      final map = _toMap(response.data);
      final code = map?['code'];
      if (code != 200) return const [];

      final rawSongs = map?['result']?['songs'];
      if (rawSongs is! List) return const [];

      final songs = <Song>[];
      for (final item in rawSongs) {
        if (item is! Map<String, dynamic> && item is! Map) continue;
        final song = _parseSearchItem(
          item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map),
        );
        if (song != null) {
          songs.add(song);
        }
      }
      return songs;
    } catch (_) {
      return const [];
    }
  }

  /// 解析单条搜索结果
  Song? _parseSearchItem(Map<String, dynamic> item) {
    final id = item['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;

    final fee = (item['fee'] as num?)?.toInt() ?? 0;
    // 彻底过滤掉 VIP 专享歌曲 (fee == 1) 和数字专辑付费歌曲 (fee == 4)
    if (fee == 1 || fee == 4) {
      return null;
    }

    final name = item['name']?.toString().trim() ?? '';
    final artistsRaw = item['ar'] ?? item['artists'];
    var artist = '云音乐人';
    if (artistsRaw is List && artistsRaw.isNotEmpty) {
      final names = artistsRaw
          .whereType<Map<String, dynamic>>()
          .map((a) => a['name']?.toString().trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        artist = names.join(' / ');
      }
    }

    final albumMap = (item['al'] ?? item['album']) as Map<String, dynamic>?;
    final albumName = albumMap?['name']?.toString().trim() ?? '';
    var pic = albumMap?['picUrl']?.toString().trim() ??
        albumMap?['blurPicUrl']?.toString().trim() ??
        '';
    if (pic.startsWith('http://')) {
      pic = 'https://${pic.substring(7)}';
    }
    if (pic.isNotEmpty && !pic.contains('param=')) {
      pic = pic.contains('?') ? '$pic&param=500y500' : '$pic?param=500y500';
    }

    final rawDuration = item['dt'] ?? item['duration'];
    final durationMs = (rawDuration as num?)?.toInt() ?? 0;

    return Song(
      id: 'netease_$id',
      title: name.isEmpty ? '云音乐' : name,
      artist: artist,
      album: albumName.isEmpty ? '云音乐' : albumName,
      duration: Duration(milliseconds: durationMs),
      audioUrl: '', // 播放时动态解析真实 CDN 直链
      coverUrl: pic,
      mvId: id,
      isSpecialSource: true,
      playbackSource: 'netease',
      playbackQuality: 'HQ',
    );
  }

  /// 解析云音乐歌曲播放流（通过 outer/url 重定向获取 CDN 直链）
  Future<Song> resolvePlayback(Song song) async {
    var rawId = song.mvId?.trim() ?? '';
    if (rawId.isEmpty && song.id.startsWith('netease_')) {
      rawId = song.id.substring(8);
    }
    if (rawId.isEmpty) {
      throw StateError('缺少云音乐歌曲标识 (id)');
    }

    final outerUrl = 'https://music.163.com/song/media/outer/url?id=$rawId.mp3';

    try {
      final redirectResp = await _dio.get<dynamic>(
        outerUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final location = redirectResp.headers.value('location')?.trim() ?? '';
      if (location.isEmpty || location.contains('404')) {
        throw StateError('该云音乐歌曲受版权或 VIP 限制，无法公开免登播放');
      }

      return song.copyWith(
        audioUrl: location,
        playbackQuality: 'HQ',
        playbackSource: 'netease',
        isSpecialSource: true,
      );
    } on StateError {
      rethrow;
    } catch (_) {
      return song.copyWith(
        audioUrl: outerUrl,
        playbackQuality: 'HQ',
        playbackSource: 'netease',
        isSpecialSource: true,
      );
    }
  }

  /// 获取云音乐歌词
  Future<List<LyricLine>> getLyrics(Song song) async {
    var rawId = song.mvId?.trim() ?? '';
    if (rawId.isEmpty && song.id.startsWith('netease_')) {
      rawId = song.id.substring(8);
    }
    if (rawId.isEmpty) return const [];

    try {
      final response = await _dio.get<dynamic>(
        'https://music.163.com/api/song/lyric',
        queryParameters: {
          'id': rawId,
          'lv': 1,
          'kv': 1,
          'tv': -1,
        },
      );

      final map = _toMap(response.data);
      final lrc = map?['lrc']?['lyric']?.toString() ?? '';
      if (lrc.trim().isEmpty) return const [];

      return _lyricParser.parseLrc(lrc);
    } catch (_) {
      return const [];
    }
  }
}
