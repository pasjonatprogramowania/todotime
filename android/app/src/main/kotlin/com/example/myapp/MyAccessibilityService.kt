package com.example.myapp

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo // Potrzebny do pracy z węzłami
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MyAccessibilityService : AccessibilityService(), EventChannel.StreamHandler {

    private val TAG = "MyAccessibilityService"
    private var eventSink: EventChannel.EventSink? = null
    private val ACCESSIBILITY_EVENT_CHANNEL = "com.tasktime.app/accessibility_event"
    private val FLUTTER_ENGINE_ID = "my_tasktime_engine_id"

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service Connected")

        val flutterEngine = FlutterEngineCache.getInstance().get(FLUTTER_ENGINE_ID)
        if (flutterEngine != null && flutterEngine.dartExecutor.isExecutingDart) {
            try {
                EventChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_EVENT_CHANNEL).setStreamHandler(this)
                Log.d(TAG, "EventChannel for AccessibilityService set up successfully.")
            } catch (e: Exception) {
                Log.e(TAG, "Error setting up EventChannel: ${e.message}")
            }
        } else {
            if (flutterEngine == null) {
                 Log.e(TAG, "FlutterEngine not found in cache (ID: $FLUTTER_ENGINE_ID). EventChannel not set up.")
            } else {
                 Log.e(TAG, "FlutterEngine found but DartExecutor not executing. EventChannel not set up.")
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val packageName = event.packageName?.toString()
                val className = event.className?.toString()

                if (packageName != null) {
                    val eventData = HashMap<String, String?>()
                    eventData["type"] = "appChangeEvent"
                    eventData["packageName"] = packageName
                    eventData["className"] = className
                    sendEventToFlutter(eventData)

                    if (isBrowserApp(packageName)) {
                        val rootNode = rootInActiveWindow // Pobierz rootNode dla aktywnego okna
                        if (rootNode != null) {
                            findAndSendUrl(rootNode, packageName)
                            rootNode.recycle() // Ważne, aby zwolnić zasoby
                        }
                    }
                }
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                val packageName = event.packageName?.toString()
                if (packageName != null && isBrowserApp(packageName)) {
                    val sourceNode = event.source // event.source może być null lub nie być rootem
                    val rootNode = rootInActiveWindow // Lepiej wziąć cały root dla pewności
                    if (rootNode != null) {
                        // Log.d(TAG, "Content changed in browser: $packageName, trying to find URL")
                        findAndSendUrl(rootNode, packageName)
                        rootNode.recycle()
                    }
                    sourceNode?.recycle() // Jeśli sourceNode nie był nullem, też go zwolnij
                }
            }
        }
    }

    private fun sendEventToFlutter(data: HashMap<String, String?>) {
        try {
            eventSink?.success(data)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending event to Flutter: ${e.message}")
        }
    }

    private fun isBrowserApp(packageName: String?): Boolean {
        val browserPackages = listOf(
            "com.android.chrome", "org.mozilla.firefox", "com.opera.browser",
            "com.brave.browser", "com.duckduckgo.mobile.android", "com.microsoft.emmx",
            "com.android.browser" // Domyślna przeglądarka AOSP
        )
        return packageName != null && browserPackages.contains(packageName.toLowerCase())
    }

    private var lastSentUrl: String? = null

    private fun findAndSendUrl(nodeInfo: AccessibilityNodeInfo, packageName: String) {
        val url = extractUrlFromNodeRecursive(nodeInfo, 0) // Dodajemy głębokość rekursji
        if (url != null && url != lastSentUrl) {
            Log.i(TAG, "URL detected in $packageName: $url")
            val eventData = HashMap<String, String?>()
            eventData["type"] = "urlChangeEvent"
            eventData["packageName"] = packageName
            eventData["url"] = url
            sendEventToFlutter(eventData)
            lastSentUrl = url
        }
    }

    private fun extractUrlFromNodeRecursive(nodeInfo: AccessibilityNodeInfo?, depth: Int): String? {
        if (nodeInfo == null || depth > 15) return null // Ograniczenie głębokości rekursji

        // Log.d(TAG, "Node: ${nodeInfo.className}, Text: ${nodeInfo.text}, Desc: ${nodeInfo.contentDescription}, ID: ${nodeInfo.viewIdResourceName}")

        // Próba 1: Sprawdzenie tekstu węzła, czy pasuje do wzorca URL
        if (nodeInfo.text != null) {
            val text = nodeInfo.text.toString().trim()
            // Bardziej liberalny wzorzec URL, który łapie też same domeny
            val urlPatternSimple = Regex("^(https?://)?[\\w.-]+\\.[a-zA-Z]{2,}(/\\S*)?\$")
            if (text.isNotEmpty() && urlPatternSimple.matches(text)) {
                 // Dodatkowe warunki, aby odfiltrować niechciane teksty, np. długość, czy to jest EditText
                 if (nodeInfo.className == "android.widget.EditText" || nodeInfo.isEditable) {
                    // Log.d(TAG, "URL found in EditText: $text (ID: ${nodeInfo.viewIdResourceName})")
                    return text
                 }
                 // Jeśli nie jest to EditText, ale tekst wygląda jak URL i jest w miarę krótki (np. tytuł strony)
                 // To może być zbyt agresywne, trzeba by testować
                 // if (text.length < 100) return text;
            }
        }
        // Próba 2: Content Description (czasem tu jest URL)
        if (nodeInfo.contentDescription != null) {
            val desc = nodeInfo.contentDescription.toString().trim()
            val urlPatternSimple = Regex("^(https?://)?[\\w.-]+\\.[a-zA-Z]{2,}(/\\S*)?\$")
             if (desc.isNotEmpty() && urlPatternSimple.matches(desc)) {
                // Log.d(TAG, "URL found in ContentDescription: $desc")
                return desc
            }
        }

        for (i in 0 until nodeInfo.childCount) {
            val childNode = nodeInfo.getChild(i)
            val childUrl = extractUrlFromNodeRecursive(childNode, depth + 1)
            childNode?.recycle() // Zwolnij węzeł dziecka po przetworzeniu
            if (childUrl != null) return childUrl
        }
        return null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "EventChannel onListen called. EventSink is now set.")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "EventChannel onCancel called. EventSink is now null.")
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
        eventSink = null;
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Accessibility Service Destroyed")
        eventSink?.endOfStream()
        eventSink = null
    }
}
