import 'package:dio/dio.dart';

import '../models/song.dart';

class BilibiliService {
  BilibiliService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Referer': 'https://www.bilibili.com/',
              },
            ),
          );

  final Dio _dio;
  String? _cachedBuvidCookie;
  DateTime? _buvidExpireTime;

  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');
  static final RegExp _hexEntityRegex = RegExp(r'&#x([0-9a-fA-F]+);');
  static final RegExp _decEntityRegex = RegExp(r'&#([0-9]+);');
  static final RegExp _bvidRegex = RegExp(
    r'BV[0-9A-Za-z]{10}',
    caseSensitive: false,
  );

  /// 获取或复用匿名 buvid Cookie，防止搜索接口触发 412 校验。
  Future<String> _ensureBuvidCookie() async {
    final now = DateTime.now();
    if (_cachedBuvidCookie != null &&
        _buvidExpireTime != null &&
        now.isBefore(_buvidExpireTime!)) {
      return _cachedBuvidCookie!;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.bilibili.com/x/frontend/finger/spi',
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final b3 = data?['b_3']?.toString() ?? '';
      final b4 = data?['b_4']?.toString() ?? '';
      if (b3.isNotEmpty) {
        _cachedBuvidCookie = 'buvid3=$b3; buvid4=$b4';
        _buvidExpireTime = now.add(const Duration(hours: 6));
        return _cachedBuvidCookie!;
      }
    } catch (_) {}
    return _cachedBuvidCookie ?? '';
  }

  /// 检索 B 站视频音源
  Future<List<Song>> search(
    String keyword, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const [];

    // 若用户直接输入 BV 号，直接查单条视频
    final bvidMatch = _bvidRegex.firstMatch(trimmed);
    if (bvidMatch != null && trimmed.length <= 30) {
      final bvid = bvidMatch.group(0)!;
      final singleSong = await _fetchVideoByBvid(bvid);
      if (singleSong != null) {
        return [singleSong];
      }
    }

    final cookie = await _ensureBuvidCookie();
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.bilibili.com/x/web-interface/search/type',
      queryParameters: {
        'search_type': 'video',
        'keyword': trimmed,
        'page': page,
        'page_size': pageSize,
      },
      options: Options(headers: {if (cookie.isNotEmpty) 'Cookie': cookie}),
    );

    final code = response.data?['code'];
    if (code != 0) return const [];

    final rawResults = response.data?['data']?['result'];
    if (rawResults is! List) return const [];

    final songs = <Song>[];
    for (final item in rawResults) {
      if (item is! Map<String, dynamic>) continue;
      final song = _parseSearchItem(item);
      if (song != null) {
        songs.add(song);
      }
    }
    return songs;
  }

  /// 解析单条搜索视频项并进行时长过滤
  Song? _parseSearchItem(Map<String, dynamic> item) {
    final bvid = item['bvid']?.toString().trim() ?? '';
    if (bvid.isEmpty) return null;

    final rawDuration = item['duration']?.toString().trim() ?? '';
    final durationSeconds = _parseDuration(rawDuration);
    // 过滤掉小于 45 秒（碎片）和大于 15 分钟（录屏/合集/教学等非歌曲内容）
    if (durationSeconds < 45 || durationSeconds > 900) {
      return null;
    }

    final rawTitle = item['title']?.toString() ?? '';
    final cleanTitle = _cleanHtml(rawTitle);
    final rawAuthor = item['author']?.toString().trim() ?? 'B站UP主';
    final author = _cleanHtml(rawAuthor);
    var pic = item['pic']?.toString().trim() ?? '';
    if (pic.startsWith('//')) {
      pic = 'https:$pic';
    }

    return Song(
      id: 'bili_$bvid',
      title: cleanTitle.isEmpty ? 'B站音频' : cleanTitle,
      artist: author,
      album: 'B站',
      duration: Duration(seconds: durationSeconds),
      audioUrl: '', // 播放时动态解析
      coverUrl: pic,
      mvId: bvid,
      isSpecialSource: true,
      playbackSource: 'bilibili',
      playbackQuality: '192K',
    );
  }

  /// 解析 BV 单条视频详情
  Future<Song?> _fetchVideoByBvid(String bvid) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {'bvid': bvid},
      );
      if (response.data?['code'] != 0) return null;
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final title = _cleanHtml(data['title']?.toString() ?? '');
      final owner = data['owner'] as Map<String, dynamic>?;
      final author = owner?['name']?.toString().trim() ?? 'B站UP主';
      var pic = data['pic']?.toString().trim() ?? '';
      if (pic.startsWith('//')) {
        pic = 'https:$pic';
      }
      final duration = (data['duration'] as num?)?.toInt() ?? 0;

      return Song(
        id: 'bili_$bvid',
        title: title.isEmpty ? 'B站音频' : title,
        artist: author,
        album: 'B站',
        duration: Duration(seconds: duration),
        audioUrl: '',
        coverUrl: pic,
        mvId: bvid,
        isSpecialSource: true,
        playbackSource: 'bilibili',
        playbackQuality: '192K',
      );
    } catch (_) {
      return null;
    }
  }

  /// 检查音频播放地址是否有效且未过期
  static bool _isAudioUrlValid(String url) {
    if (url.trim().isEmpty) return false;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      final deadlineStr =
          uri.queryParameters['deadline'] ?? uri.queryParameters['e'];
      if (deadlineStr != null) {
        final deadline = int.tryParse(deadlineStr);
        if (deadline != null) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          // 预留 10 分钟缓冲期，未临近过期且有效时可复用
          return now < (deadline - 600);
        }
      }
    } catch (_) {}
    return false;
  }

  /// 解析播放音频流（DASH 模式取纯音频）
  Future<Song> resolvePlayback(Song song) async {
    if (_isAudioUrlValid(song.audioUrl)) return song;

    var bvid = song.mvId?.trim() ?? '';
    if (bvid.isEmpty && song.id.startsWith('bili_')) {
      bvid = song.id.substring(5);
    }
    if (bvid.isEmpty) {
      throw StateError('缺少B站视频标识 (bvid)');
    }

    // 1. 获取视频 cid
    final viewResp = await _dio.get<Map<String, dynamic>>(
      'https://api.bilibili.com/x/web-interface/view',
      queryParameters: {'bvid': bvid},
    );
    if (viewResp.data?['code'] != 0) {
      throw StateError(viewResp.data?['message']?.toString() ?? '获取B站视频详情失败');
    }
    final viewData = viewResp.data?['data'] as Map<String, dynamic>?;
    final cid = viewData?['cid'];
    if (cid == null) {
      throw StateError('未获取到视频内容节点');
    }

    final durationSec =
        (viewData?['duration'] as num?)?.toInt() ?? song.duration.inSeconds;

    // 2. 获取 DASH 播放地址 (fnval=16 即 dash 协议)
    final cookie = await _ensureBuvidCookie();
    final playResp = await _dio.get<Map<String, dynamic>>(
      'https://api.bilibili.com/x/player/playurl',
      queryParameters: {'bvid': bvid, 'cid': cid, 'fnval': 16},
      options: Options(headers: {if (cookie.isNotEmpty) 'Cookie': cookie}),
    );

    if (playResp.data?['code'] != 0) {
      throw StateError(playResp.data?['message']?.toString() ?? '获取B站音频流失败');
    }

    final dash = playResp.data?['data']?['dash'] as Map<String, dynamic>?;
    final audioList = dash?['audio'] as List<dynamic>?;
    if (audioList == null || audioList.isEmpty) {
      throw StateError('未找到该视频的独立音频流');
    }

    // 按带宽排序，选择音质最高的一轨
    final audios = audioList.whereType<Map<String, dynamic>>().toList()
      ..sort((a, b) {
        final aBand = (a['bandwidth'] as num?)?.toInt() ?? 0;
        final bBand = (b['bandwidth'] as num?)?.toInt() ?? 0;
        return bBand.compareTo(aBand);
      });

    final bestAudio = audios.first;
    var audioUrl = bestAudio['baseUrl']?.toString() ?? '';
    if (audioUrl.isEmpty) {
      final backup = bestAudio['backupUrl'] as List<dynamic>?;
      if (backup != null && backup.isNotEmpty) {
        audioUrl = backup.first.toString();
      }
    }

    if (audioUrl.isEmpty) {
      throw StateError('未找到有效音频播放地址');
    }

    return song.copyWith(
      audioUrl: audioUrl,
      duration: durationSec > 0
          ? Duration(seconds: durationSec)
          : song.duration,
      playbackQuality: '192K',
      playbackSource: 'bilibili',
      isSpecialSource: true,
    );
  }

  /// 过滤 HTML 标签并转换常见字符转义（包括 16 进制与 10 进制实体）
  String _cleanHtml(String text) {
    if (text.isEmpty) return '';
    var clean = text.replaceAll(_htmlTagRegex, '');
    clean = clean.replaceAllMapped(_hexEntityRegex, (match) {
      final code = int.tryParse(match.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });
    clean = clean.replaceAllMapped(_decEntityRegex, (match) {
      final code = int.tryParse(match.group(1)!);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });
    clean = clean
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    return clean.trim();
  }

  /// 解析时间字符串（如 "04:15" 或 "01:23:45"）为总秒数
  int _parseDuration(String durationStr) {
    if (durationStr.isEmpty) return 0;
    final asInt = int.tryParse(durationStr);
    if (asInt != null) return asInt;

    final parts = durationStr.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    return 0;
  }
}
