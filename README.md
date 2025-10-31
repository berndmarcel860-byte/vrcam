# VRCam - Virtual Camera App

A virtual camera Android application that allows users to select images from their gallery and overlay them on the camera preview to create composite photos.

## Features

- **Camera Preview**: Real-time camera preview using CameraX
- **Gallery Integration**: Select images from device gallery
- **Image Overlay**: Display selected images over the camera preview with adjustable transparency
- **Composite Capture**: Capture photos with the overlay merged into the final image
- **Easy Controls**: Simple UI with buttons to select, capture, and clear overlays

## Requirements

- Android 7.0 (API level 24) or higher
- Camera permission
- Storage read permission (for selecting gallery images)

## How to Use

1. **Launch the app**: The camera preview will start automatically after granting camera permission
2. **Select an image**: Tap "SELECT IMAGE" to choose an image from your gallery
3. **Position the overlay**: The selected image will appear as a semi-transparent overlay on the camera preview
4. **Capture**: Tap "CAPTURE" to take a photo with the overlay merged
5. **Clear overlay**: Tap "CLEAR OVERLAY" to remove the current overlay image
6. **View results**: Captured images are saved to Pictures/VRCam folder

## Technical Details

- **Language**: Kotlin
- **Minimum SDK**: 24 (Android 7.0)
- **Target SDK**: 33 (Android 13)
- **Architecture**: Single Activity with CameraX
- **Key Libraries**:
  - AndroidX CameraX for camera functionality
  - Material Components for UI
  - ActivityResultContracts for permissions and image picking

## Building the Project

```bash
./gradlew build
```

## Installing on Device

```bash
./gradlew installDebug
```

## Permissions

The app requires the following permissions:
- `CAMERA` - Required for camera functionality
- `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` - Required to select images from gallery
- `WRITE_EXTERNAL_STORAGE` (API ≤ 28) - Required to save captured images

## License

This project is open source and available under the MIT License.