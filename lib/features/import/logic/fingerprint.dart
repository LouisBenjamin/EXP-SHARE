import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tally/features/import/logic/field_parsers.dart';

// The only trace an imported statement leaves on the server.
//
// Stored on expenses.source_fingerprint so that if two roommates import
// overlapping copies of the same shared-card statement from two devices, the
// second import is recognised as a duplicate instead of charging the group
// twice. A partial unique index on (group_id, source_fingerprint) enforces it.
//
// It is one-way: nothing about the merchant, amount, card or date is
// recoverable from the digest. The reference number it hashes is high-entropy
// (a 23-digit bank reference), so this is not brute-forceable the way a hash
// of a short merchant name would be.
//
// The group id is mixed in so the same transaction produces different digests
// in different groups, and so a digest can't be correlated across groups.
//
// Hashing happens on the client on purpose. Doing it server-side would mean
// sending the reference number to the server, which is exactly what this
// design exists to avoid — so the server cannot verify the digest, and simply
// trusts it. The blast radius of a bad one is a group the caller is already a
// member of.
//
// normalizeReference makes the digest identical across export formats: one
// export wraps the reference in quotes, and both must fingerprint the same or
// cross-device dedup silently stops working. That invariant is pinned by a
// known vector in the tests — changing the normalisation invalidates every
// fingerprint already stored.
String transactionFingerprint({
  required String groupId,
  required String reference,
}) {
  final key = '$groupId:${normalizeReference(reference)}';
  return sha256.convert(utf8.encode(key)).toString();
}
