import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:deliveazone_driver_app/providers/location_provider.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/utils/helpers.dart';

class MapTrackingScreen extends StatefulWidget {
  final Parcel parcel;
  const MapTrackingScreen({super.key, required this.parcel});

  @override
  State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> {
  final MapController _mapController = MapController();

  LatLng? _driverPos;
  double _heading = 0;

  bool _following = true;
  bool _userInteracting = false;

  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  
  // Track status to detect changes for re-routing
  String? _currentStatus;
  bool _mapReady = false;

  late LocationProvider _provider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<LocationProvider>();
      _provider.addListener(_onLocationUpdate);
      _provider.startTracking();
      
      // Initialize status
      _currentStatus = widget.parcel.status;
    });

    // Fallback test pos
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _driverPos ??= LatLng(24.8607, 67.0011);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_onLocationUpdate);
    _provider.stopTracking();
    super.dispose();
  }
  
  // ================= HELPERS =================
  
  void _fitBounds(LatLng start, LatLng end) {
    if (!_mapReady) return;
    final bounds = LatLngBounds.fromPoints([start, end]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50), 
      ),
    );
  }

  // ================= ROUTE API =================

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    if (_loadingRoute) return;

    try {
      _loadingRoute = true;
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson';

      final res = await http.get(Uri.parse(url));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
           final coords = data['routes'][0]['geometry']['coordinates'];
           _routePoints = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
           
           if (mounted) _fitBounds(start, end);
        }
      }
    } catch (e) {
      debugPrint('Route error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingRoute = false;
        });
      }
    }
  }

  // ================= LOCATION UPDATE =================

  void _onLocationUpdate() {
    if (!mounted || _provider.currentPosition == null) return;
    
    setState(() {
      _driverPos = LatLng(
        _provider.currentPosition!.latitude,
        _provider.currentPosition!.longitude,
      );
      _heading = _provider.currentHeading ?? 0;
    });

    _refreshRoute();
  }

  void _refreshRoute() {
    if (!mounted || _driverPos == null) return;

    final parcelProvider = context.read<ParcelProvider>();
    final currentParcel = parcelProvider.assignedParcels.followedBy(parcelProvider.parcelHistory)
        .firstWhere((p) => p.id == widget.parcel.id, orElse: () => widget.parcel);

    bool statusChanged = _currentStatus != currentParcel.status;
    if (statusChanged) {
      _currentStatus = currentParcel.status;
      _routePoints.clear();
      _following = true;
    }

    final bool isPickupPhase = ['assigned', 'pending'].contains(currentParcel.status);
    LatLng? dest;

    if (currentParcel.deliveryLatitude != null && currentParcel.deliveryLongitude != null) {
      dest = LatLng(currentParcel.deliveryLatitude!, currentParcel.deliveryLongitude!);
    } else if (currentParcel.latitude != null && currentParcel.longitude != null) {
      dest = LatLng(currentParcel.latitude!, currentParcel.longitude!);
    }

    // Always try to fetch route if we have a destination but no points, or if status just changed
    if (dest != null && (_routePoints.isEmpty || statusChanged) && !_loadingRoute) {
      _fetchRoute(_driverPos!, dest);
    }

    // Update map camera if following
    if (_mapReady && _following && !_userInteracting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady || _driverPos == null) return;
        try {
          _mapController.move(_driverPos!, _mapController.camera.zoom);
        } catch (e) {
          debugPrint('Map move postponed: $e');
        }
      });
    }
  }

  Future<void> _launchExternalMaps(LatLng? dest) async {
    if (dest == null) return;
    final url = 'https://www.google.com/maps/search/?api=1&query=${dest.latitude},${dest.longitude}';
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final parcelProvider = Provider.of<ParcelProvider>(context);
    final currentParcel = parcelProvider.assignedParcels.followedBy(parcelProvider.parcelHistory)
        .firstWhere((p) => p.id == widget.parcel.id, orElse: () => widget.parcel);

    final bool isPickupPhase = ['assigned', 'pending'].contains(currentParcel.status);
    
    double? targetLat = currentParcel.deliveryLatitude ?? currentParcel.latitude;
    double? targetLng = currentParcel.deliveryLongitude ?? currentParcel.longitude;
    String targetLabel = 'Delivery Point';
    IconData targetIcon = Icons.home;
    Color targetColor = const Color(0xFFAE2E2F);
    
    final dest = (targetLat != null && targetLng != null) ? LatLng(targetLat, targetLng) : null;
    
    // Check if status changed externally (e.g. via button press) and trigger route refresh
    if (_currentStatus != currentParcel.status) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRoute());
    }

    if (_driverPos == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (dest == null) {
       return Scaffold(
        appBar: AppBar(title: const Text('Map Tracking')),
        body: const Center(child: Text('Location details unavailable')),
       );
    }

    return Scaffold(
      body: Stack(
        children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _driverPos!,
                  initialZoom: 15,
                  onMapReady: () {
                    if (mounted) setState(() => _mapReady = true);
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) {
                      _userInteracting = true;
                      _following = false;
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.deliveazone.driver',
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5,
                          color: const Color(0xFF042840),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        key: const ValueKey('destination_marker'),
                        point: dest,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            border: Border.all(color: targetColor, width: 2),
                          ),
                          child: Icon(targetIcon, color: targetColor, size: 30),
                        ),
                      ),
                      Marker(
                        key: const ValueKey('driver_marker'),
                        point: _driverPos!,
                        width: 40,
                        height: 40,
                        child: Transform.rotate(
                          angle: _heading * math.pi / 180,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.directions_car, size: 28, color: Color(0xFF042840)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // LIVE Badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFFAE2E2F), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('LIVE TRACKING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
            ),
          ),

          // TOP CONTROLS
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'back_map',
              backgroundColor: Colors.white,
              child: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: FloatingActionButton.small(
               heroTag: 'recenter_map',
               backgroundColor: Colors.white,
               child: const Icon(Icons.gps_fixed, color: Colors.black),
               onPressed: () {
                 _following = true;
                 _userInteracting = false;
                 if (_mapReady && _driverPos != null) {
                   _mapController.move(_driverPos!, 16);
                 }
               },
            ),
          ),

          // DRAGGABLE SHEET
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.28,
            maxChildSize: 0.75,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40, height: 5,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.5)),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: targetColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: targetColor.withOpacity(0.2)),
                            ),
                            child: Icon(targetIcon, color: targetColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(targetLabel.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey.shade500)),
                                    const Spacer(),
                                    if (dest != null && _driverPos != null)
                                      Text(
                                        '${(const Distance().as(LengthUnit.Meter, _driverPos!, dest) / 1000).toStringAsFixed(1)} km',
                                        style: TextStyle(color: const Color(0xFF042840), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isPickupPhase ? currentParcel.senderName : currentParcel.receiverName,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isPickupPhase ? currentParcel.senderAddress : currentParcel.receiverAddress,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24, thickness: 0.5, indent: 20, endIndent: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _ActionButton(
                            icon: Icons.navigation_rounded, 
                            label: 'Navigate', 
                            color: const Color(0xFF042840), 
                            onTap: () => _launchExternalMaps(dest),
                          ),
                          const SizedBox(width: 10),
                          _ActionButton(
                            icon: Icons.call_rounded, 
                            label: 'Call', 
                            color: const Color(0xFF042840), 
                            onTap: () => Helpers.launchPhone(isPickupPhase ? currentParcel.senderPhone : currentParcel.receiverPhone),
                          ),
                          const SizedBox(width: 10),
                          _ActionButton(
                            icon: Icons.info_outline_rounded, 
                            label: 'Details', 
                            color: const Color(0xFF042840), 
                            onTap: () => Navigator.pushNamed(context, '/parcel-detail', arguments: currentParcel),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildStatusButtons(context, currentParcel),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButtons(BuildContext context, Parcel parcel) {
    if (parcel.status == 'assigned') {
      return _WideButton(
          label: 'SCAN TO PICKUP',
          color: const Color(0xFF042840),
          icon: Icons.qr_code_scanner,
          onTap: () => Navigator.pushNamed(context, '/scan'));
    } else if (parcel.status == 'picked_up') {
      return _WideButton(label: 'START DELIVERY', color: const Color(0xFF042840), onTap: () => _handleStatusAction(parcel, 'in_transit'));
    } else if (parcel.status == 'in_transit') {
      return Column(
        children: [
          _WideButton(label: 'DELIVERED', color: const Color(0xFF4CAF50), icon: Icons.check_circle, onTap: () => Navigator.pushNamed(context, '/pod-screen', arguments: parcel)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SmallButton(label: 'RESCHEDULED', color: const Color(0xFFFFA000), onTap: () => _showUpdateModal(parcel, 'rescheduled'))),
              const SizedBox(width: 8),
              Expanded(child: _SmallButton(label: 'CANCEL ORDER', color: const Color(0xFFAE2E2F), onTap: () => _showUpdateModal(parcel, 'failed'))),
            ],
          ),
        ],
      );
    } else {
      return _WideButton(label: 'BACK TO HOME', color: Colors.grey, onTap: () => Navigator.pop(context));
    }
  }

  void _handleStatusAction(Parcel parcel, String status) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await Provider.of<ParcelProvider>(context, listen: false).updateParcelStatus(parcel.id, status);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFAE2E2F)));
      }
    }
  }

  void _showUpdateModal(Parcel parcel, String status) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeliveryUpdateSheet(
        parcel: parcel, 
        targetStatus: status,
        onUpdate: (remarks, proofPath, rescheduledDate) async {
           Navigator.pop(ctx);
           showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
           try {
             await Provider.of<ParcelProvider>(context, listen: false).updateParcelStatus(parcel.id, status, remarks: remarks, proofImage: proofPath, rescheduledDate: rescheduledDate);
             if (mounted) {
               Navigator.pop(context);
               if (['delivered', 'failed', 'returned', 'rescheduled'].contains(status)) Navigator.pop(context);
             }
           } catch (e) {
             if (mounted) {
               Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFAE2E2F)));
             }
           }
        },
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  const _WideButton({required this.label, required this.color, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: icon != null ? Icon(icon, size: 20, color: Colors.white) : const SizedBox.shrink(),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: color.withOpacity(0.05),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
    );
  }
}

class _DeliveryUpdateSheet extends StatefulWidget {
  final Parcel parcel;
  final String targetStatus;
  final Function(String?, String?, String?) onUpdate;
  const _DeliveryUpdateSheet({required this.parcel, required this.targetStatus, required this.onUpdate});
  @override
  State<_DeliveryUpdateSheet> createState() => _DeliveryUpdateSheetState();
}

class _DeliveryUpdateSheetState extends State<_DeliveryUpdateSheet> {
  final _remarksController = TextEditingController();
  DateTime? _rescheduledDate;
  
  @override
  Widget build(BuildContext context) {
    final isFailed = widget.targetStatus == 'failed';
    final isRescheduled = widget.targetStatus == 'rescheduled';
    
    String title = 'UPDATE STATUS';
    Color btnColor = const Color(0xFF042840);
    
    if (isFailed) {
      title = 'CANCEL ORDER';
      btnColor = const Color(0xFFAE2E2F);
    } else if (isRescheduled) {
      title = 'RESCHEDULE ORDER';
      btnColor = const Color(0xFFFFA000);
    }

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF042840))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _remarksController, 
            decoration: InputDecoration(
              hintText: 'Add remarks/notes...', 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
              filled: true, 
              fillColor: Colors.white
            ), 
            maxLines: 3
          ),
          if (isRescheduled) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  setState(() => _rescheduledDate = date);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF042840)),
                    const SizedBox(width: 12),
                    Text(
                      _rescheduledDate == null ? 'Select Reschedule Date' : '${_rescheduledDate!.year}-${_rescheduledDate!.month.toString().padLeft(2, '0')}-${_rescheduledDate!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _rescheduledDate == null ? Colors.grey.shade600 : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, 
            child: ElevatedButton(
              onPressed: () {
                if (_remarksController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remarks are required')));
                  return;
                }
                  String? dateStr = _rescheduledDate != null ? '${_rescheduledDate!.year}-${_rescheduledDate!.month.toString().padLeft(2, '0')}-${_rescheduledDate!.day.toString().padLeft(2, '0')}' : null;
                  widget.onUpdate(_remarksController.text, null, dateStr);
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor, 
                padding: const EdgeInsets.symmetric(vertical: 16), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ), 
              child: const Text('SUBMIT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))
            )
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Slate 100
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)), // Slate 200
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(color: const Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
