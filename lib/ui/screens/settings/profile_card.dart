import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/data/repository/model/profile.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/router.dart';
import 'package:masiro/misc/url.dart';
import 'package:masiro/ui/widgets/cached_image.dart';

const _placeholder = '-';

class ProfileCard extends StatelessWidget {
  final Profile? profile;
  final int? favoritesCount;

  const ProfileCard({
    super.key,
    this.profile,
    this.favoritesCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme();
    final textTheme = context.textTheme();
    final localizations = context.localizations();

    const avatarSize = 75.0;
    final avatar = profile?.avatar ?? MasiroUrl.defaultAvatar;
    final name = profile?.name ?? _placeholder;
    final level =
        profile?.level == null ? _placeholder : 'Lv${profile!.level}';
    final fanCount = '${profile?.fanCount ?? _placeholder}';
    final collectedCount = '${favoritesCount ?? _placeholder}';
    final id = '${localizations.id}: ${profile?.id ?? _placeholder}';

    return Card(
      elevation: 2.0,
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            ClipOval(
              child: CachedImage(
                width: avatarSize,
                height: avatarSize,
                url: avatar.toUrl(),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Badge(label: Text(level)),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              id,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.grey),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatBlock(
                      context,
                      value: fanCount,
                      label: localizations.fan,
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    color: Colors.grey,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go(RoutePath.favorites),
                      child: _buildStatBlock(
                        context,
                        value: collectedCount,
                        label: localizations.favorites,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBlock(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final textTheme = context.textTheme();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
