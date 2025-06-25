package com.example.myapp

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.annotation.NonNull
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.view.accessibility.AccessibilityManager
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache // Import dla FlutterEngineCache

class MainActivity : FlutterActivity() {

    private val ACCESSIBILITY_CHANNEL = "com.tasktime.app/accessibility"
    private val FLUTTER_ENGINE_ID = "my_tasktime_engine_id" // ID dla cachowanego silnika

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the FlutterEngine with a specific ID.
        FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine)

        // Tworzenie kanału powiadomień
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "tasktime_service_channel"
            val channelName = "TaskTime Background Service"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = "Channel for TaskTime background service notifications"
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }

        // MethodChannel dla Usługi Dostępności
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    val serviceEnabled = isOurAccessibilityServiceEnabled()
                    result.success(serviceEnabled)
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR_OPENING_SETTINGS", "Could not open accessibility settings", e.toString())
                    }
                }
                else -> result.notImplemented()
            }
        }

        // TODO: Obsługa 'openApp' invoke z FlutterBackgroundService
    }

    private fun isOurAccessibilityServiceEnabled(): Boolean {
        val expectedServiceName = "$packageName/.MyAccessibilityService"
        Log.d("MainActivity", "Checking for Accessibility Service: $expectedServiceName")

        val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = accessibilityManager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)

        for (serviceInfo in enabledServices) {
            Log.d("MainActivity", "Found enabled service: ${serviceInfo.id}")
            if (TextUtils.equals(serviceInfo.id, expectedServiceName)) {
                Log.d("MainActivity", "Our Accessibility Service (${serviceInfo.id}) is ENABLED.")
                return true
            }
        }
        Log.d("MainActivity", "Our Accessibility Service ($expectedServiceName) is DISABLED.")
        return false
    }

    override fun onDestroy() {
        // Usuń silnik z cache, gdy aktywność jest niszczona
        FlutterEngineCache.getInstance().remove(FLUTTER_ENGINE_ID)
        super.onDestroy()
    }
}
