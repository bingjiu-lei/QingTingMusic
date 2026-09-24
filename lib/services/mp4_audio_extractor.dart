import 'dart:typed_data';

class Mp4AudioExtractResult {
  const Mp4AudioExtractResult({
    required this.bytes,
    required this.extendname,
    required this.success,
    this.originalSize = 0,
    this.extractedSize = 0,
    this.durationSeconds = 0,
  });

  final Uint8List bytes;
  final String extendname;
  final bool success;
  final int originalSize;
  final int extractedSize;
  final int durationSeconds;

  double get compressionRatio =>
      originalSize > 0 ? (1.0 - (extractedSize / originalSize)) : 0.0;
}

/// 纯 Dart 实现的 ISO-BMFF (MP4) 音频解复用器
///
/// 从 MP4 容器中解析音频 track，抽取 AAC 原始访问单元（Access Units），
/// 并添加标准 7 字节 ADTS 头部封装为兼容性极佳的纯 AAC 音频文件（后缀采用 m4a/aac）。
/// 运行在纯内存中，无需 ffmpeg，执行耗时通常低于 50ms。
class Mp4AudioExtractor {
  static const _sampleRateTable = <int>[
    96000,
    88200,
    64000,
    48000,
    44100,
    32000,
    24000,
    22050,
    16000,
    12000,
    11025,
    8000,
    7350,
  ];

  static Mp4AudioExtractResult extract(Uint8List mp4Bytes) {
    if (mp4Bytes.length < 32) {
      return Mp4AudioExtractResult(
        bytes: mp4Bytes,
        extendname: 'mp4',
        success: false,
        originalSize: mp4Bytes.length,
        extractedSize: mp4Bytes.length,
      );
    }

    try {
      final reader = _ByteReader(mp4Bytes);
      _Box? moovBox;

      // 1. 扫描顶级 Box，找到 moov
      while (reader.hasMore) {
        final box = reader.readBox();
        if (box == null) break;
        if (box.type == 'moov') {
          moovBox = box;
          break;
        }
      }

      if (moovBox == null) {
        return _fallback(mp4Bytes);
      }

      // 解析 mvhd 获取文件真实时长
      var detectedDurationSeconds = 0;
      final mvhdReader = _ByteReader(moovBox.data);
      while (mvhdReader.hasMore) {
        final box = mvhdReader.readBox();
        if (box == null) break;
        if (box.type == 'mvhd') {
          detectedDurationSeconds = _parseMvhdDuration(box.data);
          break;
        }
      }

      // 2. 遍历 moov 下的 trak，寻找 audio track
      final moovReader = _ByteReader(moovBox.data);
      _TrackAudioConfig? audioConfig;

      while (moovReader.hasMore) {
        final trakBox = moovReader.readBox();
        if (trakBox == null) break;
        if (trakBox.type != 'trak') continue;

        final config = _parseTrak(trakBox.data);
        if (config != null) {
          audioConfig = config;
          break;
        }
      }

      if (audioConfig == null || audioConfig.sampleOffsets.isEmpty) {
        return _fallback(
          mp4Bytes,
          durationSeconds: detectedDurationSeconds,
        );
      }

      // 3. 构建 ADTS 头部并组装纯 AAC 音频流
      final bb = BytesBuilder(copy: false);
      final profile = (audioConfig.profile - 1).clamp(0, 3);
      final freqIdx = audioConfig.samplingFreqIndex.clamp(0, 15);
      final chanCfg = audioConfig.channelConfig.clamp(1, 7);

      for (var i = 0; i < audioConfig.sampleOffsets.length; i++) {
        final offset = audioConfig.sampleOffsets[i];
        final size = audioConfig.sampleSizes[i];

        if (offset + size > mp4Bytes.length) {
          continue;
        }

        final frameLength = size + 7;
        final adts = Uint8List(7);
        adts[0] = 0xFF;
        adts[1] =
            0xF1; // syncword (12 bits 0xFFF) + ID (0: MPEG-4) + layer (00) + protection_absent (1)
        adts[2] =
            ((profile & 0x03) << 6) |
            ((freqIdx & 0x0F) << 2) |
            ((chanCfg >> 2) & 0x01);
        adts[3] = ((chanCfg & 0x03) << 6) | ((frameLength >> 11) & 0x03);
        adts[4] = (frameLength >> 3) & 0xFF;
        adts[5] = ((frameLength & 0x07) << 5) | 0x1F;
        adts[6] = 0xFC;

        bb.add(adts);
        bb.add(Uint8List.sublistView(mp4Bytes, offset, offset + size));
      }

      final aacBytes = bb.takeBytes();
      if (aacBytes.isEmpty) {
        return _fallback(
          mp4Bytes,
          durationSeconds: detectedDurationSeconds,
        );
      }

      return Mp4AudioExtractResult(
        bytes: aacBytes,
        extendname: 'm4a',
        success: true,
        originalSize: mp4Bytes.length,
        extractedSize: aacBytes.length,
        durationSeconds: detectedDurationSeconds,
      );
    } catch (_) {
      return _fallback(mp4Bytes);
    }
  }

  static int _parseMvhdDuration(Uint8List data) {
    if (data.length < 24) return 0;
    final version = data[0];
    int timescale = 0;
    int duration = 0;
    final byteData = ByteData.sublistView(data);
    if (version == 1) {
      if (data.length < 32) return 0;
      timescale = byteData.getUint32(20);
      duration = byteData.getUint64(24).toInt();
    } else {
      timescale = byteData.getUint32(12);
      duration = byteData.getUint32(16);
    }
    if (timescale > 0 && duration > 0) {
      return (duration / timescale).round();
    }
    return 0;
  }

  static Mp4AudioExtractResult _fallback(
    Uint8List mp4Bytes, {
    int durationSeconds = 0,
  }) {
    return Mp4AudioExtractResult(
      bytes: mp4Bytes,
      extendname: 'mp4',
      success: false,
      originalSize: mp4Bytes.length,
      extractedSize: mp4Bytes.length,
      durationSeconds: durationSeconds,
    );
  }

  static _TrackAudioConfig? _parseTrak(Uint8List trakData) {
    final reader = _ByteReader(trakData);
    _Box? mdiaBox;

    while (reader.hasMore) {
      final box = reader.readBox();
      if (box == null) break;
      if (box.type == 'mdia') {
        mdiaBox = box;
        break;
      }
    }

    if (mdiaBox == null) return null;

    final mdiaReader = _ByteReader(mdiaBox.data);
    var isAudio = false;
    _Box? minfBox;

    while (mdiaReader.hasMore) {
      final box = mdiaReader.readBox();
      if (box == null) break;
      if (box.type == 'hdlr') {
        if (box.data.length >= 12) {
          final handlerType = String.fromCharCodes(box.data.sublist(8, 12));
          if (handlerType == 'soun') {
            isAudio = true;
          }
        }
      } else if (box.type == 'minf') {
        minfBox = box;
      }
    }

    if (!isAudio || minfBox == null) return null;

    final minfReader = _ByteReader(minfBox.data);
    _Box? stblBox;

    while (minfReader.hasMore) {
      final box = minfReader.readBox();
      if (box == null) break;
      if (box.type == 'stbl') {
        stblBox = box;
        break;
      }
    }

    if (stblBox == null) return null;

    return _parseStbl(stblBox.data);
  }

  static _TrackAudioConfig? _parseStbl(Uint8List stblData) {
    final reader = _ByteReader(stblData);
    _Box? stsdBox;
    _Box? stszBox;
    _Box? stscBox;
    _Box? stcoBox;
    _Box? co64Box;

    while (reader.hasMore) {
      final box = reader.readBox();
      if (box == null) break;
      switch (box.type) {
        case 'stsd':
          stsdBox = box;
          break;
        case 'stsz':
          stszBox = box;
          break;
        case 'stsc':
          stscBox = box;
          break;
        case 'stco':
          stcoBox = box;
          break;
        case 'co64':
          co64Box = box;
          break;
      }
    }

    if (stsdBox == null ||
        stszBox == null ||
        stscBox == null ||
        (stcoBox == null && co64Box == null)) {
      return null;
    }

    // 解析 stsd (Sample Description) 提取 AAC 配置
    final aacInfo = _parseStsd(stsdBox.data);
    if (aacInfo == null) return null;

    // 解析 stsz (Sample Sizes)
    final sampleSizes = _parseStsz(stszBox.data);
    if (sampleSizes.isEmpty) return null;

    // 解析 stsc (Sample To Chunk)
    final stscEntries = _parseStsc(stscBox.data);
    if (stscEntries.isEmpty) return null;

    // 解析 chunk offsets (stco 或 co64)
    final chunkOffsets = stcoBox != null
        ? _parseStco(stcoBox.data)
        : _parseCo64(co64Box!.data);
    if (chunkOffsets.isEmpty) return null;

    // 计算每个 sample 的精确字节偏移
    final sampleOffsets = _computeSampleOffsets(
      sampleSizes: sampleSizes,
      stscEntries: stscEntries,
      chunkOffsets: chunkOffsets,
    );

    return _TrackAudioConfig(
      profile: aacInfo.profile,
      samplingFreqIndex: aacInfo.samplingFreqIndex,
      channelConfig: aacInfo.channelConfig,
      sampleSizes: sampleSizes,
      sampleOffsets: sampleOffsets,
    );
  }

  static _AacInfo? _parseStsd(Uint8List stsdData) {
    if (stsdData.length < 8) return null;
    final reader = _ByteReader(stsdData);
    reader.skip(4); // version + flags
    final count = reader.readUint32();
    if (count == 0) return null;

    while (reader.hasMore) {
      final box = reader.readBox();
      if (box == null) break;
      if (box.type == 'mp4a') {
        return _parseMp4a(box.data);
      }
    }
    return null;
  }

  static _AacInfo? _parseMp4a(Uint8List mp4aData) {
    if (mp4aData.length < 28) return null;
    final byteData = ByteData.sublistView(mp4aData);
    // mp4a: 6 bytes reserved, 2 bytes data_ref_index, 8 bytes reserved
    final channelCount = byteData.getUint16(16);
    final sampleRate = byteData.getUint16(24);

    var profile = 2; // AAC-LC
    var freqIndex = _sampleRateTable.indexOf(sampleRate);
    if (freqIndex == -1) freqIndex = 4; // default 44100
    var channelConfig = channelCount > 0 ? channelCount : 2;

    // 尝试深入解析 esds
    final reader = _ByteReader(mp4aData);
    reader.skip(28); // 跳过 mp4a 基础头部

    while (reader.hasMore) {
      final box = reader.readBox();
      if (box == null) break;
      if (box.type == 'esds') {
        final esdsParsed = _parseEsds(box.data);
        if (esdsParsed != null) {
          profile = esdsParsed.profile;
          freqIndex = esdsParsed.samplingFreqIndex;
          channelConfig = esdsParsed.channelConfig;
        }
        break;
      }
    }

    return _AacInfo(
      profile: profile,
      samplingFreqIndex: freqIndex,
      channelConfig: channelConfig,
    );
  }

  static _AacInfo? _parseEsds(Uint8List esdsData) {
    if (esdsData.length < 8) return null;
    // 简易定位 AudioSpecificConfig: 搜索 0x05 (DecSpecificInfoTag)
    for (var i = 4; i < esdsData.length - 3; i++) {
      if (esdsData[i] == 0x05) {
        // Tag 5 后面跟变长 length
        var p = i + 1;
        while (p < esdsData.length && (esdsData[p] & 0x80) != 0) {
          p++;
        }
        p++; // 跳过 length 最后一字节
        if (p + 1 < esdsData.length) {
          final b0 = esdsData[p];
          final b1 = esdsData[p + 1];
          final objType = (b0 >> 3) & 0x1F;
          final freqIdx = ((b0 & 0x07) << 1) | ((b1 >> 7) & 0x01);
          final chanCfg = (b1 >> 3) & 0x0F;
          return _AacInfo(
            profile: objType > 0 ? objType : 2,
            samplingFreqIndex: freqIdx,
            channelConfig: chanCfg > 0 ? chanCfg : 2,
          );
        }
      }
    }
    return null;
  }

  static List<int> _parseStsz(Uint8List stszData) {
    if (stszData.length < 12) return const [];
    final byteData = ByteData.sublistView(stszData);
    final uniformSize = byteData.getUint32(4);
    final sampleCount = byteData.getUint32(8);

    if (sampleCount == 0 || sampleCount > 500000) return const [];

    if (uniformSize != 0) {
      return List<int>.filled(sampleCount, uniformSize);
    }

    if (stszData.length < 12 + sampleCount * 4) return const [];

    final result = List<int>.filled(sampleCount, 0);
    var offset = 12;
    for (var i = 0; i < sampleCount; i++) {
      result[i] = byteData.getUint32(offset);
      offset += 4;
    }
    return result;
  }

  static List<_StscEntry> _parseStsc(Uint8List stscData) {
    if (stscData.length < 8) return const [];
    final byteData = ByteData.sublistView(stscData);
    final entryCount = byteData.getUint32(4);

    if (entryCount == 0 || stscData.length < 8 + entryCount * 12) {
      return const [];
    }

    final list = <_StscEntry>[];
    var offset = 8;
    for (var i = 0; i < entryCount; i++) {
      final firstChunk = byteData.getUint32(offset);
      final samplesPerChunk = byteData.getUint32(offset + 4);
      final sampleDescIndex = byteData.getUint32(offset + 8);
      list.add(_StscEntry(firstChunk, samplesPerChunk, sampleDescIndex));
      offset += 12;
    }
    return list;
  }

  static List<int> _parseStco(Uint8List stcoData) {
    if (stcoData.length < 8) return const [];
    final byteData = ByteData.sublistView(stcoData);
    final entryCount = byteData.getUint32(4);

    if (entryCount == 0 || stcoData.length < 8 + entryCount * 4) {
      return const [];
    }

    final list = List<int>.filled(entryCount, 0);
    var offset = 8;
    for (var i = 0; i < entryCount; i++) {
      list[i] = byteData.getUint32(offset);
      offset += 4;
    }
    return list;
  }

  static List<int> _parseCo64(Uint8List co64Data) {
    if (co64Data.length < 8) return const [];
    final byteData = ByteData.sublistView(co64Data);
    final entryCount = byteData.getUint32(4);

    if (entryCount == 0 || co64Data.length < 8 + entryCount * 8) {
      return const [];
    }

    final list = List<int>.filled(entryCount, 0);
    var offset = 8;
    for (var i = 0; i < entryCount; i++) {
      list[i] = byteData.getUint64(offset);
      offset += 8;
    }
    return list;
  }

  static List<int> _computeSampleOffsets({
    required List<int> sampleSizes,
    required List<_StscEntry> stscEntries,
    required List<int> chunkOffsets,
  }) {
    final sampleOffsets = List<int>.filled(sampleSizes.length, 0);
    var sampleIndex = 0;
    var stscIndex = 0;

    for (var chunkIndex = 0; chunkIndex < chunkOffsets.length; chunkIndex++) {
      final currentChunkNumber = chunkIndex + 1;

      if (stscIndex + 1 < stscEntries.length &&
          currentChunkNumber >= stscEntries[stscIndex + 1].firstChunk) {
        stscIndex++;
      }

      final samplesInThisChunk = stscEntries[stscIndex].samplesPerChunk;
      var currentOffset = chunkOffsets[chunkIndex];

      for (var s = 0; s < samplesInThisChunk; s++) {
        if (sampleIndex >= sampleSizes.length) break;
        sampleOffsets[sampleIndex] = currentOffset;
        currentOffset += sampleSizes[sampleIndex];
        sampleIndex++;
      }
    }

    return sampleOffsets;
  }
}

class _Box {
  const _Box({required this.type, required this.data});
  final String type;
  final Uint8List data;
}

class _ByteReader {
  _ByteReader(this.bytes);

  final Uint8List bytes;
  int _offset = 0;

  bool get hasMore => _offset + 8 <= bytes.length;

  void skip(int count) {
    _offset = (_offset + count).clamp(0, bytes.length);
  }

  int readUint32() {
    if (_offset + 4 > bytes.length) return 0;
    final val = ByteData.sublistView(bytes, _offset, _offset + 4).getUint32(0);
    _offset += 4;
    return val;
  }

  _Box? readBox() {
    if (_offset + 8 > bytes.length) return null;
    final byteData = ByteData.sublistView(bytes, _offset, _offset + 8);
    var size = byteData.getUint32(0);
    final type = String.fromCharCodes(bytes.sublist(_offset + 4, _offset + 8));

    var headerSize = 8;
    if (size == 1) {
      if (_offset + 16 > bytes.length) return null;
      size = ByteData.sublistView(
        bytes,
        _offset + 8,
        _offset + 16,
      ).getUint64(0);
      headerSize = 16;
    } else if (size == 0) {
      size = bytes.length - _offset;
    }

    if (size < headerSize || _offset + size > bytes.length) {
      return null;
    }

    final data = Uint8List.sublistView(
      bytes,
      _offset + headerSize,
      _offset + size,
    );
    _offset += size;
    return _Box(type: type, data: data);
  }
}

class _AacInfo {
  const _AacInfo({
    required this.profile,
    required this.samplingFreqIndex,
    required this.channelConfig,
  });

  final int profile;
  final int samplingFreqIndex;
  final int channelConfig;
}

class _StscEntry {
  const _StscEntry(this.firstChunk, this.samplesPerChunk, this.sampleDescIndex);
  final int firstChunk;
  final int samplesPerChunk;
  final int sampleDescIndex;
}

class _TrackAudioConfig {
  const _TrackAudioConfig({
    required this.profile,
    required this.samplingFreqIndex,
    required this.channelConfig,
    required this.sampleSizes,
    required this.sampleOffsets,
  });

  final int profile;
  final int samplingFreqIndex;
  final int channelConfig;
  final List<int> sampleSizes;
  final List<int> sampleOffsets;
}
