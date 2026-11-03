import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/providers.dart';

/// Records that a [LocalCollection] can hold.
abstract interface class Identified {
  String get id;
}

/// In-memory list used by screens whose backend contract is not final yet.
///
/// * Demo mode (`APP_MODE=mock`): seeded with typed sample records; create,
///   edit and delete work locally and are never sent to a server.
/// * API mode: starts empty and the screen shows `BackendPendingNotice`, so
///   sample data is never presented as server data.
class LocalCollection<T extends Identified> extends Notifier<List<T>> {
  new(this._seed);

  final List<T> Function() _seed;

  @override
  List<T> build() {
    if (!ref.watch(appConfigProvider).isMock) return <T>[];
    return _seed();
  }

  void add(T item) => state = [item, ...state];

  void replace(T item) =>
      state = state.map((x) => x.id == item.id ? item : x).toList();

  void remove(String id) =>
      state = state.where((x) => x.id != id).toList(growable: false);

  T? byId(String id) {
    for (final x in state) {
      if (x.id == id) return x;
    }
    return null;
  }
}

/// True when screens may show demo records and local mutations.
final demoModeProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).isMock,
);

int _seq = 0;

/// Locally unique id for records created on the device.
String localId(String prefix) =>
    '$prefix-local-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';
