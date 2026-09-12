import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity_model.dart';
import '../widgets/activity_card.dart';
 
/// The main feed — shows a scrollable list of past activities.
///
/// Currently uses hardcoded dummy data (_dummyActivities) so the screen
/// is fully visible and testable before the backend exists. In Week 3,
/// _dummyActivities gets replaced by a real API call that fetches
/// Activity.fromJson() results from FastAPI.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    final activities = _dummyActivities();
 
    if (activities.isEmpty) {
      return const Center(
        child: Text(
          'No runs logged yet.\nHit Track to start your first one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 15),
        ),
      );
    }
 
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ActivityCard(
          activity: activity,
          onTap: () {
            // Week 4+: navigate to a detail screen showing the full
            // route map and splits for this activity.
            debugPrint('Tapped activity: ${activity.title}');
          },
        );
      },
    );
  }
 
  /// Temporary placeholder data. Replace this entire method with a real
  /// API call once backend/routes/activities.py exists (Week 3).
  List<Activity> _dummyActivities() {
    return [
      Activity(
        id: '1',
        title: 'Morning Easy Run',
        date: DateTime.now().subtract(const Duration(days: 1)),
        distanceKm: 8.42,
        duration: const Duration(minutes: 44, seconds: 12),
        elevationGainM: 62,
        averageHeartRate: 148,
        route: const [
          LatLng(19.0760, 72.8777),
          LatLng(19.0800, 72.8800),
        ],
      ),
      Activity(
        id: '2',
        title: 'Tempo Intervals',
        date: DateTime.now().subtract(const Duration(days: 3)),
        distanceKm: 10.05,
        duration: const Duration(minutes: 48, seconds: 30),
        elevationGainM: 40,
        averageHeartRate: 165,
        route: const [
          LatLng(19.0760, 72.8777),
          LatLng(19.0900, 72.8850),
        ],
      ),
      Activity(
        id: '3',
        title: 'Long Sunday Run',
        date: DateTime.now().subtract(const Duration(days: 6)),
        distanceKm: 21.10,
        duration: const Duration(hours: 1, minutes: 52, seconds: 5),
        elevationGainM: 180,
        route: const [
          LatLng(19.0760, 72.8777),
          LatLng(19.1000, 72.9000),
        ],
        // No averageHeartRate given here on purpose — this run's watch
        // died mid-run. Demonstrates the "Avg HR" stat correctly
        // disappearing from the card when the value is null.
      ),
    ];
  }
}
 