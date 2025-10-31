package com.example.vrcam

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.view.View
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.example.vrcam.databinding.ActivityMainBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityMainBinding
    private var imageCapture: ImageCapture? = null
    private lateinit var cameraExecutor: ExecutorService
    private var overlayImageUri: Uri? = null
    
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val cameraGranted = permissions[Manifest.permission.CAMERA] ?: false
        
        if (cameraGranted) {
            startCamera()
        } else {
            Toast.makeText(
                this,
                getString(R.string.permission_denied),
                Toast.LENGTH_SHORT
            ).show()
            finish()
        }
    }
    
    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            overlayImageUri = it
            binding.overlayImageView.setImageURI(it)
            binding.overlayImageView.visibility = View.VISIBLE
            binding.clearOverlayButton.visibility = View.VISIBLE
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        cameraExecutor = Executors.newSingleThreadExecutor()
        
        // Request camera permissions
        if (allPermissionsGranted()) {
            startCamera()
        } else {
            requestPermissions()
        }
        
        // Setup button click listeners
        binding.selectImageButton.setOnClickListener {
            pickImageLauncher.launch("image/*")
        }
        
        binding.captureButton.setOnClickListener {
            capturePhoto()
        }
        
        binding.clearOverlayButton.setOnClickListener {
            clearOverlay()
        }
    }
    
    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun requestPermissions() {
        requestPermissionLauncher.launch(REQUIRED_PERMISSIONS)
    }
    
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        
        cameraProviderFuture.addListener({
            val cameraProvider: ProcessCameraProvider = cameraProviderFuture.get()
            
            // Preview
            val preview = Preview.Builder()
                .build()
                .also {
                    it.setSurfaceProvider(binding.previewView.surfaceProvider)
                }
            
            // Image capture
            imageCapture = ImageCapture.Builder()
                .build()
            
            // Select back camera as default
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            
            try {
                // Unbind use cases before rebinding
                cameraProvider.unbindAll()
                
                // Bind use cases to camera
                cameraProvider.bindToLifecycle(
                    this, cameraSelector, preview, imageCapture
                )
                
            } catch (exc: Exception) {
                Toast.makeText(
                    this,
                    "Failed to start camera: ${exc.message}",
                    Toast.LENGTH_SHORT
                ).show()
            }
            
        }, ContextCompat.getMainExecutor(this))
    }
    
    private fun capturePhoto() {
        val imageCapture = imageCapture ?: return
        
        // Create time stamped name
        val name = SimpleDateFormat(FILENAME_FORMAT, Locale.US)
            .format(System.currentTimeMillis())
        
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/VRCam")
        }
        
        val outputOptions = ImageCapture.OutputFileOptions
            .Builder(
                contentResolver,
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                contentValues
            )
            .build()
        
        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onError(exc: ImageCaptureException) {
                    Toast.makeText(
                        baseContext,
                        "${getString(R.string.error_saving)}: ${exc.message}",
                        Toast.LENGTH_SHORT
                    ).show()
                }
                
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    // If there's an overlay, we need to composite the images
                    if (overlayImageUri != null && binding.overlayImageView.visibility == View.VISIBLE) {
                        output.savedUri?.let { savedUri ->
                            lifecycleScope.launch {
                                try {
                                    compositeImages(savedUri)
                                } catch (e: Exception) {
                                    withContext(Dispatchers.Main) {
                                        Toast.makeText(
                                            baseContext,
                                            "${getString(R.string.error_saving)}: ${e.message}",
                                            Toast.LENGTH_SHORT
                                        ).show()
                                    }
                                }
                            }
                        }
                    } else {
                        val msg = "${getString(R.string.image_saved)}: ${output.savedUri}"
                        Toast.makeText(baseContext, msg, Toast.LENGTH_SHORT).show()
                    }
                }
            }
        )
    }
    
    private suspend fun compositeImages(cameraImageUri: Uri) = withContext(Dispatchers.IO) {
        try {
            // Load the camera image using modern API
            val cameraImage = loadBitmap(cameraImageUri)
            
            // Load the overlay image
            val overlayImage = loadBitmap(overlayImageUri!!)
            
            // Create a new bitmap with the same size as camera image
            val resultBitmap = Bitmap.createBitmap(
                cameraImage.width,
                cameraImage.height,
                cameraImage.config
            )
            
            // Draw both images on canvas
            val canvas = Canvas(resultBitmap)
            canvas.drawBitmap(cameraImage, 0f, 0f, null)
            
            // Scale and center the overlay image
            val scaledOverlay = Bitmap.createScaledBitmap(
                overlayImage,
                cameraImage.width,
                cameraImage.height,
                true
            )
            
            // Apply transparency to overlay
            val paint = android.graphics.Paint().apply {
                alpha = (OVERLAY_ALPHA * 255).toInt()
            }
            canvas.drawBitmap(scaledOverlay, 0f, 0f, paint)
            
            // Save the composited image
            contentResolver.openOutputStream(cameraImageUri)?.use { outputStream ->
                resultBitmap.compress(Bitmap.CompressFormat.JPEG, 95, outputStream)
            }
            
            // Clean up
            cameraImage.recycle()
            overlayImage.recycle()
            scaledOverlay.recycle()
            resultBitmap.recycle()
            
            withContext(Dispatchers.Main) {
                Toast.makeText(
                    baseContext,
                    "${getString(R.string.image_saved)}: $cameraImageUri",
                    Toast.LENGTH_SHORT
                ).show()
            }
            
        } catch (e: IOException) {
            withContext(Dispatchers.Main) {
                Toast.makeText(
                    baseContext,
                    "${getString(R.string.error_saving)}: ${e.message}",
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }
    
    private fun loadBitmap(uri: Uri): Bitmap {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(contentResolver, uri)
            ImageDecoder.decodeBitmap(source)
        } else {
            @Suppress("DEPRECATION")
            MediaStore.Images.Media.getBitmap(contentResolver, uri)
        }
    }
    
    private fun clearOverlay() {
        binding.overlayImageView.setImageURI(null)
        binding.overlayImageView.visibility = View.GONE
        binding.clearOverlayButton.visibility = View.GONE
        overlayImageUri = null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
    
    companion object {
        private const val FILENAME_FORMAT = "yyyy-MM-dd-HH-mm-ss-SSS"
        private const val OVERLAY_ALPHA = 0.7f
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }
}
