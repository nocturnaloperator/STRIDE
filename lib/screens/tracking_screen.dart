import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/activity.dart';
import '../providers/activity_history_provider.dart';
import '../providers/tracking_provider.dart';
import '../utils/formatting.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _mapController = MapController();
  var _statsExpanded = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(trackingProvider);

    ref.listen<String?>(trackingErrorProvider, (previous, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next)),
      );
      ref.read(trackingErrorProvider.notifier).state = null;
    });

    // Auto-follow the runner — but ONLY re-center when a new GPS point
    // actually arrives. The provider's state also changes once a second
    // from the duration ticker with no new point; re-centering on those
    // too would yank the map away from the user every second even while
    // they're trying to manually pan or zoom it.
    ref.listen<Activity>(trackingProvider, (previous, next) {
      final gainedNewPoint =
          next.route.length != (previous?.route.length ?? 0);

      if (gainedNewPoint && next.route.isNotEmpty) {
        final last = next.route.last;
        _mapController.move(
          LatLng(last.latitude, last.longitude),
          17,
        );
      }
    });

    final isMidActivity =
        activity.status == ActivityStatus.recording ||
        activity.status == ActivityStatus.paused;

    return PopScope(
      canPop: !isMidActivity,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Only reached when canPop was false — a recording or paused
        // activity is in progress. THIS is the fix for "activity not
        // saving": leaving via the phone's back gesture used to
        // silently discard everything, no finish(), no save.
        final shouldFinish = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Activity still recording'),
            content: const Text(
              'Leaving now will discard this activity. '
              'Finish and save it first?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep recording'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Finish & save'),
              ),
            ],
          ),
        );

        if (shouldFinish == true) {
          final completed =
              ref.read(trackingProvider.notifier).finish();

          await ref
              .read(activityHistoryProvider.notifier)
              .addCompleted(completed);

          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _RouteMap(
              activity: activity,
              controller: _mapController,
            ),
            _StatsPanel(
              activity: activity,
              isExpanded: _statsExpanded,
              onTap: () => setState(
                () => _statsExpanded = !_statsExpanded,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: _Controls(activity: activity),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.activity,
    required this.controller,
  });

  final Activity activity;
  final MapController controller;

  @override
  Widget build(BuildContext context) {
    final points = activity.route
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final initialCenter = points.isNotEmpty
        ? points.last
        : const LatLng(12.9716, 77.5946);

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 17,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.stride.app',
        ),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 5,
                color: Colors.deepOrange,
              ),
            ],
          ),
        if (points.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: points.last,
                width: 24,
                height: 24,
                child: const _CurrentPositionDot(),
              ),
            ],
          ),
      ],
    );
  }
}

class _CurrentPositionDot extends StatelessWidget {
  const _CurrentPositionDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.deepOrange,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.activity,
    required this.isExpanded,
    required this.onTap,
  });

  final Activity activity;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pace = activity.paceMinPerKm;
    final paceText = formatPace(pace);

    final minutes =
        (activity.durationSeconds ~/ 60).toString().padLeft(2, '0');

    final seconds =
        (activity.durationSeconds % 60).toString().padLeft(2, '0');

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expandedHeight = (constraints.maxHeight * 0.54)
              .clamp(260.0, 420.0)
              .toDouble();

          return Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: onTap,
              child: Semantics(
                button: true,
                label: isExpanded
                    ? 'Collapse run statistics'
                    : 'Expand run statistics',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth - 32,

                  // FIX:
                  // Both animation endpoints now have finite heights.
                  // Previously the collapsed state used null (unbounded),
                  // causing BoxConstraints.lerp() to throw.
                  height: isExpanded ? expandedHeight : 82,

                  margin: EdgeInsets.only(
                    top: isExpanded ? 36 : 10,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isExpanded ? 24 : 12,
                    vertical: isExpanded ? 20 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(
                          alpha: isExpanded ? 0.96 : 0.88,
                        ),
                    borderRadius: BorderRadius.circular(
                      isExpanded ? 28 : 18,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isExpanded
                        ? _ExpandedStats(
                            distance:
                                activity.distanceKm.toStringAsFixed(2),
                            duration: '$minutes:$seconds',
                            pace: paceText,
                          )
                        : _CompactStats(
                            distance:
                                activity.distanceKm.toStringAsFixed(2),
                            duration: '$minutes:$seconds',
                            pace: paceText,
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompactStats extends StatelessWidget {
  const _CompactStats({
    required this.distance,
    required this.duration,
    required this.pace,
  });

  final String distance;
  final String duration;
  final String pace;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('compact-stats'),
      children: [
        Expanded(
          child: _Stat(
            label: 'Distance',
            value: '$distance km',
          ),
        ),
        Expanded(
          child: _Stat(
            label: 'Time',
            value: duration,
          ),
        ),
        Expanded(
          child: _Stat(
            label: 'Pace',
            value: '$pace /km',
          ),
        ),
      ],
    );
  }
}

class _ExpandedStats extends StatelessWidget {
  const _ExpandedStats({
    required this.distance,
    required this.duration,
    required this.pace,
  });

  final String distance;
  final String duration;
  final String pace;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('expanded-stats'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(
          label: 'Distance',
          value: '$distance km',
          expanded: true,
        ),
        _Stat(
          label: 'Duration',
          value: duration,
          expanded: true,
        ),
        _Stat(
          label: 'Pace',
          value: '$pace /km',
          expanded: true,
        ),
        Text(
          'Tap anywhere to return to map',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.expanded = false,
  });

  final String label;
  final String value;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: expanded ? 36 : 18,
          ),
        ),
      ],
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({
    required this.activity,
  });

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(trackingProvider.notifier);

    return switch (activity.status) {
      ActivityStatus.idle ||
      ActivityStatus.finished =>
        _WideButton(
          label: 'Start',
          color: Colors.deepOrange,
          onPressed: () => _handleStart(context, notifier),
        ),

      ActivityStatus.recording =>
        _WideButton(
          label: 'Pause',
          color: Colors.grey.shade800,
          onPressed: notifier.pause,
        ),

      ActivityStatus.paused =>
        Row(
          children: [
            Expanded(
              child: _WideButton(
                label: 'Resume',
                color: Colors.deepOrange,
                onPressed: notifier.resume,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WideButton(
                label: 'Finish',
                color: Colors.red.shade700,
                onPressed: () =>
                    _confirmFinish(context, ref, notifier),
              ),
            ),
          ],
        ),
    };
  }

  Future<void> _handleStart(
    BuildContext context,
    TrackingNotifier notifier,
  ) async {
    try {
      await notifier.start();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _confirmFinish(
    BuildContext context,
    WidgetRef ref,
    TrackingNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish activity?'),
        content: const Text(
          'This will end and save your current run.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final completed = notifier.finish();

      await ref
          .read(activityHistoryProvider.notifier)
          .addCompleted(completed);

      if (context.mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}