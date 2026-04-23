import 'models/disease_result.dart';

/// Static database of disease information for all 38 PlantVillage classes.
/// Each entry maps a label string to a DiseaseResult with treatment info.
class DiseaseInfo {
  DiseaseInfo._();

  /// Parse label like "Tomato___Early_blight" into crop and disease names.
  static (String crop, String disease) parseLabel(String label) {
    final parts = label.split('___');
    final crop = parts[0].replaceAll('_', ' ').trim();
    final disease = parts.length > 1
        ? parts[1].replaceAll('_', ' ').trim()
        : 'Unknown';
    return (crop, disease);
  }

  /// Get a DiseaseResult for a given label and confidence.
  static DiseaseResult getResult(String label, double confidence) {
    final (crop, disease) = parseLabel(label);
    final info = _diseaseDb[label];

    if (disease.toLowerCase() == 'healthy') {
      return DiseaseResult.healthy(crop);
    }

    return DiseaseResult(
      diseaseName: info?['name'] ?? disease,
      cropName: crop,
      confidence: confidence,
      description: info?['description'] ?? 'Disease detected on $crop.',
      treatment: info?['treatment'] ?? 'Consult an agricultural expert for treatment.',
      prevention: info?['prevention'] ?? 'Maintain proper crop hygiene and rotation.',
    );
  }

  static const Map<String, Map<String, String>> _diseaseDb = {
    // ── Apple ──
    'Apple___Apple_scab': {
      'name': 'Apple Scab',
      'description':
          'Fungal disease causing olive-brown spots on leaves and dark, scabby lesions on fruit.',
      'treatment':
          'Apply fungicide (Mancozeb or Captan) during early spring. Remove infected leaves and fruit.',
      'prevention':
          'Plant resistant varieties. Ensure good air circulation. Remove fallen leaves in autumn.',
    },
    'Apple___Black_rot': {
      'name': 'Black Rot',
      'description':
          'Fungal disease causing brown leaf spots with purple borders and fruit rot with concentric rings.',
      'treatment':
          'Prune infected branches. Apply copper-based fungicide. Remove mummified fruit.',
      'prevention':
          'Keep orchard clean. Remove dead wood and fallen fruit. Ensure proper drainage.',
    },
    'Apple___Cedar_apple_rust': {
      'name': 'Cedar Apple Rust',
      'description':
          'Fungal disease causing yellow-orange spots on leaves, often with tube-like structures underneath.',
      'treatment':
          'Apply myclobutanil or sulfur-based fungicide at petal fall stage.',
      'prevention':
          'Remove nearby cedar trees. Plant resistant apple varieties.',
    },

    // ── Cherry ──
    'Cherry_(including_sour)___Powdery_mildew': {
      'name': 'Powdery Mildew',
      'description':
          'White powdery coating on leaves, shoots, and sometimes fruit of cherry trees.',
      'treatment':
          'Apply sulfur or potassium bicarbonate spray. Use neem oil for organic control.',
      'prevention':
          'Ensure good air circulation. Avoid overhead watering. Prune for open canopy.',
    },

    // ── Corn / Maize ──
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot': {
      'name': 'Gray Leaf Spot',
      'description':
          'Rectangular gray-brown lesions on corn leaves that run parallel to leaf veins.',
      'treatment':
          'Apply foliar fungicide (azoxystrobin). Remove infected plant debris.',
      'prevention':
          'Crop rotation with non-host crops. Plant resistant hybrids. Reduce residue tillage.',
    },
    'Corn_(maize)___Common_rust_': {
      'name': 'Common Rust',
      'description':
          'Small, circular to elongate reddish-brown pustules on both leaf surfaces.',
      'treatment':
          'Apply foliar fungicide (propiconazole) at early signs. Usually mild in impact.',
      'prevention':
          'Plant resistant hybrids. Early planting to avoid peak rust season.',
    },
    'Corn_(maize)___Northern_Leaf_Blight': {
      'name': 'Northern Leaf Blight',
      'description':
          'Long, cigar-shaped gray-green lesions on corn leaves that may merge to kill entire leaves.',
      'treatment':
          'Apply fungicide (azoxystrobin + propiconazole) at tasseling stage.',
      'prevention':
          'Rotate with soybeans. Plant resistant hybrids. Manage crop residue.',
    },

    // ── Grape ──
    'Grape___Black_rot': {
      'name': 'Black Rot',
      'description':
          'Brown circular lesions on leaves and shriveled black fruit (mummies) on grape clusters.',
      'treatment':
          'Apply Mancozeb or myclobutanil fungicide before bloom and after rain.',
      'prevention':
          'Remove mummified fruits. Prune for good air circulation. Manage canopy density.',
    },
    'Grape___Esca_(Black_Measles)': {
      'name': 'Esca (Black Measles)',
      'description':
          'Tiger-stripe pattern on leaves with dark spots, followed by sudden leaf wilting.',
      'treatment':
          'No effective chemical cure. Remove severely infected vines. Apply wound sealant after pruning.',
      'prevention':
          'Avoid large pruning wounds. Use double pruning technique. Protect wounds.',
    },
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)': {
      'name': 'Leaf Blight',
      'description':
          'Brown irregular spots with dark borders on grape leaves, leading to early leaf drop.',
      'treatment':
          'Apply copper-based fungicide. Remove infected leaves.',
      'prevention':
          'Maintain canopy airflow. Avoid overhead irrigation. Remove plant debris.',
    },

    // ── Orange ──
    'Orange___Haunglongbing_(Citrus_greening)': {
      'name': 'Citrus Greening (Huanglongbing)',
      'description':
          'Leaves show yellow mottling, fruit is small and lopsided with bitter taste. Deadly for citrus trees.',
      'treatment':
          'No cure exists. Remove infected trees. Control Asian citrus psyllid vector with insecticide.',
      'prevention':
          'Use disease-free nursery stock. Monitor for psyllid insects. Report to authorities.',
    },

    // ── Peach ──
    'Peach___Bacterial_spot': {
      'name': 'Bacterial Spot',
      'description':
          'Small dark spots on leaves leading to shot-hole appearance. Fruit gets cracked, sunken lesions.',
      'treatment':
          'Apply copper hydroxide or oxytetracycline spray during early bloom.',
      'prevention':
          'Plant resistant varieties. Avoid overhead irrigation. Ensure good air circulation.',
    },

    // ── Pepper ──
    'Pepper,_bell___Bacterial_spot': {
      'name': 'Bacterial Spot',
      'description':
          'Small, dark, water-soaked spots on leaves and fruit, leading to defoliation and sunscald.',
      'treatment':
          'Apply copper-based bactericide. Remove infected plants.',
      'prevention':
          'Use certified disease-free seeds. Avoid working with wet plants. Crop rotation.',
    },

    // ── Potato ──
    'Potato___Early_blight': {
      'name': 'Early Blight',
      'description':
          'Dark brown concentric ring spots (bull\'s-eye pattern) on older leaves, spreading upward.',
      'treatment':
          'Apply chlorothalonil or Mancozeb fungicide at first sign. Remove affected leaves.',
      'prevention':
          'Rotate crops (3-year cycle). Ensure adequate nutrition. Use certified seed potatoes.',
    },
    'Potato___Late_blight': {
      'name': 'Late Blight',
      'description':
          'Water-soaked dark lesions on leaves with white mold underneath. Can destroy entire crop rapidly.',
      'treatment':
          'Apply metalaxyl or cymoxanil fungicide immediately. Remove infected plants.',
      'prevention':
          'Use resistant varieties. Avoid overhead irrigation. Destroy volunteer plants.',
    },

    // ── Squash ──
    'Squash___Powdery_mildew': {
      'name': 'Powdery Mildew',
      'description':
          'White powdery patches on upper leaf surfaces, spreading to cover entire leaves.',
      'treatment':
          'Apply sulfur, neem oil, or potassium bicarbonate spray.',
      'prevention':
          'Plant resistant varieties. Space plants for airflow. Avoid late-season overhead watering.',
    },

    // ── Strawberry ──
    'Strawberry___Leaf_scorch': {
      'name': 'Leaf Scorch',
      'description':
          'Irregular dark purple spots on leaves that enlarge and merge, causing leaf edges to brown.',
      'treatment':
          'Apply captan or myclobutanil fungicide. Remove infected leaves.',
      'prevention':
          'Use drip irrigation. Remove old leaves after harvest. Plant resistant varieties.',
    },

    // ── Tomato ──
    'Tomato___Bacterial_spot': {
      'name': 'Bacterial Spot',
      'description':
          'Small, dark, greasy-looking spots on leaves and raised, scabby spots on fruit.',
      'treatment':
          'Apply copper hydroxide + mancozeb mixture. Remove severely infected plants.',
      'prevention':
          'Use certified disease-free seeds. Avoid overhead watering. Rotate crops.',
    },
    'Tomato___Early_blight': {
      'name': 'Early Blight',
      'description':
          'Dark concentric ring spots on older leaves (target pattern). Causes defoliation from bottom up.',
      'treatment':
          'Apply chlorothalonil or Mancozeb at first sign. Stake plants for air flow.',
      'prevention':
          'Mulch around plants. Rotate crops. Water at base, not overhead.',
    },
    'Tomato___Late_blight': {
      'name': 'Late Blight',
      'description':
          'Large, irregularly-shaped water-soaked lesions on leaves. White fuzzy mold on leaf undersides.',
      'treatment':
          'Apply metalaxyl-based fungicide immediately. Remove and destroy infected plants.',
      'prevention':
          'Use resistant varieties. Space plants widely. Avoid evening watering.',
    },
    'Tomato___Leaf_Mold': {
      'name': 'Leaf Mold',
      'description':
          'Pale green to yellow spots on upper leaf surface with olive-green fuzzy mold below.',
      'treatment':
          'Apply chlorothalonil fungicide. Improve greenhouse ventilation.',
      'prevention':
          'Reduce humidity. Ensure good airflow. Avoid leaf wetting.',
    },
    'Tomato___Septoria_leaf_spot': {
      'name': 'Septoria Leaf Spot',
      'description':
          'Many small circular spots with dark borders and gray centers on lower leaves.',
      'treatment':
          'Apply chlorothalonil or copper-based fungicide. Remove infected lower leaves.',
      'prevention':
          'Mulch around plants. Stake for airflow. Rotate crops (3 years).',
    },
    'Tomato___Spider_mites Two-spotted_spider_mite': {
      'name': 'Spider Mites',
      'description':
          'Tiny yellow dots on upper leaf surface, fine webbing underneath. Leaves turn bronze and dry.',
      'treatment':
          'Spray neem oil or insecticidal soap. Release predatory mites. Use miticide for severe cases.',
      'prevention':
          'Keep plants well-watered. Avoid dusty conditions. Introduce beneficial insects.',
    },
    'Tomato___Target_Spot': {
      'name': 'Target Spot',
      'description':
          'Brown spots with concentric rings on leaves, stems, and fruit. Similar to early blight.',
      'treatment':
          'Apply chlorothalonil or azoxystrobin fungicide. Remove affected leaves.',
      'prevention':
          'Maintain wide plant spacing. Mulch soil surface. Rotate crops.',
    },
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus': {
      'name': 'Yellow Leaf Curl Virus',
      'description':
          'Leaves curl upward and turn yellow. Plants become stunted. Spread by whiteflies.',
      'treatment':
          'No cure. Remove infected plants. Control whiteflies with imidacloprid or neem oil.',
      'prevention':
          'Use reflective mulch to repel whiteflies. Plant resistant varieties. Use insect nets.',
    },
    'Tomato___Tomato_mosaic_virus': {
      'name': 'Tomato Mosaic Virus',
      'description':
          'Mottled light and dark green patterns on leaves. Leaves may be distorted and fern-like.',
      'treatment':
          'No cure. Remove infected plants. Disinfect tools with 10% bleach solution.',
      'prevention':
          'Use virus-free seeds. Wash hands before handling. Do not use tobacco near plants.',
    },
  };
}
