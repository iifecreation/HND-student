// Data model representing printer symptom definitions loaded from symptoms.json.

/// Represents a single printer symptom observation or context condition.
class Symptom {
  /// Unique identifier (e.g. "paper_jam", "type_laser").
  final String id;

  /// Human-readable label (e.g. "Paper jam").
  final String label;

  /// Symptom category (paper, quality, connectivity, hardware, context).
  final String category;

  /// Spoken or written phrases indicating this symptom.
  final List<String> synonyms;

  /// Follow-up question to ask the user if this symptom is unknown.
  final String question;

  /// Mutually exclusive symptom IDs (e.g. type_laser excludes type_inkjet).
  final List<String> excludes;

  const Symptom({
    required this.id,
    required this.label,
    required this.category,
    required this.synonyms,
    required this.question,
    this.excludes = const [],
  });

  /// Creates a Symptom from a JSON map parsed from symptoms.json.
  factory Symptom.fromJson(Map<String, dynamic> json) {
    return Symptom(
      id: json['id'] as String,
      label: json['label'] as String,
      category: json['category'] as String,
      synonyms: (json['synonyms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      question: json['question'] as String,
      excludes: (json['excludes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Converts this Symptom instance into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'category': category,
      'synonyms': synonyms,
      'question': question,
      if (excludes.isNotEmpty) 'excludes': excludes,
    };
  }

  @override
  String toString() => 'Symptom(id: $id, label: $label, category: $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Symptom && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
