import 'package:injectable/injectable.dart';
import 'package:masiro/data/repository/masiro_repository.dart';
import 'package:masiro/data/repository/model/novel.dart';
import 'package:masiro/data/repository/preferences_repository.dart';
import 'package:masiro/di/get_it.dart';

@lazySingleton
class FavoritesRepository {
  final _masiroRepository = getIt<MasiroRepository>();
  final _preferencesRepository = PreferencesRepository();

  List<Novel>? _cachedFavorites;

  /// Snapshot persisted from the last successful fetch, so the bookshelf can
  /// still render when the site is unreachable (e.g. offline or timeout).
  List<Novel>? _persistedFavorites;

  bool _needsRefresh = false;

  FavoritesRepository() {
    _persistedFavorites = _preferencesRepository.bookshelfFavorites;
  }

  /// Sync access to the cached favorites list: the in-memory list from the
  /// latest fetch of this session, falling back to the persisted snapshot.
  List<Novel>? get cachedFavorites => _cachedFavorites ?? _persistedFavorites;

  Future<List<Novel>> getFavorites() async {
    if (_needsRefresh) {
      return refreshFavorites();
    }
    if (_cachedFavorites != null) {
      return List.from(_cachedFavorites!);
    }
    try {
      _cachedFavorites = await _masiroRepository.getFavorites();
      _persist(_cachedFavorites!);
    } catch (_) {
      // The site is unreachable; fall back to the persisted snapshot.
      final persisted = _persistedFavorites;
      if (persisted == null) {
        rethrow;
      }
      return List.from(persisted);
    }
    return List.from(_cachedFavorites!);
  }

  Future<List<Novel>> refreshFavorites() async {
    _cachedFavorites = await _masiroRepository.getFavorites();
    _persist(_cachedFavorites!);
    _needsRefresh = false;
    return List.from(_cachedFavorites!);
  }

  Future<void> addToFavorites(int novelId, String csrfToken) async {
    await _masiroRepository.addNovelToFavorites(novelId, csrfToken);
    _needsRefresh = true;
  }

  Future<void> removeFromFavorites(int novelId, String csrfToken) async {
    await _masiroRepository.removeNovelFromFavorites(novelId, csrfToken);
    _cachedFavorites?.removeWhere((novel) => novel.id == novelId);
    if (_persistedFavorites != null &&
        _persistedFavorites!.any((novel) => novel.id == novelId)) {
      _persist(
        _persistedFavorites!.where((novel) => novel.id != novelId).toList(),
      );
    }
  }

  void setNeedsRefresh(bool needsRefresh) {
    _needsRefresh = needsRefresh;
  }

  void _persist(List<Novel> favorites) {
    _persistedFavorites = List.from(favorites);
    _preferencesRepository.bookshelfFavorites = favorites;
  }
}
