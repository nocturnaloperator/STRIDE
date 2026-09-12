import 'package:flutter/material.dart';
 
/// A standalone summary stat box — bigger and more visual than the
/// inline stats inside ActivityCard. Used on the profile screen for
/// things like "Total distance," "Longest run," "Current streak."
///
/// Unlike _StatColumn (private to activity_card.dart), this widget is
/// public and meant to be reused anywhere a headline stat is needed.
class StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;
 
  const StatBox({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accentColor = const Color(0xFFB6FF3B),
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF15282B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 26),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
 
/// Arranges multiple StatBoxes in a responsive grid (2 per row).
/// Used directly by profile_screen.dart so that file doesn't need to
/// hand-build a GridView every time.
class StatBoxGrid extends StatelessWidget {
  final List<StatBox> boxes;
 
  const StatBoxGrid({super.key, required this.boxes});
 
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: boxes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) => boxes[index],
    );
  }
}
 