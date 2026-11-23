import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/models/api_response.dart';
import 'package:deliveazone_driver_app/services/api_service.dart';

class ParcelProvider with ChangeNotifier {
  List<Parcel> _assignedParcels = [];
  List<Parcel> _parcelHistory = [];
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  String? _error;
  Parcel? _selectedParcel;
  Map<int, List<Map<String, dynamic>>> _parcelTracking = {};
  Map<String, dynamic>? _statistics;
  String _statusFilter = 'all';
  DateTime? _dateFilter;

  List<Parcel> get assignedParcels => _assignedParcels;
  List<Parcel> get parcelHistory => _parcelHistory;
  Map<String, dynamic>? get statistics => _statistics;
  List<Parcel> get inProgressParcels => _assignedParcels
      .where((p) => p.status == 'picked_up' || p.status == 'in_transit')
      .toList();
  bool get isLoading => _isLoading;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;
  Parcel? get selectedParcel => _selectedParcel;
  Map<int, List<Map<String, dynamic>>> get parcelTracking => _parcelTracking;
  String get statusFilter => _statusFilter;
  DateTime? get dateFilter => _dateFilter;

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setDateFilter(DateTime? date) {
    _dateFilter = date;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = 'all';
    _dateFilter = null;
    notifyListeners();
  }

  Parcel? getParcelById(int id) {
    try {
      return _assignedParcels.firstWhere((p) => p.id == id);
    } catch (_) {
      try {
        return _parcelHistory.firstWhere((p) => p.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> loadStatistics({bool showLoading = true}) async {
    try {
      final api = ApiService();
      final result = await api.getStatistics();
      if (kDebugMode) {
        print('Statistics API result: ${result.data}');
      }
      if (result.success) {
        final serverStats =
            result.data['statistics'] ?? result.data['data'] ?? result.data;

        // Merge server stats with local ones, preferring local for today's counts if server is 0
        if (_statistics != null && _statistics!['calculated_locally'] == true) {
          _statistics = {
            ...(_statistics ?? {}),
            ...serverStats,
            // Keep local today/weekly if server shows 0 but we found items
            'today_deliveries':
                (serverStats['today_deliveries'] ?? 0) >
                    (_statistics!['today_deliveries'] ?? 0)
                ? serverStats['today_deliveries']
                : _statistics!['today_deliveries'],
            'assigned_today':
                (serverStats['assigned_today'] ?? 0) >
                    (_statistics!['assigned_today'] ?? 0)
                ? serverStats['assigned_today']
                : _statistics!['assigned_today'],
            'failed_today':
                (serverStats['failed_today'] ?? 0) >
                    (_statistics!['failed_today'] ?? 0)
                ? serverStats['failed_today']
                : _statistics!['failed_today'],
            'weekly_deliveries':
                (serverStats['weekly_deliveries'] ?? 0) >
                    (_statistics!['weekly_deliveries'] ?? 0)
                ? serverStats['weekly_deliveries']
                : _statistics!['weekly_deliveries'],
          };
        } else {
          _statistics = serverStats;
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load statistics: $e');
      }
    }
  }

  Future<void> loadAssignedParcels({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final api = ApiService();
      // Optional: Clear cache if we want to force fresh data logic,
      // or just trust the overwrite.
      // await _cacheParcels([]); // Uncomment if deep clean needed

      print('DEBUG: Fetching assigned parcels...');
      final result = await api.getAssignedParcels();
      print('DEBUG: API Response Success: ${result.success}');
      print('DEBUG: API Response Data: ${result.data}');

      if (result.success) {
        dynamic parcelsData;

        // Backend returns: {'success': true, 'orders': [...]}
        if (result.data is Map) {
          if (result.data.containsKey('orders')) {
            parcelsData = result.data['orders'];
          } else if (result.data.containsKey('parcels')) {
            parcelsData = result.data['parcels'];
          } else if (result.data.containsKey('data')) {
            parcelsData = result.data['data'];
          }
        } else if (result.data is List) {
          parcelsData = result.data;
        }

        print('DEBUG: Extracted parcelsData type: ${parcelsData.runtimeType}');

        if (parcelsData is List) {
          _assignedParcels = parcelsData.map((json) {
            try {
              return Parcel.fromJson(json);
            } catch (e) {
              print('DEBUG: Error parsing parcel JSON: $e');
              print('DEBUG: JSON was: $json');
              rethrow;
            }
          }).toList();
          print(
            'DEBUG: Successfully parsed ${_assignedParcels.length} parcels',
          );
          // Cache the data
          await _cacheParcels(_assignedParcels);
        } else if (parcelsData is Map && parcelsData.containsKey('data')) {
          // Handle pagination if assigned parcels ever becomes paginated
          final List<dynamic> list = parcelsData['data'];
          _assignedParcels = list.map((json) => Parcel.fromJson(json)).toList();
          print(
            'DEBUG: Successfully parsed ${_assignedParcels.length} parcels (paginated)',
          );
          await _cacheParcels(_assignedParcels);
        } else {
          print(
            'DEBUG: parcelsData is not a List or compatible Map. It is: $parcelsData',
          );
        }
      } else {
        _error = result.message;
        if (kDebugMode) print('DEBUG: API returned failure: ${_error}');
        await _loadCachedParcels();
      }
    } catch (e, stack) {
      _error = 'Failed to load parcels: $e';
      print('DEBUG: Exception in loadAssignedParcels: $e');
      print(stack);
      await _loadCachedParcels();
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      _calculateLocalStats();
      notifyListeners();
    }
  }

  Future<ApiResponse> scanParcel(String qrCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.scanParcel(qrCode);

      if (result.success) {
        final parcelData = result.data['parcel'] ?? result.data['order'];
        final updatedParcel = Parcel.fromJson(parcelData);

        // Update local list
        final index = _assignedParcels.indexWhere(
          (p) => p.id == updatedParcel.id,
        );
        if (index != -1) {
          _assignedParcels[index] = updatedParcel;
        } else {
          _assignedParcels.insert(0, updatedParcel);
        }

        await _cacheParcels(_assignedParcels);
        notifyListeners();
      } else {
        _error = result.message;
      }
      return result;
    } catch (e) {
      _error = 'Scan failed: $e';
      return ApiResponse(success: false, message: _error!);
    } finally {
      _isLoading = false;
      _calculateLocalStats();
      notifyListeners();
    }
  }

  Future<ApiResponse> manualPickup(int parcelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.manualPickup(parcelId);

      if (result.success) {
        final parcelData = result.data['parcel'] ?? result.data['order'];
        final updatedParcel = Parcel.fromJson(parcelData);

        // Update local list
        final index = _assignedParcels.indexWhere(
          (p) => p.id == updatedParcel.id,
        );
        if (index != -1) {
          _assignedParcels[index] = updatedParcel;
        }

        await _cacheParcels(_assignedParcels);
        notifyListeners();
      } else {
        _error = result.message;
      }
      return result;
    } catch (e) {
      _error = 'Manual pickup failed: $e';
      return ApiResponse(success: false, message: _error!);
    } finally {
      _isLoading = false;
      _calculateLocalStats();
      notifyListeners();
    }
  }

  Future<void> loadParcelHistory({
    int page = 1,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _isLoadingHistory = true;
      _error = null;
      notifyListeners();
    }

    try {
      final api = ApiService();
      final result = await api.getParcelHistory(page: page);

      if (kDebugMode) {
        print('History API Status: ${result.success}, Data: ${result.data}');
      }

      if (result.success) {
        dynamic parcelsData;

        // Debugging structure
        if (kDebugMode) {
          print(
            'History API Data Keys: ${result.data is Map ? result.data.keys.toList() : 'Not a Map'}',
          );
        }

        if (result.data is Map) {
          if (result.data.containsKey('orders')) {
            parcelsData = result.data['orders'];
          } else if (result.data.containsKey('parcels')) {
            parcelsData = result.data['parcels'];
          } else if (result.data.containsKey('data')) {
            parcelsData = result.data['data'];
          } else {
            // If none of the keys exist, maybe the Map itself is the list of data wrapped in Laravel pagination?
            parcelsData = result.data;
          }
        } else if (result.data is List) {
          parcelsData = result.data;
        }

        List<Parcel> loadedParcels = [];

        if (parcelsData is List) {
          loadedParcels = parcelsData
              .map((json) {
                // Ensure json is Map<String, dynamic>
                if (json is Map)
                  return Parcel.fromJson(Map<String, dynamic>.from(json));
                return null;
              })
              .whereType<Parcel>()
              .toList();
        } else if (parcelsData is Map && parcelsData.containsKey('data')) {
          final List<dynamic> list = parcelsData['data'];
          loadedParcels = list
              .map((json) {
                if (json is Map)
                  return Parcel.fromJson(Map<String, dynamic>.from(json));
                return null;
              })
              .whereType<Parcel>()
              .toList();
        }

        if (page == 1) {
          _parcelHistory = loadedParcels;
          _cacheHistory(_parcelHistory);
        } else {
          _parcelHistory.addAll(loadedParcels);
        }
      } else {
        _error = result.message;
        if (_parcelHistory.isEmpty) {
          await _loadCachedHistory();
        }
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('Error loading history: $e');
        print(stack);
      }
      _error = 'Failed to load history';
      if (_parcelHistory.isEmpty) {
        await _loadCachedHistory();
      }
    } finally {
      if (showLoading) {
        _isLoadingHistory = false;
      }
      _calculateLocalStats();
      notifyListeners();
    }
  }

  void _calculateLocalStats() {
    final now = DateTime.now();
    int todayDeliveries = 0;
    int weeklyDeliveries = 0;
    double monthlyEarnings = 0;
    int failedToday = 0;

    // Total assigned today (active + completed)
    int totalAssignedToday = 0;

    final weekAgo = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    // 1. Process History (Delivered, Failed, etc)
    for (var parcel in _parcelHistory) {
      final date = parcel.status == 'delivered' && parcel.deliveredAt != null
          ? parcel.deliveredAt!
          : parcel.updatedAt;
      final assignedDate = parcel.assignedAt ?? parcel.createdAt;

      // Check if assigned today (even if completed)
      if (assignedDate != null &&
          assignedDate.day == now.day &&
          assignedDate.month == now.month &&
          assignedDate.year == now.year) {
        totalAssignedToday++;
      }

      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        if (parcel.status == 'delivered') {
          todayDeliveries++;
        } else if (parcel.status == 'failed' ||
            parcel.status == 'returned' ||
            parcel.status == 'rescheduled') {
          failedToday++;
        }
      }

      if (date.isAfter(weekAgo) && parcel.status == 'delivered') {
        weeklyDeliveries++;
      }

      if (parcel.status == 'delivered' && date.isAfter(monthStart)) {
        monthlyEarnings += (parcel.amount ?? 0);
      }
    }

    // 2. Process Assigned (Active parcels)
    for (var parcel in _assignedParcels) {
      if (parcel.status == 'assigned') {
        final assignedDate = parcel.assignedAt;
        final updatedDate = parcel.updatedAt;

        bool isToday = false;
        if (assignedDate != null &&
            assignedDate.day == now.day &&
            assignedDate.month == now.month &&
            assignedDate.year == now.year) {
          isToday = true;
        } else if (updatedDate.day == now.day &&
            updatedDate.month == now.month &&
            updatedDate.year == now.year) {
          // If updated today and is assigned, count it as today's work
          isToday = true;
        }

        if (isToday) {
          totalAssignedToday++;
        }
      }
    }

    // Always update statistics if we have local data, using the best available keys
    _statistics = {
      ...(_statistics ?? {}),
      'today_deliveries': todayDeliveries,
      'delivered_today': todayDeliveries,
      'assigned_today': totalAssignedToday,
      'failed_today': failedToday,
      'pending_count': _assignedParcels.length,
      'weekly_deliveries': weeklyDeliveries,
      'monthly_earnings': monthlyEarnings > 0
          ? monthlyEarnings
          : (_statistics?['monthly_earnings'] ?? 0),
      'last_updated': now.toIso8601String(),
      'calculated_locally':
          true, // Prevent server overwrite if server has stale 0 values
    };

    if (kDebugMode && todayDeliveries > 0) {
      print(
        'Local Stats: DeliveredToday=$todayDeliveries, AssignedToday=$totalAssignedToday, FailedToday=$failedToday, Pending=${_assignedParcels.length}',
      );
    }
  }

  Future<void> selectParcel(Parcel parcel) async {
    _selectedParcel = parcel;
    notifyListeners();
  }

  Future<bool> updateParcelStatus(
    int parcelId,
    String status, {
    String? remarks,
    String? proofImage,
    String? otp,
    String? acceptedBy,
    String? receiverName,
    String? signature,
    double? lat,
    double? lng,
    String? paymentMethod,
    String? rescheduledDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      print('Calling API to update parcel $parcelId to status: $status');

      final result = await api.updateParcelStatus(
        parcelId,
        status,
        remarks: remarks,
        proofImage: proofImage,
        otp: otp,
        acceptedBy: acceptedBy,
        receiverName: receiverName,
        signature: signature,
        lat: lat,
        lng: lng,
        paymentMethod: paymentMethod,
        rescheduledDate: rescheduledDate,
      );

      print('API Result: success=${result.success}, message=${result.message}');

      if (result.success) {
        // Update local parcel
        final index = _assignedParcels.indexWhere((p) => p.id == parcelId);
        if (index != -1) {
          final updatedParcel = _assignedParcels[index].copyWith(
            status: status == 'rescheduled' ? 'failed' : status,
            remarks: remarks,
            isRescheduled: status == 'rescheduled'
                ? true
                : _assignedParcels[index].isRescheduled,
            deliveredAt: status == 'delivered' ? DateTime.now() : null,
            pickedUpAt: status == 'picked_up' ? DateTime.now() : null,
            updatedAt: DateTime.now(), // Local immediate update
          );

          _assignedParcels[index] = updatedParcel;

          // If delivered/failed/returned/rescheduled, move to history
          if (status == 'delivered' ||
              status == 'failed' ||
              status == 'returned' ||
              status == 'rescheduled') {
            _parcelHistory.insert(0, updatedParcel);
            _assignedParcels.removeAt(index);
          }
        }

        // Update cache
        await _cacheParcels(_assignedParcels);
        await _cacheHistory(_parcelHistory);

        // Reload parcels to get updated data
        await loadAssignedParcels();
        return true;
      } else {
        _error = result.message;
        print('API Error: ${result.message}');
        return false;
      }
    } catch (e) {
      print('Exception in updateParcelStatus: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      _calculateLocalStats();
      notifyListeners();
    }
  }

  Future<void> loadParcelTracking(int parcelId) async {
    try {
      final api = ApiService();
      final result = await api.getParcelTracking(parcelId);

      if (result.success) {
        _parcelTracking[parcelId] = List<Map<String, dynamic>>.from(
          result.data['tracking'] ?? [],
        );
        notifyListeners();
      }
    } catch (e) {
      print('Failed to load tracking: $e');
    }
  }

  Future<void> uploadProofImage(int parcelId, String imagePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.uploadProofImage(parcelId, imagePath);

      if (result.success) {
        // Update parcel with proof image
        final index = _assignedParcels.indexWhere((p) => p.id == parcelId);
        if (index != -1) {
          _assignedParcels[index] = _assignedParcels[index].copyWith(
            proofImage: result.data['proof_image'],
          );
        }
      } else {
        _error = result.message;
      }
    } catch (e) {
      _error = 'Failed to upload proof image';
    } finally {
      _isLoading = false;
      _calculateLocalStats();
      notifyListeners();
    }
  }

  Future<void> _cacheParcels(List<Parcel> parcels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final parcelsJson = parcels.map((p) => p.toJson()).toList();
      await prefs.setString('cached_parcels', json.encode(parcelsJson));
    } catch (e) {
      if (kDebugMode) {
        print('Failed to cache parcels: $e');
      }
    }
  }

  Future<void> _cacheHistory(List<Parcel> parcels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final parcelsJson = parcels.map((p) => p.toJson()).toList();
      await prefs.setString('cached_history', json.encode(parcelsJson));
    } catch (e) {
      if (kDebugMode) {
        print('Failed to cache history: $e');
      }
    }
  }

  Future<void> _loadCachedParcels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_parcels');

      if (cachedJson != null) {
        final List<dynamic> data = json.decode(cachedJson);
        _assignedParcels = data.map((json) => Parcel.fromJson(json)).toList();
      }

      // Also load history
      await _loadCachedHistory();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load cached parcels: $e');
      }
    }
  }

  Future<void> _loadCachedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_history');

      if (cachedJson != null) {
        final List<dynamic> data = json.decode(cachedJson);
        _parcelHistory = data.map((json) => Parcel.fromJson(json)).toList();
        print(
          'DEBUG: Loaded ${_parcelHistory.length} history items from cache',
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load cached history: $e');
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    final today = DateTime.now();
    final monthStart = DateTime(today.year, today.month, 1);

    final thisMonthDeliveries = _parcelHistory
        .where(
          (p) =>
              p.deliveredAt != null &&
              p.deliveredAt!.isAfter(monthStart) &&
              p.status == 'delivered',
        )
        .length;

    final thisMonthEarnings = _parcelHistory
        .where(
          (p) =>
              p.deliveredAt != null &&
              p.deliveredAt!.isAfter(monthStart) &&
              p.status == 'delivered',
        )
        .fold(0.0, (sum, p) => sum + (p.amount ?? 0));

    final successRate = _parcelHistory.isNotEmpty
        ? (_parcelHistory.where((p) => p.status == 'delivered').length /
                  _parcelHistory.length) *
              100
        : 0;

    return {
      'total_deliveries': _parcelHistory.length,
      'this_month_deliveries': thisMonthDeliveries,
      'this_month_earnings': thisMonthEarnings,
      'success_rate': successRate,
      'avg_delivery_time': _calculateAverageDeliveryTime(),
    };
  }

  double _calculateAverageDeliveryTime() {
    final deliveredParcels = _parcelHistory.where(
      (p) =>
          p.status == 'delivered' &&
          p.pickedUpAt != null &&
          p.deliveredAt != null,
    );

    if (deliveredParcels.isEmpty) return 0.0;

    final totalMinutes = deliveredParcels.fold(0.0, (sum, p) {
      final duration = p.deliveredAt!.difference(p.pickedUpAt!);
      return sum + duration.inMinutes;
    });

    return totalMinutes / deliveredParcels.length;
  }
}
