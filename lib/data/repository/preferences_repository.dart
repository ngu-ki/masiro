import 'package:masiro/data/repository/model/page_turn_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys
const _versionKey = 'version';
const _languageKey = 'language';
const _favoritesOrderKey = 'favoritesOrder';
const _readerBackgroundColorKey = 'readerBackgroundColor';
const _pageTurnModeKey = 'pageTurnMode';

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

  /// Background color (as a value) of the reader screen.
  int get readerBackgroundColor =>
      _prefs.getInt(_readerBackgroundColorKey) ?? defaultReaderBackgroundColor;

  set readerBackgroundColor(int value) =>
      _prefs.setInt(_readerBackgroundColorKey, value);

  /// Page turn mode of the reader, stored as the enum name.
  String get pageTurnMode =>
      _prefs.getString(_pageTurnModeKey) ?? PageTurnMode.vertical.name;

  set pageTurnMode(String value) => _prefs.setString(_pageTurnModeKey, value);
}
