// Data model representing IF-THEN diagnostic rules loaded from rules.json.

/// Represents an expert IF-THEN production rule with certainty factor weighting.
class Rule {
  /// Unique rule identifier (e.g. "R01", "R71").
  final String id;

  /// Symptoms that must all be observed TRUE for the rule to fire.
  final List<String> all;

  /// Symptoms where at least one must be observed TRUE (if any are specified).
  final List<String> any;

  /// Symptoms that must NOT be observed TRUE for the rule to fire.
  final List<String> none;

  /// Fault identifier concluded by this rule (e.g. "F01").
  final String then;

  /// Rule certainty factor between 0.0 and 1.0 indicating belief strength.
  final double cf;

  /// Plain-English explanation of why this rule concludes the specified fault.
  final String why;

  /// Flag indicating this rule triggers an immediate safety override (e.g. F20).
  final bool safety;

  const Rule({
    required this.id,
    this.all = const [],
    this.any = const [],
    this.none = const [],
    required this.then,
    required this.cf,
    required this.why,
    this.safety = false,
  });

  /// Creates a Rule from a JSON map parsed from rules.json.
  factory Rule.fromJson(Map<String, dynamic> json) {
    return Rule(
      id: json['id'] as String,
      all: (json['all'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      any: (json['any'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      none: (json['none'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      then: json['then'] as String,
      cf: (json['cf'] as num).toDouble(),
      why: json['why'] as String,
      safety: json['safety'] as bool? ?? false,
    );
  }

  /// Converts this Rule instance into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'all': all,
      if (any.isNotEmpty) 'any': any,
      if (none.isNotEmpty) 'none': none,
      'then': then,
      'cf': cf,
      'why': why,
      if (safety) 'safety': true,
    };
  }

  @override
  String toString() => 'Rule(id: $id, then: $then, cf: $cf, safety: $safety)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rule && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
