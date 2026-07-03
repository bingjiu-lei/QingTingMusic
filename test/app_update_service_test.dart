import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/models/app_update.dart';
import 'package:qing_ting_music/services/app_storage_service.dart';
import 'package:qing_ting_music/services/app_update_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('qingting-update-');
    AppStorageService.overrideForTesting(tempDirectory);
  });

  tearDown(() async {
    AppStorageService.overrideForTesting(null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'tries the next installer URL when the first download source fails',
    () async {
      final bytes = List<int>.filled(1024 * 1024 + 16, 7);
      final hash = sha256.convert(bytes).toString().toUpperCase();
      final badServer = await _server((request) async {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      });
      final goodServer = await _server((request) async {
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });

      try {
        final file = await AppUpdateService().downloadInstaller(
          AppUpdateInfo(
            currentVersion: '0.5.1',
            latestVersion: '0.5.2',
            releaseName: 'v0.5.2',
            releaseUrl: 'https://example.com/release',
            downloadUrl: _url(badServer),
            downloadUrls: [_url(badServer), _url(goodServer)],
            sha256: hash,
          ),
          onProgress: (_, _) {},
        );

        expect(await file.exists(), isTrue);
        expect(await file.length(), bytes.length);
      } finally {
        await badServer.close(force: true);
        await goodServer.close(force: true);
      }
    },
  );

  test('rejects installer when sha256 does not match', () async {
    final bytes = List<int>.filled(1024 * 1024 + 16, 9);
    final server = await _server((request) async {
      request.response.headers.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });

    try {
      await expectLater(
        AppUpdateService().downloadInstaller(
          AppUpdateInfo(
            currentVersion: '0.5.1',
            latestVersion: '0.5.2',
            releaseName: 'v0.5.2',
            releaseUrl: 'https://example.com/release',
            downloadUrl: _url(server),
            downloadUrls: [_url(server)],
            sha256:
                '0000000000000000000000000000000000000000000000000000000000000000',
          ),
          onProgress: (_, _) {},
        ),
        throwsA(isA<StateError>()),
      );
    } finally {
      await server.close(force: true);
    }
  });
}

Future<HttpServer> _server(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

String _url(HttpServer server) =>
    'http://${server.address.host}:${server.port}/installer.exe';
