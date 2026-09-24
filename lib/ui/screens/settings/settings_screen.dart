import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/bloc/global/app_theme_cubit.dart';
import 'package:masiro/bloc/global/user/user_bloc.dart';
import 'package:masiro/bloc/global/user/user_state.dart';
import 'package:masiro/bloc/screen/settings/settings_screen_bloc.dart';
import 'package:masiro/bloc/screen/settings/settings_screen_event.dart';
import 'package:masiro/bloc/screen/settings/settings_screen_state.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/easy_refresh.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/router.dart';
import 'package:masiro/misc/cookie.dart';
import 'package:masiro/ui/screens/settings/profile_card.dart';
import 'package:masiro/ui/screens/settings/sign_in_card.dart';
import 'package:masiro/ui/screens/settings/theme_color_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: BlocProvider<SettingsScreenBloc>(
          create: (_) => SettingsScreenBloc()
            ..add(SettingsScreenInitialized()),
          child: BlocBuilder<SettingsScreenBloc, SettingsScreenState>(
            builder: (context, state) {
              return buildScreen(context, state);
            },
          ),
        ),
      ),
    );
  }

  Widget buildScreen(BuildContext context, SettingsScreenState state) {
    final bloc = context.read<SettingsScreenBloc>();
    const spacing = 20.0;

    return Stack(
      children: [
        EasyRefresh(
          header: classicHeader(context),
          onRefresh: () async {
            bloc.add(SettingsScreenProfileRefreshed());
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            children: [
              ProfileCard(
                profile: state.profile,
                favoritesCount: state.favoritesCount,
              ),
              const SizedBox(height: spacing),
              SignInCard(profile: state.profile),
            ],
          ),
        ),
        Positioned(
          top: 4,
          left: 12,
          child: _buildSettingsButton(context),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: _buildThemeModeButton(context),
        ),
      ],
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    final localizations = context.localizations();
    final settingsScreenBloc = context.read<SettingsScreenBloc>();
    final userBloc = context.read<UserBloc>();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_rounded),
      onSelected: (value) {
        switch (value) {
          case 'about':
            context.push(RoutePath.about);
          case 'themeColor':
            ThemeColorCard.showColorPickerDialog(context);
          case 'accounts':
            _showAccountsDialog(context, settingsScreenBloc);
          case 'logout':
            _showLogoutDialog(context, settingsScreenBloc, userBloc);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'about',
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 12),
              Text(localizations.about),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'themeColor',
          child: Row(
            children: [
              const Icon(Icons.palette_rounded),
              const SizedBox(width: 12),
              Text(localizations.themeColor),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'accounts',
          child: Row(
            children: [
              const Icon(Icons.compare_arrows_rounded),
              const SizedBox(width: 12),
              Text(localizations.switchAccounts),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade500),
              const SizedBox(width: 12),
              Text(
                localizations.logout,
                style: TextStyle(color: Colors.red.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeButton(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeData>(
      buildWhen: (prev, curr) => prev.themeMode != curr.themeMode,
      builder: (context, state) {
        final themeMode = state.themeMode;
        final icon = switch (themeMode) {
          ThemeMode.light => Icons.light_mode_rounded,
          ThemeMode.dark => Icons.dark_mode_rounded,
          ThemeMode.system => Icons.brightness_auto_rounded,
        };
        final cubit = context.read<AppThemeCubit>();
        return IconButton(
          icon: Icon(icon),
          onPressed: () {
            final next = switch (themeMode) {
              ThemeMode.system => ThemeMode.light,
              ThemeMode.light => ThemeMode.dark,
              ThemeMode.dark => ThemeMode.system,
            };
            cubit.setThemeMode(next);
          },
        );
      },
    );
  }

  void _showAccountsDialog(
    BuildContext context,
    SettingsScreenBloc settingsScreenBloc,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return _AccountsDialog(settingsScreenBloc: settingsScreenBloc);
      },
    );
  }

  void _showLogoutDialog(
    BuildContext context,
    SettingsScreenBloc settingsScreenBloc,
    UserBloc userBloc,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return _LogoutDialog(
          onLogout: () async {
            final needsRedirect = await userBloc.logout();
            if (!needsRedirect) {
              settingsScreenBloc.add(SettingsScreenProfileRefreshed());
            }
            if (!context.mounted || !needsRedirect) {
              return;
            }
            context.go(RoutePath.login);
          },
        );
      },
    );
  }
}

class _AccountsDialog extends StatefulWidget {
  final SettingsScreenBloc settingsScreenBloc;

  const _AccountsDialog({required this.settingsScreenBloc});

  @override
  State<_AccountsDialog> createState() => _AccountsDialogState();
}

class _AccountsDialogState extends State<_AccountsDialog> {
  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();
    final colorScheme = context.colorScheme();

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        final userBloc = context.read<UserBloc>();
        final settingsScreenBloc = widget.settingsScreenBloc;

        final userList = state.userList;
        final currentUser = state.currentUser;

        return AlertDialog(
          title: Text(localizations.switchAccounts),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: userList.map((user) {
              final isActive = currentUser?.userId == user.userId;
              final activeIcon = Icon(
                Icons.check_circle_outline_rounded,
                color: colorScheme.primary,
              );
              return ListTile(
                title: Text(user.userName),
                subtitle: Text(user.userId.toString()),
                trailing: isActive ? activeIcon : null,
                onTap: () async {
                  await userBloc.switchCurrentUser(user.userId);
                  settingsScreenBloc.add(SettingsScreenProfileRefreshed());
                  if (!context.mounted) {
                    return;
                  }
                  context.pop();
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              child: Text(localizations.cancel),
              onPressed: () => context.pop(),
            ),
            TextButton(
              child: Text(localizations.addAnAccount),
              onPressed: () async {
                if (isMobilePhone) {
                  await clearWebviewCookies();
                }
                if (!context.mounted) {
                  return;
                }
                context.go(RoutePath.login);
              },
            ),
          ],
        );
      },
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  final void Function() onLogout;

  const _LogoutDialog({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();

    return AlertDialog(
      title: Text(localizations.logout),
      content: Text(localizations.logoutPrompt),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onLogout();
          },
          child: Text(localizations.confirm),
        ),
      ],
    );
  }
}
