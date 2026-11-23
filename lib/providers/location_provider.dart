import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' hide Constraints;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:deliveazone_driver_app/services/api_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String? _currentAddress;
  bool _isTracking = false;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<Position>? _positionStream;
  Timer? _uploadTimer;
  Timer? _backgroundCheckTimer;

  // For background tracking
  static const String _locationTaskName = "locationTrackingTask";
  static const Duration _locationUpdateInterval = Duration(seconds: 15);
  static const Duration _backgroundCheckInterval = Duration(seconds: 30);

  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  String? get error => _error;

  LocationProvider() {
    _initBackgroundTracking();
  }

  double? get currentHeading => _currentPosition?.heading;

  Future<void> _initBackgroundTracking() async {
    // Initialize workmanager for background tracking
    if (!kIsWeb) {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
    }
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );

        // Update location to MySQL
        final api = ApiService();
        await api.updateLocation(position.latitude, position.longitude);

        return Future.value(true);
        } catch (e) {
          if (kDebugMode) print('Background location fetch failed: $e');
          return Future.value(false);
        }
    });
  }

  Future<bool> _checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'Location services are disabled. Please enable GPS.';
      return false;
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _error = 'Location permissions are denied. Please enable in settings.';
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _error = 'Location permissions are permanently denied. Please enable in app settings.';
      return false;
    }

    return true;
  }

  Future<void> getCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 10),
      );

      _currentPosition = position;
      await _getAddressFromLatLng(position.latitude, position.longitude);

      // Update to server
      await _uploadLocationToServer(position);

    } catch (e) {
      _error = 'Failed to get location: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isNotEmpty) {
        final place = places.first;
        _currentAddress = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'
            .replaceAll(RegExp(r'^,\s*|\s*,\s*$'), '');
      }
    } catch (e) {
      _currentAddress = 'Unable to get address';
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    // Eagerly update UI to avoid visual delay
    _isTracking = true;
    notifyListeners();

    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      _isTracking = false;
      notifyListeners();
      return;
    }

    // Start periodic background checks
    _startBackgroundChecks();

    // Start listening to location updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, // Update continually for smooth "live" feel
        timeLimit: Duration(seconds: 30),
      ),
    ).listen((position) {
      _currentPosition = position;
      _uploadLocationToServer(position);
      _getAddressFromLatLng(position.latitude, position.longitude);
      notifyListeners();
    });

    // Also upload location every 15 seconds for reliability
    _uploadTimer = Timer.periodic(_locationUpdateInterval, (_) async {
      if (_currentPosition != null) {
        await _uploadLocationToServer(_currentPosition!);
      } else {
        // Try to get current position if null
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
          );
          _currentPosition = position;
          await _uploadLocationToServer(position);
        } catch (e) {
      // Don't throw error for location updates - just log in debug mode
      if (kDebugMode) print('Location update failed: $e');
        }
      }
    });

    // Register background task for iOS/android
    await _registerBackgroundTask();

    // Save tracking state
    await _saveTrackingState(true);
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    notifyListeners(); // Eager update

    await _positionStream?.cancel();
    _positionStream = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _backgroundCheckTimer?.cancel();
    _backgroundCheckTimer = null;

    // Cancel background task
    if (!kIsWeb) {
      await Workmanager().cancelByUniqueName(_locationTaskName);
    }

    // Save tracking state
    await _saveTrackingState(false);
  }

  Future<void> _startBackgroundChecks() async {
    _backgroundCheckTimer = Timer.periodic(_backgroundCheckInterval, (_) async {
      // Check if we're still tracking and location services are enabled
      if (_isTracking) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _error = 'Location services disabled';
          notifyListeners();
        }
      }
    });
  }

  Future<void> _registerBackgroundTask() async {
    if (kIsWeb) return;

    // For Android
    await Workmanager().registerPeriodicTask(
      _locationTaskName,
      _locationTaskName,
      frequency: _locationUpdateInterval,
      initialDelay: Duration(seconds: 10),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  Future<void> _saveTrackingState(bool isTracking) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tracking', isTracking);
  }

  Future<bool> loadTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_tracking') ?? false;
  }

  Future<void> _uploadLocationToServer(Position position) async {
    try {
      final api = ApiService();
      final result = await api.updateLocation(
        position.latitude,
        position.longitude,
      );

      if (!result.success && kDebugMode) {
        print('Location upload failed: ${result.message}');
      }
    } catch (e) {
      if (kDebugMode) print('Location upload error: $e');
    }
  }

  Future<void> updateLocationManually(double lat, double lng) async {
    _isLoading = true;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.updateLocation(lat, lng);

      if (result.success) {
        _currentPosition = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        await _getAddressFromLatLng(lat, lng);

        // Update tracking if active
        if (_isTracking) {
          await _uploadLocationToServer(_currentPosition!);
        }
      }
    } catch (e) {
      _error = 'Failed to update location';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getRouteInfo(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) async {
    try {
      // In a real app, you would use Google Maps Directions API
      // For now, return mock data
      final distance = Geolocator.distanceBetween(
        startLat,
        startLng,
        endLat,
        endLng,
      ) / 1000; // Convert to km

      final estimatedTime = (distance / 40) * 60; // Assuming 40 km/h average speed

      return {
        'distance_km': distance.toStringAsFixed(2),
        'estimated_minutes': estimatedTime.toStringAsFixed(0),
        'route': 'Direct route',
      };
    } catch (e) {
      return {
        'distance_km': '0',
        'estimated_minutes': '0',
        'route': 'Unable to calculate route',
      };
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _uploadTimer?.cancel();
    _backgroundCheckTimer?.cancel();
    super.dispose();
  }
}