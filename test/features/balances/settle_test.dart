import 'package:decimal/decimal.dart';
import 'package:exp_share/features/balances/logic/settle.dart';
import 'package:exp_share/models/member_balance.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String s) => Decimal.parse(s);
MemberBalance bal(String id, String net) =>
    MemberBalance(memberId: id, net: d(net));

void main() {
  group('simplifyDebts', () {
    test('no transfers when everyone is settled', () {
      expect(simplifyDebts([bal('a', '0'), bal('b', '0')]), isEmpty);
    });

    test('one debtor, one creditor', () {
      final t = simplifyDebts([bal('a', '-30'), bal('b', '30')]);
      expect(t, hasLength(1));
      expect(t.single.fromMemberId, 'a');
      expect(t.single.toMemberId, 'b');
      expect(t.single.amount, d('30'));
    });

    test('produces at most n-1 transfers', () {
      final t = simplifyDebts([
        bal('a', '-50'),
        bal('b', '-30'),
        bal('c', '20'),
        bal('d', '60'),
      ]);
      expect(t.length, lessThanOrEqualTo(3));
    });

    test('transfers net out every balance exactly', () {
      final balances = [
        bal('a', '-45.50'),
        bal('b', '-4.50'),
        bal('c', '20.00'),
        bal('d', '30.00'),
      ];
      final paid = <String, Decimal>{};
      for (final t in simplifyDebts(balances)) {
        paid[t.fromMemberId] = (paid[t.fromMemberId] ?? Decimal.zero) + t.amount;
        paid[t.toMemberId] = (paid[t.toMemberId] ?? Decimal.zero) - t.amount;
      }
      for (final b in balances) {
        // debtor pays out |net|, creditor receives net
        expect(paid[b.memberId] ?? Decimal.zero, -b.net,
            reason: 'member ${b.memberId}');
      }
    });

    test('largest debtor is matched to largest creditor first', () {
      final t = simplifyDebts([
        bal('bigDebt', '-100'),
        bal('smallDebt', '-10'),
        bal('bigCredit', '90'),
        bal('smallCredit', '20'),
      ]);
      expect(t.first.fromMemberId, 'bigDebt');
      expect(t.first.toMemberId, 'bigCredit');
    });
  });
}
