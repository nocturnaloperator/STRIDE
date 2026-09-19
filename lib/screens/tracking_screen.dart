import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/activity.dart';
import '../models/map_style.dart';
import '../providers/activity_history_provider.dart';
import '../providers/map_style_provider.dart';
import '../providers/tracking_provider.dart';
import '../services/location_service.dart';
import '../services/map_tile_service.dart';
import '../utils/formatting.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();

  final GeolocatorLocationService _locationService =
      GeolocatorLocationService();

  var _statsExpanded = false;

  LatLng? _currentLocation;
  var _locationLoading = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialLocation();
    });
  }

  Future<void> _loadInitialLocation() async {
    if (mounted) {
      setState(() {
        _locationLoading = true;
        _locationError = null;
      });
    }

    try {
      await _locationService.ensureReady();

      final lastKnownPosition =
          await _locationService.lastKnownPosition();

      if (lastKnownPosition != null && mounted) {
        final location = _positionToLatLng(lastKnownPosition);

        if (location != null) {
          setState(() {
            _currentLocation = location;
            _locationLoading = false;
            _locationError = null;
          });

          _moveMapTo(location);
        }
      }

      final freshPosition =
          await _locationService.currentPosition();

      if (!mounted) return;

      final freshLocation = _positionToLatLng(freshPosition);

      if (freshLocation == null) {
        setState(() {
          _locationLoading = false;
          _locationError =
              'GPS returned an invalid location. Please try again.';
        });
        return;
      }

      setState(() {
        _currentLocation = freshLocation;
        _locationLoading = false;
        _locationError = null;
      });

      _moveMapTo(freshLocation);
    } on LocationServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        _locationLoading = false;
        _locationError = error.message;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _locationLoading = false;
        _locationError =
            'Could not determine your location: $error';
      });
    }
  }

  LatLng? _positionToLatLng(Position position) {
    final latitude = position.latitude;
    final longitude = position.longitude;

    if (!latitude.isFinite || !longitude.isFinite) {
      return null;
    }

    if (latitude < -90 || latitude > 90) {
      return null;
    }

    if (longitude < -180 || longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  LatLng? _routePointToLatLng(dynamic point) {
    final latitude = point.latitude as double;
    final longitude = point.longitude as double;

    if (!latitude.isFinite || !longitude.isFinite) {
      return null;
    }

    if (latitude < -90 || latitude > 90) {
      return null;
    }

    if (longitude < -180 || longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  void _moveMapTo(LatLng location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        _mapController.move(location, 17);
      } catch (_) {
        // FlutterMap may not have attached the controller yet.
        // The map will still use the GPS location as its
        // initial center.
      }
    });
  }

  void _recenterMap() {
    final location = _currentLocation;

    if (location == null) {
      _loadInitialLocation();
      return;
    }

    _moveMapTo(location);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(trackingProvider);
    final selectedMapStyle = ref.watch(mapStyleProvider);

    ref.listen<String?>(
      trackingErrorProvider,
      (previous, next) {
        if (next == null) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );

        ref.read(trackingErrorProvider.notifier).state = null;
      },
    );

    ref.listen<Activity>(
      trackingProvider,
      (previous, next) {
        final gainedNewPoint =
            next.route.length !=
                (previous?.route.length ?? 0);

        if (!gainedNewPoint || next.route.isEmpty) {
          return;
        }

        final last = next.route.last;
        final location = _routePointToLatLng(last);

        if (location == null) {
          return;
        }

        if (!mounted) return;

        setState(() {
          _currentLocation = location;
        });

        _moveMapTo(location);
      },
    );

    final isMidActivity =
        activity.status == ActivityStatus.recording ||
        activity.status == ActivityStatus.paused;

    return PopScope(
      canPop: !isMidActivity,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

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
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text('Keep recording'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, true),
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
              currentLocation: _currentLocation,
              selectedMapStyle: selectedMapStyle,
            ),

            if (_locationLoading)
              const _LocationStatus(
                message: 'Finding your location…',
              ),

            if (!_locationLoading &&
                _locationError != null)
              _LocationErrorBanner(
                message: _locationError!,
                onRetry: _loadInitialLocation,
              ),

            _StatsPanel(
              activity: activity,
              isExpanded: _statsExpanded,
              onTap: () => setState(
                () => _statsExpanded = !_statsExpanded,
              ),
            ),

            // Keep these controls above the statistics panel.
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    _MapStyleButton(
                      selectedStyle: selectedMapStyle,
                    ),
                    const SizedBox(height: 10),
                    _RecenterButton(
                      onPressed: _recenterMap,
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: _Controls(
                  activity: activity,
                ),
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
    required this.currentLocation,
    required this.selectedMapStyle,
  });

  final Activity activity;
  final MapController controller;
  final LatLng? currentLocation;
  final MapStyle selectedMapStyle;

  @override
  Widget build(BuildContext context) {
    final rawPoints = <LatLng>[];

    for (final point in activity.route) {
      final latitude = point.latitude;
      final longitude = point.longitude;

      if (!latitude.isFinite || !longitude.isFinite) {
        continue;
      }

      if (latitude < -90 || latitude > 90) {
        continue;
      }

      if (longitude < -180 || longitude > 180) {
        continue;
      }

      rawPoints.add(
        LatLng(latitude, longitude),
      );
    }

    final points = _simplifyRoute(rawPoints);

    final tileService = const MapTileService();

    final requestedConfiguration =
        tileService.configurationFor(
      selectedMapStyle,
    );

    final configuration =
        requestedConfiguration.isAvailable
            ? requestedConfiguration
            : tileService.configurationFor(
                MapStyle.standard,
              );

    /*
     * Before the activity starts, use the actual GPS location.
     *
     * There is deliberately NO Bangalore fallback.
     */
    final initialCenter = rawPoints.isNotEmpty
        ? rawPoints.last
        : currentLocation;

    /*
     * If GPS has not arrived yet, show a neutral world view.
     * This is not a fake user location.
     */
    final center =
        initialCenter ?? const LatLng(0, 0);

    final zoom =
        initialCenter != null ? 17.0 : 2.0;

    final markers = <Marker>[];

    if (rawPoints.isNotEmpty) {
      markers.add(
        Marker(
          point: rawPoints.last,
          width: 26,
          height: 26,
          child: const _CurrentPositionDot(),
        ),
      );
    } else if (currentLocation != null) {
      markers.add(
        Marker(
          point: currentLocation!,
          width: 26,
          height: 26,
          child: const _CurrentPositionDot(),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(
            'map-${selectedMapStyle.name}',
          ),
          mapController: controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  configuration.tileUrlTemplate,
              userAgentPackageName:
                  'com.example.stride',
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

            if (markers.isNotEmpty)
              MarkerLayer(
                markers: markers,
              ),
          ],
        ),

        // Attribution intentionally lives OUTSIDE FlutterMap.
        Positioned(
          left: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.90,
              ),
              borderRadius:
                  BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              child: Text(
                configuration.attribution,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<LatLng> _simplifyRoute(
    List<LatLng> points,
  ) {
    if (points.length <= 2) {
      return points;
    }

    const toleranceMeters = 4.0;

    final keep = List<bool>.filled(
      points.length,
      false,
    );

    keep[0] = true;
    keep[points.length - 1] = true;

    void simplify(
      int first,
      int last,
    ) {
      if (last <= first + 1) {
        return;
      }

      var maxDistance = 0.0;
      var index = -1;

      final start = points[first];
      final end = points[last];

      for (
        var i = first + 1;
        i < last;
        i++
      ) {
        final distance =
            _perpendicularDistanceMeters(
          points[i],
          start,
          end,
        );

        if (distance > maxDistance) {
          maxDistance = distance;
          index = i;
        }
      }

      if (index != -1 &&
          maxDistance > toleranceMeters) {
        keep[index] = true;

        simplify(first, index);
        simplify(index, last);
      }
    }

    simplify(0, points.length - 1);

    return [
      for (
        var i = 0;
        i < points.length;
        i++
      )
        if (keep[i]) points[i],
    ];
  }

  double _perpendicularDistanceMeters(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    const earthRadius = 6371000.0;

    final latScale =
        math.pi * earthRadius / 180.0;

    final averageLatitude =
        ((start.latitude + end.latitude) / 2) *
            math.pi /
            180.0;

    final lonScale =
        latScale *
        math.cos(averageLatitude);

    final x1 =
        start.longitude * lonScale;
    final y1 =
        start.latitude * latScale;

    final x2 =
        end.longitude * lonScale;
    final y2 =
        end.latitude * latScale;

    final x =
        point.longitude * lonScale;
    final y =
        point.latitude * latScale;

    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      final px = x - x1;
      final py = y - y1;

      return math.sqrt(
        px * px + py * py,
      );
    }

    final numerator =
        ((y1 - y) * dx -
                (x1 - x) * dy)
            .abs();

    final denominator =
        math.sqrt(dx * dx + dy * dy);

    return numerator / denominator;
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

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.94,
            ),
            borderRadius:
                BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 10),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationErrorBanner
    extends StatelessWidget {
  const _LocationErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.96,
            ),
            borderRadius:
                BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.location_off,
                  color: Colors.red,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 3,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStyleButton
    extends ConsumerWidget {
  const _MapStyleButton({
    required this.selectedStyle,
  });

  final MapStyle selectedStyle;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.96,
      ),
      borderRadius:
          BorderRadius.circular(12),
      elevation: 5,
      child: PopupMenuButton<MapStyle>(
        initialValue: selectedStyle,
        tooltip: 'Map style',
        position:
            PopupMenuPosition.under,
        onSelected: (style) {
          final configuration =
              const MapTileService()
                  .configurationFor(style);

          if (!configuration.isAvailable) {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              SnackBar(
                content: Text(
                  '${configuration.name} maps '
                  'require a configured '
                  'Stadia Maps API key.',
                ),
              ),
            );
            return;
          }

          ref
              .read(mapStyleProvider.notifier)
              .setStyle(style);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: MapStyle.standard,
            child: Row(
              children: [
                Icon(Icons.map_outlined),
                SizedBox(width: 10),
                Text('Standard'),
              ],
            ),
          ),
          PopupMenuItem(
            value: MapStyle.satellite,
            child: Row(
              children: [
                Icon(Icons.satellite_alt),
                SizedBox(width: 10),
                Text('Satellite'),
              ],
            ),
          ),
          PopupMenuItem(
            value: MapStyle.terrain,
            child: Row(
              children: [
                Icon(Icons.terrain),
                SizedBox(width: 10),
                Text('Terrain'),
              ],
            ),
          ),
          PopupMenuItem(
            value: MapStyle.dark,
            child: Row(
              children: [
                Icon(Icons.dark_mode_outlined),
                SizedBox(width: 10),
                Text('Dark'),
              ],
            ),
          ),
          PopupMenuItem(
            value: MapStyle.outdoor,
            child: Row(
              children: [
                Icon(Icons.landscape_outlined),
                SizedBox(width: 10),
                Text('Outdoor'),
              ],
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.layers_outlined,
                size: 22,
              ),
              const SizedBox(width: 7),
              Text(
                selectedStyle.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecenterButton
    extends StatelessWidget {
  const _RecenterButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.96,
      ),
      borderRadius:
          BorderRadius.circular(12),
      elevation: 5,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(
            Icons.my_location,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _StatsPanel
    extends StatelessWidget {
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
        (activity.durationSeconds ~/ 60)
            .toString()
            .padLeft(2, '0');

    final seconds =
        (activity.durationSeconds % 60)
            .toString()
            .padLeft(2, '0');

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expandedHeight =
              (constraints.maxHeight * 0.54)
                  .clamp(
                    260.0,
                    420.0,
                  )
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
                  duration:
                      const Duration(
                    milliseconds: 240,
                  ),
                  curve:
                      Curves.easeOutCubic,
                  width:
                      constraints.maxWidth - 32,
                  height: isExpanded
                      ? expandedHeight
                      : 82,
                  margin: EdgeInsets.only(
                    top: isExpanded ? 36 : 10,
                  ),
                  padding:
                      EdgeInsets.symmetric(
                    horizontal:
                        isExpanded ? 24 : 12,
                    vertical:
                        isExpanded ? 20 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(
                          alpha:
                              isExpanded
                                  ? 0.96
                                  : 0.88,
                        ),
                    borderRadius:
                        BorderRadius.circular(
                      isExpanded ? 28 : 18,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset:
                            Offset(0, 3),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    child: isExpanded
                        ? _ExpandedStats(
                            distance: activity
                                .distanceKm
                                .toStringAsFixed(2),
                            duration:
                                '$minutes:$seconds',
                            pace: paceText,
                          )
                        : _CompactStats(
                            distance: activity
                                .distanceKm
                                .toStringAsFixed(2),
                            duration:
                                '$minutes:$seconds',
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

class _CompactStats
    extends StatelessWidget {
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
      key: const ValueKey(
        'compact-stats',
      ),
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

class _ExpandedStats
    extends StatelessWidget {
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
      key: const ValueKey(
        'expanded-stats',
      ),
      mainAxisAlignment:
          MainAxisAlignment.spaceEvenly,
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
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
      ],
    );
  }
}

class _Stat
    extends StatelessWidget {
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
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.bold,
                fontSize:
                    expanded ? 36 : 18,
              ),
        ),
      ],
    );
  }
}

class _Controls
    extends ConsumerWidget {
  const _Controls({
    required this.activity,
  });

  final Activity activity;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final notifier =
        ref.read(trackingProvider.notifier);

    return switch (activity.status) {
      ActivityStatus.idle ||
      ActivityStatus.finished =>
        _WideButton(
          label: 'Start',
          color: Colors.deepOrange,
          onPressed: () =>
              _handleStart(
            context,
            notifier,
          ),
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
                color:
                    Colors.deepOrange,
                onPressed:
                    notifier.resume,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WideButton(
                label: 'Finish',
                color:
                    Colors.red.shade700,
                onPressed: () =>
                    _confirmFinish(
                  context,
                  ref,
                  notifier,
                ),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _confirmFinish(
    BuildContext context,
    WidgetRef ref,
    TrackingNotifier notifier,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
        title:
            const Text('Finish activity?'),
        content: const Text(
          'This will end and save your current run.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),
            child:
                const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),
            child:
                const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final completed =
          notifier.finish();

      await ref
          .read(
            activityHistoryProvider
                .notifier,
          )
          .addCompleted(
            completed,
          );

      if (context.mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }
}

class _WideButton
    extends StatelessWidget {
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
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}