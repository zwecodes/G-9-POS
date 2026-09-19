import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const kSetupCompleteKey = 'g9pos_setup_complete';
const kSetupScannerDoneKey = 'g9pos_setup_scanner';
const kSetupPrinterDoneKey = 'g9pos_setup_printer';
const kSetupOtherDeviceKey = 'g9pos_setup_other_device';

enum ChecklistMark { pending, done, skipped }

ChecklistMark _parseMark(String? raw) {
  switch (raw) {
    case 'done':
      return ChecklistMark.done;
    case 'skipped':
      return ChecklistMark.skipped;
    default:
      return ChecklistMark.pending;
  }
}

String _encodeMark(ChecklistMark mark) {
  switch (mark) {
    case ChecklistMark.done:
      return 'done';
    case ChecklistMark.skipped:
      return 'skipped';
    case ChecklistMark.pending:
      return 'pending';
  }
}

class SetupChecklistState {
  const SetupChecklistState({
    this.loaded = false,
    this.complete = false,
    this.scanner = ChecklistMark.pending,
    this.printer = ChecklistMark.pending,
    this.otherDevice = ChecklistMark.pending,
  });

  final bool loaded;
  final bool complete;
  final ChecklistMark scanner;
  final ChecklistMark printer;
  final ChecklistMark otherDevice;

  bool get canFinish =>
      scanner != ChecklistMark.pending &&
      printer != ChecklistMark.pending &&
      otherDevice != ChecklistMark.pending;

  SetupChecklistState copyWith({
    bool? loaded,
    bool? complete,
    ChecklistMark? scanner,
    ChecklistMark? printer,
    ChecklistMark? otherDevice,
  }) {
    return SetupChecklistState(
      loaded: loaded ?? this.loaded,
      complete: complete ?? this.complete,
      scanner: scanner ?? this.scanner,
      printer: printer ?? this.printer,
      otherDevice: otherDevice ?? this.otherDevice,
    );
  }
}

class SetupChecklistNotifier extends StateNotifier<SetupChecklistState> {
  SetupChecklistNotifier(this._storage) : super(const SetupChecklistState()) {
    _restore();
  }

  final FlutterSecureStorage _storage;

  Future<void> _restore() async {
    final complete = await _storage.read(key: kSetupCompleteKey);
    final scanner = await _storage.read(key: kSetupScannerDoneKey);
    final printer = await _storage.read(key: kSetupPrinterDoneKey);
    final other = await _storage.read(key: kSetupOtherDeviceKey);
    state = SetupChecklistState(
      loaded: true,
      complete: complete == '1',
      scanner: _parseMark(scanner),
      printer: _parseMark(printer),
      otherDevice: _parseMark(other),
    );
  }

  Future<void> setScanner(ChecklistMark mark) async {
    await _storage.write(key: kSetupScannerDoneKey, value: _encodeMark(mark));
    state = state.copyWith(scanner: mark);
  }

  Future<void> setPrinter(ChecklistMark mark) async {
    await _storage.write(key: kSetupPrinterDoneKey, value: _encodeMark(mark));
    state = state.copyWith(printer: mark);
  }

  Future<void> setOtherDevice(ChecklistMark mark) async {
    await _storage.write(key: kSetupOtherDeviceKey, value: _encodeMark(mark));
    state = state.copyWith(otherDevice: mark);
  }

  Future<void> markComplete() async {
    await _storage.write(key: kSetupCompleteKey, value: '1');
    state = state.copyWith(complete: true);
  }
}

final setupChecklistProvider =
    StateNotifierProvider<SetupChecklistNotifier, SetupChecklistState>((ref) {
  return SetupChecklistNotifier(const FlutterSecureStorage());
});
