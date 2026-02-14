const eventTemplateService = require('../event-template.service');
const {
  NOTIFICATION_CATEGORIES,
  NOTIFICATION_EVENTS,
  NOTIFICATION_STATUS,
} = require('../../utils/constants');

describe('event-template.service', () => {
  test('builds subscription ending notification from event payload', () => {
    const notification = eventTemplateService.buildNotificationFromEvent({
      type: NOTIFICATION_EVENTS.SUBSCRIPTION_ENDING,
      payload: { planName: 'Gold Plan', daysLeft: 3 },
    }, 'user-1');

    expect(notification.userId).toBe('user-1');
    expect(notification.category).toBe(NOTIFICATION_CATEGORIES.SUBSCRIPTION);
    expect(notification.title).toContain('Gold Plan');
    expect(notification.body).toContain('3');
    expect(notification.status).toBe(NOTIFICATION_STATUS.PENDING);
  });

  test('throws for unsupported event type', () => {
    expect(() => eventTemplateService.buildNotificationFromEvent({
      type: 'unsupported.event',
      payload: {},
    }, 'user-1')).toThrow('Unsupported notification event type');
  });

  test('matches user interests using event filters', () => {
    const preferences = {
      interests: {
        marketplaceTags: ['seeds', 'fertilizer'],
      },
    };

    const shouldMatch = eventTemplateService.isInterestMatch(preferences, {
      interestFilters: {
        marketplaceTags: ['fertilizer'],
      },
    });

    const shouldNotMatch = eventTemplateService.isInterestMatch(preferences, {
      interestFilters: {
        marketplaceTags: ['tractor'],
      },
    });

    expect(shouldMatch).toBe(true);
    expect(shouldNotMatch).toBe(false);
  });
});
