# Using SmartLink SDK Locally in FlutterFlow

There are **3 ways** to use the SmartLink SDK in FlutterFlow without publishing to pub.dev:

---

## ✅ Option A: Git Repository (RECOMMENDED)

This is the most flexible and FlutterFlow-compatible approach.

### Step 1: Create Git Repository

1. **Initialize git** in SDK folder:
   ```bash
   cd smartlink_flutter_sdk
   git init
   git add .
   git commit -m "Initial SmartLink SDK"
   ```

2. **Push to private repository** (GitHub, GitLab, Bitbucket):
   ```bash
   # GitHub example
   git remote add origin https://github.com/your-org/smartlink_flutter_sdk.git
   git branch -M main
   git push -u origin main
   ```

### Step 2: Use in FlutterFlow

1. **Open FlutterFlow** → Settings → Dependencies

2. **Add git dependency** in `pubspec.yaml`:
   ```yaml
   dependencies:
     smartlink_flutter_sdk:
       git:
         url: https://github.com/your-org/smartlink_flutter_sdk.git
         ref: main  # or specific commit/tag
   ```

3. **Save** and FlutterFlow will fetch from Git

### Advantages:
- ✅ Works in FlutterFlow UI
- ✅ No code download needed
- ✅ Can use private repositories
- ✅ Version control with tags/branches
- ✅ Team can access same version

### Authentication (Private Repos):

**GitHub Personal Access Token**:
```yaml
dependencies:
  smartlink_flutter_sdk:
    git:
      url: https://your-token@github.com/your-org/smartlink_flutter_sdk.git
      ref: main
```

---

## Option B: Local Path (Development Only)

Use when developing SDK locally, testing changes frequently.

### Requirements:
- Must **download FlutterFlow code**
- Cannot use FlutterFlow's Test Mode
- Path must be accessible

### Step 1: Download FlutterFlow Project

1. **FlutterFlow** → Project Menu → **Download Code**
2. Extract to local folder

### Step 2: Add Path Dependency

1. **Edit `pubspec.yaml`** manually:
   ```yaml
   dependencies:
     smartlink_flutter_sdk:
       path: C:/smartlink/smartlink/smartlink_flutter_sdk  # Windows
       # path: /Users/you/smartlink/smartlink_flutter_sdk  # Mac
       # path: /home/you/smartlink/smartlink_flutter_sdk   # Linux
   ```

2. **Run**:
   ```bash
   flutter pub get
   flutter run
   ```

### Advantages:
- ✅ Instant SDK updates during development
- ✅ No git commits needed for testing

### Disadvantages:
- ❌ Must download code each time FlutterFlow updates
- ❌ Path must exist on every developer's machine
- ❌ Won't work in FlutterFlow Test Mode
- ❌ Manual sync required

---

## Option C: Local Network Server (Advanced)

Host SDK on local network, FlutterFlow fetches via HTTP.

### Step 1: Create Pub Server

1. **Install pub_server**:
   ```bash
   dart pub global activate pub_server
   ```

2. **Run server**:
   ```bash
   cd smartlink
   dart pub global run pub_server -p 8080 --directory .
   ```

3. **Server runs** on: `http://localhost:8080`

### Step 2: Use in FlutterFlow

```yaml
dependencies:
  smartlink_flutter_sdk:
    hosted:
      name: smartlink_flutter_sdk
      url: http://YOUR_LOCAL_IP:8080
    version: ^1.0.0
```

### Advantages:
- ✅ Multiple projects can use same server
- ✅ Version management

### Disadvantages:
- ❌ Complex setup
- ❌ Server must be running
- ❌ Network dependency

---

## 🎯 Recommended Workflow

### For Your Use Case (Local Network Testing):

**Phase 1: Development** (Use Option B - Path)
1. Download FlutterFlow project
2. Add SDK as path dependency
3. Develop and test locally
4. Make SDK changes → instantly reflected

**Phase 2: Team Testing** (Use Option A - Git)
1. Commit SDK to private Git repo
2. Update FlutterFlow to use Git dependency
3. Team can test without path issues
4. Can upload directly in FlutterFlow UI

**Phase 3: Production** (Publish to pub.dev)
1. Publish SDK to pub.dev
2. Update to: `smartlink_flutter_sdk: ^1.0.0`
3. Public availability

---

## 📝 Example: Complete Setup (Git Method)

### 1. Prepare SDK

```bash
cd smartlink_flutter_sdk

# Initialize git
git init
git add .
git commit -m "feat: SmartLink SDK v1.0.0"

# Create GitHub repo (via UI or CLI)
gh repo create smartlink_flutter_sdk --private

# Push
git remote add origin https://github.com/your-org/smartlink_flutter_sdk.git
git push -u origin main

# Tag version
git tag v1.0.0
git push --tags
```

### 2. FlutterFlow Configuration

In **Settings → Dependencies → pubspec.yaml**:

```yaml
name: your_app
description: Your FlutterFlow App

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # SmartLink SDK from private Git
  smartlink_flutter_sdk:
    git:
      url: https://github.com/your-org/smartlink_flutter_sdk.git
      ref: v1.0.0  # Use specific version tag
```

### 3. Create Custom Actions

**Action: initializeSmartLink**
```dart
import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

Future<bool> initializeSmartLink(String baseUrl) async {
  try {
    await SmartLinkClient.initialize(
      baseUrl: baseUrl,
      apiKey: 'demo-api-key',
      config: SmartLinkConfig(
        enableAnalytics: true,
        enableDeepLinking: true,
        logLevel: LogLevel.debug,
      ),
    );
    return true;
  } catch (e) {
    print('SmartLink init failed: $e');
    return false;
  }
}
```

**Action: setupDeepLinkListener**
```dart
import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

Future<void> setupDeepLinkListener(BuildContext context) async {
  SmartLinkClient.instance.onDeepLink.listen((deepLink) {
    print('Deep link: ${deepLink.path}');

    // Navigate based on path
    if (deepLink.path.startsWith('/hidden')) {
      context.pushNamed('HiddenPage');
    }
  });
}
```

### 4. App Initialization

**App Settings → On App Start:**
1. Add Custom Action: `initializeSmartLink`
   - Pass parameter: `baseUrl` = `http://YOUR_LOCAL_IP:3000`
2. Add Custom Action: `setupDeepLinkListener`

---

## 🔄 Updating SDK

### Git Method

```bash
# Make changes to SDK
cd smartlink_flutter_sdk
# ... edit files ...

# Commit and tag new version
git add .
git commit -m "feat: Add new feature"
git tag v1.0.1
git push origin main --tags

# Update in FlutterFlow pubspec.yaml:
# Change ref: v1.0.0 → ref: v1.0.1
```

### Path Method

```bash
# Make changes to SDK
# ... edit files ...

# In your FlutterFlow project:
flutter pub get  # Fetches latest from path
flutter run      # Test changes
```

---

## 🐛 Troubleshooting

### Issue: "Could not resolve package"

**Git Method**:
- Verify repo URL is correct
- Check authentication (private repos need token)
- Ensure ref/tag exists

**Path Method**:
- Verify path exists and is correct
- Use absolute paths
- Check forward slashes (even on Windows)

### Issue: "SDK not found in FlutterFlow"

**Solution**:
- Git dependency requires code download
- FlutterFlow Test Mode doesn't support custom packages
- Download code and run locally: `flutter run`

### Issue: "Version solving failed"

**Solution**:
- Check Flutter/Dart SDK version compatibility
- SDK requires: `sdk: ^3.10.0`, `flutter: >=3.38.0`
- Update Flutter: `flutter upgrade`

---

## ✅ Quick Checklist

Before using SDK in FlutterFlow:

- [ ] SDK tests pass: `flutter test`
- [ ] Git repo created (if using Git method)
- [ ] Dependency added to pubspec.yaml
- [ ] Custom Actions created (init + listener)
- [ ] App initialization configured
- [ ] Code downloaded (if using path/local testing)
- [ ] Platform files updated (Info.plist, AndroidManifest.xml)

---

## 🎯 Summary

| Method | Best For | FlutterFlow UI | Team Use | Effort |
|--------|----------|----------------|----------|--------|
| **Git** | Team testing, staging | ✅ Yes | ✅ Yes | Medium |
| **Path** | Solo development | ❌ No | ❌ No | Low |
| **Server** | Enterprise, CI/CD | ✅ Yes | ✅ Yes | High |

**Recommendation**: Use **Git** for your scenario (team testing on local network).

---

For detailed testing instructions, see [FLUTTERFLOW_LOCAL_TESTING.md](FLUTTERFLOW_LOCAL_TESTING.md)
