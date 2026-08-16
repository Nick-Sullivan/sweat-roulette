import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_record.dart';
import '../data/session_store.dart';

/// Every recorded session, oldest first.
///
/// Seeded once from the store's startup load and kept in step by [add] —
/// History never re-reads the file, and there is no [AsyncValue] anywhere,
/// because the data was in memory before the first frame.
final sessionHistoryProvider =
    NotifierProvider<SessionHistory, List<SessionRecord>>(SessionHistory.new);

class SessionHistory extends Notifier<List<SessionRecord>> {
  @override
  List<SessionRecord> build() => ref.watch(sessionStoreProvider).records;

  /// Re-reads the store after a commit.
  ///
  /// A mirror rather than an append. `commit` updates the store's in-memory
  /// list synchronously, so appending here would count a record twice whenever
  /// this notifier happened to be built *after* the commit that created it —
  /// which is exactly what happens the first time History is opened. Mirroring
  /// also means the seed tile's records, which are weeks older than everything
  /// else, arrive already in order.
  void refresh() => state = ref.read(sessionStoreProvider).records;
}

/// Sessions bucketed by the local day they started on — the shape a month grid
/// wants.
///
/// The value is a list because you can roll twice in one day; the calendar
/// keeps the day marked once and History pages through both.
final sessionCalendarProvider = Provider<Map<DateTime, List<SessionRecord>>>((
  ref,
) {
  final byDay = <DateTime, List<SessionRecord>>{};
  for (final record in ref.watch(sessionHistoryProvider)) {
    (byDay[record.day] ??= []).add(record);
  }
  return byDay;
});
