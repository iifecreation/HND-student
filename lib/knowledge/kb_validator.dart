// Validates knowledge base integrity, checking for missing references, duplicates, and invalid CF values.

import 'fault.dart';
import 'kb_loader.dart';
import 'rule.dart';
import 'symptom.dart';

/// Severity level of a validation outcome.
enum IssueSeverity { error, warning }

/// Describes a specific validation finding in the knowledge base.
class KbValidationIssue {
  final String message;
  final String? entityId;
  final IssueSeverity severity;

  const KbValidationIssue({
    required this.message,
    this.entityId,
    this.severity = IssueSeverity.error,
  });

  @override
  String toString() => entityId != null ? '[$entityId] $message' : message;
}

/// Container summarizing the results of knowledge base validation.
class KbValidationResult {
  final List<KbValidationIssue> issues;

  const KbValidationResult(this.issues);

  /// True if there are zero error-level issues.
  bool get isValid => errors.isEmpty;

  /// Returns only issues with error severity.
  List<KbValidationIssue> get errors =>
      issues.where((i) => i.severity == IssueSeverity.error).toList(growable: false);

  /// Returns only issues with warning severity.
  List<KbValidationIssue> get warnings =>
      issues.where((i) => i.severity == IssueSeverity.warning).toList(growable: false);
}

/// Validates knowledge base rules and entities for relational and logical consistency.
class KbValidator {
  const KbValidator();

  /// Validates a parsed [KnowledgeBase] instance.
  KbValidationResult validateKnowledgeBase(KnowledgeBase kb) {
    return validate(
      symptoms: kb.symptomList,
      faults: kb.faultList,
      rules: kb.rules,
    );
  }

  /// Validates lists of symptoms, faults, and rules for duplicates, integrity, and CF bounds.
  KbValidationResult validate({
    required List<Symptom> symptoms,
    required List<Fault> faults,
    required List<Rule> rules,
  }) {
    final issues = <KbValidationIssue>[];

    // 1. Check duplicate symptom IDs
    final seenSymptomIds = <String>{};
    final duplicateSymptomIds = <String>{};
    for (final symptom in symptoms) {
      if (!seenSymptomIds.add(symptom.id)) {
        duplicateSymptomIds.add(symptom.id);
        issues.add(KbValidationIssue(
          entityId: symptom.id,
          message: 'Duplicate symptom ID detected: ${symptom.id}',
        ));
      }
    }

    // 2. Check duplicate fault IDs
    final seenFaultIds = <String>{};
    final duplicateFaultIds = <String>{};
    for (final fault in faults) {
      if (!seenFaultIds.add(fault.id)) {
        duplicateFaultIds.add(fault.id);
        issues.add(KbValidationIssue(
          entityId: fault.id,
          message: 'Duplicate fault ID detected: ${fault.id}',
        ));
      }
    }

    // 3. Check duplicate rule IDs
    final seenRuleIds = <String>{};
    for (final rule in rules) {
      if (!seenRuleIds.add(rule.id)) {
        issues.add(KbValidationIssue(
          entityId: rule.id,
          message: 'Duplicate rule ID detected: ${rule.id}',
        ));
      }
    }

    // Build lookup sets for reference validation
    final validSymptomIds = seenSymptomIds;
    final validFaultIds = seenFaultIds;

    // 4. Validate symptoms mutual exclusion references
    for (final symptom in symptoms) {
      for (final excludedId in symptom.excludes) {
        if (!validSymptomIds.contains(excludedId)) {
          issues.add(KbValidationIssue(
            entityId: symptom.id,
            message:
                'Symptom ${symptom.id} excludes unknown symptom ID: $excludedId',
            severity: IssueSeverity.error,
          ));
        }
      }
    }

    // 4b. The same synonym must not belong to two different symptoms, or the
    // extractor cannot tell which symptom the user meant.
    final synonymOwner = <String, String>{};
    for (final symptom in symptoms) {
      for (final synonym in symptom.synonyms) {
        final key = synonym.trim().toLowerCase();
        final owner = synonymOwner[key];
        if (owner == null) {
          synonymOwner[key] = symptom.id;
        } else if (owner != symptom.id) {
          issues.add(KbValidationIssue(
            entityId: symptom.id,
            message:
                'Synonym "$synonym" is used by both $owner and ${symptom.id}',
          ));
        }
      }
    }

    // 5. Validate rules
    for (final rule in rules) {
      // Check empty conditions
      if (rule.all.isEmpty && rule.any.isEmpty && rule.none.isEmpty) {
        issues.add(KbValidationIssue(
          entityId: rule.id,
          message:
              'Rule has empty conditions (all, any, and none are all empty)',
        ));
      }

      // Check CF bounds (0.0 to 1.0)
      if (rule.cf.isNaN || rule.cf < 0.0 || rule.cf > 1.0) {
        issues.add(KbValidationIssue(
          entityId: rule.id,
          message:
              'Certainty factor out of bounds (must be 0.0 to 1.0): ${rule.cf}',
        ));
      }

      // Check referenced fault exists
      if (!validFaultIds.contains(rule.then)) {
        issues.add(KbValidationIssue(
          entityId: rule.id,
          message: 'Rule references unknown fault ID: ${rule.then}',
        ));
      }

      // Check referenced symptoms in 'all' condition
      for (final symptomId in rule.all) {
        if (!validSymptomIds.contains(symptomId)) {
          issues.add(KbValidationIssue(
            entityId: rule.id,
            message: 'Rule references unknown symptom ID in all: $symptomId',
          ));
        }
      }

      // Check referenced symptoms in 'any' condition
      for (final symptomId in rule.any) {
        if (!validSymptomIds.contains(symptomId)) {
          issues.add(KbValidationIssue(
            entityId: rule.id,
            message: 'Rule references unknown symptom ID in any: $symptomId',
          ));
        }
      }

      // Check referenced symptoms in 'none' condition
      for (final symptomId in rule.none) {
        if (!validSymptomIds.contains(symptomId)) {
          issues.add(KbValidationIssue(
            entityId: rule.id,
            message: 'Rule references unknown symptom ID in none: $symptomId',
          ));
        }
      }
    }

    return KbValidationResult(issues);
  }
}
