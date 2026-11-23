// lib/utils/helpers.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';

class Helpers {
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  static String formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: 'AED ',
      decimalDigits: 2,
    ).format(amount);
  }

  static String formatAmount(num amount) {
    return NumberFormat('#,###.##').format(amount);
  }

  static String formatWeight(double weight) {
    return '${weight.toStringAsFixed(2)} kg';
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'assigned': return 'Assigned';
      case 'picked_up': return 'Picked Up';
      case 'in_transit': return 'In Transit';
      case 'delivered': return 'Delivered';
      case 'failed': return 'Failed';
      case 'returned': return 'Returned';
      case 'rescheduled': return 'Rescheduled';
      default: return status;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'assigned': return Colors.blue;
      case 'picked_up': return Colors.indigo;
      case 'in_transit': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'failed': return Colors.red;
      case 'returned': return Colors.grey;
      case 'rescheduled': return Colors.orange;
      default: return Colors.grey;
    }
  }

  static Future<void> launchPhone(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  static Future<void> launchMaps(double lat, double lng, {String? label}) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  static Future<void> launchDirections(double fromLat, double fromLng, double toLat, double toLng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&origin=$fromLat,$fromLng&destination=$toLat,$toLng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  static String getDurationString(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  static String truncateText(String text, {int maxLength = 30}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return 'D';
  }

  static bool isParcelInProgress(Parcel parcel) {
    return parcel.status == 'assigned' ||
        parcel.status == 'picked_up' ||
        parcel.status == 'in_transit';
  }

  static String calculateDeliveryTime(DateTime? pickedUpAt, DateTime? deliveredAt) {
    if (pickedUpAt == null || deliveredAt == null) return 'N/A';

    final duration = deliveredAt.difference(pickedUpAt);
    return getDurationString(duration);
  }
}