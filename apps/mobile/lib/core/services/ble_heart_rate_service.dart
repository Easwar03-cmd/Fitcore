import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wearable_hints.dart';

final _log = Logger();

/// Bluetooth SIG assigned numbers used by the standard Heart Rate Profile.
final Guid kHeartRateService = Guid('180D');
final Guid kHeartRateMeasurement = Guid('2A37');
final Guid kBatteryService = Guid('180F');
final Guid kBatteryLevel = Guid('2A19');

const _kPrefId = 'ble_hr_device_id';
const _kPrefName = 'ble_hr_device_name';

/// Decodes a Heart Rate Measurement characteristic value (BT SIG GATT spec):
/// bit 0 of the flags byte selects an 8-bit or 16-bit little-endian value.
/// Returns null for malformed payloads.
int? parseHeartRateMeasurement(List<int> data) {
  if (data.length < 2) return null;
  final is16 = data[0] & 0x01 != 0;
  if (is16) {
    if (data.length < 3) return null;
    return data[1] | (data[2] << 8);
  }
  return data[1];
}

/// A device seen while scanning.
class BleDeviceInfo {
  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    required this.advertisesHeartRate,
  });

  final String id;
  final String name;
  final int rssi;

  /// Device advertises the standard Heart Rate service, so it is very likely
  /// to connect and stream.
  final bool advertisesHeartRate;
}

enum BleStatus { idle, scanning, connecting, connected }

class BleHeartRateState {
  const BleHeartRateState({
    this.adapterOn = true,
    this.status = BleStatus.idle,
    this.devices = const [],
    this.connectedId,
    this.connectedName,
    this.bpm,
    this.batteryPct,
    this.message,
    this.rememberedName,
    this.fallbackHint,
  });

  final bool adapterOn;
  final BleStatus status;
  final List<BleDeviceInfo> devices;
  final String? connectedId;
  final String? connectedName;
  final int? bpm;
  final int? batteryPct;

  /// Human-readable hint / error for the UI.
  final String? message;
  final String? rememberedName;

  /// Set when this watch cannot stream heart rate over standard Bluetooth
  /// and the user should use Health Connect instead.
  final WearableHint? fallbackHint;

  bool get isConnected => status == BleStatus.connected;

  BleHeartRateState copyWith({
    bool? adapterOn,
    BleStatus? status,
    List<BleDeviceInfo>? devices,
    String? connectedId,
    String? connectedName,
    int? bpm,
    int? batteryPct,
    String? message,
    String? rememberedName,
    WearableHint? fallbackHint,
    bool clearFallback = false,
    bool clearConnection = false,
    bool clearMessage = false,
  }) =>
      BleHeartRateState(
        adapterOn: adapterOn ?? this.adapterOn,
        status: status ?? this.status,
        devices: devices ?? this.devices,
        connectedId: clearConnection ? null : (connectedId ?? this.connectedId),
        connectedName:
            clearConnection ? null : (connectedName ?? this.connectedName),
        bpm: clearConnection ? null : (bpm ?? this.bpm),
        batteryPct: clearConnection ? null : (batteryPct ?? this.batteryPct),
        message: clearMessage ? null : (message ?? this.message),
        rememberedName: rememberedName ?? this.rememberedName,
        fallbackHint:
            clearFallback ? null : (fallbackHint ?? this.fallbackHint),
      );
}

final bleHeartRateProvider =
    NotifierProvider<BleHeartRateController, BleHeartRateState>(
        BleHeartRateController.new);

/// Scans for, connects to and streams heart rate from any Bluetooth LE device
/// exposing the standard Heart Rate service (Polar, Garmin broadcast, Coospo,
/// Wahoo, many bands and watches in "broadcast HR" mode).
class BleHeartRateController extends Notifier<BleHeartRateState> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _hrSub;
  StreamSubscription<List<int>>? _battSub;
  BluetoothDevice? _device;
  Timer? _silentTimer;

  @override
  BleHeartRateState build() {
    ref.onDispose(_disposeAll);
    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      final on = s == BluetoothAdapterState.on;
      state = state.copyWith(adapterOn: on);
      if (!on && state.isConnected) _handleDisconnected();
    });
    _loadRemembered();
    return const BleHeartRateState();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kPrefName);
    if (name != null) state = state.copyWith(rememberedName: name);
  }

  // ── Scan ───────────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (state.status == BleStatus.scanning || state.isConnected) return;
    if (!await FlutterBluePlus.isSupported) {
      state = state.copyWith(
          message: 'Bluetooth LE is not supported on this device.');
      return;
    }
    state = state.copyWith(
      status: BleStatus.scanning,
      devices: const [],
      clearMessage: true,
    );
    try {
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.onScanResults.listen(_onResults);
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
    } catch (e) {
      _log.w('BLE scan failed', error: e);
      state = state.copyWith(
        message: 'Could not scan. Check that Bluetooth is on and that Revive '
            'has the Nearby devices permission.',
      );
    } finally {
      await _scanSub?.cancel();
      _scanSub = null;
      if (state.status == BleStatus.scanning) {
        state = state.copyWith(status: BleStatus.idle);
      }
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  void _onResults(List<ScanResult> results) {
    final byId = <String, BleDeviceInfo>{};
    for (final r in results) {
      final name = r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : r.device.platformName;
      if (name.isEmpty) continue; // skip anonymous beacons
      byId[r.device.remoteId.str] = BleDeviceInfo(
        id: r.device.remoteId.str,
        name: name,
        rssi: r.rssi,
        advertisesHeartRate:
            r.advertisementData.serviceUuids.contains(kHeartRateService),
      );
    }
    final list = byId.values.toList()
      ..sort((a, b) {
        if (a.advertisesHeartRate != b.advertisesHeartRate) {
          return a.advertisesHeartRate ? -1 : 1;
        }
        return b.rssi.compareTo(a.rssi);
      });
    state = state.copyWith(devices: list);
  }

  // ── Connect ────────────────────────────────────────────────────────────────

  Future<void> connectById(String id, String name) async {
    if (state.status == BleStatus.connecting) return;
    await stopScan();
    state = state.copyWith(
      status: BleStatus.connecting,
      connectedName: name,
      clearMessage: true,
      clearFallback: true,
    );
    _silentTimer?.cancel();
    final device = BluetoothDevice.fromId(id);
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      await _ensureBonded(device);
      final services = await device.discoverServices();
      final manufacturer = await _logDeviceProfile(device, services);
      final hrService = services
          .where((s) => s.uuid == kHeartRateService)
          .cast<BluetoothService?>()
          .firstWhere((_) => true, orElse: () => null);
      final hrChar = hrService?.characteristics
          .where((c) => c.uuid == kHeartRateMeasurement)
          .cast<BluetoothCharacteristic?>()
          .firstWhere((_) => true, orElse: () => null);

      if (hrChar == null) {
        await device.disconnect();
        state = state.copyWith(
          status: BleStatus.idle,
          clearConnection: true,
          fallbackHint: hintFor(name, manufacturer: manufacturer),
          message: '$name uses its own private Bluetooth protocol, so Revive '
              'cannot read it directly. Use Health Connect instead: your '
              "watch's app writes the data there.",
        );
        return;
      }

      _device = device;
      await _hrSub?.cancel();
      _hrSub = hrChar.onValueReceived.listen((v) {
        final bpm = parseHeartRateMeasurement(v);
        if (bpm != null && bpm > 0) {
          _silentTimer?.cancel();
          state = state.copyWith(bpm: bpm, clearFallback: true);
        }
      });
      await hrChar.setNotifyValue(true);
      await _subscribeBattery(services);

      _connSub?.cancel();
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) _handleDisconnected();
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefId, id);
      await prefs.setString(_kPrefName, name);

      state = state.copyWith(
        status: BleStatus.connected,
        connectedId: id,
        connectedName: name,
        rememberedName: name,
      );

      // Connected but silent: many watches only stream during a workout or
      // when broadcast is on. After 20 s offer the Health Connect route.
      _silentTimer = Timer(const Duration(seconds: 20), () {
        if (state.isConnected && state.bpm == null) {
          state = state.copyWith(
            fallbackHint: hintFor(name, manufacturer: manufacturer),
          );
        }
      });
    } catch (e) {
      _log.w('BLE connect failed', error: e);
      try {
        await device.disconnect();
      } catch (_) {}
      state = state.copyWith(
        status: BleStatus.idle,
        clearConnection: true,
        message: 'Could not connect to $name. Keep the watch close, make sure '
            'it is not connected to another app, and try again.',
      );
    }
  }

  /// Watches normally pair (bond) with their phone before they stream health
  /// data. This shows the system pairing prompt when the watch asks for it.
  Future<void> _ensureBonded(BluetoothDevice device) async {
    try {
      final current = await device.bondState.first;
      if (current == BluetoothBondState.bonded) return;
      await device.createBond();
      await device.bondState
          .firstWhere((b) =>
              b == BluetoothBondState.bonded || b == BluetoothBondState.none)
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      _log.w('BLE bonding skipped', error: e);
    }
  }

  /// Logs every service / characteristic and the Device Information strings so
  /// a watch that streams over a vendor protocol can be identified.
  Future<String?> _logDeviceProfile(
    BluetoothDevice device,
    List<BluetoothService> services,
  ) async {
    final lines = <String>[];
    String? manufacturer;
    for (final svc in services) {
      lines.add('service ${svc.uuid}');
      for (final c in svc.characteristics) {
        final p = c.properties;
        final props = [
          if (p.read) 'read',
          if (p.write) 'write',
          if (p.writeWithoutResponse) 'writeNoResp',
          if (p.notify) 'notify',
          if (p.indicate) 'indicate',
        ].join(',');
        lines.add('  char ${c.uuid} [$props]');
        if (svc.uuid == Guid('180A') && p.read) {
          try {
            final v = await c.read();
            final text = String.fromCharCodes(v.where((b) => b >= 32 && b < 127));
            lines.add('    = $text');
            if (c.uuid == Guid('2A29')) manufacturer = text;
          } catch (_) {}
        }
      }
    }
    _log.i('BLE profile for ${device.remoteId.str}: ${lines.join(' | ')}');
    return manufacturer;
  }

  Future<void> _subscribeBattery(List<BluetoothService> services) async {
    try {
      final svc = services.where((s) => s.uuid == kBatteryService).toList();
      if (svc.isEmpty) return;
      final ch = svc.first.characteristics
          .where((c) => c.uuid == kBatteryLevel)
          .toList();
      if (ch.isEmpty) return;
      final first = await ch.first.read();
      if (first.isNotEmpty) state = state.copyWith(batteryPct: first.first);
      await _battSub?.cancel();
      _battSub = ch.first.onValueReceived.listen((v) {
        if (v.isNotEmpty) state = state.copyWith(batteryPct: v.first);
      });
      await ch.first.setNotifyValue(true);
    } catch (_) {
      // Battery is optional.
    }
  }

  /// Reconnects to the device used last time (silent on failure).
  Future<void> reconnectRemembered() async {
    if (state.isConnected || state.status == BleStatus.connecting) return;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kPrefId);
    final name = prefs.getString(_kPrefName);
    if (id == null || name == null || !state.adapterOn) return;
    await connectById(id, name);
  }

  Future<void> disconnect({bool forget = false}) async {
    try {
      await _device?.disconnect();
    } catch (_) {}
    if (forget) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefId);
      await prefs.remove(_kPrefName);
    }
    _handleDisconnected();
    if (forget) state = const BleHeartRateState();
  }

  void _handleDisconnected() {
    _silentTimer?.cancel();
    _hrSub?.cancel();
    _battSub?.cancel();
    _connSub?.cancel();
    _hrSub = _battSub = _connSub = null;
    _device = null;
    state = state.copyWith(status: BleStatus.idle, clearConnection: true);
  }

  void _disposeAll() {
    _silentTimer?.cancel();
    _scanSub?.cancel();
    _adapterSub?.cancel();
    _connSub?.cancel();
    _hrSub?.cancel();
    _battSub?.cancel();
  }
}
