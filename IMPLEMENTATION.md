# VRCam Implementation Details

## Overview
This document describes the implementation of the VRCam virtual camera application that allows users to select images from their gallery and overlay them on live camera preview for composite photo capture.

## Architecture

### Main Components

#### MainActivity.kt
The single activity that manages the entire application flow:

1. **Camera Management**
   - Initializes CameraX with PreviewView
   - Configures ImageCapture use case
   - Handles camera lifecycle

2. **Permission Handling**
   - Uses ActivityResultContracts for runtime permissions
   - Requests CAMERA permission
   - Handles permission denial gracefully

3. **Image Selection**
   - ActivityResultContracts.GetContent() for gallery picker
   - Supports all image types
   - Stores selected image URI

4. **Overlay System**
   - ImageView positioned over PreviewView
   - 70% transparency (alpha = 0.7)
   - Full-screen scaling with fitCenter

5. **Photo Capture**
   - Standard capture when no overlay present
   - Composite capture when overlay is visible
   - Background processing using Kotlin coroutines

6. **Image Compositing**
   - Loads both camera and overlay images
   - Creates result bitmap with camera dimensions
   - Draws camera image first (background)
   - Scales overlay to match dimensions
   - Applies transparency and draws overlay
   - Saves composite to original URI
   - Proper bitmap recycling to prevent memory leaks

### Key Technical Decisions

#### Modern APIs
- **ImageDecoder** (Android P+): Replaces deprecated MediaStore.getBitmap()
- **CameraX**: Modern camera API with lifecycle awareness
- **ViewBinding**: Type-safe view access
- **Coroutines**: Structured concurrency for background work

#### Background Processing
Heavy bitmap operations run on `Dispatchers.IO`:
- Loading images from storage
- Bitmap scaling
- Canvas drawing operations
- Image compression and saving

UI updates use `Dispatchers.Main` via `withContext()`.

#### Memory Management
All bitmaps are explicitly recycled after use:
```kotlin
cameraImage.recycle()
overlayImage.recycle()
scaledOverlay.recycle()
resultBitmap.recycle()
```

## User Flow

```
┌─────────────────────┐
│   App Launch        │
│   Request Camera    │
│   Permission        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Camera Preview    │
│   Display           │
└──────────┬──────────┘
           │
    ┌──────┴───────┐
    │              │
    ▼              ▼
┌─────────┐  ┌─────────────┐
│ SELECT  │  │  CAPTURE    │
│ IMAGE   │  │  (Regular)  │
└────┬────┘  └─────────────┘
     │
     ▼
┌─────────────────────┐
│  Gallery Picker     │
│  Shows              │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Overlay Image      │
│  Displayed on       │
│  Camera Preview     │
└──────────┬──────────┘
           │
    ┌──────┴───────┐
    │              │
    ▼              ▼
┌─────────┐  ┌─────────────┐
│ CAPTURE │  │  CLEAR      │
│ (Comp)  │  │  OVERLAY    │
└────┬────┘  └─────────────┘
     │
     ▼
┌─────────────────────┐
│  Composite Image    │
│  Saved to Storage   │
└─────────────────────┘
```

## File Structure

```
app/src/main/
├── AndroidManifest.xml          # App config, permissions, FileProvider
├── java/com/example/vrcam/
│   └── MainActivity.kt          # Main application logic (296 lines)
└── res/
    ├── layout/
    │   └── activity_main.xml    # UI layout
    ├── values/
    │   ├── colors.xml           # Color definitions
    │   ├── strings.xml          # User-facing strings
    │   └── themes.xml           # Material theme
    ├── xml/
    │   └── file_paths.xml       # FileProvider paths
    └── mipmap-*/
        └── ic_launcher.png      # App icon (all densities)
```

## Dependencies

### Core Android
- `androidx.core:core-ktx:1.9.0`
- `androidx.appcompat:appcompat:1.6.1`
- `androidx.constraintlayout:constraintlayout:2.1.4`

### UI
- `com.google.android.material:material:1.8.0`

### Camera
- `androidx.camera:camera-core:1.2.2`
- `androidx.camera:camera-camera2:1.2.2`
- `androidx.camera:camera-lifecycle:1.2.2`
- `androidx.camera:camera-view:1.2.2`

### Async
- `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.6.4`

### Activity
- `androidx.activity:activity-ktx:1.7.0`

## Permissions

### Required at Runtime
- `android.permission.CAMERA` - For camera access

### Required for Gallery
- `android.permission.READ_MEDIA_IMAGES` (Android 13+)
- `android.permission.READ_EXTERNAL_STORAGE` (Android 12 and below)

### Required for Saving (Legacy)
- `android.permission.WRITE_EXTERNAL_STORAGE` (Android 9 and below)

## Security Considerations

1. **No Vulnerabilities**: All dependencies verified against GitHub Advisory Database
2. **Runtime Permissions**: Proper permission flow with user consent
3. **FileProvider**: Secure file sharing configuration
4. **No Hardcoded Secrets**: No API keys or credentials in code
5. **ANR Prevention**: Heavy operations on background threads

## Performance Optimizations

1. **Background Processing**: Bitmap operations on IO dispatcher
2. **Bitmap Recycling**: Explicit memory cleanup
3. **Efficient Scaling**: Single-pass bitmap scaling
4. **Stream-based I/O**: Direct stream writing for image saves

## Future Enhancements

Possible improvements for future versions:
- Adjustable overlay transparency slider
- Multiple overlay support
- Overlay positioning and scaling controls
- Video recording with overlay
- Filter effects
- Front/back camera switching
- Flash control
- Image editing before save
- Social media sharing integration

## Build Instructions

### Prerequisites
- Android Studio Arctic Fox or later
- Android SDK 24+
- JDK 8 or later

### Building
```bash
./gradlew build
```

### Installing
```bash
./gradlew installDebug
```

### Running Tests
```bash
./gradlew test
```

## License
This project is open source under the MIT License.
