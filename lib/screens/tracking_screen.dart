import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/activity.dart';
import '../providers/tracking_provider.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _mapController = MapController();

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

    // Auto-follows the latest GPS point so the runner never has to
    // manually pan the map mid-activity.
    ref.listen<Activity>(trackingProvider, (previous, next) {
      if (next.route.isNotEmpty) {
        final last = next.route.last;
        _mapController.move(
          LatLng(last.latitude, last.longitude),
          17,
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          _RouteMap(
            activity: activity,
            controller: _mapController,
          ),
          _StatsPanel(activity: activity),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _Controls(activity: activity),
          ),
        ],
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
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
  const _StatsPanel({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final pace = activity.paceMinPerKm;

    final paceText = pace == null
        ? '--:--'
        : '${pace.floor()}:${((pace - pace.floor()) * 60).round().toString().padLeft(2, '0')}';

    final minutes =
        (activity.durationSeconds ~/ 60).toString().padLeft(2, '0');

    final seconds =
        (activity.durationSeconds % 60).toString().padLeft(2, '0');

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stat(
                label: 'km',
                value: activity.distanceKm.toStringAsFixed(2),
              ),
              const SizedBox(width: 24),
              _Stat(
                label: 'time',
                value: '$minutes:$seconds',
              ),
              const SizedBox(width: 24),
              _Stat(
                label: 'pace /km',
                value: paceText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.activity});

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
      ActivityStatus.recording => _WideButton(
          label: 'Pause',
          color: Colors.grey.shade800,
          onPressed: notifier.pause,
        ),
      ActivityStatus.paused => Row(
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
                onPressed: () => _confirmFinish(context, notifier),
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
      notifier.finish();

      // TODO: hand this off to activity_repository.dart â€” file #2.
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
