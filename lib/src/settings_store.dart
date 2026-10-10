import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_settings.dart';
import 'images.dart';

class SettingsStore {
  SettingsStore(this.file);

  final File file;

  Future<AppSettings> load() async {
    if (!file.existsSync()) return AppSettings.defaults();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return AppSettings.fromJson(
          decoded.map((dynamic key, dynamic value) => MapEntry('$key', value)),
        );
      }
    } catch (_) {
      return AppSettings.defaults();
    }
    return AppSettings.defaults();
  }

  Future<void> save(AppSettings settings) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(settings.toJson())}\n');
  }
}

Future<File> resolveSettingsFile() async {
  final fromAppData = settingsJsonPath(Platform.environment);
  if (Platform.environment['APPDATA']?.isNotEmpty ?? false) {
    return File(fromAppData);
  }
  try {
    final support = await getApplicationSupportDirectory();
    return File(settingsJsonPath(const {}, fallbackDirectory: support.path));
  } catch (_) {
    final home = Platform.environment['HOME'] ?? '.';
    return File(settingsJsonPath(const {}, fallbackDirectory: home));
  }
}
