import 'dart:convert';

import 'package:masiro/data/repository/model/bookshelf_stat.dart';
import 'package:masiro/data/repository/model/indent_mode.dart';
import 'package:masiro/data/repository/model/page_turn_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys
const _versionKey = 'version';
const _languageKey = 'language';
const _favoritesOrderKey = 'favoritesOrder';
const _favoritesViewModeKey = 'favoritesViewMode';
const _bookshelfStatsKey = 'bookshelfStats';
const _readerBackgroundColorKey = 'readerBackgroundColor';
const _pageTurnModeKey = 'pageTurnMode';
const _indentModeKeyPrefix = 'indentMode_';
const _shrinkEmptyLinesKeyPrefix = 'shrinkEmptyLines_';

// Represents the current version of the shared preferences data
const _currentVersion = 10;

// Default reader background color (white)
const defaultReaderBackgroundColor = 0xFFFFFFFF;

/// Manages all the shared preferences data used by the application
class PreferencesRepository {
  static bool _initialized = false;
  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    _prefs = await SharedPreferences.getInstance();

    // Save current version
    await _prefs.setInt(_versionKey, _currentVersion);
  }

  PreferencesRepository();

  String get language => _prefs.getString(_languageKey) ?? 'zh';

  set language(String value) => _prefs.setString(_languageKey, value);

  /// Manually adjusted order of the favorite novels, as a list of novel ids.
  List<String> get favoritesOrder =>
      _prefs.getStringList(_favoritesOrderKey) ?? const [];

  set favoritesOrder(List<String> value) =>
      _prefs.setStringList(_favoritesOrderKey, value);

  /// Display mode of the favorites screen ('list' or 'grid').
  String get favoritesViewMode =>
      _prefs.getString(_favoritesViewModeKey) ?? 'list';

  set favoritesViewMode(String value) =>
      _prefs.setString(_favoritesViewModeKey, value);

  /// Cached reading statistics of the favorite novels, keyed by novel id.
  Map<int, BookshelfStat> get bookshelfStats {
    final raw = _prefs.getString(_bookshelfStatsKey);
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          int.parse(key),
          BookshelfStat.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  set bookshelfStats(Map<int, BookshelfStat> value) {
    final encoded = {
      for (final entry in value.entries)
        '${entry.key}': entry.value.toJson(),
    };
    _prefs.setString(_bookshelfStatsKey, jsonEncode(encoded));
  }

  /// Background color (as a value) of the reader screen.
  int get readerBackgroundColor =>
      _prefs.getInt(_readerBackgroundColorKey) ?? defaultReaderBackgroundColor;

  set readerBackgroundColor(int value) =>
      _prefs.setInt(_readerBackgroundColorKey, value);

  /// Page turn mode of the reader, stored as the enum name.
  String get pageTurnMode =>
      _prefs.getString(_pageTurnModeKey) ?? PageTurnMode.slide.name;

  set pageTurnMode(String value) => _prefs.setString(_pageTurnModeKey, value);

  /// First-line indentation mode for the given novel, stored as the enum name.
  ///
  /// The preference is kept separately for each novel.
  String getIndentMode(int novelId) =>
      _prefs.getString('$_indentModeKeyPrefix$novelId') ??
      IndentMode.none.name;

  void setIndentMode(int novelId, String value) {
    _prefs.setString('$_indentModeKeyPrefix$novelId', value);
  }

  /// Whether blank lines (e.g. paragraphs made of `&nbsp;`) are shrunk for
  /// the given novel.
  ///
  /// The preference is kept separately for each novel.
  bool getShrinkEmptyLines(int novelId) =>
      _prefs.getBool('$_shrinkEmptyLinesKeyPrefix$novelId') ?? false;

  void setShrinkEmptyLines(int novelId, bool value) {
    _prefs.setBool('$_shrinkEmptyLinesKeyPrefix$novelId', value);
  }
}
