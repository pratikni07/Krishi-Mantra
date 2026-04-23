/// Minimum Support Price (MSP) data for 2025-26 Marketing Season.
/// Rates are in ₹ per Quintal (100 Kg).
class MSPData {
  MSPData._();

  static const Map<String, double> kharif2025 = {
    'Paddy (Common)': 2369.0,
    'Paddy (Grade A)': 2389.0,
    'Bajra': 2625.0,
    'Maize': 2225.0,
    'Tur (Arhar)': 7550.0,
    'Moong': 8682.0,
    'Urad': 7400.0,
    'Groundnut': 6783.0,
    'Sunflower Seed': 7280.0,
    'Soybean (Yellow)': 4892.0,
    'Sesamum': 9267.0,
    'Nigerseed': 8317.0,
    'Cotton (Medium Staple)': 7121.0,
    'Cotton (Long Staple)': 7521.0,
    'Jowar (Hybrid)': 3371.0,
    'Jowar (Maldandi)': 3421.0,
    'Ragi': 4290.0,
    'Sugarcane (FRP)': 340.0,
    'Jute': 5335.0,
  };

  static const Map<String, double> rabi2025 = {
    'Wheat': 2425.0,
    'Barley': 1980.0,
    'Gram': 5650.0,
    'Lentil (Masur)': 6700.0,
    'Rapeseed & Mustard': 5950.0,
    'Safflower': 5940.0,
  };

  /// Combines all MSP data for easy lookup
  static final Map<String, double> allMSP = {
    ...kharif2025,
    ...rabi2025,
  };

  /// Returns MSP for a given commodity name or 0.0 if not found
  static double getMSP(String commodity) {
    // Try exact match first
    if (allMSP.containsKey(commodity)) {
      return allMSP[commodity]!;
    }
    
    // Try partial match (case-insensitive)
    final query = commodity.toLowerCase();
    for (final entry in allMSP.entries) {
      if (query.contains(entry.key.toLowerCase()) || 
          entry.key.toLowerCase().contains(query)) {
        return entry.value;
      }
    }
    
    return 0.0;
  }
}
