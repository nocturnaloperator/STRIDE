import 'package:flutter/material.dart';
import '../models/activity_model.dart';
 
/// Displays a single [Activity] as a card — used in the feed screen,
/// and reusable anywhere else you need to show one run at a glance
/// (e.g. a "recent activity" section on the profile screen).
class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback? onTap;
 
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
  });
 
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF15282B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    activity.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(activity.date),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
 
            // Stats row: distance, pace, duration
            Row(
              children: [
                _StatColumn(
                  label: 'Distance',
                  value: '${activity.distanceKm.toStringAsFixed(2)} km',
                ),
                const SizedBox(width: 24),
                _StatColumn(
                  label: 'Pace',
                  value: activity.formattedPace,
                ),
                const SizedBox(width: 24),
                _StatColumn(
                  label: 'Time',
                  value: activity.formattedDuration,
                ),
                if (activity.averageHeartRate != null) ...[
                  const SizedBox(width: 24),
                  _StatColumn(
                    label: 'Avg HR',
                    value: '${activity.averageHeartRate} bpm',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
 
  /// Formats a DateTime as "3 Sep" without needing the `intl` package —
  /// keeps this widget dependency-free.
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
 
/// Small private helper widget: one labeled stat (used 3-4 times per card).
/// Kept private (underscore prefix) since nothing outside this file needs it.
class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
 
  const _StatColumn({required this.label, required this.value});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFB6FF3B),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
 