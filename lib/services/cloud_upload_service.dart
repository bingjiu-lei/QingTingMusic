import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/song.dart';
import 'kugou_api_client.dart';
import 'mp4_audio_extractor.dart';

class CloudUploadProgress {
  const CloudUploadProgress({
    required this.stage,
    required this.progress,
    this.message = '',
    this.details = '',
  });

  final String
  stage; // 'downloading' | 'processing' | 'uploading' | 'completed' | 'error'
  final double progress; // 0.0 - 1.0
  final String message;
  final String details;
}

class CloudUploadResult {
  const CloudUploadResult({
    required this.success,
    this.message = '',
    this.originalSize = 0,
    this.uploadedSize = 0,
    this.extendname = '',
  });

  final bool success;
  final String message;
  final int originalSize;
  final int uploadedSize;
  final String extendname;
}

class CloudUploadService {
  CloudUploadService({required this.apiClient, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 3),
              sendTimeout: const Duration(minutes: 3),
            ),
          );

  final KugouApiClient apiClient;
  final Dio _dio;

  Future<CloudUploadResult> uploadSpecialSongToCloud({
    required Song song,
    required String customTitle,
    required String customArtist,
    int? matchedAudioId,
    int? matchedAlbumAudioId,
    String? matchedHashStd,
    CancelToken? cancelToken,
    void Function(CloudUploadProgress progress)? onProgress,
  }) async {
    final audioUrl = song.audioUrl.trim();
    if (audioUrl.isEmpty) {
      throw const KugouApiException('当前歌曲尚未解析到有效播放地址');
    }

    // 1. 下载在线音频流
    onProgress?.call(
      const CloudUploadProgress(
        stage: 'downloading',
        progress: 0.05,
        message: '正在获取在线音源流...',
      ),
    );

    List<int>? rawBytes;
    try {
      final response = await _dio.get<List<int>>(
        audioUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://www.kugou.com/',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            final p = 0.05 + 0.35 * (received / total);
            final receivedMb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            onProgress(
              CloudUploadProgress(
                stage: 'downloading',
                progress: p,
                message: '正在下载音源数据 ($receivedMb MB / $totalMb MB)...',
              ),
            );
          }
        },
      );
      rawBytes = response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const KugouApiException('转存已取消');
      }
      throw KugouApiException('音源数据下载中断: ${e.message ?? '网络超时'}，请重试');
    }

    if (rawBytes == null || rawBytes.isEmpty) {
      throw const KugouApiException('下载音源数据为空，转存失败');
    }

    final rawData = Uint8List.fromList(rawBytes);
    final originalSize = rawData.length;

    // 2. 音频提取与优化
    onProgress?.call(
      const CloudUploadProgress(
        stage: 'processing',
        progress: 0.42,
        message: '正在检查并优化音频格式...',
      ),
    );

    Uint8List uploadBytes = rawData;
    String extendname = 'mp3';
    String details = '';

    final isMv =
        song.isMv ||
        song.playbackQuality == 'MV' ||
        (rawData.length > 8 &&
            rawData[4] == 0x66 &&
            rawData[5] == 0x74 &&
            rawData[6] == 0x79 &&
            rawData[7] == 0x70); // 'ftyp'

    var durationSec = song.duration.inSeconds;

    if (isMv) {
      final extractResult = Mp4AudioExtractor.extract(rawData);
      uploadBytes = extractResult.bytes;
      extendname = extractResult.extendname;
      if (durationSec <= 0 && extractResult.durationSeconds > 0) {
        durationSec = extractResult.durationSeconds;
      }
      if (extractResult.success) {
        final origMb = (extractResult.originalSize / 1024 / 1024)
            .toStringAsFixed(1);
        final optMb = (extractResult.extractedSize / 1024 / 1024)
            .toStringAsFixed(1);
        final savedRatio = (extractResult.compressionRatio * 100)
            .toStringAsFixed(0);
        details = 'MV音轨已提取为纯音频 ($origMb MB -> $optMb MB，体积精简 $savedRatio%)';
      }
    } else {
      // 检查魔法头
      if (rawData.length > 4) {
        if (rawData[0] == 0x49 && rawData[1] == 0x44 && rawData[2] == 0x33) {
          extendname = 'mp3';
        } else if (rawData[0] == 0xFF && (rawData[1] & 0xE0) == 0xE0) {
          extendname = 'mp3';
        } else if (rawData[0] == 0x66 &&
            rawData[1] == 0x4C &&
            rawData[2] == 0x61 &&
            rawData[3] == 0x43) {
          extendname = 'flac';
        } else if (rawData[4] == 0x66 &&
            rawData[5] == 0x74 &&
            rawData[6] == 0x79 &&
            rawData[7] == 0x70) {
          extendname = 'm4a';
        }
      }
      final sizeMb = (uploadBytes.length / 1024 / 1024).toStringAsFixed(1);
      details = '官方高品质音频 ($sizeMb MB)';
    }

    // 3. 上传至酷狗个人云盘
    onProgress?.call(
      CloudUploadProgress(
        stage: 'uploading',
        progress: 0.45,
        message: '正在上传到酷狗个人云盘...',
        details: details,
      ),
    );

    final bool matchCleared =
        matchedAudioId == 0 &&
        matchedAlbumAudioId == 0 &&
        (matchedHashStd == null || matchedHashStd.isEmpty);

    final effectiveAudioId =
        matchCleared ? 0 : (matchedAudioId ?? song.fileId ?? 0);
    final effectiveAlbumAudioId =
        matchCleared ? 0 : (matchedAlbumAudioId ?? song.albumAudioId ?? 0);
    final effectiveHashStd = matchCleared
        ? ''
        : (matchedHashStd ?? song.catalogHash ?? song.hash ?? '');

    await apiClient.uploadSongToCloud(
      fileBytes: uploadBytes,
      name: customTitle.trim().isNotEmpty ? customTitle.trim() : song.title,
      extendname: extendname,
      authorName: customArtist.trim().isNotEmpty
          ? customArtist.trim()
          : song.artist,
      audioId: effectiveAudioId,
      albumAudioId: effectiveAlbumAudioId,
      hashStd: effectiveHashStd,
      durationSeconds: durationSec > 0 ? durationSec : 0,
      cancelToken: cancelToken,
      onProgress: (ratio) {
        final currentProgress = 0.45 + 0.55 * ratio;
        final pct = (ratio * 100).toStringAsFixed(0);
        onProgress?.call(
          CloudUploadProgress(
            stage: 'uploading',
            progress: currentProgress.clamp(0.0, 1.0),
            message: '正在上传到酷狗个人云盘 ($pct%)...',
            details: details,
          ),
        );
      },
    );

    onProgress?.call(
      CloudUploadProgress(
        stage: 'completed',
        progress: 1.0,
        message: '转存成功！已保存到您的酷狗云盘',
        details: details,
      ),
    );

    return CloudUploadResult(
      success: true,
      message: '转存成功！已保存到您的酷狗云盘',
      originalSize: originalSize,
      uploadedSize: uploadBytes.length,
      extendname: extendname,
    );
  }
}
