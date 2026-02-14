import '../models/subscription_model.dart';
import '../services/api_service.dart';

class SubscriptionRepository {
  final ApiService _apiService;

  SubscriptionRepository(this._apiService);

  /// Get all available subscription plans
  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final response = await _apiService.get('/api/main/subscription/plans');

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> plansData = response.data['data'];
        return plansData.map((json) => SubscriptionPlan.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching subscription plans: $e');
      rethrow;
    }
  }

  /// Get current user's subscription
  Future<Map<String, dynamic>> getCurrentSubscription() async {
    try {
      final response = await _apiService.get('/api/main/subscription/current');

      if (response.data['success'] == true) {
        return {
          'subscription': response.data['data']['subscription'] != null
              ? UserSubscription.fromJson(response.data['data']['subscription'])
              : null,
          'currentPlan': response.data['data']['currentPlan'] != null
              ? SubscriptionPlan.fromJson(response.data['data']['currentPlan'])
              : null,
          'isFreePlan': response.data['data']['isFreePlan'] ?? true,
        };
      }

      return {
        'subscription': null,
        'currentPlan': null,
        'isFreePlan': true,
      };
    } catch (e) {
      print('Error fetching current subscription: $e');
      rethrow;
    }
  }

  /// Get usage stats
  Future<UsageStats> getUsageStats() async {
    try {
      final response = await _apiService.get('/api/main/subscription/usage');

      if (response.data['success'] == true && response.data['data'] != null) {
        return UsageStats.fromJson(response.data['data']);
      }

      // Return default free tier usage
      return UsageStats.fromJson({
        'usage': {
          'aiMessagesUsed': 0,
          'imageAnalysisUsed': 0,
          'consultantChatsUsed': 0,
          'videoConsultationsUsed': 0,
        },
        'limits': {
          'aiMessagesPerDay': 5,
          'imageAnalysisPerDay': 2,
          'consultantChatsPerDay': 10,
          'videoConsultationsPerMonth': 0,
        },
        'remaining': {
          'aiMessages': 5,
          'imageAnalysis': 2,
          'consultantChats': 10,
          'videoConsultations': 0,
        },
        'planName': 'KISAN',
      });
    } catch (e) {
      print('Error fetching usage stats: $e');
      rethrow;
    }
  }

  /// Create payment intent for mobile payment
  Future<Map<String, dynamic>> createPaymentIntent({
    required String planName,
    required String billingCycle,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/payment-intent',
        data: {
          'planName': planName,
          'billingCycle': billingCycle,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return {
          'clientSecret': response.data['data']['clientSecret'],
          'paymentIntentId': response.data['data']['paymentIntentId'],
          'amount': response.data['data']['amount'],
          'currency': response.data['data']['currency'],
        };
      }

      throw Exception(response.data['message'] ?? 'Failed to create payment intent');
    } catch (e) {
      print('Error creating payment intent: $e');
      rethrow;
    }
  }

  /// Confirm payment and activate subscription
  Future<Map<String, dynamic>> confirmPayment({
    required String paymentIntentId,
    required String planName,
    required String billingCycle,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/confirm-payment',
        data: {
          'paymentIntentId': paymentIntentId,
          'planName': planName,
          'billingCycle': billingCycle,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return {
          'subscription': UserSubscription.fromJson(response.data['data']['subscription']),
          'plan': SubscriptionPlan.fromJson(response.data['data']['plan']),
        };
      }

      throw Exception(response.data['message'] ?? 'Failed to confirm payment');
    } catch (e) {
      print('Error confirming payment: $e');
      rethrow;
    }
  }

  /// Create checkout session (for web)
  Future<Map<String, dynamic>> createCheckoutSession({
    required String planName,
    required String billingCycle,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/checkout',
        data: {
          'planName': planName,
          'billingCycle': billingCycle,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return {
          'sessionId': response.data['data']['sessionId'],
          'url': response.data['data']['url'],
        };
      }

      throw Exception(response.data['message'] ?? 'Failed to create checkout session');
    } catch (e) {
      print('Error creating checkout session: $e');
      rethrow;
    }
  }

  /// Cancel subscription
  Future<UserSubscription> cancelSubscription({
    bool cancelImmediately = false,
    String? reason,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/cancel',
        data: {
          'cancelImmediately': cancelImmediately,
          'reason': reason,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return UserSubscription.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Failed to cancel subscription');
    } catch (e) {
      print('Error cancelling subscription: $e');
      rethrow;
    }
  }

  /// Resume cancelled subscription
  Future<UserSubscription> resumeSubscription() async {
    try {
      final response = await _apiService.post('/api/main/subscription/resume');

      if (response.data['success'] == true && response.data['data'] != null) {
        return UserSubscription.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Failed to resume subscription');
    } catch (e) {
      print('Error resuming subscription: $e');
      rethrow;
    }
  }

  /// Get payment history
  Future<List<PaymentHistory>> getPaymentHistory({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/main/subscription/payments',
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> payments = response.data['data']['payments'] ?? [];
        return payments.map((json) => PaymentHistory.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching payment history: $e');
      rethrow;
    }
  }

  /// Check feature access
  Future<Map<String, dynamic>> checkFeatureAccess(String feature) async {
    try {
      final response = await _apiService.get('/api/main/subscription/feature/$feature');

      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data'];
      }

      return {'allowed': false};
    } catch (e) {
      print('Error checking feature access: $e');
      return {'allowed': true}; // Default to allowed on error
    }
  }

  // ========== IoT ADD-ON METHODS ==========

  /// Get all IoT add-ons
  Future<List<IotAddon>> getIotAddons() async {
    try {
      final response = await _apiService.get('/api/main/subscription/iot/addons');

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> addonsData = response.data['data'];
        return addonsData.map((json) => IotAddon.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching IoT add-ons: $e');
      rethrow;
    }
  }

  /// Get user's active IoT add-ons
  Future<List<UserIotAddon>> getUserIotAddons() async {
    try {
      final response = await _apiService.get('/api/main/subscription/iot/my-addons');

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> addonsData = response.data['data'];
        return addonsData.map((json) => UserIotAddon.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching user IoT add-ons: $e');
      rethrow;
    }
  }

  /// Create payment intent for IoT add-on
  Future<Map<String, dynamic>> createIotAddonPaymentIntent({
    required String addonName,
    required String billingCycle,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/iot/payment-intent',
        data: {
          'addonName': addonName,
          'billingCycle': billingCycle,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return {
          'clientSecret': response.data['data']['clientSecret'],
          'paymentIntentId': response.data['data']['paymentIntentId'],
          'amount': response.data['data']['amount'],
          'currency': response.data['data']['currency'],
        };
      }

      throw Exception(response.data['message'] ?? 'Failed to create IoT add-on payment intent');
    } catch (e) {
      print('Error creating IoT add-on payment intent: $e');
      rethrow;
    }
  }

  /// Confirm IoT add-on payment
  Future<Map<String, dynamic>> confirmIotAddonPayment({
    required String paymentIntentId,
    required String addonName,
    required String billingCycle,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/iot/confirm-payment',
        data: {
          'paymentIntentId': paymentIntentId,
          'addonName': addonName,
          'billingCycle': billingCycle,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return {
          'userIotAddon': UserIotAddon.fromJson(response.data['data']['userIotAddon']),
          'addon': IotAddon.fromJson(response.data['data']['addon']),
        };
      }

      throw Exception(response.data['message'] ?? 'Failed to confirm IoT add-on payment');
    } catch (e) {
      print('Error confirming IoT add-on payment: $e');
      rethrow;
    }
  }

  /// Cancel IoT add-on subscription
  Future<UserIotAddon> cancelIotAddon({
    required String addonName,
    bool cancelImmediately = false,
    String? reason,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/iot/cancel',
        data: {
          'addonName': addonName,
          'cancelImmediately': cancelImmediately,
          'reason': reason,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return UserIotAddon.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Failed to cancel IoT add-on');
    } catch (e) {
      print('Error cancelling IoT add-on: $e');
      rethrow;
    }
  }

  /// Check IoT feature access
  Future<Map<String, dynamic>> checkIotFeatureAccess(String feature) async {
    try {
      final response = await _apiService.get('/api/main/subscription/iot/feature/$feature');

      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data'];
      }

      return {'allowed': false};
    } catch (e) {
      print('Error checking IoT feature access: $e');
      return {'allowed': false};
    }
  }

  /// Link IoT device
  Future<UserIotAddon> linkIotDevice({
    required String addonName,
    required String deviceId,
    required String deviceType,
    String? deviceName,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/iot/device/link',
        data: {
          'addonName': addonName,
          'deviceId': deviceId,
          'deviceType': deviceType,
          'deviceName': deviceName,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return UserIotAddon.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Failed to link IoT device');
    } catch (e) {
      print('Error linking IoT device: $e');
      rethrow;
    }
  }

  /// Unlink IoT device
  Future<UserIotAddon> unlinkIotDevice({
    required String addonName,
    required String deviceId,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/main/subscription/iot/device/unlink',
        data: {
          'addonName': addonName,
          'deviceId': deviceId,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return UserIotAddon.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Failed to unlink IoT device');
    } catch (e) {
      print('Error unlinking IoT device: $e');
      rethrow;
    }
  }
}
