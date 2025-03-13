import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/crop_calendar_model.dart';
import '../../controllers/crop_controller.dart';

class CropDetailScreen extends StatelessWidget {
  const CropDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CropController controller = Get.find<CropController>();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Get.back(),
        ),
        title: Obx(() {
          if (!controller.isLoadingCalendar.value && 
              controller.cropCalendar.value != null) {
            return Text(
              controller.cropCalendar.value!.cropId.name,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            );
          }
          return const Text(
            'Crop Details',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        }),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoadingCalendar.value) {
          return const Center(child: CircularProgressIndicator(color: AppColors.green));
        }

        if (controller.calendarError.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(controller.calendarError.value),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        final calendar = controller.cropCalendar.value;
        if (calendar == null) {
          return const Center(child: Text('No data available'));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(calendar),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCropInfo(calendar),
                    const SizedBox(height: 24),
                    _buildCalendarDetails(calendar),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader(CropCalendarModel calendar) {
    return Stack(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(calendar.cropId.imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: 250,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.transparent,
                Colors.black.withOpacity(0.6),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: Text(
            calendar.cropId.scientificName,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropInfo(CropCalendarModel calendar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          calendar.cropId.name,
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          calendar.cropId.scientificName,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          calendar.cropId.description,
          style: GoogleFonts.nunito(
            fontSize: 16,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          'Growing Period',
          '${calendar.cropId.growingPeriod} days',
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.green),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textGrey,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDetails(CropCalendarModel calendar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Crop Calendar'),
        const SizedBox(height: 16),
        _buildCalendarSection(
          'Growth Stage',
          calendar.growthStage,
          Icons.eco,
        ),
        _buildActivitiesList(calendar.activities),
        _buildWeatherInfo(calendar.weatherConsiderations),
        _buildTipsList('Tips', calendar.tips),
        _buildTipsList('Next Month Preparation', calendar.nextMonthPreparation),
        _buildIssuesList(calendar.possibleIssues),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.green,
      ),
    );
  }

  Widget _buildCalendarSection(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.green, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textGrey,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesList(List<Activity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Activities'),
        const SizedBox(height: 12),
        ...activities.map((activity) => Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: AppColors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Week ${activity.timing.week} - ${activity.timing.recommendedTime}',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activity.instructions,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.faintGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        activity.importance,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildWeatherInfo(WeatherConsiderations weather) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Weather Considerations'),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildWeatherRow(
                  'Temperature',
                  '${weather.idealTemperature.min}°C - ${weather.idealTemperature.max}°C',
                  Icons.thermostat,
                ),
                const Divider(),
                _buildWeatherRow(
                  'Rainfall',
                  weather.rainfall,
                  Icons.water_drop,
                ),
                const Divider(),
                _buildWeatherRow(
                  'Humidity',
                  weather.humidity,
                  Icons.water,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.textGrey,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipsList(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle(title),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items
                  .map((tip) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: AppColors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip,
                                style: GoogleFonts.nunito(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIssuesList(List<PossibleIssue> issues) {
    if (issues.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Possible Issues'),
        const SizedBox(height: 12),
        ...issues.map((issue) => Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.problem,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Solution: ${issue.solution}',
                      style: GoogleFonts.nunito(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preventive Measures:',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...issue.preventiveMeasures.map((measure) => Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_right, size: 20),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  measure,
                                  style: GoogleFonts.nunito(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            )),
      ],
    );
  }
} 