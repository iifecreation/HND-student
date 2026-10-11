// Parses conversational control commands and yes/no/unsure responses from user utterances.

import 'text_normalizer.dart';

/// User answer classification for yes/no/unsure follow-up questions.
enum UserAnswer {
  yes,
  no,
  unsure,
  none;

  bool get isYes => this == UserAnswer.yes;
  bool get isNo => this == UserAnswer.no;
  bool get isUnsure => this == UserAnswer.unsure;
}

/// Dialogue navigation and workflow control commands.
enum UserCommand {
  next,
  repeat,
  back,
  stop,
  startOver,
  why,
  howSure,
  fixWorked,
  fixFailed,
  none,
}

/// Parses user speech or text input for conversational answers and control commands.
class CommandParser {
  const CommandParser();

  // Answer word sets per SPEC section 8
  static const List<String> _unsurePhrases = [
    'not sure',
    'dont know',
    'doesnt know',
    'no idea',
    'not certain',
    'hard to tell',
    'maybe',
    'unsure',
    'perhaps',
  ];

  static const Set<String> _yesWords = {
    'yes',
    'yeah',
    'yep',
    'correct',
    'right',
    'sure',
    'true',
    'affirmative',
    'ok',
    'okay',
  };

  static const Set<String> _noWords = {
    'no',
    'nope',
    'nah',
    'not',
    'negative',
    'false',
  };

  /// Parses whether [utterance] indicates yes, no, or unsure.
  ///
  /// CRITICAL RULE (SPEC section 8): Check "unsure" before "no" so that phrases
  /// like "not sure" or "dont know" are not misclassified as "no".
  UserAnswer parseAnswer(String utterance) {
    final normalized = TextNormalizer.normalize(utterance);
    if (normalized.isEmpty) return UserAnswer.none;

    final tokens = normalized.split(' ');

    // 1. Check UNSURE first
    for (final phrase in _unsurePhrases) {
      if (phrase.contains(' ')) {
        if (normalized.contains(phrase)) {
          return UserAnswer.unsure;
        }
      } else {
        if (tokens.contains(phrase)) {
          return UserAnswer.unsure;
        }
      }
    }

    // 2. Check YES
    for (final word in _yesWords) {
      if (tokens.contains(word)) {
        return UserAnswer.yes;
      }
    }

    // 3. Check NO
    for (final word in _noWords) {
      if (tokens.contains(word)) {
        return UserAnswer.no;
      }
    }

    return UserAnswer.none;
  }

  /// Parses whether [utterance] matches a system control command.
  UserCommand parseCommand(String utterance) {
    final norm = TextNormalizer.normalize(utterance);
    if (norm.isEmpty) return UserCommand.none;

    // Fix outcome commands
    if (norm.contains('didnt work') ||
        norm.contains('did not work') ||
        norm.contains('still broken') ||
        norm.contains('still not working') ||
        norm.contains('not working') ||
        norm.contains('failed')) {
      return UserCommand.fixFailed;
    }

    if (norm == 'done' ||
        norm == 'fixed' ||
        norm.contains('it worked') ||
        norm.contains('worked') ||
        norm.contains('resolved') ||
        norm.contains('problem solved')) {
      return UserCommand.fixWorked;
    }

    // Dialogue navigation commands
    if (norm == 'start over' ||
        norm == 'restart' ||
        norm == 'reset' ||
        norm == 'start again') {
      return UserCommand.startOver;
    }

    if (norm == 'repeat' ||
        norm == 'say again' ||
        norm == 'say that again' ||
        norm == 'again' ||
        norm == 'repeat step') {
      return UserCommand.repeat;
    }

    if (norm == 'back' ||
        norm == 'previous' ||
        norm == 'go back' ||
        norm == 'previous step') {
      return UserCommand.back;
    }

    if (norm == 'next' ||
        norm == 'continue' ||
        norm == 'next step' ||
        norm == 'go on') {
      return UserCommand.next;
    }

    if (norm == 'stop' ||
        norm == 'cancel' ||
        norm == 'exit' ||
        norm == 'quit') {
      return UserCommand.stop;
    }

    if (norm == 'why' ||
        norm.contains('why did you ask') ||
        norm.contains('why ask') ||
        norm.contains('why this')) {
      return UserCommand.why;
    }

    if (norm == 'how sure' ||
        norm.contains('how confident') ||
        norm == 'confidence') {
      return UserCommand.howSure;
    }

    return UserCommand.none;
  }
}
