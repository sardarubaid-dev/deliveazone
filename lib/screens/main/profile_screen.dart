// lib/screens/main/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:deliveazone_driver_app/providers/auth_provider.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/widgets/loading_indicator.dart';
import 'package:deliveazone_driver_app/utils/helpers.dart';
import 'package:deliveazone_driver_app/utils/constants.dart';
import 'package:deliveazone_driver_app/models/user.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    await Future.wait([
      Provider.of<AuthProvider>(context, listen: false).refreshUserData(),
      Provider.of<ParcelProvider>(context, listen: false).loadAssignedParcels(),
      Provider.of<ParcelProvider>(context, listen: false).loadParcelHistory(),
    ]);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
        _isEditing = true; 
      });
    }
  }

  Future<void> _updateProfile() async {
    // Only image update allowed now
    if (_profileImage == null) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      
      // Send current user data + new image
      // Ensure all fields have non-null values to prevent validation errors
      final Map<String, dynamic> data = {
        'name': user?.name ?? '',
        'email': user?.email ?? '',
        'phone': user?.phone ?? '',
        'vehicle_number': user?.vehicleNumber ?? '',
        'vehicle_type': user?.vehicleType ?? '',
        'cnic': user?.cnic ?? '',
        'address': user?.address ?? '',
      };

      final success = await authProvider.updateProfile(
        data, 
        profileImagePath: _profileImage?.path
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: Color(0xFF042840),
            ),
          );
          setState(() {
            _isEditing = false;
            _profileImage = null;
          });
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? 'Failed to update photo'),
              backgroundColor: const Color(0xFFAE2E2F),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: const Color(0xFFAE2E2F),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    
    final parcelProvider = Provider.of<ParcelProvider>(context);
    
    final localStats = parcelProvider.getStatistics();
    
    // Use the same keys as home screen for consistency
    final assignedCount = parcelProvider.assignedParcels.length; 
    final deliveredTodayCount = parcelProvider.statistics?['today_deliveries'] ?? localStats['this_month_deliveries'] ?? 0;
    final totalDelivered = localStats['total_deliveries'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Update Photo' : 'My Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        actions: [
          if (!_isEditing)
          IconButton(
             icon: const Icon(Icons.settings_outlined),
             onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          if (_isEditing)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isEditing = false;
                _profileImage = null;
              });
            },
          ),
        ],
      ),
      body: _isLoading && user == null 
        ? const LoadingIndicator()
        : Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: const Color(0xFF042840),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600), // Better for tablets
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildModernHeader(user),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildStatItem('Active', '$assignedCount', Icons.local_shipping_outlined, context),
                                      const SizedBox(width: 8),
                                      _buildStatItem('Today', '$deliveredTodayCount', Icons.check_circle_outline, context),
                                      const SizedBox(width: 8),
                                      _buildStatItem('Total', '$totalDelivered', Icons.history, context),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  _buildSectionTitle('VEHICLE INFORMATION'),
                                  const SizedBox(height: 12),
                                  _buildVehicleCard(user),
                                  const SizedBox(height: 32),
                                  _buildSectionTitle('PERSONAL INFORMATION'),
                                  const SizedBox(height: 12),
                                  _buildPersonalDetailsCard(user),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _profileImage = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF042840),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('SAVE PHOTO', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title, 
      style: const TextStyle(
        fontSize: 12, 
        fontWeight: FontWeight.w800, 
        color: Color(0xFF64748B), 
        letterSpacing: 1.2
      )
    );
  }

  Widget _buildModernHeader(User? user) {
    bool isOnline = user?.availability == 'online';
    
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF042840),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 108,
                    height: 108,
                    child: ClipOval(
                      child: _profileImage != null 
                          ? Image.file(_profileImage!, fit: BoxFit.cover)
                          : (user?.profilePhoto != null 
                              ? Image.network(
                                  (() {
                                    String photoPath = user!.profilePhoto!;
                                    if (!photoPath.startsWith('http')) {
                                      if (!photoPath.startsWith('uploads/') && !photoPath.startsWith('/uploads/')) {
                                        photoPath = 'uploads/${photoPath.startsWith('/') ? photoPath.substring(1) : photoPath}';
                                      }
                                      photoPath = photoPath.startsWith('/') 
                                          ? '${ApiConstants.baseUrl}$photoPath' 
                                          : '${ApiConstants.baseUrl}/$photoPath';
                                    }
                                    return photoPath;
                                  })(),
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: Center(
                                        child: Text(
                                          (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF042840)),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: Center(
                                    child: Text(
                                      (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF042840)),
                                    ),
                                  ),
                                )),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAE2E2F),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            user?.name ?? 'Loading...',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
          ),
          
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Removed Active/Offline status container per user request
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Delivery Partner', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          
          if (!_isEditing) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: const Text('CHANGE PHOTO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAE2E2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                elevation: 4,
                shadowColor: Colors.black26,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isSmall = screenWidth <= 340;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 16, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // Slightly smaller radius
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isSmall ? 6 : 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF042840), size: isSmall ? 18 : 22),
            ),
            SizedBox(height: isSmall ? 6 : 10),
            Text(
              value, 
              style: TextStyle(
                fontSize: isSmall ? 16 : 18, 
                fontWeight: FontWeight.bold, 
                color: const Color(0xFF042840)
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label, 
              style: TextStyle(
                fontSize: isSmall ? 10 : 11, 
                color: const Color(0xFF94A3B8), 
                fontWeight: FontWeight.w600
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(User? user) {
     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
       ),
       child: Column(
         children: [
           Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: const Color(0xFFF1F5F9),
                   borderRadius: BorderRadius.circular(14),
                 ),
                 child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF042840), size: 28),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text(
                       'Vehicle Details',
                       style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                     ),
                     const SizedBox(height: 4),
                      Text(
                        '${user?.vehicleType ?? "Not Set"} • ${user?.vehicleNumber ?? "Not Set"}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF042840)),
                      ),
                   ],
                 ),
               ),
             ],
           ),
         ],
       ),
     );
  }

  Widget _buildPersonalDetailsCard(User? user) {
    return Container(
      decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(20),
         boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
         ],
         border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          _buildDetailTile(Icons.email_outlined, 'Email Address', user?.email ?? '-'),
          _buildDetailTile(Icons.phone_outlined, 'Phone Number', user?.phone ?? '-'),
          _buildDetailTile(Icons.badge_outlined, 'Emirates ID', user?.cnic ?? '-'),
          _buildDetailTile(Icons.location_on_outlined, 'Residential Address', user?.address ?? '-'),
          _buildDetailTile(
            Icons.calendar_month_outlined, 
            'Member Since', 
            user != null ? DateFormat('dd MMMM, yyyy').format(user.createdAt) : '-', 
            isLast: true
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: const Color(0xFFF8FAFC),
               borderRadius: BorderRadius.circular(10),
             ),
             child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                 const SizedBox(height: 2),
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 6),
                   child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF042840))),
                 ),
               ],
             ),
           )
        ],
      ),
    );
  }
}