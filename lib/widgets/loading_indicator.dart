// lib/widgets/loading_indicator.dart
import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;
  final bool overlay;

  const LoadingIndicator({
    super.key,
    this.size = 30,
    this.color = const Color(0xFF042840),
    this.strokeWidth = 3,
    this.overlay = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget indicator = Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );

    if (overlay) {
      return ExcludeSemantics(
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: indicator,
        ),
      );
    }

    return indicator;
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content remains stable in the tree
        child,
        
        // Use a persistent Overlay layer that only paints when active
        if (isLoading) ...[
          // Block interaction
          const ModalBarrier(
            dismissible: false,
            color: Colors.transparent,
          ),
          
          // Visual overlay
          Container(
            key: const ValueKey('loading_overlay_active'),
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LoadingIndicator(size: 40),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message!,
                        style: const TextStyle(
                          color: Color(0xFF042840),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}