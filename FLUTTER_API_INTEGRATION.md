# Engagement API Integration in Flutter App

## Overview

This document describes the integration of the engagement/analytics API endpoints in the Krishi-Mantra Flutter mobile application. The integration ensures proper communication between the mobile app and the backend engagement-service.

## What Was Integrated

### 1. API Endpoint Constants

Added centralized engagement API endpoint definitions to `lib/core/constants/api_constants.dart`:

```dart
// Engagement/Analytics Endpoints
static const String ENGAGEMENT_SESSION_START = '/api/engagement/sessions/start';
static const String ENGAGEMENT_SESSION_END = '/api/engagement/sessions/end';
static const String ENGAGEMENT_SESSION_HEARTBEAT = '/api/engagement/sessions/heartbeat';
static const String ENGAGEMENT_EVENTS_BATCH = '/api/engagement/events/batch';
static const String ENGAGEMENT_ANALYTICS_DASHBOARD = '/api/engagement/analytics/dashboard';
static const String ENGAGEMENT_ANALYTICS_SCREENS = '/api/engagement/analytics/screens';
static const String ENGAGEMENT_ANALYTICS_USER = '/api/engagement/analytics/users/:userId';
```

**Benefits:**
- ✅ Centralized endpoint management
- ✅ Easy to update URLs across the app
- ✅ Consistent with other API endpoints
- ✅ Type-safe constant references
- ✅ Prevents typos and hardcoded strings

### 2. Engagement Service Updates

Updated `lib/data/services/engagement_service.dart` to use the new constants:

**Before:**
```dart
await apiService.post('/engagement/sessions/start', data: {...});
```

**After:**
```dart
await apiService.post(ApiConstants.ENGAGEMENT_SESSION_START, data: {...});
```

**Updated Methods:**
1. `_startSession()` - Uses `ENGAGEMENT_SESSION_START`
2. `endSession()` - Uses `ENGAGEMENT_SESSION_END`
3. `_flushEvents()` - Uses `ENGAGEMENT_EVENTS_BATCH`
4. `_sendHeartbeat()` - Uses `ENGAGEMENT_SESSION_HEARTBEAT`

## API Endpoints Explained

### Session Management

#### 1. Start Session
**Endpoint:** `POST /api/engagement/sessions/start`

**Purpose:** Creates a new user session when the app is opened or user logs in

**Request:**
```json
{
  "userId": "user123",
  "device": {
    "deviceId": "abc123",
    "platform": "android",
    "osVersion": "13",
    "appVersion": "1.0.0",
    "deviceModel": "Samsung Galaxy S21",
    "manufacturer": "Samsung"
  }
}
```

**Response:**
```json
{
  "success": true,
  "sessionId": "session_abc123_1234567890"
}
```

**Used in:** `EngagementService._startSession()`

#### 2. End Session
**Endpoint:** `POST /api/engagement/sessions/end`

**Purpose:** Closes the current session when app is closed or user logs out

**Request:**
```json
{
  "sessionId": "session_abc123_1234567890",
  "userId": "user123",
  "exitScreen": "profile"
}
```

**Used in:** `EngagementService.endSession()`

#### 3. Session Heartbeat
**Endpoint:** `POST /api/engagement/sessions/heartbeat`

**Purpose:** Keeps the session alive (sent every 5 minutes)

**Request:**
```json
{
  "sessionId": "session_abc123_1234567890",
  "userId": "user123",
  "currentScreen": "feed"
}
```

**Used in:** `EngagementService._sendHeartbeat()`

### Event Tracking

#### 4. Batch Events
**Endpoint:** `POST /api/engagement/events/batch`

**Purpose:** Submits multiple user events in a batch (20 events or 30 seconds)

**Request:**
```json
{
  "events": [
    {
      "userId": "user123",
      "sessionId": "session_abc123",
      "eventName": "screen_view",
      "eventCategory": "navigation",
      "properties": {
        "screenName": "home",
        "previousScreen": "splash"
      },
      "device": {...},
      "timestamp": "2026-02-15T05:30:00.000Z"
    },
    {
      "userId": "user123",
      "sessionId": "session_abc123",
      "eventName": "feed_like",
      "eventCategory": "engagement",
      "properties": {
        "contentId": "feed123"
      },
      "device": {...},
      "timestamp": "2026-02-15T05:31:00.000Z"
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Events processed successfully"
}
```

**Used in:** `EngagementService._flushEvents()`

### Analytics (Future Use)

#### 5. Dashboard Analytics
**Endpoint:** `GET /api/engagement/analytics/dashboard?timeframe=week`

**Purpose:** Get aggregated dashboard metrics

**Available for future feature:** User analytics dashboard in the app

#### 6. Screen Analytics
**Endpoint:** `GET /api/engagement/analytics/screens?timeframe=week`

**Purpose:** Get top screens by time spent

**Available for future feature:** In-app analytics

#### 7. User Analytics
**Endpoint:** `GET /api/engagement/analytics/users/:userId`

**Purpose:** Get analytics for a specific user

**Available for future feature:** User profile analytics

## How It Works

### 1. App Startup
```
User Opens App
    ↓
Splash Screen
    ↓
User Authenticated?
    ↓
YES → EngagementService().init(userId)
    ↓
_startSession() called
    ↓
POST /api/engagement/sessions/start
    ↓
Session ID received and cached
    ↓
Heartbeat timer started (every 5 minutes)
    ↓
Event buffer initialized
```

### 2. User Activity Tracking
```
User Navigates to Screen
    ↓
Navigator Observer detects route change
    ↓
EngagementService.trackScreenView(screenName)
    ↓
Event added to buffer
    ↓
Buffer size >= 20 OR 30 seconds elapsed?
    ↓
YES → _flushEvents() called
    ↓
POST /api/engagement/events/batch
    ↓
Events sent to backend
    ↓
Buffer cleared
```

### 3. Session Management
```
Every 5 Minutes
    ↓
_sendHeartbeat() timer triggers
    ↓
POST /api/engagement/sessions/heartbeat
    ↓
Session kept alive
```

```
User Closes App or Logs Out
    ↓
endSession() called
    ↓
_trackScreenTime() for current screen
    ↓
_flushEvents() to send remaining events
    ↓
POST /api/engagement/sessions/end
    ↓
Timers stopped
    ↓
Session ended
```

## Configuration

### Base URL
The base URL is configured in `lib/core/config/app_config.dart`:

**Development:**
```dart
'http://192.168.1.46:3001'
```

**Production:**
```dart
'https://api.krishimantra.com'
```

### Full Endpoint URLs

With base URL, the complete endpoints are:

- `http://192.168.1.46:3001/api/engagement/sessions/start`
- `http://192.168.1.46:3001/api/engagement/sessions/end`
- `http://192.168.1.46:3001/api/engagement/sessions/heartbeat`
- `http://192.168.1.46:3001/api/engagement/events/batch`

## API Service Integration

The engagement service uses the centralized `ApiService` which provides:

### 1. Authentication
- Automatically includes JWT token in headers
- Token refresh on 401 responses
- Thread-safe token refresh lock

### 2. Error Handling
- Retry logic for failed requests (3 attempts)
- Circuit breaker for failing endpoints
- Graceful degradation

### 3. Offline Support
- Failed requests queued locally
- Automatic retry when connection restored
- Events cached in SharedPreferences

### 4. Request/Response Interceptors
- Logging in debug mode
- Request/response transformation
- Error standardization

## Testing the Integration

### 1. Manual Testing

Start the backend engagement service:
```bash
cd Backend-JS/engagement-service
npm install
npm start
```

Run the Flutter app:
```bash
cd Frontend/krishimantra
flutter run
```

### 2. Verify API Calls

Check logs for:
```
I/Engagement: Session started: session_abc123_1234567890
I/Engagement: Flushed 20 events
I/Engagement: Session ended: session_abc123_1234567890
```

### 3. Check Backend Logs

Engagement service should show:
```
POST /api/engagement/sessions/start 201 45ms
POST /api/engagement/events/batch 200 12ms
POST /api/engagement/sessions/heartbeat 200 8ms
POST /api/engagement/sessions/end 200 15ms
```

### 4. Verify in MongoDB

Check the `engagementdb` database:
```javascript
// Sessions collection
db.sessions.find({ userId: "user123" }).sort({ startTime: -1 }).limit(1)

// Events collection
db.events.find({ userId: "user123" }).sort({ timestamp: -1 }).limit(10)

// User metrics collection
db.usermetrics.findOne({ userId: "user123" })
```

## Troubleshooting

### Issue: Events Not Being Sent

**Check:**
1. Is the device online? Check connectivity
2. Is the backend running? Verify `http://[host]:3007/api/engagement/health`
3. Check app logs for errors
4. Verify ApiConstants are imported correctly

**Solution:**
- Events are cached locally and will be sent when connection is restored
- Check SharedPreferences for `pending_engagement_events` key

### Issue: Session Not Starting

**Check:**
1. Is `EngagementService().init(userId)` called after login?
2. Is the userId valid?
3. Check backend logs for errors

**Solution:**
- Verify splash screen calls `init()` after authentication
- Check network inspector for request/response

### Issue: Wrong API URL

**Check:**
1. Verify `app_config.dart` has correct base URL
2. Check environment (development/staging/production)
3. Verify API gateway is routing `/api/engagement/*` correctly

**Solution:**
- Update `_devHost` in `app_config.dart` for development
- Ensure API gateway routes engagement service correctly

## Best Practices

### 1. Always Use Constants
❌ **Don't:**
```dart
await apiService.post('/engagement/sessions/start', ...);
```

✅ **Do:**
```dart
await apiService.post(ApiConstants.ENGAGEMENT_SESSION_START, ...);
```

### 2. Handle Errors Gracefully
```dart
try {
  await apiService.post(ApiConstants.ENGAGEMENT_SESSION_START, ...);
} catch (e) {
  logger.e('Failed to start session', tag: 'Engagement', error: e);
  // Don't block user flow - engagement tracking is non-critical
}
```

### 3. Don't Block UI
- All engagement calls are async and non-blocking
- Errors don't prevent app functionality
- Offline events are queued automatically

### 4. Respect User Privacy
- Only track necessary data
- No PII in event properties
- User can opt-out (if feature is added)

## Future Enhancements

### 1. In-App Analytics Dashboard
Use the analytics endpoints to show users their activity:
```dart
// Get user's analytics
final response = await apiService.get(
  ApiConstants.replacePathParams(
    ApiConstants.ENGAGEMENT_ANALYTICS_USER,
    {'userId': currentUser.id}
  )
);
```

### 2. Screen Time Limits
Use screen analytics to help users manage time:
```dart
// Get top screens
final response = await apiService.get(
  '${ApiConstants.ENGAGEMENT_ANALYTICS_SCREENS}?timeframe=today'
);
```

### 3. Gamification
Use engagement metrics for achievements and rewards:
```dart
// Get dashboard metrics
final response = await apiService.get(
  '${ApiConstants.ENGAGEMENT_ANALYTICS_DASHBOARD}?timeframe=week'
);
```

## Related Files

- `Frontend/krishimantra/lib/core/constants/api_constants.dart` - API endpoint definitions
- `Frontend/krishimantra/lib/data/services/engagement_service.dart` - Engagement tracking service
- `Frontend/krishimantra/lib/data/services/api_service.dart` - Centralized API service
- `Frontend/krishimantra/lib/core/config/app_config.dart` - App configuration
- `Frontend/krishimantra/lib/core/utils/engagement_observer.dart` - Navigation observer
- `Backend-JS/engagement-service/` - Backend engagement service

## Summary

✅ **Completed:**
- Added 7 engagement API endpoint constants
- Updated engagement service to use constants
- Ensured consistency with backend API
- Proper error handling and offline support
- Documentation complete

✅ **Benefits:**
- Centralized endpoint management
- Type-safe constant references  
- Easy to update across the app
- Consistent with existing code patterns
- Ready for production use

✅ **Testing:**
- Manual testing steps provided
- Backend verification steps included
- Troubleshooting guide available

The engagement API is now fully integrated in the Flutter mobile application and ready for use! 🎉
