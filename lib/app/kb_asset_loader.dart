// Flutter helper that loads knowledge base JSON strings from rootBundle assets.

import 'package:flutter/services.dart' show rootBundle;
import '../knowledge/kb_loader.dart';

/// Reads knowledge base JSON assets using Flutter's rootBundle and hands them to KbLoader.
class FlutterKbAssetLoader {
  static const String defaultSymptomsPath = 'assets/kb/symptoms.json';
  static const String defaultFaultsPath = 'assets/kb/faults.json';
  static const String defaultRulesPath = 'assets/kb/rules.json';

  /// Loads symptoms, faults, and rules from Flutter asset bundles into a [KnowledgeBase].
  static Future<KnowledgeBase> loadFromAssets({
    String symptomsPath = defaultSymptomsPath,
    String faultsPath = defaultFaultsPath,
    String rulesPath = defaultRulesPath,
    KbLoader loader = const KbLoader(),
  }) async {
    final symptomsJson = await rootBundle.loadString(symptomsPath);
    final faultsJson = await rootBundle.loadString(faultsPath);
    final rulesJson = await rootBundle.loadString(rulesPath);

    return loader.load(
      symptomsJson: symptomsJson,
      faultsJson: faultsJson,
      rulesJson: rulesJson,
    );
  }
}
