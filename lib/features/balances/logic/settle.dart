import 'package:decimal/decimal.dart';
import 'package:tally/models/member_balance.dart';

// A suggested payment to move the group toward settled.
class DebtTransfer {
  const DebtTransfer({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });

  final String fromMemberId; // pays
  final String toMemberId; // receives
  final Decimal amount;
}

class _Bucket {
  _Bucket(this.memberId, this.amount);
  final String memberId;
  Decimal amount;
}

// Greedy debt simplification: repeatedly match the biggest debtor to the biggest
// creditor. Produces at most (n-1) transfers instead of everyone-pays-everyone.
List<DebtTransfer> simplifyDebts(List<MemberBalance> balances) {
  final creditors = <_Bucket>[]; // net > 0, owed money
  final debtors = <_Bucket>[]; // net < 0, owe money
  for (final b in balances) {
    if (b.net > Decimal.zero) {
      creditors.add(_Bucket(b.memberId, b.net));
    } else if (b.net < Decimal.zero) {
      debtors.add(_Bucket(b.memberId, Decimal.zero - b.net));
    }
  }
  creditors.sort((a, b) => b.amount.compareTo(a.amount));
  debtors.sort((a, b) => b.amount.compareTo(a.amount));

  final transfers = <DebtTransfer>[];
  var i = 0;
  var j = 0;
  while (i < debtors.length && j < creditors.length) {
    final d = debtors[i];
    final c = creditors[j];
    final pay = d.amount < c.amount ? d.amount : c.amount;
    if (pay > Decimal.zero) {
      transfers.add(DebtTransfer(
        fromMemberId: d.memberId,
        toMemberId: c.memberId,
        amount: pay,
      ));
    }
    d.amount -= pay;
    c.amount -= pay;
    if (d.amount <= Decimal.zero) i++;
    if (c.amount <= Decimal.zero) j++;
  }
  return transfers;
}
