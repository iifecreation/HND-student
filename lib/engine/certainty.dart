// Implements certainty factor mathematical combination functions based on the MYCIN model.

import 'dart:math' as math;

/// Computes the combined certainty factor of two independent positive pieces of evidence
/// using the standard MYCIN formula: CF_combined = CF1 + CF2 * (1 - CF1).
///
/// Both [cf1] and [cf2] must be in the range [0.0, 1.0].
/// The resulting combined certainty factor is clamped to [0.0, 1.0].
double combine(double cf1, double cf2) {
  if (cf1.isNaN || cf2.isNaN) return 0.0;
  final safeCf1 = cf1.clamp(0.0, 1.0);
  final safeCf2 = cf2.clamp(0.0, 1.0);

  final combined = safeCf1 + safeCf2 * (1.0 - safeCf1);
  return combined.clamp(0.0, 1.0);
}

/// Combines multiple certainty factors iteratively using the MYCIN combination rule.
///
/// If [cfs] is empty, returns 0.0.
double combineAll(Iterable<double> cfs) {
  var accumulated = 0.0;
  for (final cf in cfs) {
    accumulated = combine(accumulated, cf);
  }
  return accumulated;
}

/// Computes rule premise evidence certainty by taking the minimum certainty
/// among all satisfied positive conditions (fuzzy AND).
///
/// If [certainties] is empty, returns 1.0 (neutral evidence).
double minEvidenceCertainty(Iterable<double> certainties) {
  if (certainties.isEmpty) return 1.0;
  var minVal = 1.0;
  for (final c in certainties) {
    final clamped = c.clamp(0.0, 1.0);
    minVal = math.min(minVal, clamped);
  }
  return minVal;
}
