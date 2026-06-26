import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EmergencyType {
  hospital,
  police,
}

class EmergencyService {
  static String get _apiKey => dotenv.env['GEOAPIFY_KEY'] ?? '';
  static const _cacheKeyPrefix = 'emergency_locations_';
  static const _cacheTimestampPrefix = 'emergency_timestamp_';
  static const _cacheDuration = Duration(hours: 24); // Cache for 24 hours

  /// Get nearby emergency locations (hospitals or police stations)
  static Future<List<Map<String, dynamic>>> getNearbyEmergencyLocations(
    LatLng position,
    EmergencyType type, {
    double radiusMeters = 5000,
    int limit = 10,
  }) async {
    // Try to get from cache first
    final cachedData = await _getCachedLocations(position, type);
    if (cachedData != null) {
      return cachedData;
    }

    // If no cache or expired, fetch from API
    try {
      final data = await _fetchFromApi(position, type, radiusMeters, limit);
      // Cache the results
      await _cacheLocations(position, type, data);
      return data;
    } catch (e) {
      // If API fails, try to return stale cache data if available
      final staleCache = await _getStaleCache(position, type);
      if (staleCache != null) {
        return staleCache;
      }
      rethrow;
    }
  }

  /// Fetch data from the API
  static Future<List<Map<String, dynamic>>> _fetchFromApi(
    LatLng position,
    EmergencyType type,
    double radiusMeters,
    int limit,
  ) async {
    final category = type == EmergencyType.hospital
        ? 'healthcare.hospital'
        : 'service.police';

    final url =
        'https://api.geoapify.com/v2/places?categories=$category&filter=circle:${position.longitude},${position.latitude},$radiusMeters&bias=proximity:${position.longitude},${position.latitude}&limit=$limit&apiKey=$_apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['features'] as List)
          .map((item) => {
                'name': item['properties']['name'] ??
                    (type == EmergencyType.hospital
                        ? 'Unknown Hospital'
                        : 'Police Station'),
                'lat': item['geometry']['coordinates'][1],
                'lon': item['geometry']['coordinates'][0],
                'type': type.toString(),
                'address': item['properties']['formatted'] ?? '',
                'city': item['properties']['city'] ?? '',
              })
          .toList();
    } else {
      throw Exception('Failed to fetch emergency locations');
    }
  }

  /// Get cached locations if they exist and are not expired
  static Future<List<Map<String, dynamic>>?> _getCachedLocations(
    LatLng position,
    EmergencyType type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey(position, type);
    final timestampKey = _getTimestampKey(position, type);

    final cachedJson = prefs.getString(cacheKey);
    final timestamp = prefs.getInt(timestampKey);

    if (cachedJson != null && timestamp != null) {
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      // Check if cache is still valid
      if (now.difference(cacheTime) < _cacheDuration) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    }

    return null;
  }

  /// Get stale cache data (even if expired) as fallback when offline
  static Future<List<Map<String, dynamic>>?> _getStaleCache(
    LatLng position,
    EmergencyType type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey(position, type);
    final cachedJson = prefs.getString(cacheKey);

    if (cachedJson != null) {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    return null;
  }

  /// Cache the locations data
  static Future<void> _cacheLocations(
    LatLng position,
    EmergencyType type,
    List<Map<String, dynamic>> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey(position, type);
    final timestampKey = _getTimestampKey(position, type);

    final jsonString = jsonEncode(data);
    await prefs.setString(cacheKey, jsonString);
    await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Generate cache key based on position and type
  static String _getCacheKey(LatLng position, EmergencyType type) {
    // Round coordinates to reduce cache fragmentation
    final lat = (position.latitude * 100).round() / 100;
    final lon = (position.longitude * 100).round() / 100;
    return '$_cacheKeyPrefix${type.toString()}_${lat}_$lon';
  }

  /// Generate timestamp key for cache
  static String _getTimestampKey(LatLng position, EmergencyType type) {
    final lat = (position.latitude * 100).round() / 100;
    final lon = (position.longitude * 100).round() / 100;
    return '$_cacheTimestampPrefix${type.toString()}_${lat}_$lon';
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_cacheTimestampPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Check if device is online
  static Future<bool> isOnline() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
