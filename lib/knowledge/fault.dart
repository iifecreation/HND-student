// Data model representing printer fault definitions loaded from faults.json.

/// Represents a diagnosed printer fault condition and associated recovery steps.
class Fault {
  /// Unique fault code (e.g. "F01", "F20").
  final String id;

  /// Human-readable title of the fault.
  final String name;

  /// Fault category (paper, quality, connectivity, hardware, safety).
  final String category;

  /// Severity rating ("low", "medium", "high", "critical").
  final String severity;

  /// Indicates if this fault requires professional technician assistance.
  final bool technician;

  /// Concise plain-English explanation of the fault cause.
  final String summary;

  /// Ordered step-by-step resolution instructions spoken and shown to the user.
  final List<String> steps;

  const Fault({
    required this.id,
    required this.name,
    required this.category,
    required this.severity,
    required this.technician,
    required this.summary,
    required this.steps,
  });

  /// Creates a Fault from a JSON map parsed from faults.json.
  factory Fault.fromJson(Map<String, dynamic> json) {
    return Fault(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      severity: json['severity'] as String,
      technician: json['technician'] as bool? ?? false,
      summary: json['summary'] as String,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Converts this Fault instance into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'severity': severity,
      'technician': technician,
      'summary': summary,
      'steps': steps,
    };
  }

  @override
  String toString() => 'Fault(id: $id, name: $name, severity: $severity)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fault && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
