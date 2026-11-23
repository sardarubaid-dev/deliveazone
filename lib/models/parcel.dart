import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Parcel {
  final int id;
  final String parcelNumber;
  final int? driverId;
  final String senderName;
  final String senderPhone;
  final String senderAddress;
  final String receiverName;
  final String receiverPhone;
  final String receiverAddress;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String status;
  final String? qrCode;
  final double? amount;
  final String? remarks;
  final String? proofImage;
  final String? acceptedBy;
  final String? signature;
  final String? deliveryOtp;
  final String? paymentMethod;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRescheduled;
  final DateTime? rescheduledDate;

  final double? pickupLatitude;
  final double? pickupLongitude;

  Parcel({
    required this.id,
    required this.parcelNumber,
    this.driverId,
    required this.senderName,
    required this.senderPhone,
    required this.senderAddress,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverAddress,
    this.latitude,
    this.longitude,
    this.pickupLatitude,
    this.pickupLongitude,
    this.description,
    required this.status,
    this.qrCode,
    this.amount,
    this.remarks,
    this.proofImage,
    this.acceptedBy,
    this.signature,
    this.deliveryOtp,
    this.paymentMethod,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
    this.isRescheduled = false,
    this.rescheduledDate,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty || value == 'NULL') return null;
    try {
      String dateStr = value.toString();
      // If it doesn't have a timezone indicator, assume it's UTC (standard for many backends)
      if (!dateStr.contains('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
        // Handle common Laravel format: "2026-01-22 12:51:01"
        if (dateStr.contains(' ')) {
          dateStr = dateStr.replaceFirst(' ', 'T') + 'Z';
        } else {
          dateStr += 'Z';
        }
      }
      return DateTime.tryParse(dateStr)?.toLocal();
    } catch (e) {
      return null;
    }
  }

  factory Parcel.fromJson(Map<String, dynamic> json) {
    return Parcel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      parcelNumber: json['parcel_number']?.toString() ?? '',
      driverId: json['driver_id'] is int ? json['driver_id'] : int.tryParse(json['driver_id']?.toString() ?? ''),
      senderName: json['sender_name']?.toString() ?? '',
      senderPhone: json['sender_phone']?.toString() ?? '',
      senderAddress: json['sender_address']?.toString() ?? '',
      receiverName: json['receiver_name']?.toString() ?? '',
      receiverPhone: json['receiver_phone']?.toString() ?? '',
      receiverAddress: json['receiver_address']?.toString() ?? '',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      pickupLatitude: json['pickup_latitude'] != null ? double.tryParse(json['pickup_latitude'].toString()) : null,
      pickupLongitude: json['pickup_longitude'] != null ? double.tryParse(json['pickup_longitude'].toString()) : null,
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      qrCode: json['qr_code']?.toString(),
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) : null,
      remarks: json['remarks']?.toString(),
      proofImage: json['proof_image']?.toString(),
      acceptedBy: json['accepted_by']?.toString(),
      signature: json['signature']?.toString(),
      deliveryOtp: json['delivery_otp']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      deliveryLatitude: json['delivery_latitude'] != null ? double.tryParse(json['delivery_latitude'].toString()) : null,
      deliveryLongitude: json['delivery_longitude'] != null ? double.tryParse(json['delivery_longitude'].toString()) : null,
      assignedAt: _parseDateTime(json['assigned_at']),
      pickedUpAt: _parseDateTime(json['picked_up_at']),
      deliveredAt: _parseDateTime(json['delivered_at']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      isRescheduled: json['is_rescheduled'] == 1 || json['is_rescheduled'] == true,
      rescheduledDate: _parseDateTime(json['rescheduled_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parcel_number': parcelNumber,
      'driver_id': driverId,
      'sender_name': senderName,
      'sender_phone': senderPhone,
      'sender_address': senderAddress,
      'receiver_name': receiverName,
      'receiver_phone': receiverPhone,
      'receiver_address': receiverAddress,
      'latitude': latitude,
      'longitude': longitude,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'description': description,
      'status': status,
      'qr_code': qrCode,
      'amount': amount,
      'remarks': remarks,
      'proof_image': proofImage,
      'accepted_by': acceptedBy,
      'signature': signature,
      'delivery_otp': deliveryOtp,
      'payment_method': paymentMethod,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'assigned_at': assignedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_rescheduled': isRescheduled,
      'rescheduled_date': rescheduledDate?.toIso8601String(),
    };
  }

  String get formattedCreatedAt => DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
  String? get formattedAssignedAt => assignedAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(assignedAt!)
      : null;
  String? get formattedPickedUpAt => pickedUpAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(pickedUpAt!)
      : null;
  String? get formattedDeliveredAt => deliveredAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(deliveredAt!)
      : null;

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pending';
      case 'assigned': return 'Assigned';
      case 'picked_up': return 'Picked Up';
      case 'in_transit': return 'In Transit';
      case 'delivered': return 'Delivered';
      case 'failed': 
        if (isRescheduled) {
          return rescheduledDate != null 
              ? 'Failed (Rescheduled: ${DateFormat('MMM dd').format(rescheduledDate!)})' 
              : 'Failed (Rescheduled)';
        }
        return 'Failed';
      case 'returned': return 'Returned';
      case 'rescheduled': return 'Rescheduled';
      default: return status;
    }
  }

  Color get statusColor {
    if (isRescheduled) return Colors.orange;
    
    switch (status) {
      case 'delivered': 
        return const Color(0xFF042840); // Navy for success/completed
      case 'failed': 
      case 'returned':
        return const Color(0xFFAE2E2F); // Red for issues/negative
      case 'pending':
      case 'assigned':
      case 'picked_up':
      case 'in_transit':
      case 'rescheduled':
      default:
        return const Color(0xFF042840); // Navy for all active/neutral states
    }
  }

  Parcel copyWith({
    int? id,
    String? parcelNumber,
    int? driverId,
    String? senderName,
    String? senderPhone,
    String? senderAddress,
    String? receiverName,
    String? receiverPhone,
    String? receiverAddress,
    double? latitude,
    double? longitude,
    double? pickupLatitude,
    double? pickupLongitude,
    String? description,
    String? status,
    String? qrCode,
    double? amount,
    String? remarks,
    String? proofImage,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRescheduled,
    DateTime? rescheduledDate,
  }) {
    return Parcel(
      id: id ?? this.id,
      parcelNumber: parcelNumber ?? this.parcelNumber,
      driverId: driverId ?? this.driverId,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      senderAddress: senderAddress ?? this.senderAddress,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      receiverAddress: receiverAddress ?? this.receiverAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      description: description ?? this.description,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      amount: amount ?? this.amount,
      remarks: remarks ?? this.remarks,
      proofImage: proofImage ?? this.proofImage,
      assignedAt: assignedAt ?? this.assignedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      rescheduledDate: rescheduledDate ?? this.rescheduledDate,
    );
  }
}