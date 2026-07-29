// ============================================================
// DulceNav — location_service.dart
// Servicio para obtener la ubicación aproximada del equipo.
// Soporta ubicación manual, GPS nativo, IP y fallback global.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'storage_service.dart';

class LocationData {
  final String city;
  final double latitude;
  final double longitude;

  LocationData({
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory LocationData.defaultLocation() {
    return LocationData(
      city: 'Manizales',
      latitude: 5.0675,
      longitude: -75.5100,
    );
  }
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<LocationData> getCurrentLocation({bool requestPermission = false}) async {
    final storage = StorageService.instance;

    // 1. Ubicación manual configurada por el usuario (si está activa)
    if (storage.manualLocationEnabled) {
      debugPrint('[LocationService] Usando ubicación manual configurada: ${storage.manualLocationCity}');
      return LocationData(
        city: storage.manualLocationCity,
        latitude: storage.manualLocationLatitude,
        longitude: storage.manualLocationLongitude,
      );
    }

    // 2. Intentar obtener ubicación nativa (GPS en Android / Location API en Windows)
    try {
      final nativePos = await _getNativePosition(requestPermission);
      if (nativePos != null) {
        String city = 'Mi Ubicación';
        
        // Reverse geocoding ultra-ligero usando OpenStreetMap Nominatim
        try {
          final geoUrl = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${nativePos.latitude}&lon=${nativePos.longitude}&zoom=10';
          final geoRes = await http.get(
            Uri.parse(geoUrl),
            headers: {'User-Agent': 'DulceNav/1.7.0'},
          ).timeout(const Duration(seconds: 3));

          if (geoRes.statusCode == 200) {
            final geoData = jsonDecode(geoRes.body);
            final address = geoData['address'];
            if (address != null) {
              city = address['city']?.toString() ??
                     address['town']?.toString() ??
                     address['village']?.toString() ??
                     address['county']?.toString() ??
                     'Mi Ubicación';
            }
          }
        } catch (_) {}

        debugPrint('[LocationService] Ubicación nativa exitosa: lat=${nativePos.latitude}, lon=${nativePos.longitude}, ciudad=$city');
        return LocationData(
          city: city,
          latitude: nativePos.latitude,
          longitude: nativePos.longitude,
        );
      }
    } catch (e) {
      debugPrint('[LocationService] Error al obtener ubicación nativa: $e');
    }

    // 3. Fallback a geolocalización por IP (ipapi.co)
    try {
      debugPrint('[LocationService] Intentando localización por IP (ipapi.co)...');
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final city = data['city']?.toString() ?? 'Manizales';
        final lat = double.tryParse(data['latitude']?.toString() ?? '') ?? 5.0675;
        final lon = double.tryParse(data['longitude']?.toString() ?? '') ?? -75.5100;
        return LocationData(city: city, latitude: lat, longitude: lon);
      }
    } catch (e) {
      // Fallback secundario por IP (ip-api.com)
      try {
        debugPrint('[LocationService] Intentando localización por IP (ip-api.com)...');
        final response = await http
            .get(Uri.parse('http://ip-api.com/json'))
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final city = data['city']?.toString() ?? 'Manizales';
          final lat = double.tryParse(data['lat']?.toString() ?? '') ?? 5.0675;
          final lon = double.tryParse(data['lon']?.toString() ?? '') ?? -75.5100;
          return LocationData(city: city, latitude: lat, longitude: lon);
        }
      } catch (_) {}
    }

    // 4. Ubicación por defecto global (Manizales, Caldas)
    debugPrint('[LocationService] Geolocalización fallida. Usando Manizales por defecto.');
    return LocationData.defaultLocation();
  }

  Future<Position?> _getNativePosition(bool requestIfNeeded) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] El servicio de ubicación nativo está desactivado.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!requestIfNeeded) {
          debugPrint('[LocationService] Permiso denegado. No se solicita en segundo plano.');
          return null;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Permiso de ubicación nativo denegado.');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Permiso de ubicación nativo denegado permanentemente.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (e) {
      debugPrint('[LocationService] Excepción al solicitar ubicación nativa: $e');
      return null;
    }
  }
}
