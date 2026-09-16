import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/user_profile.dart';
import '../providers/activity_history_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/formatting.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(userId));

    return Scaffold(
      body: profileAsync.when(
        loading: () => const _ProfileSkeleton(),
        error: (error, _) => _ProfileError(
          message: error.toString(),
          onRetry: () =>
              ref.read(profileProvider(userId).notifier).refresh(),
        ),
        data: (profile) => _ProfileBody(
          userId: userId,
          profile: profile,
        ),
      ),
    );
  }
}

/// Splits the screen into a scrolling header (cover photo + stats) and a
/// pinned TabBar, using the SliverOverlapAbsorber/Injector pattern.
class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.userId,
    required this.profile,
  });

  final String userId;
  final UserProfile profile;

  static const _tabs = [
    Tab(text: 'Activities'),
    Tab(text: 'Achievements'),
    Tab(text: 'Photos'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(activityHistoryProvider);

    return DefaultTabController(
      length: _tabs.length,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverOverlapAbsorber(
            handle:
                NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 260,
              backgroundColor:
                  Theme.of(context).scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                background: _ProfileHeader(
                  profile: profile,
                  userId: userId,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _StatsRow(stats: profile.stats),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBar(
              const TabBar(tabs: _tabs),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _SliverTab(
              tag: 'activities',
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: historyAsync.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                    error: (error, stackTrace) =>
                        SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load activities.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (activities) {
                      if (activities.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No activities yet.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == activities.length - 1
                                    ? 0
                                    : 12,
                              ),
                              child: _ActivityTile(
                                activity: activities[index],
                              ),
                            );
                          },
                          childCount: activities.length,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            _SliverTab(
              tag: 'achievements',
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _AchievementBadge(
                        achievement: profile.achievements[index],
                      ),
                      childCount: profile.achievements.length,
                    ),
                  ),
                ),
              ],
            ),
            _SliverTab(
              tag: 'photos',
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(2),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const _PhotoTile(),
                      childCount: 9,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTab extends StatelessWidget {
  const _SliverTab({
    required this.tag,
    required this.slivers,
  });

  final String tag;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => CustomScrollView(
        key: PageStorageKey<String>(tag),
        slivers: [
          SliverOverlapInjector(
            handle:
                NestedScrollView.sliverOverlapAbsorberHandleFor(
              context,
            ),
          ),
          ...slivers,
        ],
      ),
    );
  }
}

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  _StickyTabBar(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBar oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.userId,
  });

  final UserProfile profile;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: profile.coverPhotoUrl != null
              ? CachedNetworkImage(
                  imageUrl: profile.coverPhotoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.grey.shade300),
                  errorWidget: (_, __, ___) =>
                      Container(color: Colors.grey.shade400),
                )
              : Container(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 33,
                  backgroundImage:
                      CachedNetworkImageProvider(profile.avatarUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      profile.username,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _FollowButton(userId: userId),
            ],
          ),
        ),
      ],
    );
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing = ref.watch(
      profileProvider(userId)
          .select((async) => async.valueOrNull?.isFollowing),
    );

    if (isFollowing == null) {
      return const SizedBox.shrink();
    }

    return FilledButton.tonal(
      onPressed: () =>
          ref.read(profileProvider(userId).notifier).toggleFollow(),
      style: FilledButton.styleFrom(
        backgroundColor:
            isFollowing ? Colors.white24 : Colors.white,
        foregroundColor:
            isFollowing ? Colors.white : Colors.black,
      ),
      child: Text(
        isFollowing ? 'Following' : 'Follow',
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final hours = stats.totalMovingTime.inHours;
    final minutes = stats.totalMovingTime.inMinutes % 60;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 8,
      ),
      child: Row(
        children: [
          _StatItem(
            label: 'Distance',
            value:
                '${stats.totalDistanceKm.toStringAsFixed(1)} km',
          ),
          _StatItem(
            label: 'Activities',
            value: '${stats.totalActivities}',
          ),
          _StatItem(
            label: 'Time',
            value: '${hours}h ${minutes}m',
          ),
          _StatItem(
            label: 'Elev Gain',
            value:
                '${stats.totalElevationGainM.toStringAsFixed(0)} m',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
  });

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(
      seconds: activity.durationSeconds,
    );

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final durationText = hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';

    final paceText = formatPace(activity.paceMinPerKm);

    final date = activity.startedAt;

    final dateText =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.directions_run),
        title: Text(
          'Run · $dateText',
        ),
        subtitle: Text(
          '${activity.distanceKm.toStringAsFixed(2)} km · '
          '$durationText · '
          '$paceText/km',
        ),
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.achievement,
  });

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 26,
          child: Icon(
            Icons.emoji_events,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          achievement.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 40,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}