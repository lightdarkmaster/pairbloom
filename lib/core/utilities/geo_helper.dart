import 'dart:math';

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:intl/intl.dart';

class TravelEstimate {
  const TravelEstimate(this.label, this.icon, this.hours, this.note);
  final String label, note;
  final IconData icon;
  final double hours;
}

/// Pure, offline geo maths: distance, midpoint, travel estimates and the
/// share-code format two phones use to exchange a location.
class GeoHelper {
  static const _earthKm = 6371.0088;
  static double _rad(double d) => d * pi / 180;

  /// Great-circle ("as the crow flies") distance in kilometres.
  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final s1 = sin(dLat / 2);
    final s2 = sin(dLng / 2);
    final a = s1 * s1 + cos(_rad(lat1)) * cos(_rad(lat2)) * s2 * s2;
    return 2 * _earthKm * asin(min(1.0, sqrt(a)));
  }

  static ({double lat, double lng}) midpoint(double lat1, double lng1, double lat2, double lng2) {
    final p1 = _rad(lat1), l1 = _rad(lng1), p2 = _rad(lat2), dl = _rad(lng2 - lng1);
    final bx = cos(p2) * cos(dl);
    final by = cos(p2) * sin(dl);
    final p3 = atan2(sin(p1) + sin(p2), sqrt((cos(p1) + bx) * (cos(p1) + bx) + by * by));
    final l3 = l1 + atan2(by, cos(p1) + bx);
    return (lat: p3 * 180 / pi, lng: ((l3 * 180 / pi + 540) % 360) - 180);
  }

  static String formatDistance(double km, bool miles) {
    final whole = NumberFormat('#,##0');
    if (miles) {
      final mi = km * 0.621371;
      if (mi < 0.1) return '${(mi * 5280).round()} ft';
      return mi < 10 ? '${mi.toStringAsFixed(1)} mi' : '${whole.format(mi.round())} mi';
    }
    if (km < 1) return '${(km * 1000).round()} m';
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${whole.format(km.round())} km';
  }

  static String formatHours(double h) {
    final totalMin = (h * 60).round();
    if (totalMin < 1) return '< 1 min';
    if (totalMin < 60) return '$totalMin min';
    final hrs = totalMin ~/ 60, m = totalMin % 60;
    if (hrs < 48) return m == 0 ? '$hrs h' : '$hrs h $m min';
    final days = hrs ~/ 24, rh = hrs % 24;
    return rh == 0 ? '$days days' : '$days days $rh h';
  }

  /// Rough travel-time estimates from the straight-line distance. Real routes
  /// need maps and traffic data, which an offline app does not have.
  static List<TravelEstimate> estimates(double km) {
    final out = <TravelEstimate>[];
    if (km <= 50) out.add(TravelEstimate('Walking', Icons.directions_walk_rounded, km * 1.2 / 5, 'about 5 km/h'));
    if (km <= 200) out.add(TravelEstimate('Cycling', Icons.directions_bike_rounded, km * 1.2 / 15, 'about 15 km/h'));
    final road = km * 1.3;
    final speed = road > 150 ? 70.0 : 45.0;
    out.add(TravelEstimate('Driving', Icons.directions_car_rounded, road / speed, '~${road.round()} km by road'));
    if (km >= 300) out.add(TravelEstimate('Flying', Icons.flight_rounded, km / 800 + 2.5, 'incl. airport time'));
    return out;
  }

  static String mapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  /// Message a partner can paste into PairBloom (the PB1 line carries the data).
  static String shareMessage(String name, double lat, double lng, DateTime at) =>
      "📍 $name's location (shared from PairBloom)\n${mapsUrl(lat, lng)}\n"
      'PB1:${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)},${at.millisecondsSinceEpoch ~/ 1000}';

  static bool _valid(double lat, double lng) => lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  /// Understands a PairBloom share message, a Google Maps link, or plain "lat, lng".
  static ({double lat, double lng, DateTime? at, bool isCode})? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final code = RegExp(r'PB1:(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)(?:,(\d+))?').firstMatch(text);
    if (code != null) {
      final lat = double.parse(code.group(1)!), lng = double.parse(code.group(2)!);
      final secs = code.group(3);
      final at = secs == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(secs) * 1000);
      return _valid(lat, lng) ? (lat: lat, lng: lng, at: at, isCode: true) : null;
    }

    final patterns = [
      RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
      RegExp(r'[?&](?:q|query|ll)=(-?\d+(?:\.\d+)?)(?:,|%2C)(-?\d+(?:\.\d+)?)'),
      RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)\s*$'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m == null) continue;
      final lat = double.parse(m.group(1)!), lng = double.parse(m.group(2)!);
      if (_valid(lat, lng)) return (lat: lat, lng: lng, at: null, isCode: false);
    }
    return null;
  }
}
