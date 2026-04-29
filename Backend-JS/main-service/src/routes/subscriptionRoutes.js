/**
 * Subscription Routes
 * API endpoints for subscription management
 */

const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();
const subscriptionController = require('../controller/SubscriptionController');
const { auth, optionalAuth, internalAuth, adminAuth } = require('../middlewares/auth');

/**
 * Per-user rate limit on the Stripe-touching endpoints. Without this, a
 * compromised account or buggy client can burn the project's Stripe
 * quota (and rack up real charges) by hammering payment-intent creation.
 * Keyed on userId from the verified JWT — `auth` runs first so req.user
 * is populated by the time we reach `keyGenerator`.
 */
const paymentIntentLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) =>
    (req.user && (req.user._id || req.user.id) || req.ip).toString(),
  message: {
    success: false,
    message: 'Too many payment requests. Please wait a moment and try again.',
  },
});

/**
 * Public routes
 */

// Get all subscription plans
router.get('/plans', subscriptionController.getPlans);

// Stripe webhook (must be before auth middleware and use raw body)
router.post(
  '/webhook',
  express.raw({ type: 'application/json' }),
  subscriptionController.handleWebhook
);

/**
 * Internal service routes (for microservice communication)
 */

// Increment usage (from message-svc, etc.)
router.post('/increment-usage', internalAuth, subscriptionController.incrementUsageInternal);

// Get usage stats (internal - supports X-User-Id header)
router.get('/usage', optionalAuth, subscriptionController.getUsageStats);

/**
 * Protected routes (require authentication)
 */

// Get current user's subscription
router.get('/current', auth, subscriptionController.getCurrentSubscription);

// Get payment history
router.get('/payments', auth, subscriptionController.getPaymentHistory);

// Check feature access
router.get('/feature/:feature', auth, subscriptionController.checkFeatureAccess);

// Create checkout session (for web)
router.post('/checkout', auth, paymentIntentLimiter, subscriptionController.createCheckoutSession);

// Create payment intent (for mobile apps)
router.post('/payment-intent', auth, paymentIntentLimiter, subscriptionController.createPaymentIntent);

// Confirm payment and activate subscription (for mobile apps)
router.post('/confirm-payment', auth, paymentIntentLimiter, subscriptionController.confirmPayment);

// Cancel subscription
router.post('/cancel', auth, subscriptionController.cancelSubscription);

// Resume subscription
router.post('/resume', auth, subscriptionController.resumeSubscription);

/**
 * IoT Add-on Routes
 * Endpoints for managing IoT device add-on subscriptions
 */

// Get all IoT add-ons (public)
router.get('/iot/addons', optionalAuth, subscriptionController.getIotAddons);

// Get user's active IoT add-ons
router.get('/iot/my-addons', auth, subscriptionController.getUserIotAddons);

// Create payment intent for IoT add-on (mobile)
router.post('/iot/payment-intent', auth, paymentIntentLimiter, subscriptionController.createIotAddonPaymentIntent);

// Confirm IoT add-on payment and activate (mobile)
router.post('/iot/confirm-payment', auth, paymentIntentLimiter, subscriptionController.confirmIotAddonPayment);

// Cancel IoT add-on subscription
router.post('/iot/cancel', auth, subscriptionController.cancelIotAddon);

// Check IoT feature access
router.get('/iot/feature/:feature', auth, subscriptionController.checkIotFeatureAccess);

// Link IoT device to subscription
router.post('/iot/device/link', auth, subscriptionController.linkIotDevice);

// Unlink IoT device from subscription
router.post('/iot/device/unlink', auth, subscriptionController.unlinkIotDevice);

/**
 * Super Admin Routes
 * Endpoints for admin to manage subscriptions and IoT add-ons
 */

// Plan management
router.post('/admin/plans', adminAuth, subscriptionController.adminCreatePlan);
router.put('/admin/plans/:id', adminAuth, subscriptionController.adminUpdatePlan);
router.delete('/admin/plans/:id', adminAuth, subscriptionController.adminDeletePlan);

// Subscription management
router.get('/admin/subscriptions', adminAuth, subscriptionController.adminGetAllSubscriptions);
router.get('/admin/user/:userId', adminAuth, subscriptionController.adminGetUserSubscription);
router.put('/admin/user/:userId', adminAuth, subscriptionController.adminUpdateUserSubscription);
router.post('/admin/user/:userId/cancel', adminAuth, subscriptionController.adminCancelUserSubscription);

// Stats
router.get('/admin/stats', adminAuth, subscriptionController.adminGetSubscriptionStats);
router.get('/admin/revenue', adminAuth, subscriptionController.adminGetRevenueStats);

// Usage management
router.get('/admin/user/:userId/usage', adminAuth, subscriptionController.adminGetUserUsageStats);
router.post('/admin/user/:userId/reset-usage', adminAuth, subscriptionController.adminResetUserUsage);

// IoT Admin routes
router.post('/admin/iot/addons', adminAuth, subscriptionController.adminCreateIotAddon);
router.put('/admin/iot/addons/:id', adminAuth, subscriptionController.adminUpdateIotAddon);
router.delete('/admin/iot/addons/:id', adminAuth, subscriptionController.adminDeleteIotAddon);

router.get('/admin/iot/subscriptions', adminAuth, subscriptionController.adminGetAllUserAddons);
router.get('/admin/iot/user/:userId', adminAuth, subscriptionController.adminGetUserAddons);
router.post('/admin/iot/user/:userId/cancel', adminAuth, subscriptionController.adminCancelUserAddon);

router.get('/admin/iot/devices', adminAuth, subscriptionController.adminGetLinkedDevices);
router.post('/admin/iot/device/unlink', adminAuth, subscriptionController.adminUnlinkDevice);

router.get('/admin/iot/stats', adminAuth, subscriptionController.adminGetIotStats);

module.exports = router;
