# Auto Reel Upload Feature

This feature automatically posts reels to the system every 3 minutes using admin and consultant user accounts.

## How It Works

1. The system uses a cron job that runs every 3 minutes
2. For each post, it randomly selects an admin or consultant user from the predefined list
3. It then takes a reel from the sample reels JSON file (in sequential order, cycling back to the beginning when all reels are used)
4. The reel is created through the regular reel creation API

## Configuration

The auto-posting feature is enabled by default when the server starts. To control this behavior, you can use the environment variable:

```
ENABLE_AUTO_REELS=false
```

Set this to `false` to disable the feature.

You can also set the base URL for the API:

```
BASE_URL=http://localhost:3000
```

## Files

The feature consists of the following files:

- `src/utils/autoReelScheduler.js` - The main scheduler that manages the cron job
- `src/utils/sampleReels.json` - JSON file containing sample reels to be published
- `src/utils/adminConsultantUsers.json` - List of admin and consultant users who will be the authors of the reels
- `src/utils/logger.js` - Logging utility for the auto-posting feature

## Logs

Logs for the auto-posting feature are stored in:

- `logs/auto-reel.log` - General logs
- `logs/auto-reel-error.log` - Error logs

## Customizing Sample Reels

To add more sample reels or modify existing ones, edit the `src/utils/sampleReels.json` file. Each reel should follow this format:

```json
{
  "description": "Description text with #Hashtags",
  "mediaUrl": "https://example.com/videos/video-file.mp4",
  "location": {
    "latitude": 28.6139,
    "longitude": 77.209
  }
}
```

## Customizing Admin and Consultant Users

To modify the list of users who can post automatically, edit the `src/utils/adminConsultantUsers.json` file. Each user should follow this format:

```json
{
  "userId": "user_id",
  "userName": "User Name",
  "profilePhoto": "https://example.com/profiles/profile.jpg",
  "role": "admin" // or "consultant"
}
```

## Dependencies

This feature requires:
- node-cron
- axios

These are added to the project's package.json. 