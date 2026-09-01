import 'package:tally/features/import/logic/fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

String fp(String group, String ref) =>
    transactionFingerprint(groupId: group, reference: ref);

void main() {
  group('transactionFingerprint', () {
    test('is a 64-character lowercase hex digest', () {
      final digest = fp('g1', '55181366242380664636432');
      expect(digest, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(digest), isTrue);
    });

    test('is deterministic', () {
      expect(fp('g1', '123'), fp('g1', '123'));
    });

    test('differs per group, so digests cannot be correlated across groups', () {
      expect(fp('g1', '123'), isNot(fp('g2', '123')));
    });

    test('differs per transaction', () {
      expect(fp('g1', '123'), isNot(fp('g1', '124')));
    });

    // The cross-device dedup contract: one export quotes the reference number
    // and the other does not. If these ever diverge, a roommate re-importing
    // the same statement from a different export silently double-charges the
    // group.
    test('is identical across export formats of the same reference', () {
      final canonical = fp('g1', '123');
      for (final variant in ['"123"', ' 123 ', "'123'", '"123"\n', '123']) {
        expect(fp('g1', variant), canonical, reason: variant);
      }
    });

    test('preserves non-numeric references', () {
      expect(
        fp('g1', '40828MBLE-241127-225678'),
        fp('g1', '"40828MBLE-241127-225678"'),
      );
      expect(fp('g1', '40828MBLE-241127-225678'), isNot(fp('g1', '40828MBLE')));
    });

    // Pinned vectors. Changing the normalisation would invalidate every
    // fingerprint already stored on a user's expenses, so this must fail
    // loudly rather than drift.
    test('matches its pinned known vectors', () {
      expect(
        fp('g1', '123'),
        '45f4d0cb52ca1054fe2ddd8230a0cf143db7391774963f06359295e91f7f0a6c',
      );
      expect(
        fp('group-abc', '55181366242380664636432'),
        '3a23fa7924e03be02e1a4f377743665a8a1ab4f33f0135ee1462bddcf59ab90a',
      );
    });
  });
}
