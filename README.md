# VRCam - Virtual Camera Module for Kotlin/Android

A virtual camera Android application that allows users to select images from their gallery and overlay them on the camera preview to create composite photos. This README provides a comprehensive installation and usage guide, including example integration code, camera permissions setup, and guidance for using the library with third-party verification services like Sumsub.

## Features

- **Camera Preview**: Real-time camera preview using CameraX
- **Gallery Integration**: Select images from device gallery
- **Image Overlay**: Display selected images over the camera preview with adjustable transparency
- **Composite Capture**: Capture photos with the overlay merged into the final image
- **Easy Controls**: Simple UI with buttons to select, capture, and clear overlays

## Installation

### Option 1: Add as Dependency (Kotlin DSL)

Add the following to your `build.gradle.kts` file:

```kotlin
dependencies {
    implementation("com.github.berndmarcel860-byte:vrcam:1.0.0")
}
```

### Option 2: Add as Dependency (Groovy DSL)

Add the following to your `build.gradle` file:

```groovy
dependencies {
    implementation 'com.github.berndmarcel860-byte:vrcam:1.0.0'
}
```

### Repository Configuration

If using JitPack, add the repository to your root `build.gradle` or `settings.gradle`:

**Kotlin DSL:**
```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

**Groovy DSL:**
```groovy
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }
    }
}
```

## Requirements

- Android 7.0 (API level 24) or higher
- Camera permission
- Storage read permission (for selecting gallery images)

## Example Integration Code

### Basic Camera Setup

Here's a minimal example of integrating VRCam into your activity:

```kotlin
import android.Manifest
import android.net.Uri
import android.os.Bundle
import android.view.View
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.example.vrcam.databinding.ActivityMainBinding
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityMainBinding
    private var imageCapture: ImageCapture? = null
    private lateinit var cameraExecutor: ExecutorService
    private var overlayImageUri: Uri? = null
    
    // Permission launcher
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        if (permissions[Manifest.permission.CAMERA] == true) {
            startCamera()
        }
    }
    
    // Image picker launcher
    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            overlayImageUri = it
            binding.overlayImageView.setImageURI(it)
            binding.overlayImageView.visibility = View.VISIBLE
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        cameraExecutor = Executors.newSingleThreadExecutor()
        
        // Setup buttons
        binding.selectImageButton.setOnClickListener { 
            pickImageLauncher.launch("image/*") 
        }
        
        binding.captureButton.setOnClickListener { 
            capturePhoto() 
        }
        
        // Request permissions
        requestPermissionLauncher.launch(arrayOf(Manifest.permission.CAMERA))
    }
    
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()
            
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(binding.previewView.surfaceProvider)
            }
            
            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()
            
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            
            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    this, cameraSelector, preview, imageCapture
                )
            } catch (e: Exception) {
                // Handle error
            }
        }, ContextCompat.getMainExecutor(this))
    }
    
    private fun capturePhoto() {
        val imageCapture = imageCapture ?: return
        
        // Standard capture implementation
        // Add your composite capture logic here if overlay is present
    }
    
    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
}
```

### Layout XML Example

Create `activity_main.xml` with camera preview and overlay:

```xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.constraintlayout.widget.ConstraintLayout 
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <!-- Camera Preview -->
    <androidx.camera.view.PreviewView
        android:id="@+id/previewView"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        app:layout_constraintTop_toTopOf="parent"
        app:layout_constraintBottom_toTopOf="@id/controlsLayout"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent" />

    <!-- Overlay Image -->
    <ImageView
        android:id="@+id/overlayImageView"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:alpha="0.7"
        android:scaleType="fitCenter"
        android:visibility="gone"
        app:layout_constraintTop_toTopOf="@id/previewView"
        app:layout_constraintBottom_toBottomOf="@id/previewView"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent" />

    <!-- Control Buttons -->
    <LinearLayout
        android:id="@+id/controlsLayout"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:padding="16dp"
        app:layout_constraintBottom_toBottomOf="parent">
        
        <Button
            android:id="@+id/selectImageButton"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="SELECT IMAGE" />
        
        <Button
            android:id="@+id/captureButton"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="CAPTURE" />
    </LinearLayout>

</androidx.constraintlayout.widget.ConstraintLayout>
```

## Usage with Third-Party Verification Services

### Integration with Sumsub and Similar Services

VRCam can be used to capture photos for identity verification services like Sumsub. Here's how to integrate it:

#### 1. Capture Photo for Verification

```kotlin
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.ByteArrayOutputStream
import java.io.File

class VerificationHelper {
    
    /**
     * Capture and prepare photo for verification service
     */
    fun captureVerificationPhoto(
        imageCapture: ImageCapture,
        onPhotoCaptured: (File) -> Unit,
        onError: (String) -> Unit
    ) {
        val photoFile = File(
            context.getExternalFilesDir(null),
            "verification_${System.currentTimeMillis()}.jpg"
        )
        
        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()
        
        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    onPhotoCaptured(photoFile)
                }
                
                override fun onError(exception: ImageCaptureException) {
                    onError(exception.message ?: "Capture failed")
                }
            }
        )
    }
    
    /**
     * Convert captured image to format required by verification services
     */
    fun prepareImageForUpload(file: File): ByteArray {
        val bitmap = BitmapFactory.decodeFile(file.absolutePath)
        val outputStream = ByteArrayOutputStream()
        
        // Compress to JPEG with 90% quality (adjust as needed)
        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)
        
        return outputStream.toByteArray()
    }
}
```

#### 2. Send to Sumsub SDK

```kotlin
import com.sumsub.sns.core.SNSMobileSDK
import com.sumsub.sns.core.data.listener.SNSActionResultHandler

class SumsubIntegration {
    
    fun uploadVerificationPhoto(photoFile: File, applicantId: String) {
        // Initialize Sumsub SDK
        val snsMobileSDK = SNSMobileSDK.Builder(context)
            .withAccessToken("YOUR_ACCESS_TOKEN")
            .withLocale("en")
            .build()
        
        // Upload the captured photo
        val imageBytes = prepareImageForUpload(photoFile)
        
        // Use Sumsub's document upload API
        // This is a simplified example - refer to Sumsub docs for actual implementation
        snsMobileSDK.uploadDocument(
            applicantId = applicantId,
            documentType = "SELFIE",
            imageData = imageBytes,
            callback = object : SNSActionResultHandler {
                override fun onSuccess() {
                    // Photo uploaded successfully
                }
                
                override fun onError(error: String) {
                    // Handle upload error
                }
            }
        )
    }
}
```

#### 3. Best Practices for Verification Photos

When capturing photos for verification services:

```kotlin
// 1. Ensure good lighting and image quality
val imageCapture = ImageCapture.Builder()
    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
    .setTargetRotation(Surface.ROTATION_0)
    .build()

// 2. Validate image before upload
fun validateVerificationImage(file: File): Boolean {
    val bitmap = BitmapFactory.decodeFile(file.absolutePath)
    
    return when {
        bitmap == null -> false
        bitmap.width < 600 || bitmap.height < 600 -> {
            // Image too small
            false
        }
        file.length() > 10 * 1024 * 1024 -> {
            // File too large (> 10MB)
            false
        }
        else -> true
    }
}

// 3. Provide user guidance
fun showCameraGuidance() {
    // Show overlay guide for proper face positioning
    // Display instructions like:
    // - "Center your face in the frame"
    // - "Ensure good lighting"
    // - "Remove glasses if required"
}
```

#### 4. Handle Verification Flow

```kotlin
class VerificationFlowActivity : AppCompatActivity() {
    
    private enum class VerificationStep {
        SELFIE,
        ID_FRONT,
        ID_BACK,
        COMPLETE
    }
    
    private var currentStep = VerificationStep.SELFIE
    
    private fun onPhotoCaptured(photoFile: File) {
        // Validate image
        if (!validateVerificationImage(photoFile)) {
            showError("Please retake the photo with better quality")
            return
        }
        
        // Upload to verification service
        when (currentStep) {
            VerificationStep.SELFIE -> {
                uploadToVerificationService(photoFile, "selfie")
                currentStep = VerificationStep.ID_FRONT
                showInstructions("Now capture the front of your ID")
            }
            VerificationStep.ID_FRONT -> {
                uploadToVerificationService(photoFile, "id_front")
                currentStep = VerificationStep.ID_BACK
                showInstructions("Now capture the back of your ID")
            }
            VerificationStep.ID_BACK -> {
                uploadToVerificationService(photoFile, "id_back")
                currentStep = VerificationStep.COMPLETE
                showComplete()
            }
            VerificationStep.COMPLETE -> {
                // All photos captured
            }
        }
    }
    
    private fun uploadToVerificationService(file: File, documentType: String) {
        lifecycleScope.launch {
            try {
                // Upload logic here
                val imageBytes = prepareImageForUpload(file)
                // Send to your backend or directly to verification service
            } catch (e: Exception) {
                // Handle error
            }
        }
    }
}
```

### Additional Verification Service Examples

VRCam is compatible with various verification services:

- **Sumsub**: Identity verification and KYC
- **Onfido**: Identity verification
- **Jumio**: ID verification and authentication
- **Veriff**: Identity verification
- **Persona**: Identity verification platform

For each service, follow their specific SDK documentation for photo upload requirements, but the camera capture flow remains consistent.

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

## Camera Permissions and AndroidManifest Setup

### Required Permissions

Add the following permissions to your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Camera hardware feature -->
    <uses-feature android:name="android.hardware.camera" android:required="true" />
    
    <!-- Camera permission -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <!-- Gallery/Storage permissions -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    
    <!-- Legacy storage permission for older devices -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                     android:maxSdkVersion="28" />

    <application>
        <!-- Your activities here -->
    </application>

</manifest>
```

### FileProvider Configuration

If you need to share captured images, add FileProvider to your AndroidManifest:

```xml
<application>
    <!-- Other components -->
    
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
```

Create `res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="." />
    <cache-path name="cache" path="." />
</paths>
```

### Runtime Permission Handling

Request camera permissions at runtime using ActivityResultContracts:

```kotlin
class YourActivity : AppCompatActivity() {
    
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val cameraGranted = permissions[Manifest.permission.CAMERA] ?: false
        
        if (cameraGranted) {
            // Start camera
            startCamera()
        } else {
            // Handle permission denial
            Toast.makeText(this, "Camera permission required", Toast.LENGTH_SHORT).show()
        }
    }
    
    private fun checkAndRequestPermissions() {
        val permissionsToRequest = arrayOf(Manifest.permission.CAMERA)
        
        if (permissionsToRequest.any { 
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED 
        }) {
            requestPermissionLauncher.launch(permissionsToRequest)
        } else {
            startCamera()
        }
    }
}
```

## Permissions Summary

The app requires the following permissions:
- `CAMERA` - Required for camera functionality
- `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` - Required to select images from gallery
- `WRITE_EXTERNAL_STORAGE` (API ≤ 28) - Required to save captured images

## License

This project is open source and available under the MIT License.