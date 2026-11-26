
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/utils/helpers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:deliveazone_driver_app/services/api_service.dart';

class ParcelDetailScreen extends StatefulWidget {
  final Parcel parcel;

  const ParcelDetailScreen({super.key, required this.parcel});

  @override
  State<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends State<ParcelDetailScreen> {
  bool _localProcessing = false;

  Future<void> _updateStatus(Parcel currentParcel, String status) async {
    if (status == 'delivered') {
      Navigator.pushNamed(context, '/pod-screen', arguments: currentParcel);
      return;
    }
    if (extractedStatusNames.contains(status)) {
      _showUpdateModal(currentParcel, status);
      return;
    }
    
    await _processUpdate(currentParcel.id, status);
  }

  static const extractedStatusNames = ['failed', 'rescheduled', 'returned'];

  Future<void> _processUpdate(int parcelId, String status, {String? remarks, String? proofPath, String? rescheduledDate}) async {
    setState(() => _localProcessing = true);
    try {
      final provider = Provider.of<ParcelProvider>(context, listen: false);
      await provider.updateParcelStatus(
          parcelId, 
          status,
          remarks: remarks,
          proofImage: proofPath,
          rescheduledDate: rescheduledDate,
        );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status: ${status.replaceAll('_', ' ').toUpperCase()}'), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (['delivered', 'failed', 'returned', 'rescheduled'].contains(status)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: const Color(0xFFAE2E2F)),
        );
      }
    } finally {
      if (mounted) setState(() => _localProcessing = false);
    }
  }

  void _showUpdateModal(Parcel currentParcel, String status) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeliveryUpdateSheet(
        parcel: currentParcel,
        targetStatus: status,
        onUpdate: (remarks, proofPath, rescheduledDate) {
            _processUpdate(currentParcel.id, status, remarks: remarks, proofPath: proofPath, rescheduledDate: rescheduledDate);
          },
      ),
    );
  }

  Future<void> _launchMaps() async {
    // Priority: pickup address if state is assigned/pending, else delivery address
    final isPickupPhase = ['assigned', 'pending'].contains(widget.parcel.status);
    final lat = isPickupPhase ? (widget.parcel.pickupLatitude ?? widget.parcel.latitude) : widget.parcel.latitude;
    final lng = isPickupPhase ? (widget.parcel.pickupLongitude ?? widget.parcel.longitude) : widget.parcel.longitude;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  Future<void> _manualPickup(int parcelId) async {
    setState(() => _localProcessing = true);
    try {
      final provider = Provider.of<ParcelProvider>(context, listen: false);
      final result = await provider.manualPickup(parcelId);
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ORDER PICKED UP MANUALLY'), 
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${result.message}'), backgroundColor: const Color(0xFFAE2E2F)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFAE2E2F)),
        );
      }
    } finally {
      if (mounted) setState(() => _localProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcelProvider = Provider.of<ParcelProvider>(context);
    // Find the latest version of this parcel from the provider
    final currentParcel = parcelProvider.assignedParcels.followedBy(parcelProvider.parcelHistory)
        .firstWhere((p) => p.id == widget.parcel.id, orElse: () => widget.parcel);

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Simplified Header
                _buildHeader(currentParcel),
                const SizedBox(height: 20),
                
                // Parcel Details Card
                _buildInfoCard(currentParcel),
                const SizedBox(height: 20),

                // Pickup Information
                _buildAddressTile(
                  title: 'SENDER (PICKUP)',
                  name: currentParcel.senderName,
                  address: currentParcel.senderAddress,
                  phone: currentParcel.senderPhone,
                  icon: Icons.store_mall_directory_outlined,
                  color: const Color(0xFF042840),
                ),
                const SizedBox(height: 12),

                // Delivery Information
                _buildAddressTile(
                  title: 'RECEIVER (DELIVERY)',
                  name: currentParcel.receiverName,
                  address: currentParcel.receiverAddress,
                  phone: currentParcel.receiverPhone,
                  icon: Icons.location_on_outlined,
                  color: const Color(0xFFAE2E2F),
                ),
                const SizedBox(height: 16),
                
                // Hide MAP button and progress for completed/failed orders
                if (!['delivered', 'failed', 'returned', 'rescheduled'].contains(currentParcel.status)) ...[
                  // Map Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (['assigned', 'pending'].contains(currentParcel.status)) {
                          // Redirect to scanner first, then it should go to map
                          Navigator.pushNamed(
                            context, 
                            '/scan', 
                            arguments: {'redirect_to': '/map-tracking', 'parcel': currentParcel}
                          );
                          return;
                        }
                        Navigator.pushNamed(context, '/map-tracking', arguments: currentParcel);
                      }, 
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('VIEW ON MAP'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF042840),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF042840)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Timeline
                  const Text('DELIVERY PROGRESS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  _buildTimeline(currentParcel),
                ],
                
                if (['delivered', 'failed', 'rescheduled'].contains(currentParcel.status)) ...[
                  const SizedBox(height: 24),
                  _buildProofCard(currentParcel),
                ],
                
                const SizedBox(height: 100), // Space for bottom buttons
              ],
            ),
          ),
          
          // Action Buttons at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              color: Colors.white,
              child: _buildActionButtons(currentParcel),
            ),
          ),
          
          if (_localProcessing)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildHeader(Parcel currentParcel) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isSmall = screenWidth <= 340;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(isSmall ? 6 : 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_ios_new, size: isSmall ? 16 : 20, color: const Color(0xFF042840)),
                ),
              ),
              SizedBox(width: isSmall ? 8 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER #${currentParcel.parcelNumber}', 
                      style: TextStyle(fontSize: isSmall ? 15 : 18, fontWeight: FontWeight.bold, color: const Color(0xFF042840)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentParcel.formattedCreatedAt, 
                      style: TextStyle(color: Colors.grey.shade600, fontSize: isSmall ? 11 : 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: isSmall ? 4 : 6),
          decoration: BoxDecoration(
            color: currentParcel.statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            currentParcel.statusLabel.toUpperCase(),
            style: TextStyle(color: currentParcel.statusColor, fontWeight: FontWeight.bold, fontSize: isSmall ? 10 : 12),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(Parcel currentParcel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildInfoItem('COD Amount', 'AED ${Helpers.formatAmount(currentParcel.amount ?? 0)}')),
              if (currentParcel.deliveryOtp != null) ...[
                Container(width: 1, height: 30, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 8)),
                Expanded(child: _buildInfoItem('OTP', currentParcel.deliveryOtp!)),
              ],
            ],
          ),
          if (currentParcel.status == 'failed' && currentParcel.isRescheduled && currentParcel.rescheduledDate != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Rescheduled For',
                    Helpers.formatDate(currentParcel.rescheduledDate!),
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }

  Widget _buildAddressTile({required String title, required String name, required String address, required String phone, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(address, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Helpers.launchPhone(phone),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                color: const Color(0xFF042840),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Parcel currentParcel) {
    return Column(
      children: [
        _TimelineStep(
          title: 'Pick Up',
          isActive: currentParcel.status == 'assigned',
          isCompleted: !['assigned', 'pending'].contains(currentParcel.status),
          icon: Icons.warehouse_rounded,
          iconColor: const Color(0xFF042840),
        ),
        _TimelineDivider(),
        _TimelineStep(
          title: 'On the Way',
          isActive: currentParcel.status == 'picked_up',
          isCompleted: ['in_transit', 'delivered', 'failed', 'rescheduled'].contains(currentParcel.status),
          icon: Icons.local_shipping_rounded,
          iconColor: const Color(0xFF042840),
        ),
        _TimelineDivider(),
        _TimelineStep(
          title: 'Reach Destination',
          isActive: currentParcel.status == 'in_transit',
          isCompleted: currentParcel.status == 'delivered',
          icon: Icons.where_to_vote_rounded,
          iconColor: const Color(0xFF042840),
        ),
      ],
    );
  }

  Widget _buildProofCard(Parcel currentParcel) {
    bool hasProofImage = currentParcel.proofImage != null && 
        currentParcel.proofImage != 'null' && 
        currentParcel.proofImage!.trim().isNotEmpty;
        
    bool hasRemarks = currentParcel.remarks != null && 
        currentParcel.remarks != 'null' && 
        currentParcel.remarks!.trim().isNotEmpty;

    if (!hasProofImage && !hasRemarks) {
      return const SizedBox.shrink();
    }

    String title;
    if (currentParcel.status == 'delivered') {
      title = 'PROOF OF DELIVERY';
    } else if (currentParcel.isRescheduled) {
      title = 'RESCHEDULE INFO';
    } else if (currentParcel.status == 'failed') {
      title = 'FAILED ATTEMPT INFO';
    } else {
      title = 'DELIVERY ATTEMPT INFO';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF042840).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF042840))),
          const SizedBox(height: 12),
          if (hasProofImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                (() {
                  String photoPath = currentParcel.proofImage!;
                  if (!photoPath.startsWith('http')) {
                    if (!photoPath.startsWith('uploads/') && !photoPath.startsWith('/uploads/')) {
                      photoPath = 'uploads/${photoPath.startsWith('/') ? photoPath.substring(1) : photoPath}';
                    }
                    return photoPath.startsWith('/') 
                        ? '${ApiService().baseUrl}$photoPath' 
                        : '${ApiService().baseUrl}/$photoPath';
                  }
                  return photoPath;
                })(),
                height: 150, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
            if (hasRemarks) const SizedBox(height: 12),
          ],
          if (hasRemarks)
            Text('Remarks: ${currentParcel.remarks!}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Parcel currentParcel) {
    if (currentParcel.status == 'assigned') {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'SCAN TO PICKUP',
              icon: Icons.qr_code_scanner_rounded,
              color: const Color(0xFF042840),
              onTap: () => Navigator.pushNamed(context, '/scan', arguments: {'parcel': currentParcel}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              label: 'MANUAL PICKUP',
              icon: Icons.touch_app_rounded,
              color: const Color(0xFF64748B),
              onTap: () => _manualPickup(currentParcel.id),
            ),
          ),
        ],
      );
    } else if (currentParcel.status == 'picked_up') {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'START DELIVERY',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF042840),
              onTap: () => _updateStatus(currentParcel, 'in_transit'),
            ),
          ),
        ],
      );
    } else if (currentParcel.status == 'in_transit') {
      double screenWidth = MediaQuery.of(context).size.width;
      // On very small screens (<= 330dp), 2 buttons per row looks better
      double buttonWidth = screenWidth <= 340 
          ? (screenWidth - 40) / 2 
          : (screenWidth - 48) / 3;

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          SizedBox(
            width: buttonWidth,
            child: _ActionButton(
              label: 'DELIVERED',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF042840),
              onTap: () => _updateStatus(currentParcel, 'delivered'),
            ),
          ),
          SizedBox(
            width: buttonWidth,
            child: _ActionButton(
              label: 'RESCHEDULE',
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF042840),
              onTap: () => _updateStatus(currentParcel, 'rescheduled'),
            ),
          ),
          SizedBox(
            width: buttonWidth,
            child: _ActionButton(
              label: 'FAILED',
              icon: Icons.cancel_rounded,
              color: const Color(0xFFAE2E2F),
              onTap: () => _updateStatus(currentParcel, 'failed'),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'BACK TO HOME',
              icon: Icons.home_rounded,
              color: const Color(0xFF64748B),
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      );
    }
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final bool isActive;
  final IconData icon;
  final Color? iconColor;

  const _TimelineStep({
    required this.title,
    this.isCompleted = false,
    this.isActive = false,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: isCompleted ? const Color(0xFF042840) : (isActive ? (iconColor ?? const Color(0xFF042840)) : Colors.grey.shade300),
          size: 28,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: (isCompleted || isActive) ? FontWeight.bold : FontWeight.w500,
            color: (isCompleted || isActive) ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

class _TimelineDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 13.5),
      height: 20,
      width: 1,
      color: Colors.grey.shade300,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
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
  String? _proofPath;
  DateTime? _rescheduledDate;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 1024);
    if (image != null) setState(() => _proofPath = image.path);
  }

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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, 
        right: 20, 
        top: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF042840)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _remarksController,
            decoration: InputDecoration(
              hintText: 'Add remarks/notes here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF042840), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 3,
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remarks are required for this action')));
                  return;
                }
                if (isRescheduled && _rescheduledDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a reschedule date')));
                  return;
                }
                Navigator.pop(context);
                String? dateStr = _rescheduledDate != null ? '${_rescheduledDate!.year}-${_rescheduledDate!.month.toString().padLeft(2, '0')}-${_rescheduledDate!.day.toString().padLeft(2, '0')}' : null;
                widget.onUpdate(_remarksController.text, null, dateStr);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}