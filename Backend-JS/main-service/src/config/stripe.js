/**
 * Stripe Configuration for Krishi Mantra
 * Payment gateway integration for Indian farmers
 */

const Stripe = require('stripe');
const logger = require('../utils/logger');

// Initialize Stripe with secret key
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: '2023-10-16',
  appInfo: {
    name: 'Krishi Mantra',
    version: '1.0.0',
    url: 'https://krishimantra.com',
  },
});

/**
 * Subscription Plan Configuration
 * Prices in paise (100 paise = 1 INR)
 */
const SUBSCRIPTION_PLANS = {
  KISAN: {
    name: 'KISAN',
    displayName: 'Kisan (Free)',
    displayNameHindi: 'किसान (मुफ्त)',
    description: 'Basic plan for all farmers with essential features',
    descriptionHindi: 'सभी किसानों के लिए आवश्यक सुविधाओं के साथ मूल योजना',
    pricing: {
      monthly: { amount: 0, currency: 'inr' },
      yearly: { amount: 0, currency: 'inr', savings: 0 },
    },
    features: {
      aiMessagesPerDay: 5,
      imageAnalysisPerDay: 2,
      consultantChatsPerDay: 10,
      videoConsultationsPerMonth: 0,
      canCreatePosts: false,
      canCreateReels: false,
      marketplaceListings: 0,
      featuredListings: false,
      pushNotifications: true,
      smsNotifications: false,
      emailNotifications: false,
      adFree: false,
      reducedAds: 0,
      prioritySupport: false,
      analyticsAccess: 'none',
      offlineCropCalendar: false,
      priorityFeedRecommendations: false,
    },
    order: 0,
    isDefault: true,
  },
  KISAN_PRO: {
    name: 'KISAN_PRO',
    displayName: 'Kisan Pro',
    displayNameHindi: 'किसान प्रो',
    description: 'Enhanced features for serious farmers - More AI help, consultant access',
    descriptionHindi: 'गंभीर किसानों के लिए उन्नत सुविधाएं - अधिक AI सहायता, सलाहकार पहुंच',
    pricing: {
      monthly: { amount: 9900, currency: 'inr' }, // ₹99
      yearly: { amount: 99900, currency: 'inr', savings: 16 }, // ₹999 (16% savings)
    },
    features: {
      aiMessagesPerDay: 50,
      imageAnalysisPerDay: 20,
      consultantChatsPerDay: 50,
      videoConsultationsPerMonth: 0,
      canCreatePosts: true,
      canCreateReels: false,
      marketplaceListings: 0,
      featuredListings: false,
      pushNotifications: true,
      smsNotifications: false,
      emailNotifications: false,
      adFree: false,
      reducedAds: 50,
      prioritySupport: false,
      analyticsAccess: 'none',
      offlineCropCalendar: true,
      priorityFeedRecommendations: true,
    },
    order: 1,
    isDefault: false,
  },
  KISAN_PLUS: {
    name: 'KISAN_PLUS',
    displayName: 'Kisan Plus',
    displayNameHindi: 'किसान प्लस',
    description: 'Professional plan with unlimited AI, video consultations, and marketplace access',
    descriptionHindi: 'असीमित AI, वीडियो परामर्श और मार्केटप्लेस एक्सेस के साथ प्रोफेशनल प्लान',
    pricing: {
      monthly: { amount: 29900, currency: 'inr' }, // ₹299
      yearly: { amount: 299900, currency: 'inr', savings: 16 }, // ₹2999 (16% savings)
    },
    features: {
      aiMessagesPerDay: -1, // -1 means unlimited
      imageAnalysisPerDay: -1,
      consultantChatsPerDay: -1,
      videoConsultationsPerMonth: 2,
      canCreatePosts: true,
      canCreateReels: true,
      marketplaceListings: 5,
      featuredListings: true,
      pushNotifications: true,
      smsNotifications: true,
      emailNotifications: true,
      adFree: true,
      reducedAds: 100,
      prioritySupport: true,
      analyticsAccess: 'basic',
      offlineCropCalendar: true,
      priorityFeedRecommendations: true,
    },
    order: 2,
    isDefault: false,
  },
  KISAN_MEGA: {
    name: 'KISAN_MEGA',
    displayName: 'Kisan Mega',
    displayNameHindi: 'किसान मेगा',
    description: 'Enterprise plan for agri-businesses with unlimited everything and API access',
    descriptionHindi: 'कृषि व्यवसायों के लिए असीमित सब कुछ और API एक्सेस के साथ एंटरप्राइज प्लान',
    pricing: {
      monthly: { amount: 99900, currency: 'inr' }, // ₹999
      yearly: { amount: 999900, currency: 'inr', savings: 17 }, // ₹9999 (17% savings)
    },
    features: {
      aiMessagesPerDay: -1,
      imageAnalysisPerDay: -1,
      consultantChatsPerDay: -1,
      videoConsultationsPerMonth: -1,
      canCreatePosts: true,
      canCreateReels: true,
      marketplaceListings: -1,
      featuredListings: true,
      pushNotifications: true,
      smsNotifications: true,
      emailNotifications: true,
      adFree: true,
      reducedAds: 100,
      prioritySupport: true,
      analyticsAccess: 'full',
      offlineCropCalendar: true,
      priorityFeedRecommendations: true,
    },
    order: 3,
    isDefault: false,
  },
};

/**
 * IoT Add-on Configuration
 * Separate add-on subscriptions for IoT devices
 * Prices in paise (100 paise = 1 INR)
 * Water Pump: ₹100/month, Crop IoT: ₹200/month, Bundle: ₹350/month (saves ₹50)
 */
const IOT_ADDONS = {
  WATER_PUMP: {
    name: 'WATER_PUMP',
    displayName: 'Smart Water Pump',
    displayNameHindi: 'स्मार्ट वाटर पंप',
    description: 'Control and automate your water pump remotely with smart scheduling',
    descriptionHindi: 'स्मार्ट शेड्यूलिंग के साथ अपने वाटर पंप को दूर से नियंत्रित और स्वचालित करें',
    pricing: {
      monthly: { amount: 10000, currency: 'inr' }, // ₹100
      yearly: { amount: 100000, currency: 'inr', savings: 17 }, // ₹1000 (17% savings - 2 months free)
    },
    features: {
      waterPump: {
        enabled: true,
        maxDevices: 3,
        schedulingEnabled: true,
        remoteControlEnabled: true,
        automationRulesLimit: 5,
        waterUsageAnalytics: true,
        alertsEnabled: true,
      },
      cropMonitoring: {
        enabled: false,
        maxSensors: 0,
      },
      weatherStation: {
        enabled: false,
      },
    },
    bundleSavings: 0,
    order: 0,
  },
  CROP_IOT: {
    name: 'CROP_IOT',
    displayName: 'Crop IoT Sensors',
    displayNameHindi: 'फसल IoT सेंसर',
    description: 'Monitor soil moisture, temperature, humidity, and get AI-powered crop recommendations',
    descriptionHindi: 'मिट्टी की नमी, तापमान, आर्द्रता की निगरानी करें और AI-संचालित फसल सिफारिशें प्राप्त करें',
    pricing: {
      monthly: { amount: 20000, currency: 'inr' }, // ₹200
      yearly: { amount: 200000, currency: 'inr', savings: 17 }, // ₹2000 (17% savings)
    },
    features: {
      waterPump: {
        enabled: false,
        maxDevices: 0,
      },
      cropMonitoring: {
        enabled: true,
        maxSensors: 5,
        soilMoistureSensor: true,
        temperatureSensor: true,
        humiditySensor: true,
        lightSensor: true,
        phSensor: true,
        nutrientSensor: false,
        dataRefreshRateMinutes: 15,
        historicalDataDays: 30,
        alertsEnabled: true,
        aiRecommendations: true,
      },
      weatherStation: {
        enabled: true,
        localWeatherData: true,
        forecastDays: 7,
        rainPredictionAlerts: true,
        frostAlerts: true,
      },
    },
    bundleSavings: 0,
    order: 1,
  },
  IOT_BUNDLE: {
    name: 'IOT_BUNDLE',
    displayName: 'IoT Complete Bundle',
    displayNameHindi: 'IoT पूर्ण बंडल',
    description: 'Get both Water Pump and Crop IoT sensors at a discounted price - Save ₹50/month!',
    descriptionHindi: 'छूट मूल्य पर वाटर पंप और फसल IoT सेंसर दोनों प्राप्त करें - ₹50/माह बचाएं!',
    pricing: {
      monthly: { amount: 25000, currency: 'inr' }, // ₹250 (instead of ₹300, save ₹50)
      yearly: { amount: 250000, currency: 'inr', savings: 17 }, // ₹2500 (save ₹600 yearly)
    },
    features: {
      waterPump: {
        enabled: true,
        maxDevices: 5,
        schedulingEnabled: true,
        remoteControlEnabled: true,
        automationRulesLimit: 10,
        waterUsageAnalytics: true,
        alertsEnabled: true,
      },
      cropMonitoring: {
        enabled: true,
        maxSensors: 10,
        soilMoistureSensor: true,
        temperatureSensor: true,
        humiditySensor: true,
        lightSensor: true,
        phSensor: true,
        nutrientSensor: true,
        dataRefreshRateMinutes: 5,
        historicalDataDays: 90,
        alertsEnabled: true,
        aiRecommendations: true,
      },
      weatherStation: {
        enabled: true,
        localWeatherData: true,
        forecastDays: 14,
        rainPredictionAlerts: true,
        frostAlerts: true,
      },
    },
    bundleSavings: 5000, // ₹50 savings per month in paise
    order: 2,
  },
};

/**
 * Create or retrieve Stripe customer
 */
const getOrCreateCustomer = async (user) => {
  try {
    // Handle both `_id` (from DB) and `id` (from JWT token)
    const userId = user._id || user.id;

    if (!userId) {
      throw new Error('User ID is required to create Stripe customer');
    }

    // Check if user already has a Stripe customer ID
    const { UserSubscription } = require('../model/Subscription');
    const existingSub = await UserSubscription.findOne({
      userId: userId,
      stripeCustomerId: { $exists: true, $ne: null },
    });

    if (existingSub?.stripeCustomerId) {
      // Verify customer exists in Stripe
      try {
        const customer = await stripe.customers.retrieve(existingSub.stripeCustomerId);
        if (!customer.deleted) {
          return customer;
        }
      } catch (err) {
        logger.warn(`Stripe customer not found: ${existingSub.stripeCustomerId}`);
      }
    }

    // Create new customer
    const customer = await stripe.customers.create({
      email: user.email || undefined,
      phone: user.phoneNo ? `+91${user.phoneNo}` : undefined,
      name: user.name,
      metadata: {
        userId: userId.toString(),
        accountType: user.accountType || 'user',
      },
    });

    logger.info(`Created Stripe customer: ${customer.id} for user: ${user._id}`);
    return customer;
  } catch (error) {
    logger.error('Error creating Stripe customer:', error);
    throw error;
  }
};

/**
 * Create checkout session for subscription
 */
const createCheckoutSession = async ({ user, planName, billingCycle, successUrl, cancelUrl }) => {
  try {
    const plan = SUBSCRIPTION_PLANS[planName];
    if (!plan) {
      throw new Error(`Invalid plan: ${planName}`);
    }

    if (plan.pricing[billingCycle].amount === 0) {
      throw new Error('Cannot create checkout for free plan');
    }

    const customer = await getOrCreateCustomer(user);

    // Create or get price
    const priceData = {
      currency: 'inr',
      unit_amount: plan.pricing[billingCycle].amount,
      recurring: {
        interval: billingCycle === 'yearly' ? 'year' : 'month',
      },
      product_data: {
        name: `${plan.displayName} - ${billingCycle === 'yearly' ? 'Yearly' : 'Monthly'}`,
        description: plan.description,
        metadata: {
          planName: plan.name,
          billingCycle,
        },
      },
    };

    const userId = user._id || user.id;
    const session = await stripe.checkout.sessions.create({
      customer: customer.id,
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: priceData,
          quantity: 1,
        },
      ],
      mode: 'subscription',
      success_url: successUrl || `${process.env.APP_URL}/subscription/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: cancelUrl || `${process.env.APP_URL}/subscription/cancel`,
      metadata: {
        userId: userId.toString(),
        planName: plan.name,
        billingCycle,
      },
      subscription_data: {
        metadata: {
          userId: userId.toString(),
          planName: plan.name,
          billingCycle,
        },
      },
      // India specific options
      payment_method_options: {
        card: {
          request_three_d_secure: 'automatic',
        },
      },
      locale: 'en',
      // Allow promotion codes
      allow_promotion_codes: true,
    });

    logger.info(`Created checkout session: ${session.id} for user: ${user._id}`);
    return session;
  } catch (error) {
    logger.error('Error creating checkout session:', error);
    throw error;
  }
};

/**
 * Create payment intent for one-time payment
 */
const createPaymentIntent = async ({ user, planName, billingCycle }) => {
  try {
    const plan = SUBSCRIPTION_PLANS[planName];
    if (!plan) {
      throw new Error(`Invalid plan: ${planName}`);
    }

    const customer = await getOrCreateCustomer(user);
    const amount = plan.pricing[billingCycle].amount;

    const userId = user._id || user.id;
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: 'inr',
      customer: customer.id,
      metadata: {
        userId: userId.toString(),
        planName: plan.name,
        billingCycle,
      },
      description: `${plan.displayName} - ${billingCycle === 'yearly' ? 'Yearly' : 'Monthly'} Subscription`,
      // India specific
      payment_method_types: ['card'],
    });

    logger.info(`Created payment intent: ${paymentIntent.id} for user: ${userId}`);
    return paymentIntent;
  } catch (error) {
    logger.error('Error creating payment intent:', error);
    throw error;
  }
};

/**
 * Cancel subscription
 */
const cancelSubscription = async (stripeSubscriptionId, cancelAtPeriodEnd = true) => {
  try {
    if (cancelAtPeriodEnd) {
      // Cancel at end of billing period
      const subscription = await stripe.subscriptions.update(stripeSubscriptionId, {
        cancel_at_period_end: true,
      });
      logger.info(`Subscription ${stripeSubscriptionId} set to cancel at period end`);
      return subscription;
    } else {
      // Cancel immediately
      const subscription = await stripe.subscriptions.cancel(stripeSubscriptionId);
      logger.info(`Subscription ${stripeSubscriptionId} cancelled immediately`);
      return subscription;
    }
  } catch (error) {
    logger.error('Error cancelling subscription:', error);
    throw error;
  }
};

/**
 * Resume cancelled subscription
 */
const resumeSubscription = async (stripeSubscriptionId) => {
  try {
    const subscription = await stripe.subscriptions.update(stripeSubscriptionId, {
      cancel_at_period_end: false,
    });
    logger.info(`Subscription ${stripeSubscriptionId} resumed`);
    return subscription;
  } catch (error) {
    logger.error('Error resuming subscription:', error);
    throw error;
  }
};

/**
 * Get subscription details from Stripe
 */
const getSubscription = async (stripeSubscriptionId) => {
  try {
    return await stripe.subscriptions.retrieve(stripeSubscriptionId);
  } catch (error) {
    logger.error('Error getting subscription:', error);
    throw error;
  }
};

/**
 * Get customer portal session
 */
const createPortalSession = async (stripeCustomerId, returnUrl) => {
  try {
    const session = await stripe.billingPortal.sessions.create({
      customer: stripeCustomerId,
      return_url: returnUrl || process.env.APP_URL,
    });
    return session;
  } catch (error) {
    logger.error('Error creating portal session:', error);
    throw error;
  }
};

/**
 * Construct webhook event
 */
const constructWebhookEvent = (payload, signature) => {
  try {
    return stripe.webhooks.constructEvent(
      payload,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (error) {
    logger.error('Error constructing webhook event:', error);
    throw error;
  }
};

/**
 * Create payment intent for IoT add-on
 */
const createIotAddonPaymentIntent = async ({ user, addonName, billingCycle }) => {
  try {
    const addon = IOT_ADDONS[addonName];
    if (!addon) {
      throw new Error(`Invalid IoT addon: ${addonName}`);
    }

    const customer = await getOrCreateCustomer(user);
    const amount = addon.pricing[billingCycle].amount;

    const userId = user._id || user.id;
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: 'inr',
      customer: customer.id,
      metadata: {
        userId: userId.toString(),
        addonName: addon.name,
        billingCycle,
        type: 'iot_addon',
      },
      description: `${addon.displayName} - ${billingCycle === 'yearly' ? 'Yearly' : 'Monthly'} Add-on`,
      payment_method_types: ['card'],
    });

    logger.info(`Created IoT addon payment intent: ${paymentIntent.id} for user: ${userId}, addon: ${addonName}`);
    return paymentIntent;
  } catch (error) {
    logger.error('Error creating IoT addon payment intent:', error);
    throw error;
  }
};

/**
 * Create checkout session for IoT add-on subscription
 */
const createIotAddonCheckoutSession = async ({ user, addonName, billingCycle, successUrl, cancelUrl }) => {
  try {
    const addon = IOT_ADDONS[addonName];
    if (!addon) {
      throw new Error(`Invalid IoT addon: ${addonName}`);
    }

    const customer = await getOrCreateCustomer(user);

    const priceData = {
      currency: 'inr',
      unit_amount: addon.pricing[billingCycle].amount,
      recurring: {
        interval: billingCycle === 'yearly' ? 'year' : 'month',
      },
      product_data: {
        name: `${addon.displayName} - ${billingCycle === 'yearly' ? 'Yearly' : 'Monthly'}`,
        description: addon.description,
        metadata: {
          addonName: addon.name,
          billingCycle,
          type: 'iot_addon',
        },
      },
    };

    const userId = user._id || user.id;
    const session = await stripe.checkout.sessions.create({
      customer: customer.id,
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: priceData,
          quantity: 1,
        },
      ],
      mode: 'subscription',
      success_url: successUrl || `${process.env.APP_URL}/iot-addon/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: cancelUrl || `${process.env.APP_URL}/iot-addon/cancel`,
      metadata: {
        userId: userId.toString(),
        addonName: addon.name,
        billingCycle,
        type: 'iot_addon',
      },
      subscription_data: {
        metadata: {
          userId: userId.toString(),
          addonName: addon.name,
          billingCycle,
          type: 'iot_addon',
        },
      },
      payment_method_options: {
        card: {
          request_three_d_secure: 'automatic',
        },
      },
      locale: 'en',
      allow_promotion_codes: true,
    });

    logger.info(`Created IoT addon checkout session: ${session.id} for user: ${userId}, addon: ${addonName}`);
    return session;
  } catch (error) {
    logger.error('Error creating IoT addon checkout session:', error);
    throw error;
  }
};

module.exports = {
  stripe,
  SUBSCRIPTION_PLANS,
  IOT_ADDONS,
  getOrCreateCustomer,
  createCheckoutSession,
  createPaymentIntent,
  createIotAddonPaymentIntent,
  createIotAddonCheckoutSession,
  cancelSubscription,
  resumeSubscription,
  getSubscription,
  createPortalSession,
  constructWebhookEvent,
};
