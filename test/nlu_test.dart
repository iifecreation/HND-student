// Unit tests for natural-language understanding (NLU): TextNormalizer,
// Stemmer, Levenshtein, SymptomExtractor, and CommandParser.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/knowledge/kb_loader.dart';
import 'package:printer_doc/nlu/command_parser.dart';
import 'package:printer_doc/nlu/levenshtein.dart';
import 'package:printer_doc/nlu/stemmer.dart';
import 'package:printer_doc/nlu/symptom_extractor.dart';
import 'package:printer_doc/nlu/text_normalizer.dart';

void main() {
  group('TextNormalizer (text_normalizer.dart)', () {
    test('lowercases, strips apostrophes, replaces punctuation, collapses spaces', () {
      expect(
        TextNormalizer.normalize("It won't pick up paper!"),
        equals('it wont pick up paper'),
      );

      expect(
        TextNormalizer.normalize("Printer’s jammed... please help!!"),
        equals('printers jammed please help'),
      );

      expect(
        TextNormalizer.normalize('   Lots   of   spaces   here   '),
        equals('lots of spaces here'),
      );
    });

    test('tokenize produces clean token list', () {
      expect(
        TextNormalizer.tokenize("it didn't print"),
        equals(['it', 'didnt', 'print']),
      );
      expect(TextNormalizer.tokenize(''), isEmpty);
    });
  });

  group('Stemmer (stemmer.dart)', () {
    test('strips suffixes and reduces doubled consonants', () {
      expect(Stemmer.stemToken('jamming'), equals('jam'));
      expect(Stemmer.stemToken('jammed'), equals('jam'));
      expect(Stemmer.stemToken('jams'), equals('jam'));
      expect(Stemmer.stemToken('stopped'), equals('stop'));
      expect(Stemmer.stemToken('streaks'), equals('streak'));
      expect(Stemmer.stemToken('slowly'), equals('slow'));
      expect(Stemmer.stemToken('crooked'), equals('crook'));
      expect(Stemmer.stemToken('wrinkled'), equals('wrinkl'));
      expect(Stemmer.stemToken('wrinkles'), equals('wrinkl'));
      expect(Stemmer.stemToken('blinking'), equals('blink'));
    });

    test('enforces minimum stem length 3 and does not over-strip short words', () {
      expect(Stemmer.stemToken('yes'), equals('yes'));
      expect(Stemmer.stemToken('gas'), equals('gas'));
      expect(Stemmer.stemToken('red'), equals('red'));
      expect(Stemmer.stemToken('fly'), equals('fly'));
      expect(Stemmer.stemToken('sing'), equals('sing'));
    });

    test('does not strip words ending in ss', () {
      expect(Stemmer.stemToken('wireless'), equals('wireless'));
      expect(Stemmer.stemToken('glass'), equals('glass'));
    });
  });

  group('Levenshtein (levenshtein.dart)', () {
    test('distance calculations', () {
      expect(Levenshtein.distance('cat', 'cat'), equals(0));
      expect(Levenshtein.distance('printer', 'printor'), equals(1));
      expect(Levenshtein.distance('jam', 'ham'), equals(1));
      expect(Levenshtein.distance('laser', 'laserjet'), equals(3));
    });

    test('matches requires min 5 characters for distance 1', () {
      // 5+ characters: distance 1 is permitted
      expect(Levenshtein.matches('printor', 'printer'), isTrue);
      expect(Levenshtein.matches('fadid', 'faded'), isTrue);
      expect(Levenshtein.matches('offlline', 'offline'), isTrue);

      // Under 5 characters: distance 1 is NOT permitted
      expect(Levenshtein.matches('ham', 'jam'), isFalse);
      expect(Levenshtein.matches('jamm', 'jam'), isFalse);
      expect(Levenshtein.matches('red', 'bed'), isFalse);

      // Distance > 1 is rejected
      expect(Levenshtein.matches('prntr', 'printer'), isFalse);
    });
  });

  group('SymptomExtractor (symptom_extractor.dart)', () {
    late SymptomExtractor extractor;

    setUpAll(() {
      final symptomsFile = File('assets/kb/symptoms.json');
      final symptoms =
          const KbLoader().parseSymptoms(symptomsFile.readAsStringSync());
      extractor = SymptomExtractor(symptoms);
    });

    test('case 1: "my printer keeps jamming" -> paper_jam TRUE', () {
      final facts = extractor.extractFacts('my printer keeps jamming');
      expect(facts['paper_jam'], isTrue);
    });

    test('case 2: "it won\'t pick up paper" -> no_paper_pickup TRUE', () {
      final facts = extractor.extractFacts("it won't pick up paper");
      expect(facts['no_paper_pickup'], isTrue);
    });

    test('case 3: "there is no paper jam but the light is blinking" -> paper_jam FALSE, error_light TRUE', () {
      final facts = extractor.extractFacts(
        'there is no paper jam but the light is blinking',
      );
      expect(facts['paper_jam'], isFalse, reason: 'paper_jam is negated by "no"');
      expect(facts['error_light'], isTrue, reason: 'error_light is positive after clause boundary');
    });

    test('case 4: "it says paper jam but I cannot see anything inside" -> paper_jam is NOT negated', () {
      final facts = extractor.extractFacts(
        'it says paper jam but I cannot see anything inside',
      );
      expect(
        facts['paper_jam'],
        isTrue,
        reason: 'paper_jam precedes "cannot" so it must remain positive',
      );
    });

    test('case 5: one-letter speech recognition error tolerated on 5+ char tokens', () {
      // "printor" instead of "printer", "faded" mistranscribed as "fadid"
      final facts = extractor.extractFacts('my fadid print on laser printor');
      expect(facts['faded_print'], isTrue);
      expect(facts['type_laser'], isTrue);
    });

    test('longest phrase preference without double-counting', () {
      final facts = extractor.extractFacts(
        'the tray is stuffed full of paper',
      );
      expect(facts['tray_overfilled'], isTrue);
    });

    test('multi-symptom positive extraction', () {
      final facts = extractor.extractFacts(
        'my laser printer prints faded pages and has a low toner warning',
      );
      expect(facts['type_laser'], isTrue);
      expect(facts['faded_print'], isTrue);
      expect(facts['low_toner_msg'], isTrue);
    });
  });

  group('CommandParser (command_parser.dart)', () {
    const parser = CommandParser();

    test('parses yes answers', () {
      expect(parser.parseAnswer('yes'), equals(UserAnswer.yes));
      expect(parser.parseAnswer('yeah that is right'), equals(UserAnswer.yes));
      expect(parser.parseAnswer('yep'), equals(UserAnswer.yes));
      expect(parser.parseAnswer('sure'), equals(UserAnswer.yes));
    });

    test('parses no answers', () {
      expect(parser.parseAnswer('no'), equals(UserAnswer.no));
      expect(parser.parseAnswer('nope'), equals(UserAnswer.no));
      expect(parser.parseAnswer('nah'), equals(UserAnswer.no));
    });

    test('checks unsure before no (e.g. "not sure" is unsure, not no)', () {
      expect(parser.parseAnswer('not sure'), equals(UserAnswer.unsure));
      expect(parser.parseAnswer('I dont know'), equals(UserAnswer.unsure));
      expect(parser.parseAnswer('maybe'), equals(UserAnswer.unsure));
      expect(parser.parseAnswer('unsure'), equals(UserAnswer.unsure));
    });

    test('parses workflow and navigation commands', () {
      expect(parser.parseCommand('next'), equals(UserCommand.next));
      expect(parser.parseCommand('continue'), equals(UserCommand.next));
      expect(parser.parseCommand('repeat'), equals(UserCommand.repeat));
      expect(parser.parseCommand('say again'), equals(UserCommand.repeat));
      expect(parser.parseCommand('back'), equals(UserCommand.back));
      expect(parser.parseCommand('previous'), equals(UserCommand.back));
      expect(parser.parseCommand('stop'), equals(UserCommand.stop));
      expect(parser.parseCommand('start over'), equals(UserCommand.startOver));
      expect(parser.parseCommand('restart'), equals(UserCommand.startOver));
      expect(parser.parseCommand('why'), equals(UserCommand.why));
      expect(parser.parseCommand('how sure'), equals(UserCommand.howSure));
    });

    test('parses solution outcome commands', () {
      expect(parser.parseCommand('it worked'), equals(UserCommand.fixWorked));
      expect(parser.parseCommand('done'), equals(UserCommand.fixWorked));
      expect(parser.parseCommand('fixed'), equals(UserCommand.fixWorked));
      expect(parser.parseCommand('didnt work'), equals(UserCommand.fixFailed));
      expect(parser.parseCommand('still broken'), equals(UserCommand.fixFailed));
      expect(parser.parseCommand('not working'), equals(UserCommand.fixFailed));
    });
  });
}
