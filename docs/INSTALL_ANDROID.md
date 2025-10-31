# Android APK Build and Installation Guide

This guide provides comprehensive instructions for building an Android APK from source and installing it on an Android device for the VRCam project. These instructions are generic and can be adapted for various Android project types.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Building APK by Project Type](#building-apk-by-project-type)
3. [Locating the Generated APK](#locating-the-generated-apk)
4. [Installing APK on Device](#installing-apk-on-device)
5. [Troubleshooting](#troubleshooting)
6. [Additional Resources](#additional-resources)

## Prerequisites

Before building and installing an Android APK, ensure you have the following tools installed:

### Required Tools

1. **Java Development Kit (JDK)**
   - JDK 8 or higher (JDK 11 recommended for modern Android projects)
   - Download: [Oracle JDK](https://www.oracle.com/java/technologies/downloads/) or [OpenJDK](https://openjdk.org/)
   - Verify installation: `java -version`

2. **Android SDK & Platform Tools**
   - Install via [Android Studio](https://developer.android.com/studio) (recommended) or
   - Install command-line tools only: [SDK Tools](https://developer.android.com/studio#command-tools)
   - Must include:
     - Android SDK Platform (matching your target API level)
     - Android SDK Build-Tools
     - Android SDK Platform-Tools (includes `adb`)

3. **Android Debug Bridge (adb)**
   - Included with Android SDK Platform-Tools
   - Add to PATH: `export PATH=$PATH:$ANDROID_HOME/platform-tools`
   - Verify installation: `adb version`

4. **Gradle** (for native Android projects)
   - Usually included via Gradle wrapper (`./gradlew`)
   - If wrapper is not available, install Gradle: [Gradle Installation](https://gradle.org/install/)

5. **Additional Tools for Specific Project Types**
   - **Unity**: Unity Editor with Android Build Support module
   - **React Native**: Node.js (v14+), npm/yarn, React Native CLI
   - **Cordova/Ionic**: Node.js, Cordova CLI, Ionic CLI

### Environment Variables

Set up the following environment variables (add to `~/.bashrc` or `~/.zshrc`):

```bash
# Android SDK location (adjust path to your installation)
export ANDROID_HOME=$HOME/Android/Sdk  # Linux/macOS
# or on Windows: set ANDROID_HOME=C:\Users\YourName\AppData\Local\Android\Sdk

# Add platform-tools to PATH for adb access
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin

# Optional: Java Home (if not set)
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64  # Adjust to your JDK path
```

After adding these, reload your shell: `source ~/.bashrc`

## Building APK by Project Type

### Native Android (Gradle)

VRCam is a native Android project. Use the Gradle wrapper to build:

#### Debug Build (recommended for testing)

```bash
# From project root directory
./gradlew assembleDebug

# Or on Windows
gradlew.bat assembleDebug
```

The debug APK will be generated at:
```
app/build/outputs/apk/debug/app-debug.apk
```

#### Release Build (for distribution)

```bash
# Build release APK (unsigned)
./gradlew assembleRelease

# Or on Windows
gradlew.bat assembleRelease
```

The release APK will be generated at:
```
app/build/outputs/apk/release/app-release-unsigned.apk
```

**Note**: Release APKs must be signed before installation. For development purposes, use the debug build which is automatically signed with a debug keystore.

#### Signing a Release APK

If you need to sign a release APK:

```bash
# Generate a keystore (one-time setup)
keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias

# Sign the APK
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore my-release-key.jks \
  app/build/outputs/apk/release/app-release-unsigned.apk \
  my-key-alias

# Align the APK (optional but recommended)
zipalign -v 4 app/build/outputs/apk/release/app-release-unsigned.apk \
  app/build/outputs/apk/release/app-release.apk
```

### Unity Project

If this were a Unity project, you would build an APK using:

#### Via Unity Editor
1. Open the project in Unity Editor
2. Go to **File → Build Settings**
3. Select **Android** platform and click **Switch Platform**
4. Click **Build** or **Build and Run**
5. Choose output location for the APK

#### Via Command Line
```bash
# Unity command line build
/path/to/Unity -quit -batchmode -projectPath /path/to/project \
  -buildTarget Android \
  -executeMethod BuildScript.BuildAndroid
```

APK location: User-specified output path or `Builds/Android/YourApp.apk`

### React Native Project

For React Native projects:

#### Debug Build
```bash
# Using npx
npx react-native run-android

# Or using gradlew directly
cd android
./gradlew assembleDebug
```

#### Release Build
```bash
# Using gradlew
cd android
./gradlew assembleRelease

# Or using React Native CLI
npx react-native run-android --variant=release
```

APK location: `android/app/build/outputs/apk/release/app-release.apk`

### Cordova/Ionic Project

For Cordova or Ionic projects:

```bash
# Cordova
cordova build android --release

# Ionic
ionic cordova build android --release
```

APK location: `platforms/android/app/build/outputs/apk/release/app-release-unsigned.apk`

## Locating the Generated APK

After building, APKs are typically located in one of these paths:

- **Native Android**: `app/build/outputs/apk/{debug|release}/app-{debug|release}.apk`
- **React Native**: `android/app/build/outputs/apk/{debug|release}/app-{debug|release}.apk`
- **Unity**: User-specified or `Builds/Android/{ProjectName}.apk`
- **Cordova/Ionic**: `platforms/android/app/build/outputs/apk/release/app-release-unsigned.apk`

### Helper Script

Use the provided helper script to find APK files:

```bash
./scripts/android/find_apk.sh
```

This script searches common APK output locations and lists all found APK files.

## Installing APK on Device

### Step 1: Enable USB Debugging on Android Device

1. **Enable Developer Options**:
   - Go to **Settings → About Phone**
   - Tap **Build Number** 7 times
   - You'll see a message "You are now a developer!"

2. **Enable USB Debugging**:
   - Go to **Settings → System → Developer Options**
   - Enable **USB Debugging**
   - (Optional) Enable **Install via USB** for easier sideloading

3. **Connect Device**:
   - Connect your Android device to your computer via USB
   - On your device, authorize the USB debugging connection when prompted

### Step 2: Verify Device Connection

```bash
# Check if device is connected
adb devices

# You should see output like:
# List of devices attached
# 1234567890ABCDEF    device
```

If you see "unauthorized", check your device for the authorization prompt.

### Step 3: Install APK via adb

#### Manual Installation

```bash
# Install APK (replace with actual path)
adb install -r app/build/outputs/apk/debug/app-debug.apk

# The -r flag allows reinstalling with keeping data
# The -g flag grants all runtime permissions (useful for testing)
adb install -r -g app/build/outputs/apk/debug/app-debug.apk
```

#### Using Helper Script

Use the provided installation script for an easier experience:

```bash
# Install APK by providing path
./scripts/android/install_apk.sh app/build/outputs/apk/debug/app-debug.apk

# Or let the script search for APKs
./scripts/android/install_apk.sh
```

The script will:
- Verify adb is available
- Check for connected devices
- Handle multiple devices by prompting for selection
- Install the APK with appropriate flags
- Handle errors gracefully

### Step 4: Grant Install Permissions (API 26+)

For Android 8.0 (API 26) and higher, apps may need the `REQUEST_INSTALL_PACKAGES` permission:

```bash
# Grant install permission if needed
adb shell pm grant com.example.vrcam android.permission.REQUEST_INSTALL_PACKAGES

# Replace com.example.vrcam with your actual package name
```

To find your package name:
```bash
# List all package names from APK
aapt dump badging app/build/outputs/apk/debug/app-debug.apk | grep package

# Or if app is already installed
adb shell pm list packages | grep vrcam
```

### Step 5: Launch the App

```bash
# Launch the app after installation
adb shell am start -n com.example.vrcam/.MainActivity

# Or find and tap the app icon on your device
```

## Troubleshooting

### Build Issues

#### Issue: "SDK location not found"
**Solution**: Create `local.properties` file in project root:
```properties
sdk.dir=/path/to/Android/Sdk
```

#### Issue: "Gradle build fails"
**Solutions**:
- Clean and rebuild: `./gradlew clean build`
- Check Java version: `java -version` (should be JDK 8+)
- Update Gradle wrapper: `./gradlew wrapper --gradle-version 7.5`
- Sync project with Gradle files (in Android Studio)

#### Issue: "Unsupported class file major version"
**Solution**: Your JDK version might be too new. Set compatibility in `build.gradle`:
```gradle
android {
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

### adb Issues

#### Issue: "adb: command not found"
**Solution**: Add Android SDK platform-tools to PATH:
```bash
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

#### Issue: "no devices/emulators found"
**Solutions**:
- Ensure USB debugging is enabled on device
- Try different USB cable (some are charge-only)
- Revoke and re-authorize USB debugging on device
- Restart adb server: `adb kill-server && adb start-server`
- Check if device appears: `lsusb` (Linux) or check Device Manager (Windows)

#### Issue: "device unauthorized"
**Solution**: 
- Check device for authorization prompt
- Revoke USB debugging authorizations: Settings → Developer Options → Revoke USB debugging authorizations
- Reconnect and re-authorize

#### Issue: "more than one device/emulator"
**Solution**: Specify device:
```bash
# List devices with serial numbers
adb devices

# Install to specific device
adb -s <device-serial> install -r app-debug.apk
```

Or use the helper script which handles multiple devices automatically.

### Installation Issues

#### Issue: "INSTALL_FAILED_OLDER_SDK"
**Solution**: Your device's Android version is lower than the minSdkVersion in the APK. Either:
- Update your device Android version, or
- Lower the minSdkVersion in `app/build.gradle` and rebuild

#### Issue: "INSTALL_FAILED_UPDATE_INCOMPATIBLE"
**Solution**: Existing app has a conflicting signature:
```bash
# Uninstall the existing app
adb uninstall com.example.vrcam

# Then reinstall
adb install -r app-debug.apk
```

#### Issue: "INSTALL_FAILED_INSUFFICIENT_STORAGE"
**Solution**: Free up space on your device or install to SD card:
```bash
adb install -s app-debug.apk
```

#### Issue: "INSTALL_PARSE_FAILED_NO_CERTIFICATES"
**Solution**: APK is not signed. Use a debug build or sign your release build.

### Permission Issues

#### Issue: App crashes on camera/storage access
**Solution**: Grant permissions via adb:
```bash
# Grant camera permission
adb shell pm grant com.example.vrcam android.permission.CAMERA

# Grant storage permissions
adb shell pm grant com.example.vrcam android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.example.vrcam android.permission.WRITE_EXTERNAL_STORAGE

# For Android 13+ media permissions
adb shell pm grant com.example.vrcam android.permission.READ_MEDIA_IMAGES
```

## Additional Resources

### Official Documentation

- [Android Developer Guide](https://developer.android.com/guide)
- [Android Studio User Guide](https://developer.android.com/studio/intro)
- [Building Your App - Android](https://developer.android.com/studio/build)
- [Android Debug Bridge (adb)](https://developer.android.com/studio/command-line/adb)
- [Sign Your App](https://developer.android.com/studio/publish/app-signing)
- [Gradle User Manual](https://docs.gradle.org/current/userguide/userguide.html)

### Build Tool Documentation

- [Gradle for Android](https://developer.android.com/studio/build)
- [React Native - Building for Android](https://reactnative.dev/docs/signed-apk-android)
- [Unity - Android Build Settings](https://docs.unity3d.com/Manual/android-BuildProcess.html)
- [Cordova - Android Platform Guide](https://cordova.apache.org/docs/en/latest/guide/platforms/android/)

### Useful Commands

```bash
# View APK information
aapt dump badging app-debug.apk

# View detailed build output
./gradlew assembleDebug --stacktrace --info

# List all Gradle tasks
./gradlew tasks --all

# Generate dependency tree
./gradlew app:dependencies

# Run with specific device
adb -s <device-serial> install app-debug.apk

# View device logs while testing
adb logcat | grep com.example.vrcam

# Take screenshot from device
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png

# Record screen
adb shell screenrecord /sdcard/demo.mp4
adb pull /sdcard/demo.mp4
```

---

For project-specific build instructions and requirements, refer to the main [README.md](../README.md).

For automated APK installation, use the helper script: `./scripts/android/install_apk.sh`

For CI/CD automated builds, see `.github/workflows/android-build.yml`
