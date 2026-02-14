jest.mock('../../config/redis', () => {
  const store = new Map();
  return {
    get: jest.fn(async (key) => store.get(key) || null),
    set: jest.fn(async (key, value) => {
      store.set(key, value);
      return 'OK';
    }),
    client: {
      incr: jest.fn(async (key) => {
        const current = parseInt(store.get(key) || '0', 10) + 1;
        store.set(key, String(current));
        return current;
      }),
      expire: jest.fn(async () => 1),
    },
  };
});

const policyService = require('../notification-policy.service');

describe('notification-policy.service', () => {
  test('detects duplicate notifications within dedupe window', async () => {
    const notification = {
      userId: 'user-1',
      category: 'promotion',
      data: { eventType: 'subscription.discount', entityId: 'plan-1', actorId: 'sys' },
    };

    const first = await policyService.isDuplicate({ ...notification });
    const second = await policyService.isDuplicate({ ...notification });

    expect(first).toBe(false);
    expect(second).toBe(true);
  });

  test('respects mute rules for actor/entity/category', () => {
    const notification = {
      category: 'advertisement',
      data: { actorId: 'actor-1', entityId: 'entity-1' },
    };

    const preferences = {
      muted: {
        categories: ['advertisement'],
        actorIds: [],
        entityIds: [],
      },
    };

    expect(policyService.isMuted(notification, preferences)).toBe(true);
  });
});
