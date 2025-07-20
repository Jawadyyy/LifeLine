import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class HospitalService {
  static const _apiKey = 'c670b608bd2c4c859fae0e4e8a854ecb';

  static Future<List<Map<String, dynamic>>> getNearbyHospitals(
      LatLng position) async {
    final url =
        'https://api.geoapify.com/v2/places?categories=healthcare.hospital&filter=circle:${position.longitude},${position.latitude},5000&bias=proximity:${position.longitude},${position.latitude}&limit=10&apiKey=$_apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['features'] as List)
          .map((item) => {
                'name': item['properties']['name'] ?? 'Unknown Hospital',
                'lat': item['geometry']['coordinates'][1],
                'lon': item['geometry']['coordinates'][0],
              })
          .toList();
    } else {
      throw Exception('Failed to fetch hospitals');
    }
  }
}
