// Loads and parses knowledge base JSON strings into domain model collections.

import 'dart:convert';
import 'fault.dart';
import 'rule.dart';
import 'symptom.dart';

/// Container encapsulating the in-memory parsed domain entities of the knowledge base.
class KnowledgeBase {
  /// Map of symptom IDs to Symptom models for O(1) lookups.
  final Map<String, Symptom> symptoms;

  /// Map of fault IDs to Fault models for O(1) lookups.
  final Map<String, Fault> faults;

  /// Ordered list of diagnostic production rules.
  final List<Rule> rules;

  const KnowledgeBase({
    required this.symptoms,
    required this.faults,
    required this.rules,
  });

  /// Returns a symptom by ID if registered, or null.
  Symptom? getSymptom(String id) => symptoms[id];

  /// Returns a fault by ID if registered, or null.
  Fault? getFault(String id) => faults[id];

  /// Convenience getter returning all symptoms as a list.
  List<Symptom> get symptomList => symptoms.values.toList(growable: false);

  /// Convenience getter returning all faults as a list.
  List<Fault> get faultList => faults.values.toList(growable: false);
}

/// Pure Dart parser converting raw JSON strings into knowledge base models.
class KbLoader {
  const KbLoader();

  /// Parses symptoms JSON string into a list of [Symptom] instances.
  List<Symptom> parseSymptoms(String jsonString) {
    final dynamic decoded = json.decode(jsonString);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Expected root list in symptoms.json');
    }
    return decoded
        .map((item) => Symptom.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Parses faults JSON string into a list of [Fault] instances.
  List<Fault> parseFaults(String jsonString) {
    final dynamic decoded = json.decode(jsonString);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Expected root list in faults.json');
    }
    return decoded
        .map((item) => Fault.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Parses rules JSON string into a list of [Rule] instances.
  List<Rule> parseRules(String jsonString) {
    final dynamic decoded = json.decode(jsonString);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Expected root list in rules.json');
    }
    return decoded
        .map((item) => Rule.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Parses and constructs a consolidated [KnowledgeBase] from raw JSON strings.
  KnowledgeBase load({
    required String symptomsJson,
    required String faultsJson,
    required String rulesJson,
  }) {
    final symptoms = parseSymptoms(symptomsJson);
    final faults = parseFaults(faultsJson);
    final rules = parseRules(rulesJson);

    final symptomsMap = {for (final s in symptoms) s.id: s};
    final faultsMap = {for (final f in faults) f.id: f};

    return KnowledgeBase(
      symptoms: symptomsMap,
      faults: faultsMap,
      rules: rules,
    );
  }
}
