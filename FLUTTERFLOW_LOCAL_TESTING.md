# FlutterFlow Local Testing Guide - SmartLink SDK

This guide explains how to test the SmartLink SDK locally in your FlutterFlow app with deferred deep linking.

## 📋 Testing Scenario

**Goal**: Test deferred deep linking with a hidden page that's only accessible via SmartLink.

**Flow**:
1. **App NOT installed**: Click link → App Store/Play Store → Install → Open app → Navigate to hidden page
2. **App installed**: Click link → Open app → Navigate to hidden page

**Setup**: Local network only (backend + SDK)

---

## 🔧 Prerequisites

### Backend Setup
1. **Start SmartLink Backend** (on your local machine):
   ```bash
   cd backend
   npm run dev
   ```
   Backend should run on `http://localhost:3000`

2. **Get your local IP address**:
   - **Windows**: `ipconfig` → Look for IPv4 Address (e.g., `192.168.1.100`)
   - **Mac/Linux**: `ifconfig` → Look for inet address
   - **Important**: Use your local IP, NOT `localhost`, so mobile devices can reach it

3. **Verify backend is accessible** from your phone:
   - Connect phone to same WiFi network
   - Open browser on phone
   - Visit `http://YOUR_LOCAL_IP:3000/api/health`
   - Should return: `{"status":"ok"}`

### SDK Setup
1. **Build the SDK package**:
   ```bash
   cd smartlink_flutter_sdk
   flutter pub get
   flutter test  # Verify all tests pass
   ```

2. **Note the SDK path**: `C:\smartlink\smartlink\smartlink_flutter_sdk`

---

## 📱 FlutterFlow Configuration

### Step 1: Add Local SDK to FlutterFlow

1. **Open your FlutterFlow project**

2. **Go to Settings & Integrations** (⚙️ icon in left sidebar)

3. **Navigate to Dependencies** → **pubspec.yaml**

4. **Add SDK as path dependency**:
   ```yaml
   dependencies:
     smartlink_flutter_sdk:
       path: C:/smartlink/smartlink/smartlink_flutter_sdk
   ```

   **Important Notes**:
   - Use forward slashes `/` (even on Windows)
   - Use absolute path
   - FlutterFlow will copy this to the generated Flutter project

5. **Click "Save"** and wait for dependencies to resolve

### Step 2: Create Hidden Page

1. **Create new page**: `HiddenPage` or `SecretPage`

2. **Page Settings**:
   - ✅ Enable: "Hide in Navigation Menu"
   - ✅ Add route parameter: `ref` (optional, to capture campaign data)

3. **Add content** to verify it works:
   - Add Text widget: "🎉 Deferred Deep Link Success!"
   - Add Text widget to show parameters (if any)

4. **Design the page** as you like

### Step 3: Initialize SmartLink SDK

1. **Go to App Settings** → **Custom Code**

2. **Add Custom Action** → Name: `initializeSmartLink`

3. **Action Code**:
   ```dart
   import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

   Future<bool> initializeSmartLink() async {
     try {
       await SmartLinkClient.initialize(
         baseUrl: 'http://YOUR_LOCAL_IP:3000',  // Replace with your IP!
         apiKey: 'demo-api-key',
         config: SmartLinkConfig(
           enableAnalytics: true,
           enableDeepLinking: true,
           logLevel: LogLevel.debug,
         ),
       );

       print('✅ SmartLink initialized successfully');
       return true;
     } catch (e) {
       print('❌ SmartLink initialization failed: $e');
       return false;
     }
   }
   ```

4. **Important**: Replace `YOUR_LOCAL_IP` with your actual local IP (e.g., `192.168.1.100`)

### Step 4: Setup Deep Link Handler

1. **Add another Custom Action** → Name: `setupDeepLinkListener`

2. **Action Code**:
   ```dart
   import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

   Future<void> setupDeepLinkListener(BuildContext context) async {
     // Listen for deep links
     SmartLinkClient.instance.onDeepLink.listen((deepLink) {
       print('🔗 Deep link received: ${deepLink.path}');

       // Parse the path
       if (deepLink.path.startsWith('/hidden') ||
           deepLink.path.startsWith('/secret')) {

         // Navigate to hidden page
         context.pushNamed(
           'HiddenPage',  // Replace with your page name
           extra: {
             'ref': deepLink.getParam('ref'),
             'campaign': deepLink.getParam('campaign'),
           },
         );
       }
     });

     print('✅ Deep link listener setup complete');
   }
   ```

3. **Adjust navigation**:
   - Replace `'HiddenPage'` with your actual page name
   - Adjust parameters as needed

### Step 5: Configure App Initialization

1. **Go to App Settings** → **On App Start**

2. **Add Action**: Custom Action → `initializeSmartLink`

3. **Add Action**: Custom Action → `setupDeepLinkListener`

4. **Order matters**:
   - First: `initializeSmartLink`
   - Second: `setupDeepLinkListener`

### Step 6: Platform-Specific Setup

#### iOS Setup (iOS Simulator or Device)

1. **Download your FlutterFlow project** (Project → Download Code)

2. **Open in Xcode**:
   ```bash
   cd path/to/downloaded/project/ios
   open Runner.xcworkspace
   ```

3. **Update `Info.plist`** (`ios/Runner/Info.plist`):
   ```xml
   <!-- Add before closing </dict> -->

   <!-- Custom URL Scheme -->
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>smartlinktest</string>
       </array>
     </dict>
   </array>

   <!-- Disable Flutter's default deep linking -->
   <key>FlutterDeepLinkingEnabled</key>
   <false/>
   ```

4. **Build and run from Xcode**

#### Android Setup (Android Device or Emulator)

1. **Download your FlutterFlow project**

2. **Update `AndroidManifest.xml`** (`android/app/src/main/AndroidManifest.xml`):
   ```xml
   <!-- Inside <activity android:name=".MainActivity"> -->

   <!-- Custom URL scheme -->
   <intent-filter>
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />

     <data android:scheme="smartlinktest" />
   </intent-filter>
   ```

3. **Build and run**:
   ```bash
   cd path/to/downloaded/project
   flutter run
   ```

---

## 🧪 Testing the Flow

### Test 1: Create SmartLink (via Backend API)

1. **Open Terminal/Postman**

2. **Create a test link**:
   ```bash
   curl -X POST http://YOUR_LOCAL_IP:3000/api/v1/links \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
     -d '{
       "longUrl": "https://yourapp.com/hidden",
       "title": "Test Hidden Page Link",
       "deepLinkConfig": {
         "deepLinkPath": "/hidden",
         "customScheme": "smartlinktest"
       }
     }'
   ```

3. **Response** will contain:
   ```json
   {
     "success": true,
     "data": {
       "shortUrl": "http://YOUR_LOCAL_IP:3000/abc123",
       "shortCode": "abc123"
     }
   }
   ```

4. **Note the `shortCode`** (e.g., `abc123`)

### Test 2: Deferred Deep Link (App NOT Installed)

**Scenario**: User clicks link, installs app, opens app → should navigate to hidden page

1. **Uninstall your FlutterFlow app** from test device

2. **Simulate a click** (this creates fingerprint):
   ```bash
   # From your phone browser (connected to same WiFi):
   http://YOUR_LOCAL_IP:3000/abc123
   ```

   Expected: Browser opens (no app installed)

3. **Install and open app** (via Xcode/Android Studio)

4. **SDK should**:
   - ✅ Detect first launch
   - ✅ Query backend for deferred link
   - ✅ Match fingerprint
   - ✅ Navigate to hidden page

5. **Verify**:
   - Check app logs for: `🔗 Deep link received: /hidden`
   - App should navigate to `HiddenPage`

### Test 3: Direct Deep Link (App Installed)

**Scenario**: User clicks link, app is already installed → should open app and navigate

1. **App is installed and closed**

2. **Click link in browser**:
   ```
   http://YOUR_LOCAL_IP:3000/abc123
   ```

3. **Expected behavior**:
   - Browser redirects to: `smartlinktest://hidden`
   - OS prompts: "Open in [Your App]?"
   - App opens and navigates to hidden page

### Test 4: Custom URL Scheme (Direct)

**Scenario**: Test deep link directly without SmartLink redirect

1. **Open Safari (iOS) or Chrome (Android)**

2. **Enter in address bar**:
   ```
   smartlinktest://hidden?ref=test123
   ```

3. **Expected**:
   - App opens
   - Navigates to hidden page
   - Shows parameter: `ref=test123`

---

## 🐛 Debugging

### Check SDK Initialization

1. **View Flutter logs**:
   ```bash
   flutter logs
   ```

2. **Look for**:
   ```
   ✅ SmartLink initialized successfully
   ✅ Deep link listener setup complete
   Fingerprint: abc123def456...
   Session ID: xyz789...
   ```

### Check Backend Logs

1. **In backend terminal**, look for:
   ```
   [INFO] Click tracked: abc123
   [INFO] Fingerprint: abc123def456...
   [INFO] Deferred link matched: linkId=...
   ```

### Common Issues

#### ❌ "Connection refused" or "Network error"

**Solution**:
- Verify phone and computer are on **same WiFi**
- Use **local IP** (e.g., `192.168.1.100`), not `localhost`
- Disable firewall temporarily
- Test backend accessibility: `curl http://YOUR_IP:3000/api/health`

#### ❌ "SmartLink not initialized"

**Solution**:
- Check Custom Action code
- Verify `initializeSmartLink` is called in "On App Start"
- Check baseUrl is correct
- Restart app

#### ❌ Deep link doesn't open app

**iOS**:
- Verify `Info.plist` has `CFBundleURLSchemes`
- Verify `FlutterDeepLinkingEnabled` is `false`
- Rebuild app from Xcode

**Android**:
- Verify `AndroidManifest.xml` has intent-filter
- Verify scheme matches (e.g., `smartlinktest`)
- Rebuild app: `flutter run`

#### ❌ App opens but doesn't navigate

**Solution**:
- Check `setupDeepLinkListener` is called
- Verify path matching logic: `if (deepLink.path.startsWith('/hidden'))`
- Check page name matches: `context.pushNamed('HiddenPage')`
- View logs: Should show `🔗 Deep link received: /hidden`

#### ❌ Deferred link doesn't work after install

**Solution**:
- Ensure you clicked link **before** installing
- Wait ~5 seconds after install before opening
- Fingerprinting might not match if using emulator/simulator
- Test on **real device** for best results
- Check backend logs for fingerprint match

---

## 📊 Verification Checklist

Before testing:
- [ ] Backend running on local network
- [ ] Backend accessible from phone browser
- [ ] SDK added to FlutterFlow dependencies
- [ ] Custom Actions created (init + listener)
- [ ] App initialization configured
- [ ] Hidden page created
- [ ] Platform files updated (Info.plist / AndroidManifest.xml)
- [ ] App built and installed

Testing:
- [ ] Create SmartLink via API
- [ ] Test deferred deep link (uninstall → click → install → open)
- [ ] Test direct deep link (app installed → click link)
- [ ] Test custom URL scheme (direct)
- [ ] Verify navigation to hidden page
- [ ] Check parameters are passed

---

## 🎯 Next Steps

Once local testing works:

1. **Production Setup**:
   - Deploy backend to cloud (e.g., Railway, Render, AWS)
   - Update `baseUrl` in FlutterFlow
   - Configure Universal Links (iOS) and App Links (Android)
   - Add `.well-known/apple-app-site-association`
   - Add `.well-known/assetlinks.json`

2. **App Store / Play Store**:
   - Update app with production deep link config
   - Test with TestFlight (iOS) or Internal Testing (Android)
   - Submit to stores

3. **Analytics**:
   - Track link clicks
   - Monitor deferred link attribution
   - Analyze campaign performance

---

## 📞 Support

**Issues?**
- Check [Troubleshooting](#-debugging) section
- Review [SDK Documentation](README.md)
- Check backend logs and Flutter logs
- Verify network connectivity

**Common Questions**:

**Q: Can I use `localhost`?**
A: No, use your local IP address (e.g., `192.168.1.100`) so mobile devices can connect.

**Q: Do I need to publish the SDK to pub.dev?**
A: No, you're using a local path dependency in FlutterFlow.

**Q: Can I test in FlutterFlow's Test Mode?**
A: Deep linking won't work in Test Mode. You must download code and build locally.

**Q: Why doesn't deferred linking work in simulator?**
A: Device fingerprinting is less reliable in simulators. Test on **real devices** for best results.

**Q: How long is the deferred link valid?**
A: Default is 24 hours. Configure in backend settings.

---

**Happy Testing! 🚀**

For questions or issues, check the main [README.md](README.md) or contact the development team.
