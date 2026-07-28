// ============================================================
// DulceNav — weather_widget.dart
// Widget compacto, limpio y animado para mostrar el clima.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/weather_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/storage_service.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  WeatherInfo? _weatherInfo;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    // Actualizar cada 30 minutos
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) => _fetchWeather());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWeather({bool requestPermission = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final info = await WeatherService.instance.getWeather(requestPermission: requestPermission);
      if (mounted) {
        setState(() {
          _weatherInfo = info;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLocationDialog() {
    final storage = StorageService.instance;
    bool isManual = storage.manualLocationEnabled;
    
    final cityController = TextEditingController(text: storage.manualLocationCity);
    final latController = TextEditingController(text: storage.manualLocationLatitude.toString());
    final lonController = TextEditingController(text: storage.manualLocationLongitude.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF13131F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white10),
              ),
              title: const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text(
                    'Configurar Ubicación',
                    style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<bool>(
                      title: const Text('Ubicación Automática (GPS / IP)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: false,
                      groupValue: isManual,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setStateDialog(() {
                          isManual = val!;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: const Text('Ubicación Manual', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: true,
                      groupValue: isManual,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setStateDialog(() {
                          isManual = val!;
                        });
                      },
                    ),
                    if (isManual) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Presets rápidos:',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildPresetChip('Manizales', 5.0675, -75.5100, cityController, latController, lonController, setStateDialog),
                          _buildPresetChip('Bogotá', 4.7110, -74.0721, cityController, latController, lonController, setStateDialog),
                          _buildPresetChip('Medellín', 6.2442, -75.5812, cityController, latController, lonController, setStateDialog),
                          _buildPresetChip('Cali', 3.4516, -76.5320, cityController, latController, lonController, setStateDialog),
                        ],
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: cityController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          labelStyle: TextStyle(color: Colors.white60),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                        ),
                      ),
                      TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Latitud',
                          labelStyle: TextStyle(color: Colors.white60),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                        ),
                      ),
                      TextField(
                        controller: lonController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Longitud',
                          labelStyle: TextStyle(color: Colors.white60),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await storage.setManualLocationEnabled(isManual);
                    if (isManual) {
                      final lat = double.tryParse(latController.text) ?? 5.0675;
                      final lon = double.tryParse(lonController.text) ?? -75.5100;
                      await storage.setManualLocationCity(cityController.text.isNotEmpty ? cityController.text : 'Manizales');
                      await storage.setManualLocationLatitude(lat);
                      await storage.setManualLocationLongitude(lon);
                    }
                    Navigator.of(ctx).pop();
                    _fetchWeather(requestPermission: !isManual);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(
    String city,
    double lat,
    double lon,
    TextEditingController cityC,
    TextEditingController latC,
    TextEditingController lonC,
    void Function(void Function()) setStateDialog,
  ) {
    return ActionChip(
      backgroundColor: Colors.white10,
      label: Text(city, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      padding: EdgeInsets.zero,
      onPressed: () {
        setStateDialog(() {
          cityC.text = city;
          latC.text = lat.toString();
          lonC.text = lon.toString();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.instance;
    final primaryColor = theme.activePrimaryColor;
    final bool isDark = theme.isDarkMode;

    if (_isLoading && _weatherInfo == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
          ),
        ),
      );
    }

    final info = _weatherInfo;
    if (info == null) return const SizedBox.shrink();

    // Tooltip enriquecido en español
    final tooltipMsg = '${info.condition}\nHumedad: ${info.humidity}%\nViento: ${info.windSpeed.toStringAsFixed(1)} km/h\nPresiona para cambiar ubicación';

    return Tooltip(
      message: tooltipMsg,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _showLocationDialog,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.05),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  info.icon,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '${info.city}, ${info.temperature.toStringAsFixed(0)}°C',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DulceColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
