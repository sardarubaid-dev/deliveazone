// lib/screens/main/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/widgets/loading_indicator.dart';
import 'package:deliveazone_driver_app/widgets/empty_state.dart';
import 'package:url_launcher/url_launcher.dart'; // For View Location
import 'package:deliveazone_driver_app/services/api_service.dart'; // For proof image URL

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'all'; // Default to all time as per user request
  String _selectedStatus = 'all';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  DateTime _lastSync = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await Provider.of<ParcelProvider>(
      context,
      listen: false,
    ).loadParcelHistory();
    if (mounted) {
      setState(() {
        _lastSync = DateTime.now();
      });
    }
  }

  List<Parcel> _filterHistory(List<Parcel> history) {
    final now = DateTime.now();
    List<Parcel> filtered = List.from(history);

    // Apply time filter
    if (_selectedFilter == 'today') {
      filtered = filtered.where((parcel) {
        // For today's filter, we care about when the action happened (delivered, failed, etc)
        // If not delivered/failed/etc recently, updatedAt will reflect the last status change.
        DateTime date = parcel.status == 'delivered' && parcel.deliveredAt != null
            ? parcel.deliveredAt!
            : parcel.updatedAt;
        date = date.toLocal(); // Fix Timezone issue
        return date.day == now.day &&
            date.month == now.month &&
            date.year == now.year;
      }).toList();
    } else if (_selectedFilter == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      filtered = filtered.where((parcel) {
        DateTime date = parcel.status == 'delivered' && parcel.deliveredAt != null
            ? parcel.deliveredAt!
            : parcel.updatedAt;
        return date.toLocal().isAfter(weekAgo);
      }).toList();
    } else if (_selectedFilter == 'month') {
      final monthAgo = now.subtract(const Duration(days: 30));
      filtered = filtered.where((parcel) {
        DateTime date = parcel.status == 'delivered' && parcel.deliveredAt != null
            ? parcel.deliveredAt!
            : parcel.updatedAt;
        return date.toLocal().isAfter(monthAgo);
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != 'all') {
      if (_selectedStatus == 'rescheduled') {
        filtered = filtered
            .where(
              (parcel) => parcel.status == 'failed' && parcel.isRescheduled,
            )
            .toList();
      } else if (_selectedStatus == 'failed') {
        // Only pure failed, exclude rescheduled as it has its own filter
        filtered = filtered
            .where((parcel) => parcel.status == 'failed' && !parcel.isRescheduled)
            .toList();
      } else {
        filtered = filtered
            .where((parcel) => parcel.status == _selectedStatus)
            .toList();
      }
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((parcel) {
        return parcel.parcelNumber.toLowerCase().contains(searchTerm) ||
            parcel.receiverName.toLowerCase().contains(searchTerm) ||
            parcel.receiverAddress.toLowerCase().contains(searchTerm);
      }).toList();
    }

    // Sort by action date descending (newest first)
    filtered.sort((a, b) {
      final aDate = a.status == 'delivered' && a.deliveredAt != null
          ? a.deliveredAt!
          : a.updatedAt;
      final bDate = b.status == 'delivered' && b.deliveredAt != null
          ? b.deliveredAt!
          : b.updatedAt;
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case 'today':
        return 'Today';
      case 'week':
        return 'Last 7 Days';
      case 'month':
        return 'Last 30 Days';
      case 'all':
        return 'All Time';
      default:
        return 'Today';
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcelProvider = Provider.of<ParcelProvider>(context);
    // Combine history and assigned (if they are delivered/completed but not moved to history yet?
    // Usually history contains completed. Let's assume provider.parcelHistory is the source for completed ones.
    // However, sometimes delivered parcels might still be in 'assigned' list until refresh?
    // Safest is to check both or just history if your app logic moves them immediately.)
    // For now, using parcelHistory as in original code.
    final List<Parcel> history = parcelProvider.parcelHistory;
    final List<Parcel> filteredHistory = _filterHistory(history);

    // Calculate Summary Stats
    final deliveredCount = filteredHistory
        .where((p) => p.status == 'delivered')
        .length;
    final totalCod = filteredHistory
        .where((p) => p.status == 'delivered' && p.amount != null)
        .fold(0.0, (sum, p) => sum + (p.amount ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF042840),
        elevation: 0,
        title: const Text(
          'Order History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
          ), // Better for tablets
          child: Column(
            children: [
              // Filter Bar & Search
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    if (_isSearchVisible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search Order ID, Name...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: const Color(0xFF042840).withOpacity(0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF042840),
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedFilter,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF042840),
                              ),
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: Color(0xFF042840),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null)
                                  setState(() => _selectedFilter = newValue);
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'today',
                                  child: Text('Today'),
                                ),
                                DropdownMenuItem(
                                  value: 'week',
                                  child: Text('This Week'),
                                ),
                                DropdownMenuItem(
                                  value: 'month',
                                  child: Text('This Month'),
                                ),
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Time'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedStatus,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF042840),
                              ),
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: Color(0xFF042840),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null)
                                  setState(() => _selectedStatus = newValue);
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Status'),
                                ),
                                DropdownMenuItem(
                                  value: 'delivered',
                                  child: Text('Delivered'),
                                ),
                                DropdownMenuItem(
                                  value: 'failed',
                                  child: Text('Failed'),
                                ),
                                DropdownMenuItem(
                                  value: 'returned',
                                  child: Text('Returned'),
                                ),
                                DropdownMenuItem(
                                  value: 'rescheduled',
                                  child: Text('Rescheduled'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_isSearchVisible) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isSearchVisible = true;
                              });
                            },
                            icon: const Icon(
                              Icons.search_rounded,
                              size: 22,
                              color: Color(0xFF042840),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: parcelProvider.isLoadingHistory
                    ? const LoadingIndicator()
                    : filteredHistory.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No Orders Found',
                        message: 'No delivered orders found for this period.',
                        onAction: _loadHistory,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredHistory.length,
                        itemBuilder: (context, index) {
                          return _HistoryCard(parcel: filteredHistory[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final double totalAmount;
  final DateTime lastSync;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.totalAmount,
    required this.lastSync,
  });

  @override
  Widget build(BuildContext context) {
    final timeDiff = DateTime.now().difference(lastSync).inMinutes;
    String syncText = timeDiff < 1 ? 'Just now' : '$timeDiff min ago';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivered $label:',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF042840).withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF042840),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'COD Collected:',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF042840).withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AED ${totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF042840),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: Color(0xFF042840),
              ),
              const SizedBox(width: 6),
              Text(
                'Last Sync: $syncText',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF042840).withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Parcel parcel;

  const _HistoryCard({required this.parcel});

  Future<void> _viewProof(BuildContext context) async {
    bool hasProofImage = parcel.proofImage != null && 
        parcel.proofImage != 'null' && 
        parcel.proofImage!.trim().isNotEmpty;

    if (hasProofImage) {
      final String photoPath = parcel.proofImage!;
      String imageUrl = photoPath;
      if (!photoPath.startsWith('http')) {
        String cleanPath = photoPath;
        if (!cleanPath.startsWith('uploads/') &&
            !cleanPath.startsWith('/uploads/')) {
          cleanPath =
              'uploads/${cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath}';
        }
        imageUrl = cleanPath.startsWith('/')
            ? '${ApiService().baseUrl}$cleanPath'
            : '${ApiService().baseUrl}/$cleanPath';
      }

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                imageUrl,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No proof image available')));
    }
  }

  Future<void> _viewLocation(BuildContext context) async {
    String? query;

    // 1. Try Actual Delivery Location
    if (parcel.deliveryLatitude != null && parcel.deliveryLongitude != null) {
      query = '${parcel.deliveryLatitude},${parcel.deliveryLongitude}';
    }
    // 2. Fallback to Expected Delivery Location
    else if (parcel.latitude != null && parcel.longitude != null) {
      query = '${parcel.latitude},${parcel.longitude}';
    }
    // 3. Fallback to Address
    else if (parcel.receiverAddress.isNotEmpty) {
      query = Uri.encodeComponent(parcel.receiverAddress);
    }

    if (query != null) {
      final url = 'https://www.google.com/maps/search/?api=1&query=$query';
      final uri = Uri.parse(url);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // Try launching without specific mode if external fails
          await launchUrl(uri);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open maps: $e')));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location details not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract Area from address (simple split by comma)
    String area = '';
    if (parcel.receiverAddress.contains(',')) {
      final parts = parcel.receiverAddress.split(',');
      if (parts.length > 1) {
        area = parts[1].trim(); // Assuming standard "Street, Area, City" format
      } else {
        area = parts[0];
      }
    } else {
      area = parcel.receiverAddress;
    }

    final String statusTime =
        (parcel.status == 'delivered' && parcel.deliveredAt != null)
        ? DateFormat('h:mm a').format(parcel.deliveredAt!)
        : DateFormat('h:mm a').format(parcel.updatedAt);

    final String timeLabel = parcel.status == 'delivered'
        ? 'Delivered $statusTime'
        : '${parcel.statusLabel} $statusTime';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/parcel-detail', arguments: parcel),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Top Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: Color(0xFF042840),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              parcel.parcelNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF042840),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: parcel.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        parcel.statusLabel.toUpperCase(),
                        style: TextStyle(
                          color: parcel.statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Name and Time Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${parcel.receiverName},',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF042840),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF042840).withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Address - Full address, small grey text
                Text(
                  parcel.receiverAddress,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF042840).withOpacity(0.5),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Status/Remarks
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: parcel.statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        parcel.remarks != null && parcel.remarks!.isNotEmpty
                            ? 'Remarks: ${parcel.remarks}'
                            : 'Self Accepted',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF042840).withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1),

          // Bottom Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.center, // Centered like the screenshot
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24, // Wider spacing for horizontal layout
              runSpacing: 8, // More space if wrapped
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: parcel.statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'COD AED ${(parcel.amount ?? 0).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: parcel.statusColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (parcel.proofImage != null && 
                        parcel.proofImage != 'null' && 
                        parcel.proofImage!.trim().isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _viewProof(context),
                        child: const Text(
                          'View Proof',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF042840),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 16,
                        color: const Color(0xFF042840).withOpacity(0.1),
                      ),
                      const SizedBox(width: 12),
                    ],
                    GestureDetector(
                      onTap: () => _viewLocation(context),
                      child: const Text(
                        'View Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF042840),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
