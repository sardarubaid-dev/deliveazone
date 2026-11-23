import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/utils/helpers.dart';
import 'package:deliveazone_driver_app/widgets/loading_indicator.dart';

class PODScreen extends StatefulWidget {
  final Parcel parcel;
  const PODScreen({super.key, required this.parcel});

  @override
  State<PODScreen> createState() => _PODScreenState();
}

class _PODScreenState extends State<PODScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Section 1: Who accepted
  String _acceptedBy = 'Self';
  

  
  // Section 3: GPS
  Position? _currentPosition;
  bool _isLocationValid = false;
  bool _validatingLocation = false;
  double _distanceInMeters = 0;
  
  // Section 4: Signature
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _hasSignature = false;
  
  // Section 5: Photo
  File? _proofPhoto;
  
  // Section 6: Notes & Payment
  final _notesController = TextEditingController();
  final _customRoleController = TextEditingController();
  final _receiverNameController = TextEditingController();
  String _paymentMethod = 'COD'; // COD, Paid
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _signatureController.onDrawEnd = () => setState(() => _hasSignature = true);
    
    // Postpone to next frame to avoid setState during build/navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureAndVerifyLocation();
    });
  }

  @override
  void dispose() {
    _receiverNameController.dispose();
    _customRoleController.dispose();
    _signatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ================= LOGIC =================

  Future<void> _captureAndVerifyLocation() async {
    if (!mounted) return;
    setState(() {
      _validatingLocation = true;
      _isLocationValid = false;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 15),
        );
        
        if (!mounted) return;
        
        _currentPosition = position;

        double distance = 0;
        bool isValid = false;

        if (widget.parcel.latitude != null && 
            widget.parcel.longitude != null && 
            position.latitude != 0.0) {
          distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            widget.parcel.latitude!,
            widget.parcel.longitude!,
          );
          
          if (distance <= 500) {
            isValid = true;
          }
        } else {
          // If no destination coordinate provided, default to valid
          isValid = true;
        }

        setState(() {
          _distanceInMeters = distance;
          _isLocationValid = isValid;
          _validatingLocation = false;
        });
      } else {
        setState(() => _validatingLocation = false);
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _validatingLocation = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1024,
    );
    if (image != null && mounted) {
      setState(() => _proofPhoto = File(image.path));
    }
  }



  bool get _canSubmit {
    bool requiresName = ['Maid', 'Friend', 'Others'].contains(_acceptedBy);
    bool isNameProvided = !requiresName || _receiverNameController.text.trim().isNotEmpty;
    bool isRoleProvided = _acceptedBy != 'Others' || _customRoleController.text.trim().isNotEmpty;
    
    return _isLocationValid && 
           isNameProvided &&
           isRoleProvided &&
           (_hasSignature || _acceptedBy == 'Left at the Door') && 
           _proofPhoto != null && 
           !_isSubmitting;
  }

  Future<void> _submitDelivery() async {
    if (!_canSubmit || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      String? base64Signature;
      if (signatureBytes != null) {
        base64Signature = 'data:image/png;base64,${base64Encode(signatureBytes)}';
      }

      String role = _acceptedBy;
      if (_acceptedBy == 'Others') {
        role = _customRoleController.text.trim();
      }
      
      String finalAcceptedBy = role;
      if (['Maid', 'Friend', 'Others'].contains(_acceptedBy)) {
        finalAcceptedBy = "$role: ${_receiverNameController.text.trim()}";
      }

      final provider = Provider.of<ParcelProvider>(context, listen: false);
      final success = await provider.updateParcelStatus(
        widget.parcel.id,
        'delivered',
        otp: '',
        acceptedBy: finalAcceptedBy,
        receiverName: '', 
        signature: base64Signature,
        proofImage: _proofPhoto?.path,
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
        paymentMethod: _paymentMethod,
        remarks: _notesController.text,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery Completed Successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (mounted) {
         final errorMsg = provider.error ?? 'Check internet connection';
         debugPrint('DEBUG: POD Submit Failed: $errorMsg');
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $errorMsg'), backgroundColor: const Color(0xFFAE2E2F)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFAE2E2F)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ================= WIDGETS =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Proof of Delivery'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF042840),
      ),
      body: LoadingOverlay(
        key: const ValueKey('pod_loading_overlay'),
        isLoading: _isSubmitting,
        message: 'Submitting Proof of Delivery...',
        child: CustomScrollView(
          key: const ValueKey('pod_scroll_view'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Column(
                    key: const ValueKey('pod_static_column'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('1. Who accepted the delivery?'),
                      _buildAcceptedByOptions(),
                      
                      if (['Maid', 'Friend', 'Others'].contains(_acceptedBy)) ...[
                        const SizedBox(height: 16),
                        if (_acceptedBy == 'Others') ...[
                          _buildSectionHeader('Enter Relationship'),
                          TextFormField(
                            controller: _customRoleController,
                            decoration: InputDecoration(
                              labelText: 'Relationship (e.g. Brother, Security)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          _buildSectionHeader(_acceptedBy),
                        ],
                        
                        _buildSectionHeader('Recipient Name'),
                        TextFormField(
                          controller: _receiverNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter name of the person receiving',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],

                      const SizedBox(height: 24),
                      _buildSectionHeader('2. GPS Validation'),
                      _buildLocationStatus(),

                      if (_isLocationValid) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader('3. Customer Signature'),
                        RepaintBoundary(
                          key: const ValueKey('signature_boundary'),
                          child: _buildSignaturePad(),
                        ),

                        const SizedBox(height: 24),
                        _buildSectionHeader('4. Delivery Photo'),
                        RepaintBoundary(
                          key: const ValueKey('photo_boundary'),
                          child: _buildPhotoSelector(),
                        ),

                        const SizedBox(height: 24),
                        _buildSectionHeader('5. Notes & Payment'),
                        _buildTextField(
                          key: const ValueKey('notes_field'),
                          controller: _notesController,
                          label: 'Delivery Notes',
                          hint: 'Any special remarks...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildPaymentMethodSelector(),
                        
                        const SizedBox(height: 40),
                        _buildSubmitButton(),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF042840)),
      ),
    );
  }

  Widget _buildAcceptedByOptions() {
    final options = ['Self', 'Friend', 'Maid', 'Left at the Door', 'Others'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = _acceptedBy == opt;
        return InkWell(
          onTap: () => setState(() => _acceptedBy = opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF042840) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? const Color(0xFF042840) : Colors.grey.shade300),
            ),
            child: Text(
              opt,
              style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildLocationStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isLocationValid ? Colors.green.shade50 : (_validatingLocation ? const Color(0xFF042840).withOpacity(0.05) : const Color(0xFFAE2E2F).withOpacity(0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isLocationValid ? Colors.green.shade200 : (_validatingLocation ? const Color(0xFF042840).withOpacity(0.2) : const Color(0xFFAE2E2F).withOpacity(0.2))),
      ),
      child: Row(
        children: [
          if (_validatingLocation)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(
              _isLocationValid ? Icons.check_circle : Icons.error,
              color: _isLocationValid ? Colors.green : const Color(0xFFAE2E2F),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLocationValid ? 'Location Verified' : (_validatingLocation ? 'Verifying GPS...' : 'Invalid Location'),
                  style: TextStyle(fontWeight: FontWeight.bold, color: _isLocationValid ? Colors.green.shade700 : (_validatingLocation ? const Color(0xFF042840) : const Color(0xFFAE2E2F))),
                ),
                if (!_validatingLocation)
                   Text(
                     _isLocationValid 
                       ? 'You are within delivery radius (${_distanceInMeters.toStringAsFixed(0)}m)' 
                       : 'You are ${_distanceInMeters.toStringAsFixed(0)}m away. Move closer to proceed.',
                     style: const TextStyle(fontSize: 12),
                   ),
              ],
            ),
          ),
          if (!_validatingLocation && !_isLocationValid)
            IconButton(onPressed: _captureAndVerifyLocation, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }

  Widget _buildSignaturePad() {
    return Column(
      key: const ValueKey('signature_section'),
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RepaintBoundary(
              child: Signature(
                key: const ValueKey('signature_pad_widget'),
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () {
                _signatureController.clear();
                setState(() => _hasSignature = false);
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoSelector() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _proofPhoto != null
            ? ClipRRect(
                key: const ValueKey('photo_preview_container'),
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _proofPhoto!, 
                  key: ValueKey('photo_preview_${_proofPhoto!.path}'),
                  fit: BoxFit.cover,
                ),
              )
            : const Column(
                key: ValueKey('photo_placeholder'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 40, color: Color(0xFF042840)),
                  SizedBox(height: 8),
                  Text('Capture Delivery Photo', style: TextStyle(color: Colors.grey)),
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _paymentMethod,
              isExpanded: true,
              items: ['COD', 'Paid'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canSubmit ? _submitDelivery : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF042840),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: const Text(
          'CONFIRM DELIVERY',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
