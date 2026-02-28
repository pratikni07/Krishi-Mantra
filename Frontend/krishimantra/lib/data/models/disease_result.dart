/// Represents a disease detection result from the AI model.
class DiseaseResult {
  final String diseaseName;
  final String cropName;
  final double confidence;
  final String description;
  final String treatment;
  final String prevention;
  final bool isHealthy;

  const DiseaseResult({
    required this.diseaseName,
    required this.cropName,
    required this.confidence,
    required this.description,
    required this.treatment,
    required this.prevention,
    this.isHealthy = false,
  });

  factory DiseaseResult.healthy(String cropName) => DiseaseResult(
        diseaseName: 'Healthy',
        cropName: cropName,
        confidence: 1.0,
        description: 'This leaf appears healthy with no visible signs of disease.',
        treatment: 'No treatment needed.',
        prevention: 'Continue regular care and monitoring.',
        isHealthy: true,
      );

  factory DiseaseResult.unknown() => const DiseaseResult(
        diseaseName: 'Unknown',
        cropName: 'Unknown',
        confidence: 0.0,
        description: 'Could not identify the disease. Please try again with a clearer image.',
        treatment: 'Consult an agricultural expert.',
        prevention: '',
      );
}
