import 'package:equatable/equatable.dart';
import 'package:masiro/data/repository/model/app_configuration.dart';
import 'package:masiro/data/repository/model/profile.dart';

class SettingsScreenState extends Equatable {
  final Profile? profile;
  final AppConfiguration? config;
  final int? favoritesCount;

  const SettingsScreenState({
    this.profile,
    this.config,
    this.favoritesCount,
  });

  SettingsScreenState copyWith({
    Profile? profile,
    AppConfiguration? config,
    int? favoritesCount,
  }) {
    return SettingsScreenState(
      profile: profile ?? this.profile,
      config: config ?? this.config,
      favoritesCount: favoritesCount ?? this.favoritesCount,
    );
  }

  @override
  List<Object?> get props => [profile, config, favoritesCount];
}
