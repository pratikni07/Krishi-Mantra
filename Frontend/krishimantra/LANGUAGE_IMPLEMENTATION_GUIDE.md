# KrishiMantra Language Support Implementation Guide

This guide provides step-by-step instructions for implementing consistent language support and error handling across the KrishiMantra application.

## Overview

We've developed a robust system for adding multi-language support to all screens in the app. The implementation follows these key principles:

1. Centralized language management through the `LanguageHelper` class
2. Easy integration with screens using the `TranslationMixin`
3. Support for translating dynamic API data
4. Consistent error handling with translated error messages

## Implementation Steps

Follow these steps to add language support to any screen:

### Step 1: Import Required Files

```dart
import '../../../core/utils/language_helper.dart';
import '../../../data/services/language_service.dart';
```

### Step 2: Add the TranslationMixin to Your Screen

```dart
class _YourScreenState extends State<YourScreen> with TranslationMixin {
  // Screen implementation
}
```

### Step 3: Define Translation Keys

Create constants for all text that needs translation in your screen:

```dart
// Translation keys
static const String KEY_TITLE = 'title';
static const String KEY_SUBTITLE = 'subtitle';
static const String KEY_BUTTON = 'button';
// Add more keys as needed
```

### Step 4: Register Default Translations

In your `initState` method, register all translations:

```dart
@override
void initState() {
  super.initState();
  _registerTranslations();
  // Your existing initialization code
}

void _registerTranslations() {
  registerTranslation(KEY_TITLE, 'Default Title');
  registerTranslation(KEY_SUBTITLE, 'Default Subtitle');
  registerTranslation(KEY_BUTTON, 'Default Button Text');
  // Register more translations as needed
}
```

### Step 5: Use the Translations in Your UI

Replace hardcoded text with translation keys:

```dart
Text(
  getTranslation(KEY_TITLE),
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
)
```

### Step 6: Translating Dynamic Data

For data loaded from APIs, use the translation methods:

```dart
// For single items
final translatedItem = await translateItem(item, ['title', 'description']);

// For lists
final translatedList = await translateItems(items, ['title', 'description']);
```

## Error Handling with Translations

Use the `TranslatedErrorHandler` for consistent error handling:

```dart
try {
  // Your API call or other operation
} catch (e) {
  await TranslatedErrorHandler.showError(e, context: context);
}
```

For error widgets embedded in the UI:

```dart
FutureBuilder(
  future: TranslatedErrorHandler.getErrorWidget(
    error,
    onRetry: () => yourRetryFunction(),
  ),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return snapshot.data!;
    } else {
      return CircularProgressIndicator();
    }
  },
)
```

## Best Practices

1. **Keep translation keys consistent** across screens for shared terms
2. **Use descriptive key names** to make the code more maintainable
3. **Group related translations** together in the registration method
4. **Always handle errors** with proper language translation
5. **Test all screens** with different language settings

## Example Implementation

Here's a complete example of a screen with language support:

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/language_helper.dart';
import '../../../core/utils/error_with_translation.dart';

class ExampleScreen extends StatefulWidget {
  @override
  _ExampleScreenState createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> with TranslationMixin {
  // Translation keys
  static const String KEY_TITLE = 'example_title';
  static const String KEY_DESCRIPTION = 'example_description';
  static const String KEY_BUTTON = 'example_button';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _loadData();
  }

  void _registerTranslations() {
    registerTranslation(KEY_TITLE, 'Example Screen');
    registerTranslation(KEY_DESCRIPTION, 'This is an example screen with translation support');
    registerTranslation(KEY_BUTTON, 'Click Me');
  }

  Future<void> _loadData() async {
    try {
      // Your API call or data loading logic
    } catch (e) {
      await TranslatedErrorHandler.showError(e, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getTranslation(KEY_TITLE)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(getTranslation(KEY_DESCRIPTION)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(getTranslation(KEY_BUTTON)),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Checklist for Existing Screens

When updating existing screens, make sure to:

1. ✅ Add the `TranslationMixin`
2. ✅ Define translation keys
3. ✅ Register default translations
4. ✅ Replace hardcoded text with `getTranslation()` calls
5. ✅ Implement error handling with translated messages
6. ✅ Test the screen with different languages

## Conclusion

Following this guide will ensure consistent language support and error handling across the entire KrishiMantra application. If you have any questions or need assistance with implementation, please reach out to the development team.
