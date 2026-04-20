# FlutterFlow Integration Examples

This directory contains example custom actions for integrating the LinkGravity SDK in FlutterFlow apps.

## ⚠️ Important Notes

The files in this directory are **examples** meant to be **copied into FlutterFlow projects**. They contain FlutterFlow-specific imports that don't exist in this SDK package, so you'll see errors when viewing them here. **This is expected and normal.**

## 📂 Files

### `actions.dart`
Pre-built FlutterFlow custom actions that work with the current SDK API. These include:
- `initLinkGravity()` - Initialize the SDK
- `createLinkGravity()` - Create short links
- `trackLinkGravityEvent()` - Track analytics events
- And many more...

### `attach_linkgravity_listener.dart` ⭐ **NEW**
Example showing the **new simplified route registration API**. This replaces the old manual stream subscription approach.

## 🚀 How to Use in FlutterFlow

### Method 1: Using the New Route Registration (Recommended)

**Step 1:** Copy `attach_linkgravity_listener.dart` content

**Step 2:** In FlutterFlow:
1. Go to **Custom Code** → **Actions** → **Add Action**
2. Name it: `attachLinkGravityListener`
3. Add parameter: `context` (type: `BuildContext`)
4. Set return type: `Future<void>`
5. Paste the code from `attach_linkgravity_listener.dart`

**Step 3:** Customize the routes map to match your app's pages

**Step 4:** Call it in your first page's **On Page Load** trigger

### Method 2: Using Pre-built Actions

**Step 1:** Add the SDK as a dependency in FlutterFlow:
```yaml
dependencies:
  linkgravity_flutter_sdk:
    git:
      url: https://github.com/your-org/linkgravity_flutter_sdk.git
      ref: main
```

**Step 2:** Copy individual functions from `actions.dart` into FlutterFlow custom actions

**Step 3:** Use them throughout your app

## 📖 Integration Examples

### Simple Integration (2 Actions)

**Action 1: Initialize SDK (in main.dart final action)**
```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

Future<bool> initializeLinkGravity() async {
  await LinkGravityClient.initialize(
    baseUrl: 'https://your-api.com',
    iosApiKey: 'your-ios-api-key',
    androidApiKey: 'your-android-api-key',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
    ),
  );
  return true;
}
```

That's it! 🎉

## 🔄 Migration from Old Approach

If you're currently using the manual stream subscription approach, here's how to migrate:

### Before (Old Approach)
```dart
// Required 2 separate custom actions with ~80 lines of code
// Action 1: initializeLinkGravity() ~30 lines
// Action 2: setupDeepLinkListener() ~50 lines with manual handling
```

### After (New Approach)
```dart
// Still 2 actions, but much simpler (~40 lines total)
// Action 1: initializeLinkGravity() ~15 lines (unchanged)
// Action 2: attachLinkGravityListener() ~25 lines (simplified)
```

**What changed:**
- ❌ No more manual `onDeepLink.listen()`
- ❌ No more manual `scheduleMicrotask()`
- ❌ No more checking `initialDeepLink` manually
- ❌ No more separate handler functions
- ✅ Simple route map registration
- ✅ Automatic cold/warm start handling
- ✅ Built-in navigation scheduling

## 📝 Notes

- The import errors in this directory are **expected** - these files are templates
- FlutterFlow-specific imports only exist in FlutterFlow projects
- Always test deep links on physical devices for best results
- Use iOS Simulator / Android Emulator for quick testing during development

## 🐛 Troubleshooting

**Q: Why do I see import errors in VS Code?**
A: These are example files meant for FlutterFlow. The imports only exist when copied into a FlutterFlow project.

**Q: Can I use these files directly from the package?**
A: No, these are templates. Copy the code into FlutterFlow Custom Actions.

**Q: Do I need both actions.dart and attach_linkgravity_listener.dart?**
A: No. Use `actions.dart` for pre-built functions, OR create your own based on `attach_linkgravity_listener.dart` example.

## 📚 Additional Resources

- [Main SDK Documentation](../../README.md)
- [FlutterFlow Local Usage Guide](../../FLUTTERFLOW_LOCAL_USAGE.md)
- [Testing Guide](../../FLUTTERFLOW_LOCAL_TESTING.md)
