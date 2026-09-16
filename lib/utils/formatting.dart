/// Formats a pace value (minutes per km, as a decimal like 5.98) into
/// "M:SS" display form.
///
/// This exists because the naive version of this — floor the minutes,
/// separately round the fractional part times 60 for seconds — has a
/// real carry bug: a pace like 5.999 min/km floors to "5", and its
/// fractional part (0.999 * 60 = 59.94) rounds to 60, producing the
/// display "5:60". That's not a valid time — it should read "6:00".
///
/// The fix is to round the TOTAL seconds first, then split into
/// minutes/seconds with integer division and modulo. That ordering
/// makes the carry impossible: rounding 359.94 seconds gives 360,
/// and 360 ~/ 60 = 6, 360 % 60 = 0 — "6:00", correctly, every time.
String formatPace(double? paceMinPerKm) {
  if (paceMinPerKm == null || !paceMinPerKm.isFinite) {
    return '--:--';
  }

  final totalSeconds = (paceMinPerKm * 60).round();

  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}