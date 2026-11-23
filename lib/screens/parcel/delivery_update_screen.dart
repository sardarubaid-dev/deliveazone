// lib/screens/parcel/delivery_update_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/widgets/loading_indicator.dart';

class DeliveryUpdateScreen extends StatefulWidget {
  final Parcel parcel;

  const DeliveryUpdateScreen({super.key, required this.parcel});

  @override
  State<DeliveryUpdateScreen> createState() => _DeliveryUpdateScreenState();
}

class _DeliveryUpdateScreenState extends State<DeliveryUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();

  String _selectedStatus = '';
  String? _proofImagePath;
  bool _isLoading = false;

  final Map<String, List<String>> _statusFlow = {
    'assigned': ['picked_up'],
    'picked_up': ['in_transit'],
    'in_transit': ['delivered', 'failed', 'returned'],
  };

  @override
  void initState() {
    super.initState();
    _selectedStatus = _getNextStatus();
  }

  String _getNextStatus() {
    final currentStatus = widget.parcel.status;
    final nextStatuses = _statusFlow[currentStatus] ?? [];
    return nextStatuses.isNotEmpty ? nextStatuses.first : currentStatus;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1024,
    );

    if (image != null) {
      setState(() {
        _proofImagePath = image.path;
      });
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStatus == 'failed' || _selectedStatus == 'returned') {
      if (_remarksController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide remarks for failed/returned delivery'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      print('Submitting status update: parcelId=${widget.parcel.id}, status=$_selectedStatus');
      
      await Provider.of<ParcelProvider>(context, listen: false).updateParcelStatus(
        widget.parcel.id,
        _selectedStatus,
        remarks: _remarksController.text.trim(),
        proofImage: _proofImagePath,
      );

      print('Status update successful!');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery status updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate success to the previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Status update failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'picked_up':
        return 'Mark as picked up from sender';
      case 'in_transit':
        return 'Start delivery to receiver';
      case 'delivered':
        return 'Mark as delivered to receiver';
      case 'failed':
        return 'Delivery failed (provide reason)';
      case 'returned':
        return 'Return to sender (provide reason)';
      default:
        return 'Update delivery status';
    }
  }

  String _getStatusIcon(String status) {
    switch (status) {
      case 'picked_up':
        return '📦';
      case 'in_transit':
        return '🚚';
      case 'delivered':
        return '✅';
      case 'failed':
        return '❌';
      case 'returned':
        return '↩️';
      default:
        return '🔄';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextStatuses = _statusFlow[widget.parcel.status] ?? [];
    final showProofUpload = _selectedStatus == 'delivered';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Delivery'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Parcel Info
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.parcel.parcelNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF042840),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To: ${widget.parcel.receiverName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF042840),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.parcel.receiverAddress,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Current Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.parcel.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: widget.parcel.statusColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Status',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.parcel.statusLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: widget.parcel.statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Status Selection
              const Text(
                'Select New Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF042840),
                ),
              ),
              const SizedBox(height: 12),
              // Status Options
              ...nextStatuses.map((status) {
                return _StatusOption(
                  icon: _getStatusIcon(status),
                  title: status.replaceAll('_', ' ').toUpperCase(),
                  description: _getStatusDescription(status),
                  selected: _selectedStatus == status,
                  onTap: () => setState(() => _selectedStatus = status),
                );
              }),
              const SizedBox(height: 24),
              // Remarks
              const Text(
                'Remarks (Required for Failed/Returned)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF042840),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  hintText: 'Enter remarks or delivery notes...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 4,
                validator: (value) {
                  if ((_selectedStatus == 'failed' || _selectedStatus == 'returned') &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Remarks are required for this status';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Proof Upload (for delivered)
              if (showProofUpload) ...[
                const Text(
                  'Proof of Delivery',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF042840),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Take a photo as proof of delivery',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _proofImagePath != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_proofImagePath!),
                        fit: BoxFit.cover,
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to take photo',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_proofImagePath != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _proofImagePath = null),
                        child: const Text(
                          'Remove Photo',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitUpdate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFAE2E2F),
                  ),
                  child: const Text(
                    'Update Delivery Status',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF042840)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF042840),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF042840).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF042840) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF042840) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected ? const Color(0xFF042840) : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? const Color(0xFF042840).withOpacity(0.8) : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Radio
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFF042840) : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF042840),
                  ),
                ),
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}