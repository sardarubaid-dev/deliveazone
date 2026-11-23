// lib/models/delivery_status.dart
import 'package:flutter/material.dart';

enum DeliveryStatus {
  pending('Pending', 'pending', Colors.orange),
  assigned('Assigned', 'assigned', Colors.blue),
  pickedUp('Picked Up', 'picked_up', Colors.indigo),
  inTransit('In Transit', 'in_transit', Colors.purple),
  delivered('Delivered', 'delivered', Colors.green),
  failed('Failed', 'failed', Colors.red),
  returned('Returned', 'returned', Colors.grey);

  final String label;
  final String value;
  final Color color;

  const DeliveryStatus(this.label, this.value, this.color);

  static DeliveryStatus fromString(String value) {
    return DeliveryStatus.values.firstWhere(
          (status) => status.value == value,
      orElse: () => DeliveryStatus.pending,
    );
  }
}