// What import_expenses did. A skipped row is not an error: it means somebody,
// possibly on another device, already imported that transaction.
class ImportResult {
  const ImportResult({
    required this.inserted,
    required this.skipped,
    required this.skippedFingerprints,
  });

  final int inserted;
  final int skipped;
  final List<String> skippedFingerprints;

  String get summary {
    final parts = <String>['Imported $inserted'];
    if (skipped > 0) parts.add('$skipped already existed');
    return parts.join(' · ');
  }

  factory ImportResult.fromJson(Map<String, dynamic> json) => ImportResult(
        inserted: json['inserted'] as int? ?? 0,
        skipped: json['skipped'] as int? ?? 0,
        skippedFingerprints: [
          for (final f in (json['skipped_fingerprints'] as List? ?? []))
            f as String,
        ],
      );
}
