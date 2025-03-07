import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:weather_icons/weather_icons.dart';
import '../../../data/services/language_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // Custom color scheme
  static final customColors = {
    'primary': const Color.fromARGB(255, 116, 206, 88),
    'secondary': const Color(0xFF31A05F),
    'accent': const Color(0xFFE09F3E), // Warm orange
    'background': const Color(0xFFF5F3EF), // Light cream
    'cardBg': Colors.white,
    'textDark': const Color(0xFF2C3639), // Dark gray
    'textLight': const Color(0xFF6B7280), // Medium gray
  };

  String currentLocation = "Loading...";
  Position? currentPosition;
  bool isLoading = true;
  late LanguageService _languageService;

  // Translatable text
  String loadingText = "Loading...";
  String temperatureText = "Temperature";
  String humidityText = "Humidity";
  String cloudsText = "Clouds";
  String needHelpText = "Need Help?";
  String gotItText = "Got it";
  String searchSchemesText = "Search Schemes";
  String filterByCategoryText = "Filter by Category";
  String viewDetailsText = "View Details";
  String searchBarHintText = "Use the search bar to find specific schemes";
  String categoryFilterHintText =
      "Use category chips to filter schemes by type";
  String viewDetailsHintText =
      "Tap on any scheme to see full details and apply";
  String farmingTipsText = "Today's Farming Tips";
  String irrigationTipText = "Ideal for irrigation";
  String morningRecommendedText = "Morning hours recommended";
  String pestAlertText = "Pest Alert";
  String monitorPestText = "Monitor for increased pest activity";
  String todaysDetailsText = "Today's Details";
  String feelsLikeText = "Feels Like";
  String windSpeedText = "Wind Speed";
  String rainChanceText = "Rain Chance";
  String weeklyForecastText = "7-Day Forecast";
  String temperatureVariationText = "Temperature Variation";

  Map<String, dynamic> weatherData = {
    'temperature': 28,
    'feels_like': 30,
    'humidity': 65,
    'rain_chance': 30,
    'wind_speed': 12,
    'condition': 'Partly Cloudy',
  };

  List<Map<String, dynamic>> hourlyForecast = List.generate(24, (index) {
    return {
      'time': DateTime.now().add(Duration(hours: index)),
      'temperature': 25 + (index % 5),
      'condition': index % 2 == 0 ? 'Sunny' : 'Cloudy',
    };
  });

  List<Map<String, dynamic>> weeklyForecast = List.generate(7, (index) {
    return {
      'date': DateTime.now().add(Duration(days: index)),
      'max_temp': 30 + (index % 3),
      'min_temp': 22 + (index % 3),
      'condition': index % 2 == 0 ? 'Sunny' : 'Cloudy',
    };
  });

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Loading...'),
      _languageService.translate('Temperature'),
      _languageService.translate('Humidity'),
      _languageService.translate('Clouds'),
      _languageService.translate('Need Help?'),
      _languageService.translate('Got it'),
      _languageService.translate('Search Schemes'),
      _languageService.translate('Filter by Category'),
      _languageService.translate('View Details'),
      _languageService.translate('Use the search bar to find specific schemes'),
      _languageService
          .translate('Use category chips to filter schemes by type'),
      _languageService
          .translate('Tap on any scheme to see full details and apply'),
      _languageService.translate("Today's Farming Tips"),
      _languageService.translate('Ideal for irrigation'),
      _languageService.translate('Morning hours recommended'),
      _languageService.translate('Pest Alert'),
      _languageService.translate('Monitor for increased pest activity'),
      _languageService.translate("Today's Details"),
      _languageService.translate('Feels Like'),
      _languageService.translate('Wind Speed'),
      _languageService.translate('Rain Chance'),
      _languageService.translate('7-Day Forecast'),
      _languageService.translate('Temperature Variation'),
    ]);

    setState(() {
      loadingText = translations[0];
      temperatureText = translations[1];
      humidityText = translations[2];
      cloudsText = translations[3];
      needHelpText = translations[4];
      gotItText = translations[5];
      searchSchemesText = translations[6];
      filterByCategoryText = translations[7];
      viewDetailsText = translations[8];
      searchBarHintText = translations[9];
      categoryFilterHintText = translations[10];
      viewDetailsHintText = translations[11];
      farmingTipsText = translations[12];
      irrigationTipText = translations[13];
      morningRecommendedText = translations[14];
      pestAlertText = translations[15];
      monitorPestText = translations[16];
      todaysDetailsText = translations[17];
      feelsLikeText = translations[18];
      windSpeedText = translations[19];
      rainChanceText = translations[20];
      weeklyForecastText = translations[21];
      temperatureVariationText = translations[22];
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        currentPosition = position;
        currentLocation = "${placemarks[0].locality}, ${placemarks[0].country}";
        isLoading = false;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: customColors['background'],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              customColors['cardBg']!,
              customColors['background']!,
              customColors['background']!,
            ],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: customColors['primary'],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      _buildCurrentWeather(),
                      _buildFarmingAdvice(),
                      _buildWeatherDetails(),
                      _buildHourlyForecast(),
                      _buildWeeklyForecast(),
                      _buildTemperatureGraph(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: customColors['primary'],
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        currentLocation,
                        style: TextStyle(
                          color: customColors['textDark'],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  style: TextStyle(
                    color: customColors['textLight'],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: customColors['primary'],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _getCurrentLocation,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeather() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors['cardBg'],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: customColors['textLight']!.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weatherData['temperature']}°C',
                    style: TextStyle(
                      color: customColors['textDark'],
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    weatherData['condition'],
                    style: TextStyle(
                      color: customColors['textLight'],
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              BoxedIcon(
                WeatherIcons.day_cloudy,
                size: 80,
                color: customColors['accent'],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherInfo(
                WeatherIcons.humidity,
                '${weatherData['humidity']}%',
                humidityText,
              ),
              _buildWeatherInfo(
                WeatherIcons.rain,
                '${weatherData['rain_chance']}%',
                rainChanceText,
              ),
              _buildWeatherInfo(
                WeatherIcons.strong_wind,
                '${weatherData['wind_speed']} km/h',
                windSpeedText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        BoxedIcon(icon, size: 20, color: customColors['primary']),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: customColors['textDark'],
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: customColors['textLight'],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFarmingAdvice() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors['cardBg'],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: customColors['primary']!.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: customColors['textLight']!.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.agriculture,
                color: customColors['primary'],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                farmingTipsText,
                style: TextStyle(
                  color: customColors['textDark'],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem(
            Icons.water_drop,
            irrigationTipText,
            morningRecommendedText,
          ),
          const SizedBox(height: 8),
          _buildTipItem(
            Icons.pest_control,
            pestAlertText,
            monitorPestText,
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: customColors['primary']!.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: customColors['primary'], size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: customColors['textDark'],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: customColors['textLight'],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors['cardBg'],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: customColors['textLight']!.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            todaysDetailsText,
            style: TextStyle(
              color: customColors['textDark'],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(feelsLikeText, '${weatherData['feels_like']}°C'),
          _buildDetailRow(humidityText, '${weatherData['humidity']}%'),
          _buildDetailRow(windSpeedText, '${weatherData['wind_speed']} km/h'),
          _buildDetailRow(rainChanceText, '${weatherData['rain_chance']}%'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: customColors['textLight'],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: customColors['textDark'],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: hourlyForecast.length,
        itemBuilder: (context, index) {
          final forecast = hourlyForecast[index];
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: customColors['cardBg'],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: customColors['textLight']!.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  DateFormat('HH:mm').format(forecast['time']),
                  style:
                      TextStyle(color: customColors['textLight'], fontSize: 12),
                ),
                BoxedIcon(
                  forecast['condition'] == 'Sunny'
                      ? WeatherIcons.day_sunny
                      : WeatherIcons.day_cloudy,
                  size: 25,
                  color: customColors['accent'],
                ),
                Text(
                  '${forecast['temperature']}°C',
                  style: TextStyle(
                    color: customColors['textDark'],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyForecast() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors['cardBg'],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: customColors['textLight']!.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            weeklyForecastText,
            style: TextStyle(
              color: customColors['textDark'],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...weeklyForecast
              .map((forecast) => _buildDailyForecastItem(forecast)),
        ],
      ),
    );
  }

  Widget _buildDailyForecastItem(Map<String, dynamic> forecast) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              DateFormat('EEEE').format(forecast['date']),
              style: TextStyle(color: customColors['textLight'], fontSize: 14),
            ),
          ),
          BoxedIcon(
            forecast['condition'] == 'Sunny'
                ? WeatherIcons.day_sunny
                : WeatherIcons.day_cloudy,
            size: 20,
            color: customColors['accent'],
          ),
          Text(
            '${forecast['min_temp']}°C - ${forecast['max_temp']}°C',
            style: TextStyle(color: customColors['textDark'], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureGraph() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors['cardBg'],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: customColors['textLight']!.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            temperatureVariationText,
            style: TextStyle(
              color: customColors['textDark'],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: customColors['textLight']!.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 6,
                      getTitlesWidget: (value, meta) {
                        if (value % 6 == 0) {
                          final hour = value.toInt();
                          return Text(
                            '$hour:00',
                            style: TextStyle(
                              color: customColors['textLight'],
                              fontSize: 12,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}°',
                          style: TextStyle(
                            color: customColors['textLight'],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: hourlyForecast
                        .asMap()
                        .entries
                        .map((entry) => FlSpot(
                              entry.key.toDouble(),
                              entry.value['temperature'].toDouble(),
                            ))
                        .toList(),
                    isCurved: true,
                    color: customColors['primary'],
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: customColors['primary']!,
                          strokeWidth: 0,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: customColors['primary']!.withOpacity(0.1),
                    ),
                  ),
                ],
                minX: 0,
                maxX: 23,
                minY: 20,
                maxY: 35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
