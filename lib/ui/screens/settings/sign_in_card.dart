import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:masiro/bloc/global/user/user_bloc.dart';
import 'package:masiro/bloc/global/user/user_state.dart';
import 'package:masiro/bloc/screen/settings/settings_screen_bloc.dart';
import 'package:masiro/bloc/screen/settings/settings_screen_event.dart';
import 'package:masiro/data/repository/model/profile.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/time.dart';
import 'package:masiro/misc/toast.dart';

/// Height of a regular settings row, matching a single-line [ListTile].
const double _regularRowHeight = 56;

/// The wallet row is 1.5 times as tall as the other rows.
const double _walletRowHeight = _regularRowHeight * 1.5;

/// Font size of the "wallet" label, matching the [ListTile] title size.
const double _walletLabelFontSize = 16;

/// The coin amount is slightly smaller than the wallet label.
const double _coinAmountFontSize = 14;

const _placeholder = '-';

class SignInCard extends StatelessWidget {
  final Profile? profile;

  const SignInCard({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();
    final userBloc = context.read<UserBloc>();
    final settingsScreenBloc = context.read<SettingsScreenBloc>();

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        final lastSignInTime = state.currentUser?.lastSignInTime ?? 0;
        final hasSignedIn = isTimestampToday(lastSignInTime);
        final coinCount = profile?.coinCount ?? _placeholder;

        return Card(
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _walletRowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.wallet,
                            style: const TextStyle(
                              fontSize: _walletLabelFontSize,
                            ),
                          ),
                          Text(
                            '$coinCount ${localizations.coin}',
                            style: const TextStyle(
                              fontSize: _coinAmountFontSize,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: _walletRowHeight,
                child: InkWell(
                  onTap: hasSignedIn
                      ? null
                      : () => _signIn(userBloc, settingsScreenBloc),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          hasSignedIn
                              ? Icons.lightbulb_rounded
                              : Icons.lightbulb_outline_rounded,
                          color: hasSignedIn ? Colors.amber : null,
                          size: 40,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasSignedIn
                                  ? localizations.hasSignedIn
                                  : localizations.signIn,
                              style: const TextStyle(
                                fontSize: _walletLabelFontSize,
                              ),
                            ),
                            // Invisible spacer matching the coin amount line
                            // height so the sign-in label aligns with the
                            // wallet label.
                            Text(
                              '',
                              style: TextStyle(
                                fontSize: _coinAmountFontSize,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signIn(
    UserBloc userBloc,
    SettingsScreenBloc settingsScreenBloc,
  ) async {
    String msg;
    try {
      msg = await userBloc.signIn();
      settingsScreenBloc.add(SettingsScreenProfileRefreshed());
    } catch (e) {
      msg = e.toString();
    }
    msg.toast();
  }
}
