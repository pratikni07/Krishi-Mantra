# Auto Post Feature

This feature automatically posts feeds to the system every 2 minutes using admin and consultant user accounts.

## How It Works

1. The system uses a cron job that runs every 2 minutes
2. For each post, it randomly selects an admin or consultant user from the predefined list
3. It then takes a post from the sample posts JSON file (in sequential order, cycling back to the beginning when all posts are used)
4. The post is created through the regular feed creation API

## Configuration

The auto-posting feature is enabled by default when the server starts. To control this behavior, you can use the environment variable:

```
ENABLE_AUTO_POST=false
```

Set this to `false` to disable the feature.

## Files

The feature consists of the following files:

- `src/utils/autoPostScheduler.js` - The main scheduler that manages the cron job
- `src/utils/samplePosts.json` - JSON file containing sample posts to be published
- `src/utils/adminConsultantUsers.json` - List of admin and consultant users who will be the authors of the posts
- `src/utils/logger.js` - Logging utility for the auto-posting feature

## Logs

Logs for the auto-posting feature are stored in:

- `logs/auto-post.log` - General logs
- `logs/auto-post-error.log` - Error logs

## Customizing Sample Posts

To add more sample posts or modify existing ones, edit the `src/utils/samplePosts.json` file. Each post should follow this format:

```json
{
  "description": "Post summary",
  "content": "Post content with #Hashtags",
  "mediaUrl": "https://example.com/images/image.jpg",
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
