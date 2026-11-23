import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/widgets/parcel_card.dart';
import 'package:deliveazone_driver_app/widgets/empty_state.dart';
import 'package:deliveazone_driver_app/widgets/loading_indicator.dart';

class ParcelsScreen extends StatefulWidget {
  const ParcelsScreen({super.key});

  @override
  State<ParcelsScreen> createState() => _ParcelsScreenState();
}

class _ParcelsScreenState extends State<ParcelsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _handleInitialFilter();
    });
    final provider = Provider.of<ParcelProvider>(context, listen: false);
    provider.addListener(_onProviderChange);
  }

  void _onProviderChange() {
    if (mounted) {
      _handleInitialFilter();
    }
  }

  void _handleInitialFilter() {
    final provider = Provider.of<ParcelProvider>(context, listen: false);
    if (provider.statusFilter == 'delivered' || provider.statusFilter == 'failed') {
      _tabController.animateTo(2); // History tab
    } else if (provider.statusFilter == 'pending' || provider.statusFilter == 'picked_up' || provider.statusFilter == 'in_transit') {
      _tabController.animateTo(1); // Active tab
    } else if (provider.statusFilter == 'assigned') {
      _tabController.animateTo(0); // New tab
    }
  }

  Future<void> _loadData() async {
    final provider = Provider.of<ParcelProvider>(context, listen: false);
    await Future.wait([
      provider.loadAssignedParcels(),
      provider.loadParcelHistory(),
    ]);
  }

  @override
  void dispose() {
    final provider = Provider.of<ParcelProvider>(context, listen: false);
    provider.removeListener(_onProviderChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Parcels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
          if (Provider.of<ParcelProvider>(context).statusFilter != 'all' || 
              Provider.of<ParcelProvider>(context).dateFilter != null)
            IconButton(
              icon: const Icon(Icons.filter_list_off, color: Colors.red),
              onPressed: () => Provider.of<ParcelProvider>(context, listen: false).clearFilters(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF042840),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF042840),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'New'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Consumer<ParcelProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
             return const LoadingIndicator();
          }
          
          final statusFilter = provider.statusFilter;
          final dateFilter = provider.dateFilter;

          List<Parcel> filterList(List<Parcel> list) {
            return list.where((p) {
              bool matchStatus = true;
              if (statusFilter != 'all') {
                if (statusFilter == 'pending') {
                   matchStatus = ['picked_up', 'in_transit'].contains(p.status);
                } else if (statusFilter == 'rescheduled') {
                   matchStatus = p.status == 'failed' && p.isRescheduled;
                } else if (statusFilter == 'failed') {
                   matchStatus = p.status == 'failed' && !p.isRescheduled;
                } else {
                   matchStatus = p.status == statusFilter;
                }
              }
              
              bool matchDate = true;
              if (dateFilter != null) {
                DateTime date = p.status == 'delivered' && p.deliveredAt != null 
                           ? p.deliveredAt! 
                           : p.updatedAt;
                date = date.toLocal(); // Fix timezone issue
                matchDate = date.day == dateFilter.day && 
                           date.month == dateFilter.month && 
                           date.year == dateFilter.year;
              }
              
              return matchStatus && matchDate;
            }).toList();
          }

          final newParcels = filterList(provider.assignedParcels
              .where((p) => p.status == 'assigned')
              .toList());
              
          final activeParcels = filterList(provider.assignedParcels
              .where((p) => ['picked_up', 'in_transit'].contains(p.status))
              .toList());

          final historyParcels = filterList(provider.parcelHistory);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600), // Better for tablets
              child: TabBarView(
                controller: _tabController,
                children: [
                   _buildParcelList(newParcels, 'No new parcels assigned'),
                   _buildParcelList(activeParcels, 'No active deliveries'),
                   _buildParcelList(historyParcels, 'No delivery history', readOnly: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildParcelList(List<Parcel> parcels, String emptyMessage, {bool readOnly = false}) {
    if (parcels.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Empty List',
        message: emptyMessage,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF042840),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: parcels.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return ParcelCard(
            parcel: parcels[index],
            onTap: readOnly ? () {} : null, // Disable navigation if readOnly
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _FilterBottomSheet(),
    );
  }
}

class _FilterBottomSheet extends StatelessWidget {
  const _FilterBottomSheet();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ParcelProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: provider.statusFilter,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Statuses')),
              DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
              DropdownMenuItem(value: 'pending', child: Text('Pending (Active)')),
              DropdownMenuItem(value: 'picked_up', child: Text('Picked Up')),
              DropdownMenuItem(value: 'in_transit', child: Text('In Transit')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'failed', child: Text('Failed')),
              DropdownMenuItem(value: 'returned', child: Text('Returned')),
              DropdownMenuItem(value: 'rescheduled', child: Text('Rescheduled')),
            ],
            onChanged: (val) {
              if (val != null) provider.setStatusFilter(val);
            },
          ),
          const SizedBox(height: 20),
          const Text('Date', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: provider.dateFilter ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (date != null) provider.setDateFilter(date);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.dateFilter == null 
                      ? 'Select Date' 
                      : '${provider.dateFilter!.day}/${provider.dateFilter!.month}/${provider.dateFilter!.year}',
                  ),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    provider.clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF042840),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}