import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';
import 'package:masiro/bloc/screen/reader/reader_screen_event.dart';
import 'package:masiro/bloc/screen/reader/reader_screen_state.dart';
import 'package:masiro/bloc/util/event_transformer.dart';
import 'package:masiro/data/repository/app_configuration_repository.dart';
import 'package:masiro/data/repository/masiro_repository.dart';
import 'package:masiro/data/repository/model/bookshelf_stat.dart';
import 'package:masiro/data/repository/model/chapter_detail.dart';
import 'package:masiro/data/repository/model/chapter_record.dart';
import 'package:masiro/data/repository/model/indent_mode.dart';
import 'package:masiro/data/repository/model/loading_status.dart';
import 'package:masiro/data/repository/model/page_turn_mode.dart';
import 'package:masiro/data/repository/model/read_position.dart';
import 'package:masiro/data/repository/model/reading_mode.dart';
import 'package:masiro/data/repository/model/text_color_mode.dart';
import 'package:masiro/data/repository/novel_record_repository.dart';
import 'package:masiro/data/repository/preferences_repository.dart';
import 'package:masiro/data/repository/user_repository.dart';
import 'package:masiro/di/get_it.dart';
import 'package:masiro/misc/reading_progress_bus.dart';

class ReaderScreenBloc extends Bloc<ReaderScreenEvent, ReaderScreenState> {
  final masiroRepository = getIt<MasiroRepository>();
  final novelRecordRepository = getIt<NovelRecordRepository>();
  final appConfigurationRepository = getIt<AppConfigurationRepository>();
  final userRepository = getIt<UserRepository>();
  final preferencesRepository = PreferencesRepository();

  final int novelId;

  /// Cached current user id, so saving the reading position doesn't query
  /// the user table on every page turn.
  int? _currentUserId;

  /// Isar record ids of per-chapter reading positions already seen this
  /// session, keyed by chapter id. Avoids a lookup query on every save.
  final Map<int, Id> _chapterRecordIds = {};

  ReaderScreenBloc({
    required this.novelId,
  }) : super(ReaderScreenInitialState()) {
    on<ReaderScreenChapterDetailRequested>(_onRequestReaderScreenChapterDetail);
    on<ReaderScreenHudToggled>(_onToggleReaderScreenHud);
    on<ReaderScreenPositionChanged>(
      _onChangeReaderScreenPosition,
      transformer: debounce(const Duration(milliseconds: 500)),
    );
    on<ReaderScreenChapterNavigated>(_onReaderScreenChapterNavigated);
    on<ReaderScreenFontSizeChanged>(_onReaderScreenFontSizeChanged);
    on<ReaderScreenBackgroundColorChanged>(
      _onReaderScreenBackgroundColorChanged,
    );
    on<ReaderScreenPageTurnModeChanged>(_onReaderScreenPageTurnModeChanged);
    on<ReaderScreenIndentModeChanged>(_onReaderScreenIndentModeChanged);
    on<ReaderScreenShrinkEmptyLinesChanged>(
      _onReaderScreenShrinkEmptyLinesChanged,
    );
    on<ReaderScreenForceSimplifiedChanged>(
      _onReaderScreenForceSimplifiedChanged,
    );
    on<ReaderScreenTextColorModeChanged>(
      _onReaderScreenTextColorModeChanged,
    );
    on<ReaderScreenOneHandedModeChanged>(
      _onReaderScreenOneHandedModeChanged,
    );
  }

  ReadingMode _readingModeOf(PageTurnMode pageTurnMode) {
    return ReadingMode.page;
  }

  /// Resolves a chapter id to open. When [hint] is positive it is used
  /// directly; otherwise the novel detail is fetched to resume at the server's
  /// last read chapter, falling back to the first chapter.
  Future<int> _resolveChapterId(int hint) async {
    if (hint > 0) {
      return hint;
    }
    final detail = await masiroRepository.getNovelDetail(novelId);
    var chapterId = detail.lastReadChapterId;
    if (chapterId <= 0) {
      chapterId = detail.volumes.firstOrNull?.chapters.firstOrNull?.id ?? 0;
    }
    return chapterId;
  }

  Future<void> _onRequestReaderScreenChapterDetail(
    ReaderScreenChapterDetailRequested event,
    Emitter<ReaderScreenState> emit,
  ) async {
    try {
      // A single loading spinner covers chapter resolution + the chapter
      // fetch. The bookshelf no longer shows its own loading dialog, so the
      // cover tap -> reader transition is one animation.
      var chapterId = await _resolveChapterId(event.chapterId);
      if (chapterId <= 0) {
        emit(ReaderScreenErrorState(message: 'No chapter available.'));
        return;
      }

      ChapterDetail chapterDetail;
      try {
        chapterDetail = await masiroRepository.getChapterDetail(
          novelId,
          chapterId,
        );
      } catch (_) {
        // The hinted chapter may no longer exist (e.g. deleted on the
        // server). Resolve a valid chapter from the novel detail and retry
        // once before giving up.
        if (event.chapterId <= 0) {
          rethrow;
        }
        chapterId = await _resolveChapterId(0);
        if (chapterId <= 0) {
          rethrow;
        }
        chapterDetail = await masiroRepository.getChapterDetail(
          novelId,
          chapterId,
        );
      }

      final currentUser = await userRepository.getCurrentUser();
      final pageTurnMode =
          pageTurnModeFromName(preferencesRepository.pageTurnMode);
      final indentMode = indentModeFromName(
        preferencesRepository.getIndentMode(novelId),
      );
      final shrinkEmptyLines =
          preferencesRepository.getShrinkEmptyLines(novelId);
      final forceSimplified = preferencesRepository.getForceSimplified(novelId);
      final textColorMode = textColorModeFromName(
        preferencesRepository.getTextColorMode(novelId),
      );
      final chapterRecord = await novelRecordRepository.findChapterRecord(
        currentUser!.userId,
        chapterId,
        _readingModeOf(pageTurnMode),
      );
      _currentUserId = currentUser.userId;
      if (chapterRecord != null) {
        _chapterRecordIds[chapterId] = chapterRecord.id;
      }
      final appConfig = await appConfigurationRepository.getAppConfiguration();
      emit(
        ReaderScreenLoadedState(
          chapterDetail: chapterDetail,
          position: event.openAtEnd
              ? endPosition
              : (chapterRecord?.position ?? startPosition),
          fontSize: appConfig.fontSize,
          backgroundColor: preferencesRepository.readerBackgroundColor,
          pageTurnMode: pageTurnMode,
          indentMode: indentMode,
          shrinkEmptyLines: shrinkEmptyLines,
          forceSimplified: forceSimplified,
          textColorMode: textColorMode,
          oneHandedMode: preferencesRepository.oneHandedMode,
          readingMode: _readingModeOf(pageTurnMode),
        ),
      );
      _stampReadingTime(chapterId);
    } catch (e) {
      emit(ReaderScreenErrorState(message: e.toString()));
    }
  }

  /// Stamps the novel's reading timestamp when a chapter loads, rather than
  /// when the reader pops, so the book tops the "recently read" sort even
  /// when the app is killed while still in the reader. The prefs write
  /// survives the kill; the bus update keeps a live favorites bloc's cached
  /// stats in sync, so its next persist doesn't overwrite the fresh stamp.
  void _stampReadingTime(int chapterId) {
    final stats = Map<int, BookshelfStat>.from(
      preferencesRepository.bookshelfStats,
    );
    final existing = stats[novelId];
    final now = DateTime.now().millisecondsSinceEpoch;
    stats[novelId] = BookshelfStat(
      totalChapters: existing?.totalChapters ?? 0,
      unreadCount: existing?.unreadCount ?? 0,
      lastReadChapterId: chapterId,
      lastReadAt: now,
    );
    preferencesRepository.bookshelfStats = stats;
    getIt<ReadingProgressBus>().publish(
      ReadingProgressUpdate(
        novelId: novelId,
        lastReadChapterId: chapterId,
        lastReadAt: now,
      ),
    );
  }

  void _onToggleReaderScreenHud(
    ReaderScreenHudToggled event,
    Emitter<ReaderScreenState> emit,
  ) {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    final loadedState = state as ReaderScreenLoadedState;
    final isHudVisible = loadedState.isHudVisible;
    emit(loadedState.copyWith(isHudVisible: !isHudVisible));
  }

  Future<void> _onChangeReaderScreenPosition(
    ReaderScreenPositionChanged event,
    Emitter<ReaderScreenState> emit,
  ) async {
    final state = this.state;
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    final loadedState = state;
    await _savePosition(
      chapterId: loadedState.chapterDetail.chapterId,
      readingMode: loadedState.readingMode,
      position: event.position,
    );
  }

  /// Persists [position] immediately, bypassing the event debounce. Called
  /// when the reader is popped so a page turn that happened inside the
  /// debounce window is still saved.
  void persistLatestPosition(ReadPosition position) {
    final state = this.state;
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    unawaited(
      _savePosition(
        chapterId: state.chapterDetail.chapterId,
        readingMode: state.readingMode,
        position: position,
      ),
    );
  }

  /// Writes the reading position with a single Isar write. The user id and
  /// the chapter record id are cached after first lookup, so steady-state
  /// page turns cost one put instead of two queries plus a put.
  Future<void> _savePosition({
    required int chapterId,
    required ReadingMode readingMode,
    required ReadPosition position,
  }) async {
    var userId = _currentUserId;
    if (userId == null) {
      userId = (await userRepository.getCurrentUser())?.userId;
      _currentUserId = userId;
    }
    if (userId == null) {
      return;
    }
    var recordId = _chapterRecordIds[chapterId];
    if (recordId == null) {
      final chapterRecord = await novelRecordRepository.findChapterRecord(
        userId,
        chapterId,
        readingMode,
      );
      recordId = chapterRecord?.id;
    }
    final savedId = await novelRecordRepository.putChapterRecord(
      ChapterRecord(
        id: recordId ?? Isar.autoIncrement,
        chapterId: chapterId,
        novelId: novelId,
        position: position,
        readingMode: readingMode,
        userId: userId,
      ),
    );
    _chapterRecordIds[chapterId] = savedId;
  }

  Future<void> _onReaderScreenChapterNavigated(
    ReaderScreenChapterNavigated event,
    Emitter<ReaderScreenState> emit,
  ) async {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    final loadedState = state as ReaderScreenLoadedState;
    emit(loadedState.copyWith(loadingStatus: LoadingStatus.loading));
    add(
      ReaderScreenChapterDetailRequested(
        chapterId: event.chapterId,
        openAtEnd: event.openAtEnd,
      ),
    );
  }

  Future<void> _onReaderScreenFontSizeChanged(
    ReaderScreenFontSizeChanged event,
    Emitter<ReaderScreenState> emit,
  ) async {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    final appConfig = await appConfigurationRepository.getAppConfiguration();
    final nextAppConfig = appConfig.copyWith(fontSize: event.fontSize);
    await appConfigurationRepository.putAppConfiguration(nextAppConfig);
    final loadedState = state as ReaderScreenLoadedState;
    emit(loadedState.copyWith(fontSize: event.fontSize));
  }

  Future<void> _onReaderScreenBackgroundColorChanged(
    ReaderScreenBackgroundColorChanged event,
    Emitter<ReaderScreenState> emit,
  ) async {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    preferencesRepository.readerBackgroundColor = event.colorValue;
    final loadedState = state as ReaderScreenLoadedState;
    emit(loadedState.copyWith(backgroundColor: event.colorValue));
  }

  Future<void> _onReaderScreenPageTurnModeChanged(
    ReaderScreenPageTurnModeChanged event,
    Emitter<ReaderScreenState> emit,
  ) async {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    preferencesRepository.pageTurnMode = event.pageTurnMode.name;
    final loadedState = state as ReaderScreenLoadedState;
    emit(
      loadedState.copyWith(
        pageTurnMode: event.pageTurnMode,
        readingMode: _readingModeOf(event.pageTurnMode),
      ),
    );
  }

  Future<void> _onReaderScreenIndentModeChanged(
    ReaderScreenIndentModeChanged event,
    Emitter<ReaderScreenState> emit,
  ) async {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    preferencesRepository.setIndentMode(novelId, event.indentMode.name);
    final loadedState = state as ReaderScreenLoadedState;
    emit(loadedState.copyWith(indentMode: event.indentMode));
  }

  Future<void> _onReaderScreenShrinkEmptyLinesChanged(
    ReaderScreenShrinkEmptyLinesChanged event,
    Emitter<ReaderScreenState> emit,
  ) async {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    preferencesRepository.setShrinkEmptyLines(novelId, event.shrinkEmptyLines);
    final loadedState = state as ReaderScreenLoadedState;
    emit(loadedState.copyWith(shrinkEmptyLines: event.shrinkEmptyLines));
  }

  Future<void> _onReaderScreenForceSimplifiedChanged(
    ReaderScreenForceSimplifiedChanged event,
    Emitter<ReaderScreenState> emit,
  ) async {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    preferencesRepository.setForceSimplified(novelId, event.enabled);
    final loadedState = state as ReaderScreenLoadedState;
    emit(loadedState.copyWith(forceSimplified: event.enabled));
  }

  Future<void> _onReaderScreenTextColorModeChanged(
    ReaderScreenTextColorModeChanged event,
    Emitter<ReaderScreenState> emit,
  ) async {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    preferencesRepository.setTextColorMode(
      novelId,
      event.textColorMode.name,
    );
    final loadedState = state as ReaderScreenLoadedState;
    emit(loadedState.copyWith(textColorMode: event.textColorMode));
  }

  void _onReaderScreenOneHandedModeChanged(
    ReaderScreenOneHandedModeChanged event,
    Emitter<ReaderScreenState> emit,
  ) {
    if (state is! ReaderScreenLoadedState) {
      return;
    }
    // Global preference: shared across every novel.
    preferencesRepository.oneHandedMode = event.enabled;
    final loadedState = state as ReaderScreenLoadedState;
    emit(loadedState.copyWith(oneHandedMode: event.enabled));
  }

  Future<String> purchasePaidChapter(PaymentInfo paymentInfo) async {
    if (state is! ReaderScreenLoadedState) {
      throw Exception(
        '''Current state isn't an instance of the `ReaderScreenLoadedState`.''',
      );
    }
    final loadedState = state as ReaderScreenLoadedState;
    final csrfToken = loadedState.chapterDetail.csrfToken;
    final msg = await masiroRepository.purchasePaidChapter(
      chapterId: paymentInfo.chapterId,
      cost: paymentInfo.cost,
      type: paymentInfo.type,
      csrfToken: csrfToken,
    );
    add(ReaderScreenChapterNavigated(chapterId: paymentInfo.chapterId));
    return msg;
  }
}
