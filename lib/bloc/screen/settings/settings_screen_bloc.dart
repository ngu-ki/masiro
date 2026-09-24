import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:masiro/bloc/screen/settings/settings_screen_event.dart';
import 'package:masiro/bloc/screen/settings/settings_screen_state.dart';
import 'package:masiro/data/repository/app_configuration_repository.dart';
import 'package:masiro/data/repository/favorites_repository.dart';
import 'package:masiro/data/repository/novel_record_repository.dart';
import 'package:masiro/data/repository/profile_repository.dart';
import 'package:masiro/di/get_it.dart';

typedef _SettingsScreenBloc = Bloc<SettingsScreenEvent, SettingsScreenState>;

class SettingsScreenBloc extends _SettingsScreenBloc {
  final appConfigurationRepository = getIt<AppConfigurationRepository>();
  final novelRecordRepository = getIt<NovelRecordRepository>();
  final profileRepository = getIt<ProfileRepository>();
  final favoritesRepository = getIt<FavoritesRepository>();

  SettingsScreenBloc()
      : super(
          // Seed the first frame from cached data so switching to the
          // settings tab doesn't briefly show the default avatar (and
          // "-" placeholders) before the async profile load completes.
          SettingsScreenState(
            profile: getIt<ProfileRepository>().cachedProfile,
            favoritesCount:
                getIt<FavoritesRepository>().cachedFavorites?.length,
          ),
        ) {
    on<SettingsScreenInitialized>(_onSettingsScreenInitialized);
    on<SettingsScreenProfileRequested>(_onSettingsScreenProfileRequested);
    on<SettingsScreenProfileRefreshed>(_onSettingsScreenProfileRefreshed);
  }

  Future<void> _onSettingsScreenInitialized(
    SettingsScreenInitialized event,
    Emitter<SettingsScreenState> emit,
  ) async {
    final config = await appConfigurationRepository.getAppConfiguration();
    final profile = await profileRepository.getProfile();
    final favoritesCount = (await favoritesRepository.getFavorites()).length;
    emit(
      state.copyWith(
        config: config,
        profile: profile,
        favoritesCount: favoritesCount,
      ),
    );
  }

  Future<void> _onSettingsScreenProfileRequested(
    SettingsScreenProfileRequested event,
    Emitter<SettingsScreenState> emit,
  ) async {
    final profile = await profileRepository.getProfile();
    final favoritesCount = (await favoritesRepository.getFavorites()).length;
    emit(
      state.copyWith(
        profile: profile,
        favoritesCount: favoritesCount,
      ),
    );
  }

  Future<void> _onSettingsScreenProfileRefreshed(
    SettingsScreenProfileRefreshed event,
    Emitter<SettingsScreenState> emit,
  ) async {
    final profile = await profileRepository.refreshProfile();
    final favoritesCount = (await favoritesRepository.getFavorites()).length;
    emit(
      state.copyWith(
        profile: profile,
        favoritesCount: favoritesCount,
      ),
    );
  }
}
