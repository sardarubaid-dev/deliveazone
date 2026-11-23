// lib/screens/main/scan_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/services/api_service.dart';
import 'package:deliveazone_driver_app/widgets/loading_indicator.dart';
import 'package:deliveazone_driver_app/models/api_response.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isLoading = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    // Explicitly stop the camera before disposing to prevent potential resource leaks or logs
    cameraController.stop();
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture barcodes) async {
    if (!_isScanning || _isLoading) return;

    final barcode = barcodes.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;

    // Prevent duplicate scans
    if (_lastScannedCode == code) return;
    _lastScannedCode = code;

    setState(() {
      _isScanning = false;
      _isLoading = true;
    });

    try {
      final provider = Provider.of<ParcelProvider>(context, listen: false);
      final result = await provider.scanParcel(code);

      if (!mounted) return;

      if (result.success) {
        final parcelData = result.data['parcel'] ?? result.data['order'];
        final parcel = Parcel.fromJson(parcelData);

        // Check for redirection arguments
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final redirectTo = args?['redirect_to'] as String?;

        if (redirectTo != null) {
          Navigator.pushReplacementNamed(
            context,
            redirectTo,
            arguments: parcel,
          );
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/parcel-detail',
            arguments: parcel,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Picked up: ${parcel.parcelNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFFAE2E2F),
          ),
        );

        // Resume scanning after error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
              _isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Scan failed. Please try again.'),
          backgroundColor: const Color(0xFFAE2E2F),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isScanning = true;
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
          actions: [
            IconButton(
              icon: Icon(
                cameraController.torchEnabled
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
              iconSize: 32,
              onPressed: () async {
                await cameraController.toggleTorch();
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              iconSize: 32,
              onPressed: () async {
                await cameraController.switchCamera();
              },
            ),
          ],
          
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleBarcode,
          ),
          // Scanner Overlay
          _ScannerOverlay(
            scanning: _isScanning,
            isLoading: _isLoading,
          ),
          // Instructions
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _isLoading ? 'Processing...' : 'Align QR code within frame',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoading
                        ? 'Please wait while we verify the parcel'
                        : 'Hold steady for automatic scan',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Removed invalid extension

class _ScannerOverlay extends StatelessWidget {
  final bool scanning;
  final bool isLoading;

  const _ScannerOverlay({
    required this.scanning,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed background
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              // Scanner window
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scanner border
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scanning ? const Color(0xFFAE2E2F) : Colors.grey,
                width: 3,
              ),
            ),
            child: isLoading
                ? const Center(
              child: LoadingIndicator(size: 30),
            )
                : scanning
                ? _ScanningAnimation()
                : null,
          ),
        ),
      ],
    );
  }
}

class _ScanningAnimation extends StatefulWidget {
  @override
  State<_ScanningAnimation> createState() => _ScanningAnimationState();
}

class _ScanningAnimationState extends State<_ScanningAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScannerPainter(_animation.value),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double value;

  _ScannerPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFAE2E2F).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final lineHeight = 2.0;
    final yPosition = size.height * value;

    canvas.drawRect(
      Rect.fromLTWH(0, yPosition, size.width, lineHeight),
      paint,
    );

    // Corner markers
    final cornerPaint = Paint()
      ..color = const Color(0xFFAE2E2F)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 20.0;

    // Top left
    canvas.drawLine(Offset.zero, const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(Offset.zero, const Offset(0, cornerLength), cornerPaint);

    // Top right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      cornerPaint,
    );

    // Bottom left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      cornerPaint,
    );

    // Bottom right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}