// lib/widgets/parcel_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:deliveazone_driver_app/utils/helpers.dart';
import 'package:deliveazone_driver_app/widgets/status_badge.dart';

class ParcelCard extends StatelessWidget {
  final Parcel parcel;
  final VoidCallback? onTap;
  final bool showActions;

  const ParcelCard({
    super.key,
    required this.parcel,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Theme handles elevation/shape (flat, bordered)
      child: InkWell(
        onTap:
            onTap ??
            () => Navigator.pushNamed(
              context,
              '/parcel-detail',
              arguments: parcel,
            ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width <= 340 ? 12 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: ID + Status + Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parcel.parcelNumber,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF042840),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Receiver Name & Date Row
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              parcel.receiverName,
                              style: const TextStyle(
                                fontSize: 13, // Slightly smaller
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF042840),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (parcel.receiverName.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              parcel.status == 'delivered' &&
                                      parcel.deliveredAt != null
                                  ? Helpers.formatDateTime(parcel.deliveredAt!)
                                  : [
                                      'failed',
                                      'returned',
                                      'rescheduled',
                                    ].contains(parcel.status)
                                  ? Helpers.formatDateTime(parcel.updatedAt)
                                  : Helpers.formatDateTime(parcel.createdAt),
                              style: TextStyle(
                                fontSize: 11, // Slightly smaller
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(
                        status: parcel.status,
                        isRescheduled: parcel.isRescheduled,
                        rescheduledDate: parcel.rescheduledDate,
                      ),
                      if (parcel.amount != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          Helpers.formatCurrency(parcel.amount!),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF042840),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Address Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      parcel.receiverAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Actions
              if (showActions && Helpers.isParcelInProgress(parcel)) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/parcel-detail',
                          arguments: parcel,
                        ),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text(
                          'DETAILS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: const Color(0xFF042840),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (['assigned', 'pending'].contains(parcel.status)) {
                            Navigator.pushNamed(
                              context,
                              '/scan',
                              arguments: {
                                'redirect_to': '/map-tracking',
                                'parcel': parcel,
                              },
                            );
                            return;
                          }
                          Navigator.pushNamed(
                            context,
                            '/map-tracking',
                            arguments: parcel,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Color(0xFF042840)),
                        ),
                        child: const Icon(
                          Icons.map,
                          size: 20,
                          color: Color(0xFF042840),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Helpers.launchPhone(parcel.receiverPhone),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Color(0xFF042840)),
                        ),
                        child: const Icon(
                          Icons.call,
                          size: 20,
                          color: Color(0xFF042840),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
