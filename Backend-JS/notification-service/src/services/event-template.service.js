const {
  NOTIFICATION_CATEGORIES,
  NOTIFICATION_EVENTS,
  NOTIFICATION_PRIORITY,
  NOTIFICATION_STATUS,
  NOTIFICATION_TYPES,
} = require('../utils/constants');

const EVENT_TEMPLATE_MAP = {
  [NOTIFICATION_EVENTS.SUBSCRIPTION_ENDING]: {
    category: NOTIFICATION_CATEGORIES.SUBSCRIPTION,
    priority: NOTIFICATION_PRIORITY.HIGH,
    defaultType: NOTIFICATION_TYPES.PUSH,
    fallbackChannels: [NOTIFICATION_TYPES.IN_APP, NOTIFICATION_TYPES.EMAIL],
    title: ({ planName = 'your plan' }) => `${planName} expires soon`,
    body: ({ daysLeft = 0 }) => `Your subscription ends in ${daysLeft} day(s). Renew now to avoid interruption.`,
  },
  [NOTIFICATION_EVENTS.SUBSCRIPTION_DISCOUNT]: {
    category: NOTIFICATION_CATEGORIES.PROMOTION,
    priority: NOTIFICATION_PRIORITY.MEDIUM,
    defaultType: NOTIFICATION_TYPES.PUSH,
    fallbackChannels: [NOTIFICATION_TYPES.IN_APP],
    title: ({ discountPercent = 0 }) => `${discountPercent}% discount on subscription`,
    body: ({ planName = 'premium plan' }) => `Limited-time offer available for ${planName}. Upgrade today.`,
  },
  [NOTIFICATION_EVENTS.ADVERTISEMENT_BROADCAST]: {
    category: NOTIFICATION_CATEGORIES.ADVERTISEMENT,
    priority: NOTIFICATION_PRIORITY.LOW,
    defaultType: NOTIFICATION_TYPES.IN_APP,
    fallbackChannels: [],
    title: ({ campaignName = 'New campaign' }) => campaignName,
    body: ({ message = 'Check new offers tailored for you.' }) => message,
  },
  [NOTIFICATION_EVENTS.POST_LIKED]: {
    category: NOTIFICATION_CATEGORIES.POST_ENGAGEMENT,
    priority: NOTIFICATION_PRIORITY.LOW,
    defaultType: NOTIFICATION_TYPES.IN_APP,
    fallbackChannels: [],
    title: ({ actorName = 'Someone' }) => `${actorName} liked your post`,
    body: () => 'Your post is getting engagement. Tap to view activity.',
  },
  [NOTIFICATION_EVENTS.POST_COMMENTED]: {
    category: NOTIFICATION_CATEGORIES.POST_ENGAGEMENT,
    priority: NOTIFICATION_PRIORITY.MEDIUM,
    defaultType: NOTIFICATION_TYPES.PUSH,
    fallbackChannels: [NOTIFICATION_TYPES.IN_APP],
    title: ({ actorName = 'Someone' }) => `${actorName} commented on your post`,
    body: ({ commentSnippet = '' }) => commentSnippet || 'Open to read and reply to the comment.',
  },
  [NOTIFICATION_EVENTS.REEL_LIKED]: {
    category: NOTIFICATION_CATEGORIES.REEL_ENGAGEMENT,
    priority: NOTIFICATION_PRIORITY.LOW,
    defaultType: NOTIFICATION_TYPES.IN_APP,
    fallbackChannels: [],
    title: ({ actorName = 'Someone' }) => `${actorName} liked your reel`,
    body: () => 'Your reel is gaining traction. See your latest reactions.',
  },
  [NOTIFICATION_EVENTS.REEL_COMMENTED]: {
    category: NOTIFICATION_CATEGORIES.REEL_ENGAGEMENT,
    priority: NOTIFICATION_PRIORITY.MEDIUM,
    defaultType: NOTIFICATION_TYPES.PUSH,
    fallbackChannels: [NOTIFICATION_TYPES.IN_APP],
    title: ({ actorName = 'Someone' }) => `${actorName} commented on your reel`,
    body: ({ commentSnippet = '' }) => commentSnippet || 'Open the reel to view and respond.',
  },
  [NOTIFICATION_EVENTS.MARKETPLACE_PRODUCT_MATCH]: {
    category: NOTIFICATION_CATEGORIES.MARKETPLACE,
    priority: NOTIFICATION_PRIORITY.MEDIUM,
    defaultType: NOTIFICATION_TYPES.PUSH,
    fallbackChannels: [NOTIFICATION_TYPES.IN_APP],
    title: ({ productName = 'A product' }) => `${productName} matches your interests`,
    body: ({ location = '' }) => (location ? `Now available near ${location}.` : 'A new matching product is now available.'),
  },
};

class EventTemplateService {
  getTemplate(eventType) {
    return EVENT_TEMPLATE_MAP[eventType] || null;
  }

  buildNotificationFromEvent(event, userId, locale = 'en') {
    const template = this.getTemplate(event.type);
    if (!template) {
      throw new Error(`Unsupported notification event type: ${event.type}`);
    }

    const payload = event.payload || {};
    return {
      userId,
      title: event.title || template.title(payload, locale),
      body: event.body || template.body(payload, locale),
      type: event.channel || template.defaultType,
      fallbackChannels: event.fallbackChannels || template.fallbackChannels,
      category: event.category || template.category,
      priority: event.priority || template.priority,
      data: {
        ...payload,
        eventType: event.type,
        source: event.source || 'unknown',
        actionUrl: payload.actionUrl || null,
        actorId: payload.actorId || null,
        entityId: payload.entityId || null,
      },
      scheduledFor: event.scheduledFor ? new Date(event.scheduledFor) : new Date(),
      status: NOTIFICATION_STATUS.PENDING,
    };
  }

  isInterestMatch(preferences, event) {
    const filters = event.interestFilters || {};
    const userInterests = preferences?.interests || {};

    const keys = Object.keys(filters);
    if (!keys.length) return true;

    return keys.every((key) => {
      const expected = Array.isArray(filters[key]) ? filters[key] : [filters[key]];
      const actual = Array.isArray(userInterests[key]) ? userInterests[key] : [];
      if (!expected.length) return true;
      return expected.some((value) => actual.includes(value));
    });
  }
}

module.exports = new EventTemplateService();
