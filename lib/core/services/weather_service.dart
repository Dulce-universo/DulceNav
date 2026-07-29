// ============================================================
// DulceNav — weather_service.dart
// Servicio para consultar el clima usando la API de Open-Meteo.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'location_service.dart';
import 'storage_service.dart';

class WeatherInfo {
  final String city;
  final double temperature;
  final String condition;
  final IconData icon;
  final int humidity;        // Humedad en %
  final double windSpeed;    // Velocidad del viento en km/h

  WeatherInfo({
    required this.city,
    required this.temperature,
    required this.condition,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
  });
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  Future<WeatherInfo> getWeather({bool requestPermission = false}) async {
    try {
      // 1. Obtener la ubicación actual (Manual, GPS o IP)
      final loc = await LocationService.instance.getCurrentLocation(requestPermission: requestPermission);

      // 2. Consultar Open-Meteo usando latitud y longitud, pidiendo tanto 'current' como 'current_weather' para compatibilidad
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=${loc.latitude}&longitude=${loc.longitude}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&current_weather=true';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        final currentWeather = data['current_weather'];

        double temp = 20.0;
        int code = 0;
        int humidity = 60;
        double wind = 10.0;

        if (current != null) {
          temp = double.tryParse(current['temperature_2m']?.toString() ?? '') ?? 20.0;
          code = int.tryParse(current['weather_code']?.toString() ?? '') ?? 0;
          humidity = int.tryParse(current['relative_humidity_2m']?.toString() ?? '') ?? 60;
          wind = double.tryParse(current['wind_speed_10m']?.toString() ?? '') ?? 10.0;
        } else if (currentWeather != null) {
          temp = double.tryParse(currentWeather['temperature']?.toString() ?? '') ?? 20.0;
          code = int.tryParse(currentWeather['weathercode']?.toString() ?? '') ?? 0;
          wind = double.tryParse(currentWeather['windspeed']?.toString() ?? '') ?? 10.0;
        }

        final cond = _mapWeatherCode(code);
        try {
          StorageService.instance.saveCachedWeather(
            city: loc.city,
            temp: temp,
            condition: cond.condition,
            humidity: humidity,
            wind: wind,
            iconCode: code,
          );
        } catch (_) {}

        return WeatherInfo(
          city: loc.city,
          temperature: temp,
          condition: cond.condition,
          icon: cond.icon,
          humidity: humidity,
          windSpeed: wind,
        );
      }
    } catch (e) {
      debugPrint('[WeatherService] Error al obtener el clima: $e');
    }

    // Usar datos en caché guardados en StorageService
    final storage = StorageService.instance;
    final cachedCode = storage.weatherCachedIconCode;
    final cachedCond = _mapWeatherCode(cachedCode);
    return WeatherInfo(
      city: storage.weatherCachedCity,
      temperature: storage.weatherCachedTemp,
      condition: storage.weatherCachedCondition,
      icon: cachedCond.icon,
      humidity: storage.weatherCachedHumidity,
      windSpeed: storage.weatherCachedWind,
    );
  }

  _ConditionInfo _mapWeatherCode(int code) {
    switch (code) {
      case 0:
        return _ConditionInfo('Despejado', Icons.wb_sunny_rounded);
      case 1:
      case 2:
        return _ConditionInfo('Parcialmente Nublado', Icons.cloud_queue_rounded);
      case 3:
        return _ConditionInfo('Nublado', Icons.wb_cloudy_rounded);
      case 45:
      case 48:
        return _ConditionInfo('Niebla', Icons.blur_on_rounded);
      case 51:
      case 53:
      case 55:
        return _ConditionInfo('Llovizna', Icons.grain_rounded);
      case 61:
      case 63:
      case 65:
        return _ConditionInfo('Lluvia', Icons.umbrella_rounded);
      case 71:
      case 73:
      case 75:
        return _ConditionInfo('Nieve', Icons.ac_unit_rounded);
      case 80:
      case 81:
      case 82:
        return _ConditionInfo('Lluvia Fuerte', Icons.umbrella_rounded);
      case 95:
      case 96:
      case 99:
        return _ConditionInfo('Tormenta', Icons.thunderstorm_rounded);
      default:
        return _ConditionInfo('Despejado', Icons.wb_sunny_rounded);
    }
  }
}

class _ConditionInfo {
  final String condition;
  final IconData icon;

  _ConditionInfo(this.condition, this.icon);
}
