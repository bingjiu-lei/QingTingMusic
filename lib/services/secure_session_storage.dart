import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../models/kugou_session.dart';

class SecureSessionStorage {
  static const _cryptProtectUiForbidden = 0x1;

  File get _file {
    final root =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    return File('$root\\QingTingMusic\\session.dat');
  }

  Future<KugouSession> load() async {
    if (!Platform.isWindows || !await _file.exists()) {
      return const KugouSession();
    }

    try {
      final encrypted = await _file.readAsBytes();
      if (encrypted.isEmpty) return const KugouSession();
      final json = jsonDecode(utf8.decode(_unprotect(encrypted)));
      return KugouSession.fromJson((json as Map).cast<String, Object?>());
    } catch (_) {
      return const KugouSession();
    }
  }

  Future<void> save(KugouSession session) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('安全会话存储仅支持 Windows');
    }

    final plain = Uint8List.fromList(utf8.encode(jsonEncode(session.toJson())));
    final encrypted = _protect(plain);
    await _file.parent.create(recursive: true);
    await _file.writeAsBytes(encrypted, flush: true);
  }

  Uint8List _protect(Uint8List plain) {
    return _transform(
      plain,
      (input, output) => CryptProtectData(
        input,
        null,
        null,
        null,
        _cryptProtectUiForbidden,
        output,
      ).value,
    );
  }

  Uint8List _unprotect(Uint8List encrypted) {
    return _transform(
      encrypted,
      (input, output) => CryptUnprotectData(
        input,
        null,
        null,
        null,
        _cryptProtectUiForbidden,
        output,
      ).value,
    );
  }

  Uint8List _transform(
    Uint8List source,
    bool Function(
      Pointer<CRYPT_INTEGER_BLOB> input,
      Pointer<CRYPT_INTEGER_BLOB> output,
    )
    operation,
  ) {
    final sourcePointer = calloc<Uint8>(source.length);
    final input = calloc<CRYPT_INTEGER_BLOB>();
    final output = calloc<CRYPT_INTEGER_BLOB>();

    try {
      sourcePointer.asTypedList(source.length).setAll(0, source);
      input.ref
        ..cbData = source.length
        ..pbData = sourcePointer;

      if (!operation(input, output)) {
        throw StateError('Windows DPAPI operation failed');
      }

      return Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
    } finally {
      if (output.ref.pbData.address != 0) {
        HLOCAL(output.ref.pbData.cast()).close();
      }
      calloc
        ..free(sourcePointer)
        ..free(input)
        ..free(output);
    }
  }
}
