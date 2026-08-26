import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device_reading.dart';
import '../models/owned_device.dart';
import '../services/database_service.dart';

class WeatherProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<OwnedDevice> _devices = [];
  OwnedDevice? _selectedDevice;
  List<DeviceReading> _readings = [];
  DeviceReading? _latestReading;
  DeviceReading? _forecastReading;

  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUid;

  StreamSubscription<List<OwnedDevice>>? _devicesSub;
  StreamSubscription<List<DeviceReading>>? _readingsSub;

  List<OwnedDevice> get devices => _devices;
  OwnedDevice? get selectedDevice => _selectedDevice;
  List<DeviceReading> get readings => _readings;
  DeviceReading? get latestReading => _latestReading;
  DeviceReading? get forecastReading => _forecastReading;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void initForUser(String? uid) {
    if (_currentUid == uid) return;
    _currentUid = uid;
    _devicesSub?.cancel();
    _readingsSub?.cancel();
    _devices = [];
    _selectedDevice = null;
    _readings = [];
    _latestReading = null;
    _forecastReading = null;

    if (uid != null && uid.isNotEmpty) {
      _loadDevices(uid);
    } else {
      notifyListeners();
    }
  }

  void _loadDevices(String uid) {
    _isLoading = true;
    notifyListeners();

    _devicesSub?.cancel();
    _devicesSub = _dbService.streamOwnedDevices(uid).listen((devs) {
      _devices = devs;
      _isLoading = false;

      if (_devices.isEmpty) {
        _selectedDevice = null;
        _readings = [];
        _latestReading = null;
        _forecastReading = null;
      } else {
        if (_selectedDevice == null || !_devices.any((d) => d.mac == _selectedDevice!.mac)) {
          _selectedDevice = _devices.first;
        }
        _subscribeToDevice(_selectedDevice!.mac);
      }
      notifyListeners();
    }, onError: (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  void selectDevice(OwnedDevice device) {
    if (_selectedDevice?.mac == device.mac) return;
    _selectedDevice = device;
    _subscribeToDevice(device.mac);
    notifyListeners();
  }

  void _subscribeToDevice(String mac) {
    _readingsSub?.cancel();
    _readingsSub = _dbService.streamDeviceReadings(mac).listen((list) {
      _readings = list;
      _processReadings(list);
      notifyListeners();
    }, onError: (e) {
      _errorMessage = e.toString();
      notifyListeners();
    });
  }

  void _processReadings(List<DeviceReading> list) {
    if (list.isEmpty) {
      _latestReading = null;
      _forecastReading = null;
      return;
    }

    _latestReading = list.last;

    DeviceReading? fNode;
    int fTs = 0;
    for (final r in list) {
      if (r.forecast != null && r.forecast!.isNotEmpty && (r.ts ?? 0) >= fTs) {
        fNode = r;
        fTs = r.ts ?? 0;
      }
    }
    _forecastReading = fNode;
  }

  Future<void> refresh() async {
    if (_currentUid == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final devs = await _dbService.getOwnedDevices(_currentUid!);
      _devices = devs;
      if (_devices.isNotEmpty) {
        if (_selectedDevice == null || !_devices.any((d) => d.mac == _selectedDevice!.mac)) {
          _selectedDevice = _devices.first;
        }
        final readings = await _dbService.getDeviceReadings(_selectedDevice!.mac);
        _readings = readings;
        _processReadings(readings);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _readingsSub?.cancel();
    super.dispose();
  }
}
