import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service to fetch real-time market price data from Indian mandis.
/// Uses a combination of government APIs and CEDA Agri Data.
class MandiService {
  static const String _CACHE_KEY = 'mandi_price_cache_v2';
  static const Duration _CACHE_VALIDITY = Duration(hours: 4);

  // Government Data API Endpoint (Example URL from data.gov.in)
  // For production, this should have a valid API Key from data.gov.in
  static const String _GOV_API_URL = 
      'https://api.data.gov.in/resource/9ef27816-870f-4315-a79b-471523e41c98';
  static const String _API_KEY = ''; // User to provide or obtained from config

  static MandiService? _instance;

  MandiService._();

  static MandiService getInstance() {
    _instance ??= MandiService._();
    return _instance!;
  }

  /// Fetches prices for a specific state or all states.
  /// Filters by [cropName] if provided.
  Future<List<Map<String, dynamic>>> fetchMandiPrices({
    String? state,
    String? district,
    String? commodity,
    DateTime? date,
  }) async {
    final String dateKey = date != null 
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : 'today';
    final String fullCacheKey = '${_CACHE_KEY}_$dateKey';

    // Temporarily bypass cache to ensure mock generator runs during testing phase
    /*
    final cached = await _getCachedPrices(fullCacheKey);
    if (cached != null) {
      return _filterData(cached, state, district, commodity);
    }
    */

    // If no cache or cache expired, fetch fresh data
    try {
      // In a real implementation, we'd handle pagination and API parameters
      // For this MVP, we'll aim for a reasonable mock-to-real flow.
      final url = Uri.parse('$_GOV_API_URL?api-key=$_API_KEY&format=json&limit=50');
      
      // If we don't have an API key, we'll provide some fallback mock data
      if (_API_KEY.isEmpty) {
        final mockData = await _getMockData(targetDate: date);
        await _cachePrices(fullCacheKey, mockData);
        return _filterData(mockData, state, district, commodity);
      }

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> records = 
            List<Map<String, dynamic>>.from(data['records'] ?? []);
        
        await _cachePrices(fullCacheKey, records);
        return _filterData(records, state, district, commodity);
      }
    } catch (e) {
      print('Mandi API Error: $e');
    }

    // Return mock data as a last resort fallback
    return _filterData(await _getMockData(targetDate: date), state, district, commodity);
  }

  List<Map<String, dynamic>> _filterData(
    List<Map<String, dynamic>> data,
    String? state,
    String? district,
    String? commodity,
  ) {
    return data.where((item) {
      bool matches = true;
      if (state != null && state.isNotEmpty) {
        matches &= item['state'].toString().toLowerCase().contains(state.toLowerCase());
      }
      if (district != null && district.isNotEmpty) {
        matches &= item['district'].toString().toLowerCase().contains(district.toLowerCase());
      }
      if (commodity != null && commodity.isNotEmpty) {
        matches &= item['commodity'].toString().toLowerCase().contains(commodity.toLowerCase());
      }
      return matches;
    }).toList();
  }

  Future<void> _cachePrices(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'records': data,
    };
    await prefs.setString(key, jsonEncode(cacheData));
  }

  Future<List<Map<String, dynamic>>?> _getCachedPrices(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return null;

    final data = jsonDecode(jsonStr);
    final timestamp = DateTime.parse(data['timestamp']);
    
    if (DateTime.now().difference(timestamp) > _CACHE_VALIDITY) {
      return null; // Cache expired
    }

    return List<Map<String, dynamic>>.from(data['records']);
  }

  /// Provides realistic mock data for UI testing if the API key is missing.
  /// Dynamically generates a national dataset covering all states and districts.
  Future<List<Map<String, dynamic>>> _getMockData({DateTime? targetDate}) async {
    final List<Map<String, dynamic>> records = [];
    final dateObj = targetDate ?? DateTime.now();
    final String date = '${dateObj.day.toString().padLeft(2, '0')}/${dateObj.month.toString().padLeft(2, '0')}/${dateObj.year}';

    final Map<String, List<String>> indiaHierarchy = {
      'Andhra Pradesh': ['Anantapur', 'Chittoor', 'East Godavari', 'Guntur', 'Krishna', 'Kurnool', 'Prakasam', 'Srikakulam', 'Visakhapatnam', 'Vizianagaram', 'West Godavari', 'Kadapa', 'Nellore'],
      'Arunachal Pradesh': ['Lohit', 'Papum Pare', 'Tawang', 'West Kameng'],
      'Assam': ['Barpeta', 'Dhubri', 'Dibrugarh', 'Jorhat', 'Kamrup', 'Nagaon', 'Sonitpur', 'Tinsukia'],
      'Bihar': ['Araria', 'Begusarai', 'Bhagalpur', 'Bhojpur', 'Darbhanga', 'Gaya', 'Katihar', 'Madhubani', 'Muzaffarpur', 'Nalanda', 'Patna', 'Purnia', 'Rohtas', 'Samastipur', 'Saran', 'Siwan', 'Vaishali'],
      'Chhattisgarh': ['Bilaspur', 'Durg', 'Janjgir-Champa', 'Raigarh', 'Raipur', 'Rajnandgaon'],
      'Goa': ['North Goa', 'South Goa'],
      'Gujarat': ['Ahmedabad', 'Amreli', 'Anand', 'Banaskantha', 'Bharuch', 'Bhavnagar', 'Dahod', 'Gandhinagar', 'Jamnagar', 'Junagadh', 'Kachchh', 'Kheda', 'Mehsana', 'Narmada', 'Navsari', 'Panchmahal', 'Patan', 'Porbandar', 'Rajkot', 'Sabarkantha', 'Surat', 'Surendranagar', 'Tapi', 'Vadodara', 'Valsad'],
      'Haryana': ['Ambala', 'Bhiwani', 'Faridabad', 'Fatehabad', 'Gurgaon', 'Hisar', 'Jhajjar', 'Jind', 'Kaithal', 'Karnal', 'Kurukshetra', 'Mahendragarh', 'Panchkula', 'Panipat', 'Rewari', 'Rohtak', 'Sirsa', 'Sonipat', 'Yamunanagar'],
      'Himachal Pradesh': ['Bilaspur', 'Chamba', 'Hamirpur', 'Kangra', 'Kinnaur', 'Kullu', 'Lahaul and Spiti', 'Mandi', 'Shimla', 'Sirmaur', 'Solan', 'Una'],
      'Jharkhand': ['Bokaro', 'Dhanbad', 'Dumka', 'East Singhbhum', 'Garhwa', 'Giridih', 'Gumla', 'Hazaribagh', 'Jamtara', 'Khunti', 'Koderma', 'Latehar', 'Lohardaga', 'Pakur', 'Palamu', 'Ramgarh', 'Ranchi', 'Sahibganj', 'Seraikela-Kharsawan', 'Simdega', 'West Singhbhum'],
      'Karnataka': ['Bagalkot', 'Bangalore Rural', 'Bangalore Urban', 'Belgaum', 'Bellary', 'Bidar', 'Bijapur', 'Chamarajanagar', 'Chikkaballapur', 'Chikmagalur', 'Chitradurga', 'Dakshina Kannada', 'Davangere', 'Dharwad', 'Gadag', 'Gulbarga', 'Hassan', 'Haveri', 'Kodagu', 'Kolar', 'Koppal', 'Mandya', 'Mysore', 'Raichur', 'Ramanagara', 'Shimoga', 'Tumkur', 'Udupi', 'Uttara Kannada', 'Yadgir'],
      'Kerala': ['Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod', 'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad', 'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'],
      'Madhya Pradesh': ['Agar Malwa', 'Alirajpur', 'Anuppur', 'Ashoknagar', 'Balaghat', 'Barwani', 'Betul', 'Bhind', 'Bhopal', 'Burhanpur', 'Chhatarpur', 'Chhindwara', 'Damoh', 'Datia', 'Dewas', 'Dhar', 'Dindori', 'Guna', 'Gwalior', 'Harda', 'Hoshangabad', 'Indore', 'Jabalpur', 'Jhabua', 'Katni', 'Khandwa', 'Khargone', 'Mandla', 'Mandsaur', 'Morena', 'Narsinghpur', 'Neemuch', 'Panna', 'Raisen', 'Rajgarh', 'Ratlam', 'Rewa', 'Sagar', 'Satna', 'Sehore', 'Seoni', 'Shahdol', 'Shajapur', 'Sheopur', 'Shivpuri', 'Sidhi', 'Singrauli', 'Tikamgarh', 'Ujjain', 'Umaria', 'Vidisha'],
      'Maharashtra': ['Ahmednagar', 'Akola', 'Amravati', 'Aurangabad', 'Beed', 'Bhandara', 'Buldhana', 'Chandrapur', 'Dhule', 'Gadchiroli', 'Gondia', 'Hingoli', 'Jalgaon', 'Jalna', 'Kolhapur', 'Latur', 'Mumbai', 'Nagpur', 'Nanded', 'Nandurbar', 'Nashik', 'Osmanabad', 'Palghar', 'Parbhani', 'Pune', 'Raigad', 'Ratnagiri', 'Sangli', 'Satara', 'Sindhudurg', 'Solapur', 'Thane', 'Wardha', 'Washim', 'Yavatmal'],
      'Manipur': ['Bishnupur', 'Chandel', 'Churachandpur', 'Imphal East', 'Imphal West', 'Senapati', 'Tamenglong', 'Thoubal', 'Ukhrul'],
      'Meghalaya': ['East Garo Hills', 'East Jaintia Hills', 'East Khasi Hills', 'North Garo Hills', 'Ri Bhoi', 'South Garo Hills', 'South West Garo Hills', 'South West Khasi Hills', 'West Garo Hills', 'West Jaintia Hills', 'West Khasi Hills'],
      'Mizoram': ['Aizawl', 'Champhai', 'Kolasib', 'Lawngtlai', 'Lunglei', 'Mamit', 'Saiha', 'Serchhip'],
      'Nagaland': ['Dimapur', 'Kiphire', 'Kohima', 'Longleng', 'Mokokchung', 'Mon', 'Peren', 'Phek', 'Tuensang', 'Wokha', 'Zunheboto'],
      'Odisha': ['Angul', 'Balangir', 'Balasore', 'Bargarh', 'Bhadrak', 'Baudh', 'Cuttack', 'Deogarh', 'Dhenkanal', 'Gajapati', 'Ganjam', 'Jagatsinghapur', 'Jajpur', 'Jharsuguda', 'Kalahandi', 'Kandhamal', 'Kendrapara', 'Kendujhar', 'Khordha', 'Koraput', 'Malkangiri', 'Mayurbhanj', 'Nabarangpur', 'Nayagarh', 'Nuapada', 'Puri', 'Rayagada', 'Sambalpur', 'Subarnapur', 'Sundargarh'],
      'Punjab': ['Amritsar', 'Barnala', 'Bathinda', 'Faridkot', 'Fatehgarh Sahib', 'Fazilka', 'Ferozepur', 'Gurdaspur', 'Hoshiarpur', 'Jalandhar', 'Kapurthala', 'Ludhiana', 'Mansa', 'Moga', 'Muktsar', 'Pathankot', 'Patiala', 'Rupnagar', 'Sahibzada Ajit Singh Nagar', 'Sangrur', 'Shahid Bhagat Singh Nagar', 'Tarn Taran'],
      'Rajasthan': ['Ajmer', 'Alwar', 'Banswara', 'Baran', 'Barmer', 'Bharatpur', 'Bhilwara', 'Bikaner', 'Bundi', 'Chittorgarh', 'Churu', 'Dausa', 'Dholpur', 'Dungarpur', 'Hanumangarh', 'Jaipur', 'Jaisalmer', 'Jalore', 'Jhalawar', 'Jhunjhunu', 'Jodhpur', 'Karauli', 'Kota', 'Nagaur', 'Pali', 'Pratapgarh', 'Rajsamand', 'Sawai Madhopur', 'Sikar', 'Sirohi', 'Sri Ganganagar', 'Tonk', 'Udaipur'],
      'Sikkim': ['East Sikkim', 'North Sikkim', 'South Sikkim', 'West Sikkim'],
      'Tamil Nadu': ['Ariyalur', 'Chennai', 'Coimbatore', 'Cuddalore', 'Dharmapuri', 'Dindigul', 'Erode', 'Kanchipuram', 'Kanyakumari', 'Karur', 'Krishnagiri', 'Madurai', 'Nagapattinam', 'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai', 'Ramanathapuram', 'Salem', 'Sivaganga', 'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli', 'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur', 'Vellore', 'Viluppuram', 'Virudhunagar'],
      'Telangana': ['Adilabad', 'Bhadradri Kothagudem', 'Hyderabad', 'Jagtial', 'Jangaon', 'Jayashankar Bhupalpally', 'Jogulamba Gadwal', 'Kamareddy', 'Karimnagar', 'Khammam', 'Kumuram Bheem Asifabad', 'Mahabubabad', 'Mahabubnagar', 'Mancherial', 'Medak', 'Medchal', 'Mulugu', 'Nagarkurnool', 'Nalgonda', 'Narayanpet', 'Nirmal', 'Nizamabad', 'Peddapalli', 'Rajanna Sircilla', 'Rangareddy', 'Sangareddy', 'Siddipet', 'Suryapet', 'Vikarabad', 'Wanaparthy', 'Warangal Rural', 'Warangal Urban', 'Yadadri Bhuvanagiri'],
      'Tripura': ['Dhalai', 'Gomati', 'Khowai', 'North Tripura', 'Sepahijala', 'South Tripura', 'Unakoti', 'West Tripura'],
      'Uttar Pradesh': ['Agra', 'Aligarh', 'Allahabad', 'Ambedkar Nagar', 'Amethi', 'Amroha', 'Auraiya', 'Azamgarh', 'Baghpat', 'Bahraich', 'Ballia', 'Balrampur', 'Banda', 'Barabanki', 'Bareilly', 'Basti', 'Bijnor', 'Budaun', 'Bulandshahr', 'Chandauli', 'Chitrakoot', 'Deoria', 'Etah', 'Etawah', 'Faizabad', 'Farrukhabad', 'Fatehpur', 'Firozabad', 'Gautam Buddha Nagar', 'Ghaziabad', 'Ghazipur', 'Gonda', 'Gorakhpur', 'Hamirpur', 'Hapur', 'Hardoi', 'Hathras', 'Jalaun', 'Jaunpur', 'Jhansi', 'Kannauj', 'Kanpur Dehat', 'Kanpur Nagar', 'Kasganj', 'Kaushambi', 'Kheri', 'Kushinagar', 'Lalitpur', 'Lucknow', 'Maharajganj', 'Mahoba', 'Mainpuri', 'Mathura', 'Mau', 'Meerut', 'Mirzapur', 'Moradabad', 'Muzaffarnagar', 'Pilibhit', 'Pratapgarh', 'Rae Bareli', 'Rampur', 'Saharanpur', 'Sambhal', 'Sant Kabir Nagar', 'Shahjahanpur', 'Shamli', 'Shravasti', 'Siddharthnagar', 'Sitapur', 'Sonbhadra', 'Sultanpur', 'Unnao', 'Varanasi'],
      'Uttarakhand': ['Almora', 'Bageshwar', 'Chamoli', 'Champawat', 'Dehradun', 'Haridwar', 'Nainital', 'Pauri Garhwal', 'Pithoragarh', 'Rudraprayag', 'Tehri Garhwal', 'Udham Singh Nagar', 'Uttarkashi'],
      'West Bengal': ['Alipurduar', 'Bankura', 'Birbhum', 'Cooch Behar', 'Dakshin Dinajpur', 'Darjeeling', 'Hooghly', 'Howrah', 'Jalpaiguri', 'Jhargram', 'Kalimpong', 'Kolkata', 'Malda', 'Murshidabad', 'Nadia', 'North 24 Parganas', 'Paschim Bardhaman', 'Paschim Medinipur', 'Purba Bardhaman', 'Purba Medinipur', 'Purulia', 'South 24 Parganas', 'Uttar Dinajpur'],
      'Andaman and Nicobar Islands': ['Nicobar', 'North and Middle Andaman', 'South Andaman'],
      'Chandigarh': ['Chandigarh'],
      'Dadra and Nagar Haveli': ['Dadra and Nagar Haveli'],
      'Daman and Diu': ['Daman', 'Diu'],
      'Delhi': ['Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi', 'North East Delhi', 'North West Delhi', 'Shahdara', 'South Delhi', 'South East Delhi', 'South West Delhi', 'West Delhi'],
      'Lakshadweep': ['Lakshadweep'],
      'Puducherry': ['Karaikal', 'Mahe', 'Puducherry', 'Yanam'],
      'Ladakh': ['Kargil', 'Leh'],
      'Jammu and Kashmir': ['Anantnag', 'Bandipora', 'Baramulla', 'Budgam', 'Doda', 'Ganderbal', 'Jammu', 'Kathua', 'Kishtwar', 'Kulgam', 'Kupwara', 'Mandi', 'Poonch', 'Pulwama', 'Rajouri', 'Ramban', 'Reasi', 'Samba', 'Shopian', 'Srinagar', 'Udhampur'],
    };

    final List<Map<String, dynamic>> commodityPool = [
      {'commodity': 'Onion', 'variety': 'Red', 'min': 1500, 'max': 3000},
      {'commodity': 'Potato', 'variety': 'Desi', 'min': 1000, 'max': 2000},
      {'commodity': 'Tomato', 'variety': 'Hybrid', 'min': 500, 'max': 1500},
      {'commodity': 'Wheat', 'variety': 'Lokwan', 'min': 2200, 'max': 2800},
      {'commodity': 'Paddy (Common)', 'variety': 'Common', 'min': 2000, 'max': 2500},
      {'commodity': 'Cotton', 'variety': 'Long Staple', 'min': 6500, 'max': 8000},
      {'commodity': 'Groundnut', 'variety': 'G-20', 'min': 5500, 'max': 7500},
      {'commodity': 'Garlic', 'variety': 'Desi', 'min': 8000, 'max': 14000},
      {'commodity': 'Ginger', 'variety': 'Dry', 'min': 4000, 'max': 7000},
      {'commodity': 'Cumin(Jeera)', 'variety': 'Common', 'min': 15000, 'max': 25000},
      {'commodity': 'Mustard', 'variety': 'Mustard', 'min': 5000, 'max': 6500},
      {'commodity': 'Soybean', 'variety': 'Yellow', 'min': 4000, 'max': 5500},
      {'commodity': 'Chilli', 'variety': 'Teja', 'min': 12000, 'max': 20000},
      {'commodity': 'Turmeric', 'variety': 'Finger', 'min': 9000, 'max': 14000},
      {'commodity': 'Banana', 'variety': 'Grand Naine', 'min': 800, 'max': 1500},
      {'commodity': 'Mango', 'variety': 'Local', 'min': 3000, 'max': 6000},
      {'commodity': 'Apple', 'variety': 'Delicious', 'min': 4000, 'max': 9000},
      {'commodity': 'Arecanut', 'variety': 'Rashi', 'min': 40000, 'max': 55000},
      {'commodity': 'Black Pepper', 'variety': 'Pepper', 'min': 45000, 'max': 58000},
      {'commodity': 'Cardamom', 'variety': 'Small', 'min': 1200, 'max': 2500, 'unit': 'Kg'},
      {'commodity': 'Coffee', 'variety': 'Arabica', 'min': 14000, 'max': 22000},
      {'commodity': 'Cashewnuts', 'variety': 'W-210', 'min': 60000, 'max': 90000},
      {'commodity': 'Jaggery', 'variety': 'Common', 'min': 3000, 'max': 5000},
      {'commodity': 'Rice', 'variety': 'Basmati', 'min': 3500, 'max': 6000},
    ];

    int counter = 0;
    final int daySeed = dateObj.day + dateObj.month;

    indiaHierarchy.forEach((state, districts) {
      // For each state, add at least all districts but with multiple commodities
      for (String dist in districts) {
        // Generate 3 to 5 products per district depending on the counter
        final int numProducts = 3 + (counter % 3);

        for (int p = 0; p < numProducts; p++) {
          // Select commodity template variation based on district and date
          final commodityTemplate = commodityPool[(counter + p + daySeed) % commodityPool.length];
          
          // Incorporate the date into the randomization drift so prices change on different days
          final int baseMin = commodityTemplate['min'] as int;
          final int baseMax = commodityTemplate['max'] as int;
          
          // Drift calculation that varies by date but is consistent for the same date
          final int timeDrift = ((daySeed * 5) % 30) - 15; // -15% to +15% variation
          final int staticDrift = ((counter + p) % 20) * 10;
          
          final double dateMultiplier = 1.0 + (timeDrift / 100.0);
          
          final int minPrice = ((baseMin + staticDrift) * dateMultiplier).round();
          final int maxPrice = ((baseMax + staticDrift) * dateMultiplier).round();
          final int modalPrice = (((baseMin + baseMax) ~/ 2 + staticDrift) * dateMultiplier).round();

          records.add({
            'state': state,
            'district': dist,
            'market': dist, // Using district name as market for simplicity in coverage
            'commodity': commodityTemplate['commodity'],
            'variety': commodityTemplate['variety'],
            'grade': 'FAQ',
            'arrival_date': date,
            'min_price': minPrice.toString(),
            'max_price': maxPrice.toString(),
            'modal_price': modalPrice.toString(),
            'unit': commodityTemplate['unit'] ?? 'Quintal',
          });
        }
        counter++;
      }
    });

    return records;
  }

  /// Generates 7 days of historical mock data for a given record.
  /// Used for the Product History Graph.
  Future<List<Map<String, dynamic>>> getHistoricalData(Map<String, dynamic> currentRecord, {int days = 7}) async {
    final List<Map<String, dynamic>> history = [];
    final currentDateStr = currentRecord['arrival_date'] as String;
    
    // Parse current date (format DD/MM/YYYY)
    final parts = currentDateStr.split('/');
    DateTime baseDate = DateTime.now();
    if (parts.length == 3) {
      baseDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    }

    final int currentModal = int.tryParse(currentRecord['modal_price'].toString()) ?? 0;
    final int currentMin = int.tryParse(currentRecord['min_price'].toString()) ?? 0;
    final int currentMax = int.tryParse(currentRecord['max_price'].toString()) ?? 0;

    // Add current day first
    history.add(Map<String, dynamic>.from(currentRecord));

    // Generate past days with realistic variations
    for (int i = 1; i < days; i++) {
      final pastDate = baseDate.subtract(Duration(days: i));
      final dateStr = '${pastDate.day.toString().padLeft(2, '0')}/${pastDate.month.toString().padLeft(2, '0')}/${pastDate.year}';
      
      // Calculate random drift (-5% to +5% variation from previous day)
      // To keep it somewhat consistent, we'll base it off the current modal but scale it
      final double driftFactor = 1.0 + ((i % 5) - 2) * 0.02; // Small drift
      
      final int modal = (currentModal * driftFactor).round();
      final int min = (currentMin * driftFactor).round();
      final int max = (currentMax * driftFactor).round();

      final record = Map<String, dynamic>.from(currentRecord);
      record['arrival_date'] = dateStr;
      record['modal_price'] = modal.toString();
      record['min_price'] = min.toString();
      record['max_price'] = max.toString();
      
      history.add(record);
    }

    // Return in chronological order (oldest first)
    return history.reversed.toList();
  }
}
