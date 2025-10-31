# VRCam - Virtual Camera Library

VRCam is a camera module for Kotlin/Android that enables virtual camera functionality, allowing developers to select images from the device gallery and overlay them on the camera preview to create composite photos. This README provides installation instructions, usage examples, and guidance for integrating VRCam into your Android applications, including usage with third-party verification services like Sumsub.

## Features

- **Camera Preview**: Real-time camera preview using CameraX
- **Gallery Integration**: Select images from device gallery
- **Image Overlay**: Display selected images over the camera preview with adjustable transparency
- **Composite Capture**: Capture photos with the overlay merged into the final image
- **Easy Controls**: Simple UI with buttons to select, capture, and clear overlays

## Installation

You can integrate VRCam into your Android project using either Kotlin DSL or Groovy DSL syntax.

> **⚠️ Important**: The artifact coordinates below use JitPack distribution. The maintainer should update the version number to match the actual release version available in the repository.

### Option A: Kotlin DSL (build.gradle.kts)

Add the following dependency to your app module's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.github.berndmarcel860-byte:vrcam:1.0.0")
}
```

And add the repository to your `settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

### Option B: Groovy DSL (build.gradle)

Add the following dependency to your app module's `build.gradle`:

```groovy
dependencies {
    implementation 'com.github.berndmarcel860-byte:vrcam:1.0.0'
}
```

And add the repository to your `settings.gradle`:

```groovy
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }
    }
}
```

> **Note**: Replace `1.0.0` with the latest version available in the repository releases.

## Requirements

- Android 7.0 (API level 24) or higher
- Camera permission
- Storage read permission (for selecting gallery images)

## Camera Permissions and AndroidManifest Configuration

To use VRCam in your application, you must declare the required permissions and features in your `AndroidManifest.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Declare camera hardware feature as required -->
    <uses-feature android:name="android.hardware.camera" android:required="true" />
    
    <!-- Camera permission - required for camera access -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <!-- Storage permissions - required for gallery image selection -->
    <!-- READ_EXTERNAL_STORAGE for Android 12L and below -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="32" />
    <!-- READ_MEDIA_IMAGES for Android 13 and above -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    
    <!-- Write permission for saving captured images (legacy devices) -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                     android:maxSdkVersion="28" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/AppTheme">
        
        <!-- Your activities here -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        
        <!-- FileProvider for secure file sharing (required for saving images) -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
        
    </application>

</manifest>
```

### FileProvider Configuration

Create a file at `res/xml/file_paths.xml` to configure FileProvider paths:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-path name="external_files" path="." />
    <external-files-path name="external_files" path="." />
</paths>
```

### Runtime Permission Handling

VRCam requires runtime permissions for Android 6.0+ (API 23+). You must request these permissions before using the camera:

```kotlin
private val cameraPermissionLauncher = registerForActivityResult(
    ActivityResultContracts.RequestPermission()
) { isGranted ->
    if (isGranted) {
        // Permission granted, initialize camera
        startCamera()
    } else {
        // Permission denied, show explanation to user
        Toast.makeText(this, "Camera permission is required", Toast.LENGTH_SHORT).show()
    }
}

// Request permission
cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
```

## Example Integration Code

Here's a complete example showing how to integrate VRCam into your Android activity:

```kotlin
import android.Manifest
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.yourapp.databinding.ActivityMainBinding
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityMainBinding
    private var imageCapture: ImageCapture? = null
    private lateinit var cameraExecutor: ExecutorService
    private var overlayImageUri: Uri? = null
    
    // Camera permission launcher
    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            startCamera()
        } else {
            Toast.makeText(this, "Camera permission is required", Toast.LENGTH_SHORT).show()
        }
    }
    
    // Image picker launcher
    private val imagePickerLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            overlayImageUri = it
            binding.overlayImage.setImageURI(it)
            binding.overlayImage.visibility = View.VISIBLE
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        cameraExecutor = Executors.newSingleThreadExecutor()
        
        // Request camera permission
        cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        
        // Set up button click listeners
        binding.selectImageButton.setOnClickListener {
            imagePickerLauncher.launch("image/*")
        }
        
        binding.captureButton.setOnClickListener {
            takePhoto()
        }
        
        binding.clearOverlayButton.setOnClickListener {
            clearOverlay()
        }
    }
    
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()
            
            // Preview use case
            val preview = Preview.Builder()
                .build()
                .also {
                    it.setSurfaceProvider(binding.previewView.surfaceProvider)
                }
            
            // ImageCapture use case
            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()
            
            // Select back camera
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            
            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    this, cameraSelector, preview, imageCapture
                )
            } catch (exc: Exception) {
                Toast.makeText(this, "Failed to start camera", Toast.LENGTH_SHORT).show()
            }
        }, ContextCompat.getMainExecutor(this))
    }
    
    private fun takePhoto() {
        val imageCapture = imageCapture ?: return
        
        // Create output file
        val photoFile = File(
            getExternalFilesDir(null),
            "vrcam_${System.currentTimeMillis()}.jpg"
        )
        
        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()
        
        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    Toast.makeText(this@MainActivity, "Photo saved", Toast.LENGTH_SHORT).show()
                }
                
                override fun onError(exc: ImageCaptureException) {
                    Toast.makeText(this@MainActivity, "Failed to save photo", Toast.LENGTH_SHORT).show()
                }
            }
        )
    }
    
    private fun clearOverlay() {
        binding.overlayImage.setImageURI(null)
        binding.overlayImage.visibility = View.GONE
        overlayImageUri = null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
}
```

## Usage with Third-Party Verification Services

VRCam is designed to work seamlessly with identity verification services like **Sumsub**, **Onfido**, **Jumio**, and others. These services often require capturing photos of identity documents or user selfies for KYC (Know Your Customer) compliance.

### Integration with Sumsub

When integrating VRCam with Sumsub's identity verification flow:

1. **Capture Identity Documents**: Use VRCam to capture high-quality photos of passports, driver's licenses, or other ID documents.

2. **Selfie Capture**: Use VRCam for liveness detection by capturing user selfies with or without overlays.

3. **Image Preparation**: After capturing with VRCam, convert the image to the format required by Sumsub:

```kotlin
// Capture photo with VRCam
private fun captureForVerification(callback: (File) -> Unit) {
    val imageCapture = imageCapture ?: return
    
    val photoFile = File(
        cacheDir,
        "verification_${System.currentTimeMillis()}.jpg"
    )
    
    val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()
    
    imageCapture.takePicture(
        outputOptions,
        ContextCompat.getMainExecutor(this),
        object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                // Pass the captured image to Sumsub SDK
                callback(photoFile)
            }
            
            override fun onError(exc: ImageCaptureException) {
                // Handle error
            }
        }
    )
}

// Send to Sumsub
private fun sendToSumsub(imageFile: File) {
    // Example: Integrate with Sumsub SDK
    // NOTE: This is a simplified example. Actual Sumsub SDK integration
    // varies by version and implementation approach.
    // Always refer to the official Sumsub documentation for the most
    // up-to-date integration instructions:
    // https://developers.sumsub.com/
    
    // Typical flow:
    // 1. Initialize the Sumsub SDK with your access token
    // 2. Create a verification session
    // 3. Upload the captured image as part of the verification process
    // 4. Handle the verification result callback
}
```

4. **Quality Considerations**:
   - Ensure adequate lighting for document captures
   - Use the camera's auto-focus feature for sharp images
   - Verify image resolution meets verification service requirements (typically 1280x720 or higher)
   - Consider disabling overlay features during actual verification captures

5. **Privacy and Security**:
   - Store verification images securely in app's private storage
   - Clear cached verification images after successful upload
   - Implement proper data retention policies
   - Follow GDPR/CCPA guidelines for handling biometric data

### General Verification Service Integration

For other verification services, the general pattern is:

1. Configure VRCam to capture images at required resolution
2. Capture the image using VRCam's `takePhoto()` method
3. Process/compress if needed based on service requirements
4. Upload to the verification service via their SDK or API
5. Clean up temporary files after successful upload

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

## Building and Installing APK

For comprehensive instructions on building an Android APK from source and installing it on a device, see the [Android Installation Guide](docs/INSTALL_ANDROID.md).

### Quick Start

**Build APK:**
```bash
./gradlew assembleDebug
```

**Install on device:**
```bash
# Option 1: Use helper script (handles device selection automatically)
./scripts/android/install_apk.sh

# Option 2: Manual installation
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

**Find built APKs:**
```bash
./scripts/android/find_apk.sh
```

For detailed instructions including troubleshooting, prerequisites, and support for multiple project types, see [docs/INSTALL_ANDROID.md](docs/INSTALL_ANDROID.md).

## License

This project is open source and available under the MIT License.