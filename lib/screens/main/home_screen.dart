import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/providers/auth_provider.dart';
import 'package:deliveazone_driver_app/providers/location_provider.dart';
import 'package:deliveazone_driver_app/providers/notification_provider.dart'; // Added import for badge functionality
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/widgets/parcel_card.dart';
import 'package:deliveazone_driver_app/widgets/empty_state.dart';
import 'package:deliveazone_driver_app/widgets/loading_indicator.dart';

// Screens for Navigation
import 'package:deliveazone_driver_app/screens/main/parcels_screen.dart';
import 'package:deliveazone_driver_app/screens/main/history_screen.dart';
import 'package:deliveazone_driver_app/screens/main/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _checkLocationTracking();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadData(isAutoRefresh: true);
    });
  }

  Future<void> _loadData({bool isAutoRefresh = false}) async {
    if (!mounted) return;

    final parcelProvider = Provider.of<ParcelProvider>(context, listen: false);
    await Future.wait([
      parcelProvider.loadAssignedParcels(showLoading: !isAutoRefresh),
      parcelProvider.loadParcelHistory(showLoading: !isAutoRefresh),
      parcelProvider.loadStatistics(showLoading: !isAutoRefresh),
      Provider.of<AuthProvider>(context, listen: false).refreshUserData(showLoading: !isAutoRefresh),
      Provider.of<NotificationProvider>(context, listen: false).loadNotifications(showLoading: !isAutoRefresh),
    ]);
  }

  Future<void> _checkLocationTracking() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final wasTracking = await locationProvider.loadTrackingState();

    if (wasTracking) {
      await locationProvider.startTracking();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only show Home AppBar when on Dashboard (index 0)
    // Other screens (Parcels, History, Profile) likely have their own AppBars.
    final showAppBar = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: showAppBar ? _buildDashboardAppBar() : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardBody(),
          const ParcelsScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF042840),
          unselectedItemColor: const Color(0xFF042840).withOpacity(0.4),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping),
              label: 'Deliveries',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildDashboardAppBar() {
    final locationProvider = Provider.of<LocationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return AppBar(
      title: Image.asset('assets/logo.png', height: 32),
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF042840),
      automaticallyImplyLeading: false, // Hide back button if any
      actions: [
        // Notification Icon with Badge
        Consumer<NotificationProvider>(
          builder: (context, notifProvider, child) {
            return Stack(
              children: [
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, '/notifications'),
                  icon: const Icon(Icons.notifications_outlined, color: Color(0xFF042840)),
                ),
                if (notifProvider.unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFAE2E2F),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${notifProvider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        
        // Location Status
        IconButton(
          onPressed: () {
            if (locationProvider.isTracking) {
              locationProvider.stopTracking();
            } else {
              locationProvider.startTracking();
            }
          },
          icon: Icon(
            locationProvider.isTracking ? Icons.location_on : Icons.location_off_outlined,
            color: locationProvider.isTracking ? const Color(0xFFAE2E2F) : const Color(0xFF042840).withOpacity(0.3),
          ),
          tooltip: locationProvider.isTracking ? 'Tracking Active' : 'Tracking Inactive',
        ),
        // Settings / Profile Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle_outlined, color: Color(0xFF042840)),
          onSelected: (value) {
            if (value == 'profile') {
              setState(() => _selectedIndex = 3); // Switch to Profile Tab
            } else if (value == 'notifications') {
              Navigator.pushNamed(context, '/notifications');
            } else if (value == 'settings') {
              Navigator.pushNamed(context, '/settings');
            } else if (value == 'logout') {
               // Show confirmation dialog before logout
               showDialog(
                 context: context,
                 builder: (ctx) => AlertDialog(
                   title: const Text('Logout'),
                   content: const Text('Are you sure you want to logout?'),
                   actions: [
                     TextButton(
                       onPressed: () => Navigator.pop(ctx),
                       child: const Text('Cancel'),
                     ),
                     TextButton(
                       onPressed: () {
                         Navigator.pop(ctx);
                         authProvider.logout();
                         Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                       },
                       child: const Text('Logout', style: TextStyle(color: Colors.red)),
                     ),
                   ],
                 ),
               );
            }
          },
          itemBuilder: (BuildContext context) {
            return [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),

              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ];
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDashboardBody() {
    final authProvider = Provider.of<AuthProvider>(context);
    final parcelProvider = Provider.of<ParcelProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final user = authProvider.user;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600), // Better for tablets
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header (Flat)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF042840).withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.name?.split(' ').first ?? 'Driver',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF042840),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
    
                // Today's Summary Header
                const Text(
                  "Today's Summary",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF042840),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
    
                // Statistics Grid (2x2)
                Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width <= 340 ? 12 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    children: [
                       Row(
                         children: [
                           _GridStatItem(
                             label: 'Assigned',
                             value: (parcelProvider.statistics?['assigned_today'] ?? 0).toString(),
                             icon: Icons.assignment_outlined,
                             color: const Color(0xFF042840),
                             bgColor: const Color(0xFF042840).withOpacity(0.05),
                             onTap: () {
                               parcelProvider.setStatusFilter('assigned');
                               parcelProvider.setDateFilter(DateTime.now());
                               setState(() => _selectedIndex = 1);
                             },
                           ),
                           SizedBox(width: MediaQuery.of(context).size.width <= 340 ? 8 : 16),
                           _GridStatItem(
                             label: 'Delivered',
                             value: (parcelProvider.statistics?['today_deliveries'] ??
                                     parcelProvider.statistics?['delivered_today'] ?? 0).toString(),
                             icon: Icons.check_circle_outline,
                             color: const Color(0xFF042840),
                             bgColor: const Color(0xFF042840).withOpacity(0.05),
                             onTap: () {
                               parcelProvider.setStatusFilter('delivered');
                               parcelProvider.setDateFilter(DateTime.now());
                               setState(() => _selectedIndex = 1);
                             },
                           ),
                         ],
                       ),
                       SizedBox(height: MediaQuery.of(context).size.width <= 340 ? 8 : 20),
                       Row(
                         children: [
                           _GridStatItem(
                             label: 'Pending',
                             value: (parcelProvider.statistics?['pending_count'] ??
                                     parcelProvider.assignedParcels.length).toString(),
                             icon: Icons.pending_actions_outlined,
                             color: const Color(0xFF042840),
                             bgColor: const Color(0xFF042840).withOpacity(0.05),
                             onTap: () {
                               parcelProvider.clearFilters(); // Show all pending/active
                               setState(() => _selectedIndex = 1);
                             },
                           ),
                           SizedBox(width: MediaQuery.of(context).size.width <= 340 ? 8 : 16),
                           _GridStatItem(
                             label: 'Failed Today',
                             value: (parcelProvider.statistics?['failed_today'] ?? 0).toString(),
                             icon: Icons.error_outline,
                             color: const Color(0xFFAE2E2F),
                             bgColor: const Color(0xFFAE2E2F).withOpacity(0.05),
                             onTap: () {
                               parcelProvider.setStatusFilter('failed');
                               parcelProvider.setDateFilter(DateTime.now());
                               setState(() => _selectedIndex = 1);
                             },
                           ),
                         ],
                       ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
    
                // Quick Actions (Pills) - Optional now but kept for quick access
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                       _ActionPill(
                        icon: Icons.qr_code_scanner,
                        label: 'Scan Parcel',
                        onTap: () => Navigator.pushNamed(context, '/scan'),
                        isPrimary: true,
                      ),
                      const SizedBox(width: 12),
                      // Removed History/Tracking pills as they are redundant with Nav Bar 
                      // But kept Tracking as it's specific to active parcel
                      _ActionPill(
                        icon: Icons.map_outlined,
                        label: 'Track',
                        onTap: () {
                          final inProgress = parcelProvider.inProgressParcels;
                          if (inProgress.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No active deliveries to track')),
                            );
                            return;
                          }
    
                          if (inProgress.length == 1) {
                            Navigator.pushNamed(context, '/map-tracking', arguments: inProgress.first);
                          } else {
                            // Show Selection Bottom Sheet
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Select Delivery to Track',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF042840)),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 20),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: inProgress.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                                        itemBuilder: (context, index) {
                                          final parcel = inProgress[index];
                                          return InkWell(
                                            onTap: () {
                                              Navigator.pop(context);
                                              Navigator.pushNamed(context, '/map-tracking', arguments: parcel);
                                            },
                                            borderRadius: BorderRadius.circular(16),
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: const Color(0xFFF1F5F9)),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF042840)),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          parcel.parcelNumber,
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                        ),
                                                        Text(
                                                          parcel.receiverName,
                                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
    
                // Active Deliveries Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Deliveries',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF042840),
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedIndex = 1), // Switch to Deliveries Tab
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
    
                // Parcels List
                if (parcelProvider.isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: LoadingIndicator(size: 30)))
                else if (parcelProvider.assignedParcels.isEmpty)
                  const Center(
                    child: SizedBox(
                       width: double.infinity,
                       child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No Active Deliveries',
                        message: 'Assigned parcels will appear here.',
                        actionText: 'Refresh',
                      ),
                    ),
                  )
                else
                  Column(
                    children: parcelProvider.assignedParcels.take(3).map((parcel) => ParcelCard(parcel: parcel)).toList(),
                  ),
                
                const SizedBox(height: 24),
                
                if (locationProvider.currentAddress != null)
                  Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: const Color(0xFFF1F5F9),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Row(
                       children: [
                         const Icon(Icons.my_location, size: 16, color: Color(0xFF64748B)),
                         const SizedBox(width: 8),
                         Expanded(
                           child: Text(
                             locationProvider.currentAddress!,
                             style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                       ],
                     ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isCurrency;

  const _StatItem({
    required this.label,
    required this.value,
    this.isCurrency = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (isCurrency)
                Text(
                  'AED ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF042840),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? const Color(0xFF042840) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isPrimary ? BorderSide.none : const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : const Color(0xFF042840),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : const Color(0xFF042840),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _GridStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isSmall = screenWidth <= 340;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(isSmall ? 8 : 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 24, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}