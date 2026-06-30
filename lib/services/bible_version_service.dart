import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible_version.dart';

class BibleVersionService {
  static const _key = 'selectedBibleVersion';

  static Future<BibleVersion> getSelectedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final versionId = prefs.getString(_key) ?? availableVersions.first.id;
    return availableVersions.firstWhere(
      (v) => v.id == versionId,
      orElse: () => availableVersions.first,
    );
  }

  static Future<void> setSelectedVersion(String versionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, versionId);
  }
}
