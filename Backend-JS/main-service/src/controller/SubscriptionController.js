/**
 * Subscription Controller
 * Handles all subscription-related operations for Krishi Mantra
 */

const { SubscriptionPlan, UserSubscription, PaymentHistory, UsageTracking, IotAddon, UserIotAddon, PendingCheckoutSession } = require('../model/Subscription');
const { notify } = require('../utils/notificationClient');
const User = require('../model/User');
const UserDetail = require('../model/UserDetail');
const stripeConfig = require('../config/stripe');
const logger = require('../utils/logger');
const redis = require('../config/redis');

const { HTTP_STATUS, CACHE_TTL } = require('../utils/constants');

/**
 * Get all subscription plans
 */
const getPlans = async (req, res) => {
  try {
    // Try cache first
    const cacheKey = 'subscription:plans';
    const cachedPlans = await redis.get(cacheKey);

    if (cachedPlans) {
      return res.status(HTTP_STATUS.OK).json({
        success: true,
        message: 'Subscription plans retrieved from cache',
        data: JSON.parse(cachedPlans),
      });
    }

    // Get from database
    let plans = await SubscriptionPlan.find({ isActive: true }).sort({ order: 1 }).lean();

    // If no plans in DB, seed them
    if (plans.length === 0) {
      await seedSubscriptionPlans();
      plans = await SubscriptionPlan.find({ isActive: true }).sort({ order: 1 }).lean();
    }

    // Cache for 1 hour
    await redis.set(cacheKey, JSON.stringify(plans), CACHE_TTL.VERY_LONG);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Subscription plans retrieved successfully',
      data: plans,
    });
  } catch (error) {
    logger.error('Error getting subscription plans:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get subscription plans',
      error: error.message,
    });
  }
};

/**
 * Get current user's subscription
 */
const getCurrentSubscription = async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;

    // Get active subscription
    const subscription = await UserSubscription.findOne({
      userId,
      status: { $in: ['active', 'trialing'] },
      endDate: { $gt: new Date() },
    })
      .populate('planId')
      .lean();

    if (!subscription) {
      // Return default free plan
      const freePlan = await SubscriptionPlan.findOne({ name: 'KISAN', isDefault: true }).lean();
      return res.status(HTTP_STATUS.OK).json({
        success: true,
        message: 'User is on free plan',
        data: {
          subscription: null,
          currentPlan: freePlan || stripeConfig.SUBSCRIPTION_PLANS.KISAN,
          isFreePlan: true,
        },
      });
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Subscription retrieved successfully',
      data: {
        subscription,
        currentPlan: subscription.planId,
        isFreePlan: false,
      },
    });
  } catch (error) {
    logger.error('Error getting current subscription:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get subscription',
      error: error.message,
    });
  }
};

/**
 * Create checkout session for subscription
 */
const createCheckoutSession = async (req, res) => {
  try {
    const { planName, billingCycle } = req.body;
    const user = req.user;

    // Handle both `_id` (from DB) and `id` (from JWT token)
    const userId = user._id || user.id;

    if (!planName || !billingCycle) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Plan name and billing cycle are required',
      });
    }

    if (!['KISAN_PRO', 'KISAN_PLUS', 'KISAN_MEGA'].includes(planName)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Invalid plan name. Choose from KISAN_PRO, KISAN_PLUS, or KISAN_MEGA',
      });
    }

    if (!['monthly', 'yearly'].includes(billingCycle)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Billing cycle must be monthly or yearly',
      });
    }
    // Check if user already has an active subscription
    const existingSubscription = await UserSubscription.findOne({
      userId: userId,
      status: 'active',
      endDate: { $gt: new Date() },
    });

    if (existingSubscription) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'You already have an active subscription. Please cancel it first or upgrade.',
        currentPlan: existingSubscription.planName,
      });
    }

    const session = await stripeConfig.createCheckoutSession({
      user,
      planName,
      billingCycle,
      successUrl: `${process.env.FRONTEND_URL || 'krishimantra://'}subscription/success?session_id={CHECKOUT_SESSION_ID}`,
      cancelUrl: `${process.env.FRONTEND_URL || 'krishimantra://'}subscription/cancel`,
    });

    // Persist (sessionId -> userId) so the webhook handler can verify the
    // session was created by the same user before activating.
    await PendingCheckoutSession.create({
      sessionId: session.id,
      userId,
      planName,
      billingCycle,
    });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Checkout session created',
      data: {
        sessionId: session.id,
        url: session.url,
      },
    });
  } catch (error) {
    logger.error('Error creating checkout session:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to create checkout session',
      error: error.message,
    });
  }
};

/**
 * Create payment intent for mobile apps
 */
const createPaymentIntent = async (req, res) => {
  try {
    const { planName, billingCycle } = req.body;
    const user = req.user;

    if (!planName || !billingCycle) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Plan name and billing cycle are required',
      });
    }

    const paymentIntent = await stripeConfig.createPaymentIntent({
      user,
      planName,
      billingCycle,
    });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Payment intent created',
      data: {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      },
    });
  } catch (error) {
    logger.error('Error creating payment intent:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to create payment intent',
      error: error.message,
    });
  }
};

/**
 * Confirm payment and activate subscription (for mobile).
 *
 * Hardening:
 *  - Trust intent metadata, not request body, for userId/planName/billingCycle.
 *    The body fields are ignored except `paymentIntentId`. createPaymentIntent
 *    writes the trusted values into Stripe metadata server-side at create time;
 *    re-reading them here prevents a hijacked-intent attack where user A pays
 *    for an intent created by user B.
 *  - Verify intent.metadata.userId === authenticated user.
 *  - Idempotent: if a PaymentHistory row already exists for this intent, return
 *    the existing subscription instead of creating a duplicate. Combined with
 *    the unique sparse index on stripePaymentIntentId this guards against
 *    races between concurrent confirm calls.
 *  - Refuse to activate if the user already has a different active subscription.
 */
const confirmPayment = async (req, res) => {
  try {
    const { paymentIntentId } = req.body;
    const user = req.user;
    const userId = (user._id || user.id).toString();

    if (!paymentIntentId) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Payment intent ID is required',
      });
    }

    // Idempotency: short-circuit if we've already processed this intent.
    const existingPayment = await PaymentHistory.findOne({
      stripePaymentIntentId: paymentIntentId,
    });
    if (existingPayment) {
      // Make sure the caller is the same user the intent belongs to. Don't
      // leak another user's subscription back to a hijacker.
      if (existingPayment.userId.toString() !== userId) {
        return res.status(HTTP_STATUS.FORBIDDEN).json({
          success: false,
          message: 'Payment intent does not belong to this user',
        });
      }
      const existingSubscription = await UserSubscription.findById(existingPayment.subscriptionId);
      return res.status(HTTP_STATUS.OK).json({
        success: true,
        message: 'Subscription already activated',
        data: { subscription: existingSubscription },
      });
    }

    // Verify payment intent with Stripe
    const paymentIntent = await stripeConfig.stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== 'succeeded') {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: `Payment not successful. Status: ${paymentIntent.status}`,
      });
    }

    // Trust the intent's metadata (set server-side at create time), not
    // the request body. This blocks a hijacker from paying a different
    // user's intent and activating their own plan.
    const intentUserId = paymentIntent.metadata?.userId;
    const planName = paymentIntent.metadata?.planName;
    const billingCycle = paymentIntent.metadata?.billingCycle;

    if (!intentUserId || !planName || !billingCycle) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Payment intent is missing required metadata',
      });
    }

    if (intentUserId !== userId) {
      logger.warn(
        `confirmPayment: user ${userId} attempted to confirm intent ${paymentIntentId} owned by ${intentUserId}`
      );
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Payment intent does not belong to this user',
      });
    }

    // Get plan (DB record — for displayName + planId)
    const plan = await SubscriptionPlan.findOne({ name: planName });
    if (!plan) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'Plan not found',
      });
    }

    // Reject if a different active subscription already exists. This mirrors
    // the guard in createCheckoutSession so the mobile path can't bypass it.
    const existingActive = await UserSubscription.findOne({
      userId,
      status: 'active',
      endDate: { $gt: new Date() },
    });
    if (existingActive && existingActive.planName !== planName) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'You already have an active subscription. Cancel it before subscribing to a different plan.',
        currentPlan: existingActive.planName,
      });
    }

    // Calculate end date
    const startDate = new Date();
    const endDate = new Date();
    if (billingCycle === 'yearly') {
      endDate.setFullYear(endDate.getFullYear() + 1);
    } else {
      endDate.setMonth(endDate.getMonth() + 1);
    }

    // Create or update subscription
    const subscription = await UserSubscription.findOneAndUpdate(
      { userId: userId },
      {
        userId: userId,
        planId: plan._id,
        planName: plan.name,
        stripeCustomerId: paymentIntent.customer,
        billingCycle,
        status: 'active',
        startDate,
        endDate,
        lastPaymentAmount: paymentIntent.amount,
        lastPaymentDate: new Date(),
        nextPaymentDate: endDate,
        autoRenew: true,
      },
      { upsert: true, new: true }
    );

    // Create payment history. Unique index on stripePaymentIntentId blocks
    // duplicates if two confirm calls race past the existence check above.
    try {
      await PaymentHistory.create({
        userId: userId,
        subscriptionId: subscription._id,
        stripePaymentIntentId: paymentIntentId,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        status: 'succeeded',
        description: `${plan.displayName} - ${billingCycle === 'yearly' ? 'Yearly' : 'Monthly'} Subscription`,
      });
    } catch (err) {
      // Duplicate key — another concurrent confirm call won the race.
      // The subscription is already activated; treat as success.
      if (err && err.code === 11000) {
        logger.info(`confirmPayment: duplicate intent ${paymentIntentId} short-circuited via unique index`);
        return res.status(HTTP_STATUS.OK).json({
          success: true,
          message: 'Subscription already activated',
          data: { subscription, plan },
        });
      }
      throw err;
    }

    // Update user detail
    await UserDetail.findOneAndUpdate(
      { userId: userId },
      {
        'subscription.type': plan.name,
        'subscription.endDate': endDate,
        'subscription.purchasedDate': startDate,
        'subscription.transactionDetails': {
          paymentIntentId,
          amount: paymentIntent.amount,
          billingCycle,
        },
      },
      { upsert: true }
    );

    // Clear cache
    await redis.del(`subscription:user:${userId}`);

    logger.info(`Subscription activated for user ${userId}: ${plan.name}`);

    // Best-effort push notification — fire-and-forget so a notification-
    // service blip can't roll back a successfully activated subscription.
    notify({
      userId,
      title: 'Subscription activated',
      message: `Your ${plan.displayName} plan is now active.`,
      type: 'subscription.activated',
      data: {
        planName: plan.name,
        billingCycle,
        endDate,
      },
    });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Subscription activated successfully',
      data: {
        subscription,
        plan,
      },
    });
  } catch (error) {
    logger.error('Error confirming payment:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to confirm payment',
      error: error.message,
    });
  }
};

/**
 * Cancel subscription
 */
const cancelSubscription = async (req, res) => {
  try {
    const { cancelImmediately, reason } = req.body;
    const userId = req.user._id || req.user.id;

    const subscription = await UserSubscription.findOne({
      userId,
      status: 'active',
    });

    if (!subscription) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'No active subscription found',
      });
    }

    // If Stripe subscription exists, cancel it
    if (subscription.stripeSubscriptionId) {
      await stripeConfig.cancelSubscription(
        subscription.stripeSubscriptionId,
        !cancelImmediately
      );
    }

    // Update subscription status
    subscription.status = cancelImmediately ? 'cancelled' : 'active';
    subscription.cancelledAt = new Date();
    subscription.cancellationReason = reason;
    subscription.autoRenew = false;

    if (cancelImmediately) {
      subscription.endDate = new Date();
    }

    await subscription.save();

    // Update user detail
    if (cancelImmediately) {
      await UserDetail.findOneAndUpdate(
        { userId },
        {
          'subscription.type': 'FREE',
          'subscription.endDate': null,
        }
      );
    }

    // Clear cache
    await redis.del(`subscription:user:${userId}`);

    logger.info(`Subscription cancelled for user ${userId}`);

    notify({
      userId,
      title: cancelImmediately
        ? 'Subscription cancelled'
        : 'Subscription cancellation scheduled',
      message: cancelImmediately
        ? 'Your subscription is cancelled and the plan is now free.'
        : 'Your subscription will end at the close of the current billing period.',
      type: 'subscription.cancelled',
      data: { cancelImmediately: !!cancelImmediately, reason },
    });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: cancelImmediately
        ? 'Subscription cancelled immediately'
        : 'Subscription will be cancelled at the end of the billing period',
      data: subscription,
    });
  } catch (error) {
    logger.error('Error cancelling subscription:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to cancel subscription',
      error: error.message,
    });
  }
};

/**
 * Resume cancelled subscription
 */
const resumeSubscription = async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;

    const subscription = await UserSubscription.findOne({
      userId,
      status: 'active',
      autoRenew: false,
    });

    if (!subscription) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'No subscription to resume',
      });
    }

    if (subscription.stripeSubscriptionId) {
      await stripeConfig.resumeSubscription(subscription.stripeSubscriptionId);
    }

    subscription.autoRenew = true;
    subscription.cancelledAt = null;
    subscription.cancellationReason = null;
    await subscription.save();

    // Clear cache
    await redis.del(`subscription:user:${userId}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Subscription resumed successfully',
      data: subscription,
    });
  } catch (error) {
    logger.error('Error resuming subscription:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to resume subscription',
      error: error.message,
    });
  }
};

/**
 * Get usage stats for current user
 */
const getUsageStats = async (req, res) => {
  try {
    const userId = req.user?._id || req.user?.id;

    if (!userId) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'User ID is required',
      });
    }

    // Get today's usage
    const usage = await UsageTracking.getTodayUsage(userId);

    // Aggregate this calendar month's video consultations across all
    // per-day rows. The daily counters reset by virtue of a new row
    // being created each day, but `videoConsultationsPerMonth` is a
    // monthly limit — without summing the month we'd compare a
    // single-day count against a monthly cap, undercounting and
    // letting users exceed it.
    const now = new Date();
    const monthStart = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-01`;
    const monthlyAgg = await UsageTracking.aggregate([
      { $match: { userId, date: { $gte: monthStart } } },
      {
        $group: {
          _id: null,
          videoConsultationsUsed: { $sum: '$videoConsultationsUsed' },
        },
      },
    ]);
    const videoConsultationsUsedMonth =
      (monthlyAgg[0] && monthlyAgg[0].videoConsultationsUsed) || 0;

    // Get user's subscription/plan limits
    const subscription = await UserSubscription.findOne({
      userId,
      status: { $in: ['active', 'trialing'] },
      endDate: { $gt: new Date() },
    }).populate('planId');

    let limits;
    if (subscription?.planId) {
      limits = subscription.planId.features;
    } else {
      // Default free plan limits
      limits = stripeConfig.SUBSCRIPTION_PLANS.KISAN.features;
    }

    // Calculate remaining
    const remaining = {
      aiMessages: limits.aiMessagesPerDay === -1 ? -1 : Math.max(0, limits.aiMessagesPerDay - usage.aiMessagesUsed),
      imageAnalysis: limits.imageAnalysisPerDay === -1 ? -1 : Math.max(0, limits.imageAnalysisPerDay - usage.imageAnalysisUsed),
      consultantChats: limits.consultantChatsPerDay === -1 ? -1 : Math.max(0, limits.consultantChatsPerDay - usage.consultantChatsUsed),
      videoConsultations: limits.videoConsultationsPerMonth === -1 ? -1 : Math.max(0, limits.videoConsultationsPerMonth - videoConsultationsUsedMonth),
    };

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Usage stats retrieved',
      data: {
        usage: {
          aiMessagesUsed: usage.aiMessagesUsed,
          imageAnalysisUsed: usage.imageAnalysisUsed,
          consultantChatsUsed: usage.consultantChatsUsed,
          // Month-to-date so the client sees usage that matches the
          // monthly limit it's compared against.
          videoConsultationsUsed: videoConsultationsUsedMonth,
        },
        limits: {
          aiMessagesPerDay: limits.aiMessagesPerDay,
          imageAnalysisPerDay: limits.imageAnalysisPerDay,
          consultantChatsPerDay: limits.consultantChatsPerDay,
          videoConsultationsPerMonth: limits.videoConsultationsPerMonth,
        },
        remaining,
        planName: subscription?.planName || 'KISAN',
      },
    });
  } catch (error) {
    logger.error('Error getting usage stats:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get usage stats',
      error: error.message,
    });
  }
};

/**
 * Get payment history
 */
const getPaymentHistory = async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    const { page = 1, limit = 10 } = req.query;

    const payments = await PaymentHistory.find({ userId })
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .lean();

    const total = await PaymentHistory.countDocuments({ userId });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Payment history retrieved',
      data: {
        payments,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / limit),
        },
      },
    });
  } catch (error) {
    logger.error('Error getting payment history:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get payment history',
      error: error.message,
    });
  }
};

/**
 * Check feature access
 */
const checkFeatureAccess = async (req, res) => {
  try {
    const { feature } = req.params;
    const userId = req.user._id || req.user.id;

    const access = await checkUserFeatureAccess(userId, feature);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Feature access checked',
      data: access,
    });
  } catch (error) {
    logger.error('Error checking feature access:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to check feature access',
      error: error.message,
    });
  }
};

/**
 * Stripe webhook handler
 */
const handleWebhook = async (req, res) => {
  const sig = req.headers['stripe-signature'];

  let event;

  try {
    event = stripeConfig.constructWebhookEvent(req.body, sig);
  } catch (err) {
    logger.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  try {
    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutCompleted(event.data.object);
        break;

      case 'customer.subscription.created':
      case 'customer.subscription.updated':
        await handleSubscriptionUpdated(event.data.object);
        break;

      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object);
        break;

      case 'invoice.paid':
        await handleInvoicePaid(event.data.object);
        break;

      case 'invoice.payment_failed':
        await handlePaymentFailed(event.data.object);
        break;

      default:
        logger.info(`Unhandled webhook event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (error) {
    logger.error('Error handling webhook:', error);
    res.status(500).json({ error: 'Webhook handler failed' });
  }
};

// Webhook handlers
async function handleCheckoutCompleted(session) {
  // Look up the session in our DB. If we never created it, refuse to
  // activate — the webhook signature was valid but the metadata is not
  // something we recorded, so we can't trust it.
  const pending = await PendingCheckoutSession.findOne({ sessionId: session.id });
  if (!pending) {
    logger.error(
      `handleCheckoutCompleted: no pending session record for ${session.id}; refusing activation`
    );
    return;
  }

  // Cross-check: the metadata carried by Stripe must match what we
  // stored at create time. A mismatch means either tampering or a
  // service drift; either way, don't activate.
  const metaUserId = session.metadata?.userId;
  const metaPlanName = session.metadata?.planName;
  const metaBillingCycle = session.metadata?.billingCycle;
  const expectedUserId = pending.userId.toString();

  if (
    metaUserId !== expectedUserId ||
    metaPlanName !== pending.planName ||
    metaBillingCycle !== pending.billingCycle
  ) {
    logger.error(
      `handleCheckoutCompleted: metadata mismatch for session ${session.id}. expected user=${expectedUserId} plan=${pending.planName} cycle=${pending.billingCycle}; got user=${metaUserId} plan=${metaPlanName} cycle=${metaBillingCycle}`
    );
    return;
  }

  const userId = expectedUserId;
  const { planName, billingCycle } = pending;

  logger.info(`Checkout completed for user ${userId}: ${planName}`);

  const plan = await SubscriptionPlan.findOne({ name: planName });
  if (!plan) {
    logger.error(`Plan not found: ${planName}`);
    return;
  }

  // Calculate dates
  const startDate = new Date();
  const endDate = new Date();
  if (billingCycle === 'yearly') {
    endDate.setFullYear(endDate.getFullYear() + 1);
  } else {
    endDate.setMonth(endDate.getMonth() + 1);
  }

  // Create subscription
  await UserSubscription.findOneAndUpdate(
    { userId },
    {
      userId,
      planId: plan._id,
      planName: plan.name,
      stripeCustomerId: session.customer,
      stripeSubscriptionId: session.subscription,
      billingCycle,
      status: 'active',
      startDate,
      endDate,
      lastPaymentAmount: session.amount_total,
      lastPaymentDate: new Date(),
      autoRenew: true,
    },
    { upsert: true, new: true }
  );

  // Update user detail
  await UserDetail.findOneAndUpdate(
    { userId },
    {
      'subscription.type': plan.name,
      'subscription.endDate': endDate,
      'subscription.purchasedDate': startDate,
    },
    { upsert: true }
  );

  // Clear cache
  await redis.del(`subscription:user:${userId}`);

  // Consume the pending record so a replay of the same webhook can't
  // re-activate later.
  await PendingCheckoutSession.deleteOne({ sessionId: session.id });
}

async function handleSubscriptionUpdated(subscription) {
  const userId = subscription.metadata?.userId;
  if (!userId) return;

  const status = subscription.status;
  const cancelAtPeriodEnd = subscription.cancel_at_period_end;

  await UserSubscription.findOneAndUpdate(
    { stripeSubscriptionId: subscription.id },
    {
      status: cancelAtPeriodEnd ? 'active' : status,
      autoRenew: !cancelAtPeriodEnd,
      endDate: new Date(subscription.current_period_end * 1000),
      nextPaymentDate: cancelAtPeriodEnd ? null : new Date(subscription.current_period_end * 1000),
    }
  );

  await redis.del(`subscription:user:${userId}`);
}

async function handleSubscriptionDeleted(subscription) {
  const userId = subscription.metadata?.userId;
  if (!userId) return;

  await UserSubscription.findOneAndUpdate(
    { stripeSubscriptionId: subscription.id },
    {
      status: 'cancelled',
      endDate: new Date(),
    }
  );

  // Downgrade to free
  await UserDetail.findOneAndUpdate(
    { userId },
    {
      'subscription.type': 'FREE',
      'subscription.endDate': null,
    }
  );

  await redis.del(`subscription:user:${userId}`);
}

async function handleInvoicePaid(invoice) {
  const subscriptionId = invoice.subscription;

  const userSub = await UserSubscription.findOne({ stripeSubscriptionId: subscriptionId });
  if (!userSub) return;

  await PaymentHistory.create({
    userId: userSub.userId,
    subscriptionId: userSub._id,
    stripeInvoiceId: invoice.id,
    stripeChargeId: invoice.charge,
    amount: invoice.amount_paid,
    currency: invoice.currency,
    status: 'succeeded',
    invoiceUrl: invoice.hosted_invoice_url,
    receiptUrl: invoice.receipt_url,
  });

  userSub.lastPaymentAmount = invoice.amount_paid;
  userSub.lastPaymentDate = new Date();
  await userSub.save();
}

async function handlePaymentFailed(invoice) {
  const subscriptionId = invoice.subscription;

  const userSub = await UserSubscription.findOne({ stripeSubscriptionId: subscriptionId });
  if (!userSub) return;

  userSub.status = 'past_due';
  await userSub.save();

  await PaymentHistory.create({
    userId: userSub.userId,
    subscriptionId: userSub._id,
    stripeInvoiceId: invoice.id,
    amount: invoice.amount_due,
    currency: invoice.currency,
    status: 'failed',
  });

  await redis.del(`subscription:user:${userSub.userId}`);
}

/**
 * Seed subscription plans
 */
async function seedSubscriptionPlans() {
  try {
    const plans = Object.values(stripeConfig.SUBSCRIPTION_PLANS);

    for (const plan of plans) {
      await SubscriptionPlan.findOneAndUpdate(
        { name: plan.name },
        plan,
        { upsert: true, new: true }
      );
    }

    logger.info('Subscription plans seeded successfully');

    // Clear plans cache
    await redis.del('subscription:plans');
  } catch (error) {
    logger.error('Error seeding subscription plans:', error);
    throw error;
  }
}

/**
 * Helper function to check user feature access
 */
async function checkUserFeatureAccess(userId, feature) {
  // Try cache first
  const cacheKey = `subscription:user:${userId}:access`;
  const cached = await redis.get(cacheKey);

  let subscription;
  let limits;

  if (cached) {
    const data = JSON.parse(cached);
    limits = data.limits;
  } else {
    subscription = await UserSubscription.findOne({
      userId,
      status: { $in: ['active', 'trialing'] },
      endDate: { $gt: new Date() },
    }).populate('planId');

    if (subscription?.planId) {
      limits = subscription.planId.features;
    } else {
      limits = stripeConfig.SUBSCRIPTION_PLANS.KISAN.features;
    }

    // Cache for 5 minutes
    await redis.set(cacheKey, JSON.stringify({ limits }), 300);
  }

  // Get today's usage
  const usage = await UsageTracking.getTodayUsage(userId);

  // Check specific feature
  switch (feature) {
    case 'aiMessage':
      if (limits.aiMessagesPerDay === -1) {
        return { allowed: true, remaining: -1, limit: -1 };
      }
      const aiRemaining = limits.aiMessagesPerDay - usage.aiMessagesUsed;
      return {
        allowed: aiRemaining > 0,
        remaining: Math.max(0, aiRemaining),
        limit: limits.aiMessagesPerDay,
        used: usage.aiMessagesUsed,
      };

    case 'imageAnalysis':
      if (limits.imageAnalysisPerDay === -1) {
        return { allowed: true, remaining: -1, limit: -1 };
      }
      const imgRemaining = limits.imageAnalysisPerDay - usage.imageAnalysisUsed;
      return {
        allowed: imgRemaining > 0,
        remaining: Math.max(0, imgRemaining),
        limit: limits.imageAnalysisPerDay,
        used: usage.imageAnalysisUsed,
      };

    case 'consultantChat':
      if (limits.consultantChatsPerDay === -1) {
        return { allowed: true, remaining: -1, limit: -1 };
      }
      const chatRemaining = limits.consultantChatsPerDay - usage.consultantChatsUsed;
      return {
        allowed: chatRemaining > 0,
        remaining: Math.max(0, chatRemaining),
        limit: limits.consultantChatsPerDay,
        used: usage.consultantChatsUsed,
      };

    case 'createPost':
      return { allowed: limits.canCreatePosts };

    case 'createReel':
      return { allowed: limits.canCreateReels };

    case 'marketplaceListing':
      return {
        allowed: limits.marketplaceListings === -1 || limits.marketplaceListings > 0,
        limit: limits.marketplaceListings,
      };

    default:
      return { allowed: false, message: 'Unknown feature' };
  }
}

/**
 * Increment usage (internal helper)
 */
async function incrementUsage(userId, feature) {
  const usage = await UsageTracking.getTodayUsage(userId);

  const fieldMap = {
    aiMessage: 'aiMessagesUsed',
    imageAnalysis: 'imageAnalysisUsed',
    consultantChat: 'consultantChatsUsed',
    videoConsultation: 'videoConsultationsUsed',
  };

  const field = fieldMap[feature];
  if (!field) {
    throw new Error(`Invalid feature: ${feature}`);
  }

  usage[field] += 1;
  await usage.save();

  return usage;
}

/**
 * Increment usage (internal API endpoint)
 * Called by other microservices to track usage
 */
const incrementUsageInternal = async (req, res) => {
  try {
    const { userId, feature } = req.body;

    if (!userId || !feature) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'userId and feature are required',
      });
    }

    const usage = await incrementUsage(userId, feature);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Usage incremented successfully',
      data: {
        aiMessagesUsed: usage.aiMessagesUsed,
        imageAnalysisUsed: usage.imageAnalysisUsed,
        consultantChatsUsed: usage.consultantChatsUsed,
        videoConsultationsUsed: usage.videoConsultationsUsed,
      },
    });
  } catch (error) {
    logger.error('Error incrementing usage internally:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to increment usage',
      error: error.message,
    });
  }
};

// ========== IoT ADD-ON FUNCTIONS ==========


const getDefaultDeviceAccess = () => ({
  pump: { purchased: false, enabled: false },
  krishiDoctor: { purchased: false, enabled: false },
});

const getUserDeviceAccess = async (userId) => {
  const userDetails = await UserDetail.findOne({ userId }).select('deviceAccess').lean();
  const access = userDetails?.deviceAccess || getDefaultDeviceAccess();

  return {
    pump: {
      purchased: Boolean(access.pump?.purchased),
      enabled: Boolean(access.pump?.enabled),
    },
    krishiDoctor: {
      purchased: Boolean(access.krishiDoctor?.purchased),
      enabled: Boolean(access.krishiDoctor?.enabled),
    },
  };
};

const getAllowedAddonNames = (deviceAccess) => {
  const allowed = [];

  const hasPump = deviceAccess.pump.purchased && deviceAccess.pump.enabled;
  const hasKrishiDoctor = deviceAccess.krishiDoctor.purchased && deviceAccess.krishiDoctor.enabled;

  if (hasPump) allowed.push('WATER_PUMP');
  if (hasKrishiDoctor) allowed.push('CROP_IOT');
  if (hasPump && hasKrishiDoctor) allowed.push('IOT_BUNDLE');

  return allowed;
};

/**
 * Get all IoT add-ons
 */
const getIotAddons = async (req, res) => {
  try {
    // Try cache first
    const cacheKey = 'iot:addons';
    const cachedAddons = await redis.get(cacheKey);

    let addons = cachedAddons ? JSON.parse(cachedAddons) : [];

    // Get from database if cache miss
    if (!cachedAddons) {
      addons = await IotAddon.find({ isActive: true }).sort({ order: 1 }).lean();

      // If no addons in DB, seed them
      if (addons.length === 0) {
        await seedIotAddons();
        addons = await IotAddon.find({ isActive: true }).sort({ order: 1 }).lean();
      }

      // Cache for 1 hour
      await redis.set(cacheKey, JSON.stringify(addons), CACHE_TTL.VERY_LONG);
    }

    // If authenticated user is available, filter by admin-enabled device access
    if (req.user) {
      const userId = req.user._id || req.user.id;
      const deviceAccess = await getUserDeviceAccess(userId);
      const allowedAddonNames = getAllowedAddonNames(deviceAccess);
      addons = addons.filter((addon) => allowedAddonNames.includes(addon.name));
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'IoT add-ons retrieved successfully',
      data: addons,
    });
  } catch (error) {
    logger.error('Error getting IoT add-ons:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get IoT add-ons',
      error: error.message,
    });
  }
};

/**
 * Get user's IoT add-on subscriptions
 */
const getUserIotAddons = async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;

    const deviceAccess = await getUserDeviceAccess(userId);
    const allowedAddonNames = getAllowedAddonNames(deviceAccess);

    if (allowedAddonNames.length === 0) {
      return res.status(HTTP_STATUS.OK).json({
        success: true,
        message: 'User IoT add-ons retrieved successfully',
        data: [],
      });
    }

    const userAddons = await UserIotAddon.find({
      userId,
      addonName: { $in: allowedAddonNames },
      status: 'active',
      endDate: { $gt: new Date() },
    }).populate('addonId').lean();

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User IoT add-ons retrieved successfully',
      data: userAddons,
    });
  } catch (error) {
    logger.error('Error getting user IoT add-ons:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get user IoT add-ons',
      error: error.message,
    });
  }
};

/**
 * Create payment intent for IoT add-on (mobile)
 */
const createIotAddonPaymentIntent = async (req, res) => {
  try {
    const { addonName, billingCycle } = req.body;
    const user = req.user;

    // Handle both `_id` (from DB) and `id` (from JWT token)
    const userId = user._id || user.id;

    if (!addonName || !billingCycle) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Addon name and billing cycle are required',
      });
    }

    if (!['WATER_PUMP', 'CROP_IOT', 'IOT_BUNDLE'].includes(addonName)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Invalid addon name. Choose from WATER_PUMP, CROP_IOT, or IOT_BUNDLE',
      });
    }

    if (!['monthly', 'yearly'].includes(billingCycle)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Billing cycle must be monthly or yearly',
      });
    }

    const deviceAccess = await getUserDeviceAccess(userId);
    const allowedAddonNames = getAllowedAddonNames(deviceAccess);

    if (!allowedAddonNames.includes(addonName)) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Addon is not enabled for this user. Please contact admin.',
      });
    }

    // Check if user already has this addon (or bundle that includes it)
    const existingAddon = await UserIotAddon.findOne({
      userId: userId,
      status: 'active',
      endDate: { $gt: new Date() },
      $or: [
        { addonName },
        { addonName: 'IOT_BUNDLE' }, // Bundle includes both
      ],
    });

    if (existingAddon) {
      // If buying individual addon but already has bundle
      if (existingAddon.addonName === 'IOT_BUNDLE') {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          message: 'You already have the IoT Bundle which includes all features',
        });
      }
      // If buying same addon again
      if (existingAddon.addonName === addonName) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          message: `You already have an active ${addonName} subscription`,
        });
      }
    }

    // If buying bundle, check if they have individual addons (offer discount info)
    if (addonName === 'IOT_BUNDLE') {
      const hasWaterPump = await UserIotAddon.findOne({
        userId: userId,
        addonName: 'WATER_PUMP',
        status: 'active',
        endDate: { $gt: new Date() },
      });
      const hasCropIot = await UserIotAddon.findOne({
        userId: userId,
        addonName: 'CROP_IOT',
        status: 'active',
        endDate: { $gt: new Date() },
      });

      if (hasWaterPump || hasCropIot) {
        // Cancel existing individual addons when buying bundle
        if (hasWaterPump) {
          hasWaterPump.status = 'cancelled';
          hasWaterPump.cancelledAt = new Date();
          await hasWaterPump.save();
        }
        if (hasCropIot) {
          hasCropIot.status = 'cancelled';
          hasCropIot.cancelledAt = new Date();
          await hasCropIot.save();
        }
      }
    }

    const paymentIntent = await stripeConfig.createIotAddonPaymentIntent({
      user,
      addonName,
      billingCycle,
    });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'IoT add-on payment intent created',
      data: {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      },
    });
  } catch (error) {
    logger.error('Error creating IoT addon payment intent:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to create payment intent',
      error: error.message,
    });
  }
};

/**
 * Confirm IoT add-on payment and activate (mobile)
 */
const confirmIotAddonPayment = async (req, res) => {
  try {
    const { paymentIntentId, addonName, billingCycle } = req.body;
    const user = req.user;

    // Handle both `_id` (from DB) and `id` (from JWT token)
    const userId = user._id || user.id;

    if (!paymentIntentId || !addonName || !billingCycle) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Payment intent ID, addon name, and billing cycle are required',
      });
    }

    const deviceAccess = await getUserDeviceAccess(userId);
    const allowedAddonNames = getAllowedAddonNames(deviceAccess);

    if (!allowedAddonNames.includes(addonName)) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Addon is not enabled for this user. Please contact admin.',
      });
    }

    // Verify payment intent
    const paymentIntent = await stripeConfig.stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== 'succeeded') {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: `Payment not successful. Status: ${paymentIntent.status}`,
      });
    }

    // Get addon
    const addon = await IotAddon.findOne({ name: addonName });
    if (!addon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'IoT add-on not found',
      });
    }

    // Calculate end date
    const startDate = new Date();
    const endDate = new Date();
    if (billingCycle === 'yearly') {
      endDate.setFullYear(endDate.getFullYear() + 1);
    } else {
      endDate.setMonth(endDate.getMonth() + 1);
    }

    // Create user IoT addon subscription
    const userIotAddon = await UserIotAddon.create({
      userId: userId,
      addonId: addon._id,
      addonName: addon.name,
      stripeCustomerId: paymentIntent.customer,
      billingCycle,
      status: 'active',
      startDate,
      endDate,
      lastPaymentAmount: paymentIntent.amount,
      lastPaymentDate: new Date(),
      nextPaymentDate: endDate,
      autoRenew: true,
    });

    // Create payment history
    await PaymentHistory.create({
      userId: userId,
      subscriptionId: userIotAddon._id,
      stripePaymentIntentId: paymentIntentId,
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
      status: 'succeeded',
      description: `${addon.displayName} - ${billingCycle === 'yearly' ? 'Yearly' : 'Monthly'} Add-on`,
      metadata: {
        type: 'iot_addon',
        addonName: addon.name,
      },
    });

    // Clear cache
    await redis.del(`iot:user:${userId}`);

    logger.info(`IoT add-on activated for user ${userId}: ${addon.name}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'IoT add-on activated successfully',
      data: {
        userIotAddon,
        addon,
      },
    });
  } catch (error) {
    logger.error('Error confirming IoT addon payment:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to confirm IoT addon payment',
      error: error.message,
    });
  }
};

/**
 * Cancel IoT add-on subscription
 */
const cancelIotAddon = async (req, res) => {
  try {
    const { addonName, cancelImmediately, reason } = req.body;
    const userId = req.user._id || req.user.id;

    const userAddon = await UserIotAddon.findOne({
      userId,
      addonName,
      status: 'active',
    });

    if (!userAddon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'No active IoT add-on found',
      });
    }

    // If Stripe subscription exists, cancel it
    if (userAddon.stripeSubscriptionId) {
      await stripeConfig.cancelSubscription(
        userAddon.stripeSubscriptionId,
        !cancelImmediately
      );
    }

    // Update status
    userAddon.status = cancelImmediately ? 'cancelled' : 'active';
    userAddon.cancelledAt = new Date();
    userAddon.autoRenew = false;

    if (cancelImmediately) {
      userAddon.endDate = new Date();
    }

    await userAddon.save();

    // Clear cache
    await redis.del(`iot:user:${userId}`);

    logger.info(`IoT add-on cancelled for user ${userId}: ${addonName}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: cancelImmediately
        ? 'IoT add-on cancelled immediately'
        : 'IoT add-on will be cancelled at the end of the billing period',
      data: userAddon,
    });
  } catch (error) {
    logger.error('Error cancelling IoT addon:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to cancel IoT add-on',
      error: error.message,
    });
  }
};

/**
 * Check IoT feature access
 */
const checkIotFeatureAccess = async (req, res) => {
  try {
    const { feature } = req.params;
    const userId = req.user._id || req.user.id;

    const access = await checkUserIotAccess(userId, feature);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'IoT feature access checked',
      data: access,
    });
  } catch (error) {
    logger.error('Error checking IoT feature access:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to check IoT feature access',
      error: error.message,
    });
  }
};

/**
 * Helper function to check IoT feature access
 */
async function checkUserIotAccess(userId, feature) {
  // Get user's active IoT addons
  const deviceAccess = await getUserDeviceAccess(userId);
  const allowedAddonNames = getAllowedAddonNames(deviceAccess);

  if (allowedAddonNames.length === 0) {
    return { allowed: false, message: 'IoT devices are not enabled by admin' };
  }

  const userAddons = await UserIotAddon.find({
    userId,
    addonName: { $in: allowedAddonNames },
    status: 'active',
    endDate: { $gt: new Date() },
  }).populate('addonId');

  if (userAddons.length === 0) {
    return { allowed: false, message: 'No active IoT add-on' };
  }

  // Aggregate features from all active addons
  const iotFeatures = {
    waterPump: { enabled: false },
    cropMonitoring: { enabled: false },
    weatherStation: { enabled: false },
  };

  for (const addon of userAddons) {
    if (addon.addonId.features.waterPump?.enabled) {
      iotFeatures.waterPump = addon.addonId.features.waterPump;
    }
    if (addon.addonId.features.cropMonitoring?.enabled) {
      iotFeatures.cropMonitoring = addon.addonId.features.cropMonitoring;
    }
    if (addon.addonId.features.weatherStation?.enabled) {
      iotFeatures.weatherStation = addon.addonId.features.weatherStation;
    }
  }

  // Check specific feature
  switch (feature) {
    case 'waterPump':
      return {
        allowed: iotFeatures.waterPump.enabled,
        features: iotFeatures.waterPump,
      };
    case 'cropMonitoring':
      return {
        allowed: iotFeatures.cropMonitoring.enabled,
        features: iotFeatures.cropMonitoring,
      };
    case 'weatherStation':
      return {
        allowed: iotFeatures.weatherStation.enabled,
        features: iotFeatures.weatherStation,
      };
    default:
      return { allowed: false, message: 'Unknown IoT feature' };
  }
}

/**
 * Seed IoT add-ons
 */
async function seedIotAddons() {
  try {
    const addons = Object.values(stripeConfig.IOT_ADDONS);

    for (const addon of addons) {
      await IotAddon.findOneAndUpdate(
        { name: addon.name },
        addon,
        { upsert: true, new: true }
      );
    }

    logger.info('IoT add-ons seeded successfully');

    // Clear cache
    await redis.del('iot:addons');
  } catch (error) {
    logger.error('Error seeding IoT add-ons:', error);
    throw error;
  }
}

/**
 * Link IoT device to user's subscription
 */
const linkIotDevice = async (req, res) => {
  try {
    const { addonName, deviceId, deviceType, deviceName } = req.body;
    const userId = req.user._id || req.user.id;

    if (!addonName || !deviceId || !deviceType) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Addon name, device ID, and device type are required',
      });
    }

    const userAddon = await UserIotAddon.findOne({
      userId,
      addonName,
      status: 'active',
      endDate: { $gt: new Date() },
    }).populate('addonId');

    if (!userAddon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'No active IoT add-on found',
      });
    }

    // Check device limit
    const features = userAddon.addonId.features;
    let maxDevices = 0;

    if (deviceType === 'water_pump') {
      maxDevices = features.waterPump?.maxDevices || 0;
    } else if (['soil_sensor', 'temperature_sensor', 'humidity_sensor'].includes(deviceType)) {
      maxDevices = features.cropMonitoring?.maxSensors || 0;
    }

    if (maxDevices !== -1 && userAddon.linkedDevices.length >= maxDevices) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: `Maximum device limit (${maxDevices}) reached for this add-on`,
      });
    }

    // Check if device already linked
    const deviceExists = userAddon.linkedDevices.find(d => d.deviceId === deviceId);
    if (deviceExists) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Device already linked',
      });
    }

    // Link device
    userAddon.linkedDevices.push({
      deviceId,
      deviceType,
      deviceName: deviceName || `${deviceType}_${deviceId.substring(0, 6)}`,
      addedAt: new Date(),
      isActive: true,
    });

    await userAddon.save();

    logger.info(`IoT device linked for user ${userId}: ${deviceId}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Device linked successfully',
      data: userAddon,
    });
  } catch (error) {
    logger.error('Error linking IoT device:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to link IoT device',
      error: error.message,
    });
  }
};

/**
 * Unlink IoT device
 */
const unlinkIotDevice = async (req, res) => {
  try {
    const { addonName, deviceId } = req.body;
    const userId = req.user._id || req.user.id;

    const userAddon = await UserIotAddon.findOne({
      userId,
      addonName,
      status: 'active',
    });

    if (!userAddon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'No active IoT add-on found',
      });
    }

    const deviceIndex = userAddon.linkedDevices.findIndex(d => d.deviceId === deviceId);
    if (deviceIndex === -1) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'Device not found',
      });
    }

    userAddon.linkedDevices.splice(deviceIndex, 1);
    await userAddon.save();

    logger.info(`IoT device unlinked for user ${userId}: ${deviceId}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Device unlinked successfully',
      data: userAddon,
    });
  } catch (error) {
    logger.error('Error unlinking IoT device:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to unlink IoT device',
      error: error.message,
    });
  }
};

// ========== SUPER ADMIN FUNCTIONS ==========

/**
 * Get all subscriptions with pagination and filters (Admin)
 */
const adminGetAllSubscriptions = async (req, res) => {
  try {
    const { page = 1, limit = 20, status, planName, search } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Build query
    const query = {};
    if (status) query.status = status;
    if (planName) query.planName = planName;

    // If search query, find matching users first. Escape regex metachars
    // so admin-supplied search can't drift into a ReDoS pattern.
    let userIds = null;
    if (search && typeof search === 'string') {
      const safe = search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').slice(0, 100);
      const users = await User.find({
        $or: [
          { name: { $regex: safe, $options: 'i' } },
          { phone: { $regex: safe, $options: 'i' } },
          { email: { $regex: safe, $options: 'i' } },
        ],
      }).select('_id');
      userIds = users.map(u => u._id);
      query.userId = { $in: userIds };
    }

    const [subscriptions, total] = await Promise.all([
      UserSubscription.find(query)
        .populate('userId', 'name phone email avatar')
        .populate('planId', 'name displayName')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .lean(),
      UserSubscription.countDocuments(query),
    ]);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Subscriptions retrieved successfully',
      data: {
        subscriptions,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit)),
        },
      },
    });
  } catch (error) {
    logger.error('Error getting all subscriptions:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get subscriptions',
      error: error.message,
    });
  }
};

/**
 * Get user's subscription by user ID (Admin)
 */
const adminGetUserSubscription = async (req, res) => {
  try {
    const { userId } = req.params;

    const [subscription, usage, paymentHistory] = await Promise.all([
      UserSubscription.findOne({ userId })
        .populate('planId')
        .lean(),
      UsageTracking.getTodayUsage(userId),
      PaymentHistory.find({ userId })
        .sort({ createdAt: -1 })
        .limit(10)
        .lean(),
    ]);

    const user = await User.findById(userId).select('name phone email avatar').lean();

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User subscription retrieved',
      data: {
        user,
        subscription,
        usage: {
          aiMessagesUsed: usage.aiMessagesUsed,
          imageAnalysisUsed: usage.imageAnalysisUsed,
          consultantChatsUsed: usage.consultantChatsUsed,
          videoConsultationsUsed: usage.videoConsultationsUsed,
        },
        paymentHistory,
      },
    });
  } catch (error) {
    logger.error('Error getting user subscription:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get user subscription',
      error: error.message,
    });
  }
};

/**
 * Update user's subscription (Admin)
 */
const adminUpdateUserSubscription = async (req, res) => {
  try {
    const { userId } = req.params;
    const { planName, status, endDate, billingCycle, autoRenew } = req.body;

    let subscription = await UserSubscription.findOne({ userId });

    if (!subscription) {
      // Create new subscription
      const plan = await SubscriptionPlan.findOne({ name: planName || 'KISAN' });
      if (!plan) {
        return res.status(HTTP_STATUS.NOT_FOUND).json({
          success: false,
          message: 'Plan not found',
        });
      }

      subscription = await UserSubscription.create({
        userId,
        planId: plan._id,
        planName: plan.name,
        status: status || 'active',
        startDate: new Date(),
        endDate: endDate ? new Date(endDate) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        billingCycle: billingCycle || 'monthly',
        autoRenew: autoRenew !== undefined ? autoRenew : true,
      });
    } else {
      // Update existing subscription
      if (planName) {
        const plan = await SubscriptionPlan.findOne({ name: planName });
        if (plan) {
          subscription.planId = plan._id;
          subscription.planName = plan.name;
        }
      }
      if (status) subscription.status = status;
      if (endDate) subscription.endDate = new Date(endDate);
      if (billingCycle) subscription.billingCycle = billingCycle;
      if (autoRenew !== undefined) subscription.autoRenew = autoRenew;

      await subscription.save();
    }

    // Update user detail
    const plan = await SubscriptionPlan.findById(subscription.planId);
    await UserDetail.findOneAndUpdate(
      { userId },
      {
        'subscription.type': plan?.name || 'KISAN',
        'subscription.endDate': subscription.endDate,
      },
      { upsert: true }
    );

    // Clear cache
    await redis.del(`subscription:user:${userId}`);

    logger.info(`Admin updated subscription for user ${userId}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User subscription updated',
      data: subscription,
    });
  } catch (error) {
    logger.error('Error updating user subscription:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to update user subscription',
      error: error.message,
    });
  }
};

/**
 * Cancel user's subscription (Admin)
 */
const adminCancelUserSubscription = async (req, res) => {
  try {
    const { userId } = req.params;
    const { reason, cancelImmediately } = req.body;

    const subscription = await UserSubscription.findOne({
      userId,
      status: { $in: ['active', 'trialing'] },
    });

    if (!subscription) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'No active subscription found',
      });
    }

    // Cancel Stripe subscription if exists
    if (subscription.stripeSubscriptionId) {
      try {
        await stripeConfig.cancelSubscription(subscription.stripeSubscriptionId, !cancelImmediately);
      } catch (stripeError) {
        logger.warn('Stripe cancellation failed:', stripeError.message);
      }
    }

    subscription.status = cancelImmediately ? 'cancelled' : 'active';
    subscription.cancelledAt = new Date();
    subscription.cancellationReason = `[Admin] ${reason || 'Cancelled by admin'}`;
    subscription.autoRenew = false;

    if (cancelImmediately) {
      subscription.endDate = new Date();
    }

    await subscription.save();

    // Update user detail if cancelled immediately
    if (cancelImmediately) {
      await UserDetail.findOneAndUpdate(
        { userId },
        {
          'subscription.type': 'FREE',
          'subscription.endDate': null,
        }
      );
    }

    // Clear cache
    await redis.del(`subscription:user:${userId}`);

    logger.info(`Admin cancelled subscription for user ${userId}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: cancelImmediately
        ? 'Subscription cancelled immediately'
        : 'Subscription will be cancelled at period end',
      data: subscription,
    });
  } catch (error) {
    logger.error('Error admin cancelling subscription:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to cancel subscription',
      error: error.message,
    });
  }
};

/**
 * Get subscription stats (Admin)
 */
const adminGetSubscriptionStats = async (req, res) => {
  try {
    const [
      totalSubscriptions,
      activeSubscriptions,
      planStats,
      recentPayments,
      monthlyRevenue,
    ] = await Promise.all([
      UserSubscription.countDocuments(),
      UserSubscription.countDocuments({ status: 'active', endDate: { $gt: new Date() } }),
      UserSubscription.aggregate([
        { $match: { status: 'active', endDate: { $gt: new Date() } } },
        { $group: { _id: '$planName', count: { $sum: 1 } } },
      ]),
      PaymentHistory.find({ status: 'succeeded' })
        .sort({ createdAt: -1 })
        .limit(10)
        .populate('userId', 'name phone')
        .lean(),
      PaymentHistory.aggregate([
        {
          $match: {
            status: 'succeeded',
            createdAt: { $gte: new Date(new Date().setDate(1)) },
          },
        },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]),
    ]);

    // Calculate plan distribution
    const planDistribution = {
      KISAN: 0,
      KISAN_PRO: 0,
      KISAN_PLUS: 0,
      KISAN_MEGA: 0,
    };
    planStats.forEach(stat => {
      if (planDistribution.hasOwnProperty(stat._id)) {
        planDistribution[stat._id] = stat.count;
      }
    });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Subscription stats retrieved',
      data: {
        overview: {
          totalSubscriptions,
          activeSubscriptions,
          freeUsers: totalSubscriptions - activeSubscriptions,
          conversionRate: totalSubscriptions > 0
            ? ((activeSubscriptions / totalSubscriptions) * 100).toFixed(2)
            : 0,
        },
        planDistribution,
        monthlyRevenue: monthlyRevenue[0]?.total || 0,
        recentPayments,
      },
    });
  } catch (error) {
    logger.error('Error getting subscription stats:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get subscription stats',
      error: error.message,
    });
  }
};

/**
 * Get revenue stats (Admin)
 */
const adminGetRevenueStats = async (req, res) => {
  try {
    const { timeframe = 'month' } = req.query;

    let startDate = new Date();
    if (timeframe === 'week') {
      startDate.setDate(startDate.getDate() - 7);
    } else if (timeframe === 'month') {
      startDate.setMonth(startDate.getMonth() - 1);
    } else if (timeframe === 'year') {
      startDate.setFullYear(startDate.getFullYear() - 1);
    }

    const [revenueByDay, revenueByPlan, totalRevenue] = await Promise.all([
      PaymentHistory.aggregate([
        { $match: { status: 'succeeded', createdAt: { $gte: startDate } } },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
            revenue: { $sum: '$amount' },
            count: { $sum: 1 },
          },
        },
        { $sort: { _id: 1 } },
      ]),
      PaymentHistory.aggregate([
        { $match: { status: 'succeeded', createdAt: { $gte: startDate } } },
        { $group: { _id: '$description', revenue: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
      PaymentHistory.aggregate([
        { $match: { status: 'succeeded', createdAt: { $gte: startDate } } },
        { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
    ]);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Revenue stats retrieved',
      data: {
        timeframe,
        revenueByDay,
        revenueByPlan,
        totalRevenue: totalRevenue[0]?.total || 0,
        totalTransactions: totalRevenue[0]?.count || 0,
      },
    });
  } catch (error) {
    logger.error('Error getting revenue stats:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get revenue stats',
      error: error.message,
    });
  }
};

/**
 * Get user usage stats (Admin)
 */
const adminGetUserUsageStats = async (req, res) => {
  try {
    const { userId } = req.params;

    const usage = await UsageTracking.getTodayUsage(userId);
    const subscription = await UserSubscription.findOne({
      userId,
      status: { $in: ['active', 'trialing'] },
    }).populate('planId');

    let limits;
    if (subscription?.planId) {
      limits = subscription.planId.features;
    } else {
      limits = stripeConfig.SUBSCRIPTION_PLANS.KISAN.features;
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User usage stats retrieved',
      data: {
        usage: {
          aiMessagesUsed: usage.aiMessagesUsed,
          imageAnalysisUsed: usage.imageAnalysisUsed,
          consultantChatsUsed: usage.consultantChatsUsed,
          videoConsultationsUsed: usage.videoConsultationsUsed,
        },
        limits,
        planName: subscription?.planName || 'KISAN',
      },
    });
  } catch (error) {
    logger.error('Error getting user usage stats:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get user usage stats',
      error: error.message,
    });
  }
};

/**
 * Reset user usage (Admin)
 */
const adminResetUserUsage = async (req, res) => {
  try {
    const { userId } = req.params;

    await UsageTracking.findOneAndUpdate(
      {
        userId,
        date: new Date().toISOString().split('T')[0],
      },
      {
        aiMessagesUsed: 0,
        imageAnalysisUsed: 0,
        consultantChatsUsed: 0,
        videoConsultationsUsed: 0,
      }
    );

    logger.info(`Admin reset usage for user ${userId}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User usage reset successfully',
    });
  } catch (error) {
    logger.error('Error resetting user usage:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to reset user usage',
      error: error.message,
    });
  }
};

/**
 * Create subscription plan (Admin)
 */
const adminCreatePlan = async (req, res) => {
  try {
    const planData = req.body;

    // Check if plan name already exists
    const existingPlan = await SubscriptionPlan.findOne({ name: planData.name });
    if (existingPlan) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Plan with this name already exists',
      });
    }

    const plan = await SubscriptionPlan.create(planData);

    // Clear cache
    await redis.del('subscription:plans');

    logger.info(`Admin created plan: ${plan.name}`);

    res.status(HTTP_STATUS.CREATED).json({
      success: true,
      message: 'Plan created successfully',
      data: plan,
    });
  } catch (error) {
    logger.error('Error creating plan:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to create plan',
      error: error.message,
    });
  }
};

/**
 * Update subscription plan (Admin)
 */
const adminUpdatePlan = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    const plan = await SubscriptionPlan.findByIdAndUpdate(id, updateData, { new: true });

    if (!plan) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'Plan not found',
      });
    }

    // Clear cache
    await redis.del('subscription:plans');

    logger.info(`Admin updated plan: ${plan.name}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Plan updated successfully',
      data: plan,
    });
  } catch (error) {
    logger.error('Error updating plan:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to update plan',
      error: error.message,
    });
  }
};

/**
 * Delete subscription plan (Admin)
 */
const adminDeletePlan = async (req, res) => {
  try {
    const { id } = req.params;

    const plan = await SubscriptionPlan.findById(id);
    if (!plan) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'Plan not found',
      });
    }

    // Check if any users are on this plan
    const usersOnPlan = await UserSubscription.countDocuments({
      planId: id,
      status: 'active',
    });

    if (usersOnPlan > 0) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: `Cannot delete plan. ${usersOnPlan} users are currently on this plan.`,
      });
    }

    // Soft delete (mark as inactive)
    plan.isActive = false;
    await plan.save();

    // Clear cache
    await redis.del('subscription:plans');

    logger.info(`Admin deleted plan: ${plan.name}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Plan deleted successfully',
    });
  } catch (error) {
    logger.error('Error deleting plan:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to delete plan',
      error: error.message,
    });
  }
};

// ========== ADMIN IoT FUNCTIONS ==========

/**
 * Get all user IoT addon subscriptions (Admin)
 */
const adminGetAllUserAddons = async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [addons, total] = await Promise.all([
      UserIotAddon.find()
        .populate('userId', 'name phone email')
        .populate('addonId', 'name displayName')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .lean(),
      UserIotAddon.countDocuments(),
    ]);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User IoT addons retrieved',
      data: {
        addons,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit)),
        },
      },
    });
  } catch (error) {
    logger.error('Error getting all user addons:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get user IoT addons',
      error: error.message,
    });
  }
};

/**
 * Get user's IoT addons by user ID (Admin)
 */
const adminGetUserAddons = async (req, res) => {
  try {
    const { userId } = req.params;

    const addons = await UserIotAddon.find({ userId })
      .populate('addonId')
      .lean();

    const user = await User.findById(userId).select('name phone email').lean();

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User IoT addons retrieved',
      data: {
        user,
        addons,
      },
    });
  } catch (error) {
    logger.error('Error getting user addons:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get user IoT addons',
      error: error.message,
    });
  }
};

/**
 * Cancel user's IoT addon (Admin)
 */
const adminCancelUserAddon = async (req, res) => {
  try {
    const { userId } = req.params;
    const { addonName, reason, cancelImmediately } = req.body;

    const userAddon = await UserIotAddon.findOne({
      userId,
      addonName,
      status: 'active',
    });

    if (!userAddon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'No active IoT addon found',
      });
    }

    // Cancel Stripe subscription if exists
    if (userAddon.stripeSubscriptionId) {
      try {
        await stripeConfig.cancelSubscription(userAddon.stripeSubscriptionId, !cancelImmediately);
      } catch (stripeError) {
        logger.warn('Stripe cancellation failed:', stripeError.message);
      }
    }

    userAddon.status = cancelImmediately ? 'cancelled' : 'active';
    userAddon.cancelledAt = new Date();
    userAddon.autoRenew = false;

    if (cancelImmediately) {
      userAddon.endDate = new Date();
    }

    await userAddon.save();

    // Clear cache
    await redis.del(`iot:user:${userId}`);

    logger.info(`Admin cancelled IoT addon for user ${userId}: ${addonName}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: cancelImmediately
        ? 'IoT addon cancelled immediately'
        : 'IoT addon will be cancelled at period end',
      data: userAddon,
    });
  } catch (error) {
    logger.error('Error admin cancelling addon:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to cancel IoT addon',
      error: error.message,
    });
  }
};

/**
 * Get all linked devices (Admin)
 */
const adminGetLinkedDevices = async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const addons = await UserIotAddon.find({ 'linkedDevices.0': { $exists: true } })
      .populate('userId', 'name phone email')
      .populate('addonId', 'name displayName')
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    // Flatten devices with user info
    const devices = [];
    addons.forEach(addon => {
      addon.linkedDevices.forEach(device => {
        devices.push({
          ...device,
          user: addon.userId,
          addon: addon.addonId,
          addonSubscriptionId: addon._id,
        });
      });
    });

    const total = await UserIotAddon.aggregate([
      { $match: { 'linkedDevices.0': { $exists: true } } },
      { $unwind: '$linkedDevices' },
      { $count: 'total' },
    ]);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Linked devices retrieved',
      data: {
        devices,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: total[0]?.total || 0,
        },
      },
    });
  } catch (error) {
    logger.error('Error getting linked devices:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get linked devices',
      error: error.message,
    });
  }
};

/**
 * Unlink device (Admin)
 */
const adminUnlinkDevice = async (req, res) => {
  try {
    const { userId, addonName, deviceId } = req.body;

    const userAddon = await UserIotAddon.findOne({
      userId,
      addonName,
    });

    if (!userAddon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'IoT addon not found',
      });
    }

    const deviceIndex = userAddon.linkedDevices.findIndex(d => d.deviceId === deviceId);
    if (deviceIndex === -1) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'Device not found',
      });
    }

    userAddon.linkedDevices.splice(deviceIndex, 1);
    await userAddon.save();

    logger.info(`Admin unlinked device ${deviceId} for user ${userId}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Device unlinked successfully',
      data: userAddon,
    });
  } catch (error) {
    logger.error('Error admin unlinking device:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to unlink device',
      error: error.message,
    });
  }
};

/**
 * Get IoT stats (Admin)
 */
const adminGetIotStats = async (req, res) => {
  try {
    const [
      totalIotSubscriptions,
      activeIotSubscriptions,
      addonStats,
      totalDevices,
    ] = await Promise.all([
      UserIotAddon.countDocuments(),
      UserIotAddon.countDocuments({ status: 'active', endDate: { $gt: new Date() } }),
      UserIotAddon.aggregate([
        { $match: { status: 'active', endDate: { $gt: new Date() } } },
        { $group: { _id: '$addonName', count: { $sum: 1 } } },
      ]),
      UserIotAddon.aggregate([
        { $match: { 'linkedDevices.0': { $exists: true } } },
        { $unwind: '$linkedDevices' },
        { $count: 'total' },
      ]),
    ]);

    const addonDistribution = {
      WATER_PUMP: 0,
      CROP_IOT: 0,
      IOT_BUNDLE: 0,
    };
    addonStats.forEach(stat => {
      if (addonDistribution.hasOwnProperty(stat._id)) {
        addonDistribution[stat._id] = stat.count;
      }
    });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'IoT stats retrieved',
      data: {
        overview: {
          totalIotSubscriptions,
          activeIotSubscriptions,
          totalDevices: totalDevices[0]?.total || 0,
        },
        addonDistribution,
      },
    });
  } catch (error) {
    logger.error('Error getting IoT stats:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get IoT stats',
      error: error.message,
    });
  }
};

/**
 * Create IoT addon (Admin)
 */
const adminCreateIotAddon = async (req, res) => {
  try {
    const addonData = req.body;

    const existingAddon = await IotAddon.findOne({ name: addonData.name });
    if (existingAddon) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Addon with this name already exists',
      });
    }

    const addon = await IotAddon.create(addonData);

    // Clear cache
    await redis.del('iot:addons');

    logger.info(`Admin created IoT addon: ${addon.name}`);

    res.status(HTTP_STATUS.CREATED).json({
      success: true,
      message: 'IoT addon created successfully',
      data: addon,
    });
  } catch (error) {
    logger.error('Error creating IoT addon:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to create IoT addon',
      error: error.message,
    });
  }
};

/**
 * Update IoT addon (Admin)
 */
const adminUpdateIotAddon = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    const addon = await IotAddon.findByIdAndUpdate(id, updateData, { new: true });

    if (!addon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'IoT addon not found',
      });
    }

    // Clear cache
    await redis.del('iot:addons');

    logger.info(`Admin updated IoT addon: ${addon.name}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'IoT addon updated successfully',
      data: addon,
    });
  } catch (error) {
    logger.error('Error updating IoT addon:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to update IoT addon',
      error: error.message,
    });
  }
};

/**
 * Delete IoT addon (Admin)
 */
const adminDeleteIotAddon = async (req, res) => {
  try {
    const { id } = req.params;

    const addon = await IotAddon.findById(id);
    if (!addon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'IoT addon not found',
      });
    }

    // Check if any users have this addon
    const usersWithAddon = await UserIotAddon.countDocuments({
      addonId: id,
      status: 'active',
    });

    if (usersWithAddon > 0) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: `Cannot delete addon. ${usersWithAddon} users have this addon.`,
      });
    }

    // Soft delete
    addon.isActive = false;
    await addon.save();

    // Clear cache
    await redis.del('iot:addons');

    logger.info(`Admin deleted IoT addon: ${addon.name}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'IoT addon deleted successfully',
    });
  } catch (error) {
    logger.error('Error deleting IoT addon:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to delete IoT addon',
      error: error.message,
    });
  }
};

// ========== IoT DEVICE SERVICE-TO-SERVICE ENDPOINTS ==========

/**
 * Validate device subscription during handshake
 * Called by IoT service when device attempts to connect
 * POST /api/v1/iot/validate-subscription
 */
const validateDeviceSubscription = async (req, res) => {
  try {
    const { device_id, device_type, mac_address } = req.body;

    if (!device_id || !mac_address) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        is_valid: false,
        reason: 'INVALID_REQUEST',
        message: 'device_id and mac_address are required',
      });
    }

    logger.info(`Validating device subscription: ${device_id} (MAC: ${mac_address})`);

    // Find if this device MAC is linked to any active IoT add-on
    const userAddon = await UserIotAddon.findOne({
      'linkedDevices.deviceId': device_id,
      'linkedDevices.macAddress': mac_address,
      status: 'active',
      endDate: { $gt: new Date() },
    }).populate('addonId');

    if (!userAddon) {
      // Check if device is registered but subscription expired
      const expiredAddon = await UserIotAddon.findOne({
        'linkedDevices.deviceId': device_id,
        'linkedDevices.macAddress': mac_address,
      });

      if (expiredAddon) {
        return res.status(HTTP_STATUS.OK).json({
          is_valid: false,
          reason: 'SUBSCRIPTION_EXPIRED',
          message: 'Device subscription has expired',
        });
      }

      return res.status(HTTP_STATUS.OK).json({
        is_valid: false,
        reason: 'DEVICE_NOT_REGISTERED',
        message: 'Device is not registered to any subscription',
      });
    }

    // Check if addon supports this device type
    const addon = userAddon.addonId;
    if (device_type && addon.supportedDeviceTypes &&
      !addon.supportedDeviceTypes.includes(device_type)) {
      return res.status(HTTP_STATUS.OK).json({
        is_valid: false,
        reason: 'UNSUPPORTED_DEVICE_TYPE',
        message: `Device type ${device_type} not supported by addon ${addon.name}`,
      });
    }

    // Success - return subscription details
    res.status(HTTP_STATUS.OK).json({
      is_valid: true,
      reason: 'ACTIVE',
      message: 'Device has active subscription',
      subscription: {
        device_id: device_id,
        user_id: userAddon.userId.toString(),
        subscription_id: userAddon._id.toString(),
        status: userAddon.status,
        plan_name: addon.name,
        start_date: userAddon.startDate,
        end_date: userAddon.endDate,
        is_active: true,
        features: addon.features,
        max_devices: addon.maxDevices,
      },
    });
  } catch (error) {
    logger.error('Error validating device subscription:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      is_valid: false,
      reason: 'VALIDATION_ERROR',
      message: 'Internal error during validation',
    });
  }
};

/**
 * Get device subscription details
 * GET /api/v1/iot/devices/:deviceId/subscription
 */
const getDeviceSubscriptionDetails = async (req, res) => {
  try {
    const { deviceId } = req.params;

    const userAddon = await UserIotAddon.findOne({
      'linkedDevices.deviceId': deviceId,
    }).populate('addonId');

    if (!userAddon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'Device not found in any subscription',
      });
    }

    const device = userAddon.linkedDevices.find(d => d.deviceId === deviceId);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      data: {
        device_id: deviceId,
        user_id: userAddon.userId.toString(),
        subscription_id: userAddon._id.toString(),
        status: userAddon.status,
        plan_name: userAddon.addonId?.name,
        start_date: userAddon.startDate,
        end_date: userAddon.endDate,
        is_active: userAddon.status === 'active' && userAddon.endDate > new Date(),
        device_details: {
          name: device.deviceName,
          type: device.deviceType,
          mac_address: device.macAddress,
          linked_at: device.linkedAt,
          last_active: device.lastActive,
        },
      },
    });
  } catch (error) {
    logger.error('Error getting device subscription:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to get device subscription',
    });
  }
};

/**
 * Update device online/offline status
 * PUT /api/v1/iot/devices/:deviceId/status
 */
const updateDeviceStatus = async (req, res) => {
  try {
    const { deviceId } = req.params;
    const { status, metadata, timestamp } = req.body;

    if (!status || !['ONLINE', 'OFFLINE'].includes(status)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Invalid status. Must be ONLINE or OFFLINE',
      });
    }

    // Find the device and update its status
    const userAddon = await UserIotAddon.findOneAndUpdate(
      { 'linkedDevices.deviceId': deviceId },
      {
        $set: {
          'linkedDevices.$.lastActive': timestamp || new Date(),
          'linkedDevices.$.status': status,
          ...(metadata?.session_id && { 'linkedDevices.$.lastSessionId': metadata.session_id }),
        },
      },
      { new: true }
    );

    if (!userAddon) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'Device not found',
      });
    }

    logger.info(`Device ${deviceId} status updated to ${status}`);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Device status updated',
    });
  } catch (error) {
    logger.error('Error updating device status:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to update device status',
    });
  }
};

/**
 * Log device activity
 * POST /api/v1/iot/devices/activity
 */
const logDeviceActivity = async (req, res) => {
  try {
    const { device_id, activity_type, details, timestamp } = req.body;

    if (!device_id || !activity_type) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'device_id and activity_type are required',
      });
    }

    // Log the activity (can be stored in a separate collection if needed)
    logger.info(`Device activity: ${device_id} - ${activity_type}`, {
      device_id,
      activity_type,
      details,
      timestamp: timestamp || new Date(),
    });

    // Update last activity timestamp on the device
    await UserIotAddon.updateOne(
      { 'linkedDevices.deviceId': device_id },
      {
        $set: {
          'linkedDevices.$.lastActive': timestamp || new Date(),
        },
      }
    );

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Activity logged',
    });
  } catch (error) {
    logger.error('Error logging device activity:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to log activity',
    });
  }
};

// Export all functions
module.exports = {
  // Subscription functions
  getPlans,
  getCurrentSubscription,
  createCheckoutSession,
  createPaymentIntent,
  confirmPayment,
  cancelSubscription,
  resumeSubscription,
  getUsageStats,
  getPaymentHistory,
  checkFeatureAccess,
  handleWebhook,
  seedSubscriptionPlans,
  checkUserFeatureAccess,
  incrementUsage,
  incrementUsageInternal,
  // IoT add-on functions
  getIotAddons,
  getUserIotAddons,
  createIotAddonPaymentIntent,
  confirmIotAddonPayment,
  cancelIotAddon,
  checkIotFeatureAccess,
  checkUserIotAccess,
  seedIotAddons,
  linkIotDevice,
  unlinkIotDevice,
  // Admin functions
  adminGetAllSubscriptions,
  adminGetUserSubscription,
  adminUpdateUserSubscription,
  adminCancelUserSubscription,
  adminGetSubscriptionStats,
  adminGetRevenueStats,
  adminGetUserUsageStats,
  adminResetUserUsage,
  adminCreatePlan,
  adminUpdatePlan,
  adminDeletePlan,
  // Admin IoT functions
  adminGetAllUserAddons,
  adminGetUserAddons,
  adminCancelUserAddon,
  adminGetLinkedDevices,
  adminUnlinkDevice,
  adminGetIotStats,
  adminCreateIotAddon,
  adminUpdateIotAddon,
  adminDeleteIotAddon,
  // IoT device service-to-service functions
  validateDeviceSubscription,
  getDeviceSubscriptionDetails,
  updateDeviceStatus,
  logDeviceActivity,
};
