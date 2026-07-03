import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/services/app_storage_service.dart';
import 'package:qing_ting_music/services/developer_mode_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('qingting-dev-');
    AppStorageService.overrideForTesting(tempDirectory);
  });

  tearDown(() async {
    AppStorageService.overrideForTesting(null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('verifies developer passphrase without storing it in preferences', () {
    expect(DeveloperModeService.verify('qtyy'), isTrue);
    expect(DeveloperModeService.verify('wrong'), isFalse);
  });

  test('persists developer mode flag', () async {
    final service = DeveloperModeService();

    expect(await service.loadEnabled(), isFalse);

    await service.saveEnabled(true);
    expect(await service.loadEnabled(), isTrue);

    await service.saveEnabled(false);
    expect(await service.loadEnabled(), isFalse);
  });
}
