import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import 'logger_service.dart';
import 'language_service.dart';

final _log = LoggerService();

/// WMO Weather Code descriptions (German/Romanian)
class WeatherCode {
  // Getter statt const: tr() muss bei jedem Zugriff die aktuelle Sprache lesen.
  static Map<int, String> get descriptions => {
    0: tr('Klar', 'Senin'),
    1: tr('Überwiegend klar', 'Predominant senin'),
    2: tr('Teilweise bewölkt', 'Parțial noros'),
    3: tr('Bewölkt', 'Noros'),
    45: tr('Nebel', 'Ceață'),
    48: tr('Nebel mit Reif', 'Ceață cu chiciură'),
    51: tr('Leichter Nieselregen', 'Burniță slabă'),
    53: tr('Nieselregen', 'Burniță'),
    55: tr('Starker Nieselregen', 'Burniță puternică'),
    56: tr('Gefrierender Nieselregen', 'Burniță care îngheață'),
    57: tr('Starker gefrierender Nieselregen', 'Burniță puternică care îngheață'),
    61: tr('Leichter Regen', 'Ploaie slabă'),
    63: tr('Regen', 'Ploaie'),
    65: tr('Starker Regen', 'Ploaie puternică'),
    66: tr('Gefrierender Regen', 'Ploaie care îngheață'),
    67: tr('Starker gefrierender Regen', 'Ploaie puternică care îngheață'),
    71: tr('Leichter Schneefall', 'Ninsoare slabă'),
    73: tr('Schneefall', 'Ninsoare'),
    75: tr('Starker Schneefall', 'Ninsoare puternică'),
    77: tr('Schneegriesel', 'Grăunțe de zăpadă'),
    80: tr('Leichte Regenschauer', 'Averse slabe de ploaie'),
    81: tr('Regenschauer', 'Averse de ploaie'),
    82: tr('Starke Regenschauer', 'Averse puternice de ploaie'),
    85: tr('Leichte Schneeschauer', 'Averse slabe de ninsoare'),
    86: tr('Starke Schneeschauer', 'Averse puternice de ninsoare'),
    95: tr('Gewitter', 'Furtună'),
    96: tr('Gewitter mit Hagel', 'Furtună cu grindină'),
    99: tr('Starkes Gewitter mit Hagel', 'Furtună puternică cu grindină'),
  };

  static String describe(int code) =>
      descriptions[code] ?? tr('Unbekannt', 'Necunoscut');

  static bool isRain(int code) => (code >= 51 && code <= 67) || (code >= 80 && code <= 82);
  static bool isSnow(int code) => (code >= 71 && code <= 77) || (code >= 85 && code <= 86);
  static bool isThunder(int code) => code >= 95 && code <= 99;
  static bool isSevere(int code) => code >= 65 || isThunder(code);

  static String icon(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (isThunder(code)) return '⛈️';
    if (isSnow(code)) return '🌨️';
    if (isRain(code)) return '🌧️';
    return '☁️';
  }
}

/// Current weather data
class WeatherData {
  final double temperature;
  final int weatherCode;
  final double windSpeed;
  final int humidity;
  final String city;
  final DateTime timestamp;

  WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.humidity,
    required this.city,
    required this.timestamp,
  });

  String get description => WeatherCode.describe(weatherCode);
  String get icon => WeatherCode.icon(weatherCode);
  bool get isRain => WeatherCode.isRain(weatherCode);
  bool get isSnow => WeatherCode.isSnow(weatherCode);
  bool get isThunder => WeatherCode.isThunder(weatherCode);
}

/// Hourly forecast entry
class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final double windSpeed;
  final int humidity;
  final double precipitation;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.humidity,
    required this.precipitation,
  });

  String get icon => WeatherCode.icon(weatherCode);
  String get description => WeatherCode.describe(weatherCode);
}

/// Daily forecast entry
class DailyForecast {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int weatherCode;
  final double precipitationSum;
  final double windSpeedMax;

  DailyForecast({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.weatherCode,
    required this.precipitationSum,
    required this.windSpeedMax,
  });

  String get icon => WeatherCode.icon(weatherCode);
  String get description => WeatherCode.describe(weatherCode);
}

/// DWD Weather Alert
class WeatherAlert {
  final String headline;
  final String description;
  final String severity; // minor, moderate, severe, extreme
  final String event;
  final String? instruction;
  final DateTime? onset;
  final DateTime? expires;

  WeatherAlert({
    required this.headline,
    required this.description,
    required this.severity,
    required this.event,
    this.instruction,
    this.onset,
    this.expires,
  });

  /// Show alerts that haven't expired yet (including upcoming ones)
  bool get isRelevant {
    final now = DateTime.now();
    if (expires != null && now.isAfter(expires!)) return false;
    return true;
  }

  String get severityLabel {
    switch (severity) {
      case 'extreme':
        return tr('Extrem', 'Extremă');
      case 'severe':
        return tr('Schwer', 'Severă');
      case 'moderate':
        return tr('Mäßig', 'Moderată');
      default:
        return tr('Leicht', 'Ușoară');
    }
  }
}

/// Weather service using Open-Meteo (free, no API key) + Bright Sky (DWD alerts)
class WeatherService {
  Timer? _weatherTimer;
  Timer? _alertTimer;
  double? _latitude;
  double? _longitude;
  String _city = '';

  WeatherData? currentWeather;
  List<WeatherAlert> currentAlerts = [];
  List<HourlyForecast> hourlyForecast = [];
  List<DailyForecast> dailyForecast = [];

  // Track last notified conditions to avoid spam
  int? _lastNotifiedWeatherCode;
  bool _lastNotifiedStrongWind = false;
  Set<String> _lastNotifiedAlertHeadlines = {};

  // Callbacks
  void Function(WeatherData)? onWeatherUpdate;
  void Function(List<WeatherAlert>)? onAlertsUpdate;

  final _client = http.Client();

  /// Start weather monitoring — accepts optional GPS coordinates
  Future<void> start(String city, {double? lat, double? lon}) async {
    _city = city;

    if (lat != null && lon != null) {
      _latitude = lat;
      _longitude = lon;
      _log.info('Weather: Starting with GPS ($_latitude, $_longitude)', tag: 'WEATHER');
    } else if (city.isNotEmpty) {
      _log.info('Weather: Starting for city "$city"', tag: 'WEATHER');
      final success = await _geocodeCity(city);
      if (!success) {
        _log.error('Weather: Could not geocode "$city"', tag: 'WEATHER');
        return;
      }
    } else {
      _log.info('Weather: No location provided, skipping', tag: 'WEATHER');
      return;
    }

    // Initial fetch
    await _fetchWeather();
    await _fetchAlerts();

    // Weather every 30 minutes
    _weatherTimer = Timer.periodic(const Duration(minutes: 30), (_) => _fetchWeather());

    // Alerts every 15 minutes
    _alertTimer = Timer.periodic(const Duration(minutes: 15), (_) => _fetchAlerts());
  }

  void stop() {
    _weatherTimer?.cancel();
    _alertTimer?.cancel();
    _weatherTimer = null;
    _alertTimer = null;
    _lastNotifiedWeatherCode = null;
    _lastNotifiedStrongWind = false;
    _lastNotifiedAlertHeadlines = {};
    _log.info('Weather: Stopped', tag: 'WEATHER');
  }

  /// Geocode city name to lat/lon using Open-Meteo Geocoding API
  Future<bool> _geocodeCity(String city) async {
    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1&language=de&format=json',
      );
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          _latitude = (results[0]['latitude'] as num).toDouble();
          _longitude = (results[0]['longitude'] as num).toDouble();
          _log.info('Weather: Geocoded "$city" → $_latitude, $_longitude', tag: 'WEATHER');
          return true;
        }
      }
      return false;
    } catch (e) {
      _log.error('Weather: Geocoding failed: $e', tag: 'WEATHER');
      return false;
    }
  }

  /// Fetch current weather + hourly + daily forecast from Open-Meteo
  Future<void> _fetchWeather() async {
    if (_latitude == null || _longitude == null) return;

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_latitude&longitude=$_longitude'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&hourly=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,precipitation'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max'
        '&timezone=Europe/Berlin'
        '&forecast_days=7',
      );
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Current weather
        final current = data['current'];
        if (current != null) {
          final weather = WeatherData(
            temperature: (current['temperature_2m'] as num).toDouble(),
            weatherCode: (current['weather_code'] as num).toInt(),
            windSpeed: (current['wind_speed_10m'] as num).toDouble(),
            humidity: (current['relative_humidity_2m'] as num).toInt(),
            city: _city,
            timestamp: DateTime.now(),
          );

          currentWeather = weather;
          onWeatherUpdate?.call(weather);
          _checkWeatherNotification(weather);

          _log.debug(
            'Weather: ${weather.icon} ${weather.temperature}°C, ${weather.description}, Wind: ${weather.windSpeed} km/h',
            tag: 'WEATHER',
          );
        }

        // Hourly forecast
        final hourly = data['hourly'];
        if (hourly != null) {
          final times = (hourly['time'] as List).cast<String>();
          final temps = (hourly['temperature_2m'] as List);
          final codes = (hourly['weather_code'] as List);
          final winds = (hourly['wind_speed_10m'] as List);
          final humids = (hourly['relative_humidity_2m'] as List);
          final precips = (hourly['precipitation'] as List);

          hourlyForecast = [];
          for (int i = 0; i < times.length; i++) {
            final t = DateTime.tryParse(times[i]);
            if (t != null) {
              hourlyForecast.add(HourlyForecast(
                time: t,
                temperature: (temps[i] as num).toDouble(),
                weatherCode: (codes[i] as num).toInt(),
                windSpeed: (winds[i] as num).toDouble(),
                humidity: (humids[i] as num).toInt(),
                precipitation: (precips[i] as num).toDouble(),
              ));
            }
          }
        }

        // Daily forecast
        final daily = data['daily'];
        if (daily != null) {
          final dates = (daily['time'] as List).cast<String>();
          final maxTemps = (daily['temperature_2m_max'] as List);
          final minTemps = (daily['temperature_2m_min'] as List);
          final codes = (daily['weather_code'] as List);
          final precips = (daily['precipitation_sum'] as List);
          final winds = (daily['wind_speed_10m_max'] as List);

          dailyForecast = [];
          for (int i = 0; i < dates.length; i++) {
            final d = DateTime.tryParse(dates[i]);
            if (d != null) {
              dailyForecast.add(DailyForecast(
                date: d,
                tempMax: (maxTemps[i] as num).toDouble(),
                tempMin: (minTemps[i] as num).toDouble(),
                weatherCode: (codes[i] as num).toInt(),
                precipitationSum: (precips[i] as num).toDouble(),
                windSpeedMax: (winds[i] as num).toDouble(),
              ));
            }
          }
        }
      }
    } catch (e) {
      _log.error('Weather: Fetch failed: $e', tag: 'WEATHER');
    }
  }

  /// Fetch DWD alerts from Bright Sky API
  Future<void> _fetchAlerts() async {
    if (_latitude == null || _longitude == null) return;

    try {
      final uri = Uri.parse(
        'https://api.brightsky.dev/alerts?lat=$_latitude&lon=$_longitude',
      );
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final alertsJson = data['alerts'] as List? ?? [];

        final alerts = alertsJson.map<WeatherAlert>((a) {
          return WeatherAlert(
            headline: a['headline_de'] ?? a['headline'] ?? '',
            description: a['description_de'] ?? a['description'] ?? '',
            severity: a['severity'] ?? 'minor',
            event: a['event_de'] ?? a['event'] ?? '',
            instruction: a['instruction_de'] ?? a['instruction'],
            onset: a['onset'] != null ? DateTime.tryParse(a['onset']) : null,
            expires: a['expires'] != null ? DateTime.tryParse(a['expires']) : null,
          );
        }).where((a) => a.isRelevant).toList();

        currentAlerts = alerts;
        onAlertsUpdate?.call(alerts);

        // Notify new alerts
        _checkAlertNotifications(alerts);

        _log.info('Weather: ${alerts.length} DWD warning(s) for $_city', tag: 'WEATHER');
      }
    } catch (e) {
      _log.error('Weather: Alerts fetch failed: $e', tag: 'WEATHER');
    }
  }

  /// Send notification when weather changes to rain/snow/thunder
  void _checkWeatherNotification(WeatherData weather) {
    // Only notify on change (not same code repeatedly)
    if (_lastNotifiedWeatherCode == weather.weatherCode) return;

    String? title;
    String? body;

    if (weather.isThunder) {
      title = tr('⛈️ Gewitter in $_city', '⛈️ Furtună în $_city');
      body = '${weather.description} • ${weather.temperature.toStringAsFixed(0)}°C';
    } else if (weather.isSnow) {
      title = tr('🌨️ Schneefall in $_city', '🌨️ Ninsoare în $_city');
      body = '${weather.description} • ${weather.temperature.toStringAsFixed(0)}°C';
    } else if (weather.isRain) {
      title = tr('🌧️ Regen in $_city', '🌧️ Ploaie în $_city');
      body = '${weather.description} • ${weather.temperature.toStringAsFixed(0)}°C';
    }

    if (title != null && body != null) {
      _lastNotifiedWeatherCode = weather.weatherCode;
      NotificationService().show(
        title: title,
        body: body,
      );
      _log.info('Weather: Notification sent - $title', tag: 'WEATHER');
    } else {
      // Reset when weather clears
      _lastNotifiedWeatherCode = weather.weatherCode;
    }

    // Wind notification (separate from weather code)
    final isStrongWind = weather.windSpeed >= 50;
    if (isStrongWind && !_lastNotifiedStrongWind) {
      _lastNotifiedStrongWind = true;
      NotificationService().show(
        title: tr('💨 Starker Wind in $_city', '💨 Vânt puternic în $_city'),
        body: tr('Windgeschwindigkeit: ${weather.windSpeed.toStringAsFixed(0)} km/h',
            'Viteza vântului: ${weather.windSpeed.toStringAsFixed(0)} km/h'),
      );
      _log.info('Weather: Wind notification sent - ${weather.windSpeed} km/h', tag: 'WEATHER');
    } else if (!isStrongWind) {
      _lastNotifiedStrongWind = false;
    }
  }

  /// Send notification for new DWD weather alerts
  void _checkAlertNotifications(List<WeatherAlert> alerts) {
    for (final alert in alerts) {
      if (!_lastNotifiedAlertHeadlines.contains(alert.headline)) {
        _lastNotifiedAlertHeadlines.add(alert.headline);

        String severityIcon;
        switch (alert.severity) {
          case 'extreme':
            severityIcon = '🔴';
            break;
          case 'severe':
            severityIcon = '🟠';
            break;
          case 'moderate':
            severityIcon = '🟡';
            break;
          default:
            severityIcon = '🟢';
        }

        NotificationService().show(
          title: tr('$severityIcon DWD Warnung: ${alert.event}',
              '$severityIcon Avertizare DWD: ${alert.event}'),
          body: alert.headline,
        );
        _log.info('Weather: DWD alert notification - ${alert.headline}', tag: 'WEATHER');
      }
    }
  }

  /// Update location (e.g. when GPS detects a new city) and re-fetch
  Future<void> updateLocation(String city, {required double lat, required double lon}) async {
    _city = city;
    _latitude = lat;
    _longitude = lon;
    _log.info('Weather: Location updated → $city ($lat, $lon)', tag: 'WEATHER');
    await _fetchWeather();
    await _fetchAlerts();
  }

  /// Force refresh weather + alerts
  Future<void> refresh() async {
    await _fetchWeather();
    await _fetchAlerts();
  }
}
