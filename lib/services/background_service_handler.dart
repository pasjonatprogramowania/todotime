import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Dla EventChannel
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:app_usage/app_usage.dart';
import 'package:myapp/overlays/overlay_entry_point.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/utils/database_helper.dart';
import 'package:myapp/models/task_model.dart';

// Klucze SharedPreferences
const String availableTimeKey = 'availableScreenTimeInSeconds';
const String prefKeyBlockTimeHour = 'blockTimeHour';
const String prefKeyBlockTimeMinute = 'blockTimeMinute';
const String prefKeyBlockDays = 'blockDays';
const String prefKeyBlockedApps = 'blockedAppsList';
const String prefKeyBlockedWebsites = 'blockedWebsitesList';
const String prefKeyLastDailyReset = 'lastDailyResetDate';
const String prefKeyDeleteUncompletedTasks = 'deleteUncompletedTasks';

// Zmienne globalne usługi
int availableTimeInSeconds = 3600;
TimeOfDay _serviceBlockTime = const TimeOfDay(hour: 15, minute: 30);
Map<int, bool> _serviceBlockDays = { for (var i = 0; i < 7; i++) i: false };
List<String> _serviceBlockedApps = [];
List<String> _serviceBlockedWebsites = [];
String _lastDailyResetDate = "";
bool _serviceDeleteUncompletedTasks = false;

// Zmienne dla Accessibility Service
const String accessibilityEventChannelName = "com.tasktime.app/accessibility_event";
String? _lastDetectedAppPackageName;
String? _lastDetectedUrl;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  print('Background Service Started: ${DateTime.now()}');

  final prefs = await SharedPreferences.getInstance();
  final dbHelper = DatabaseHelper.instance;

  availableTimeInSeconds = prefs.getInt(availableTimeKey) ?? 3600;
  _serviceBlockTime = TimeOfDay(
    hour: prefs.getInt(prefKeyBlockTimeHour) ?? 15,
    minute: prefs.getInt(prefKeyBlockTimeMinute) ?? 30,
  );
  List<String> daysIndices = prefs.getStringList(prefKeyBlockDays) ?? [];
  _serviceBlockDays = { for (var i = 0; i < 7; i++) i: daysIndices.contains(i.toString()) };
  if (daysIndices.isEmpty && !_serviceBlockDays.values.any((e) => e)) {
      _serviceBlockDays[2] = true;
  }
  _serviceBlockedApps = prefs.getStringList(prefKeyBlockedApps) ?? [];
  _serviceBlockedWebsites = prefs.getStringList(prefKeyBlockedWebsites) ?? [];
  _lastDailyResetDate = prefs.getString(prefKeyLastDailyReset) ?? "";
  _serviceDeleteUncompletedTasks = prefs.getBool(prefKeyDeleteUncompletedTasks) ?? false;
  // print("Service initial settings loaded.");

  const EventChannel accessibilityEventChannel = EventChannel(accessibilityEventChannelName);
  accessibilityEventChannel.receiveBroadcastStream().listen((dynamic event) {
    if (event is Map) {
      final String? type = event['type'] as String?;
      if (type == 'appChangeEvent') {
        _lastDetectedAppPackageName = event['packageName'] as String?;
        if (isBrowserApp(_lastDetectedAppPackageName) == false) { // Jeśli to nie przeglądarka, URL nie jest istotny
             _lastDetectedUrl = null;
        }
        // print("Service ACCESSIBILITY Event: App changed to ${_lastDetectedAppPackageName}");
      } else if (type == 'urlChangeEvent') {
        _lastDetectedUrl = event['url'] as String?;
        _lastDetectedAppPackageName = event['packageName'] as String?;
        // print("Service ACCESSIBILITY Event: URL changed to $_lastDetectedUrl in package $_lastDetectedAppPackageName");
      }
    }
  }, onError: (dynamic error) {
    print('Error receiving accessibility event: ${error.toString()}');
  });

  FlutterOverlayWindow.overlayListener.listen((data) {
    if (data is Map && data['action'] == 'closeOverlayAndOpenApp') {
      closeLockOverlay().then((_) {
        if (service is ServiceInstance) service.invoke('openApp');
      });
    }
    if (data is Map && data['action'] == 'requestInitialDataFromService') {
        FlutterOverlayWindow.shareData({'availableTimeInSeconds': availableTimeInSeconds});
    }
  });

  service.on('stopService').listen((event) { service.stopSelf(); });

  service.on('addRewardTime').listen((event) async {
    if (event != null && event.containsKey('minutes')) {
      final minutesToAdd = event['minutes'] as int;
      availableTimeInSeconds += minutesToAdd * 60;
      await prefs.setInt(availableTimeKey, availableTimeInSeconds);
      if (service is ServiceInstance) service.invoke('update', {"available_time_seconds": availableTimeInSeconds});
    }
  });

  service.on('subtractRewardTime').listen((event) async {
     if (event != null && event.containsKey('minutes')) {
      final minutesToSubtract = event['minutes'] as int;
      availableTimeInSeconds -= minutesToSubtract * 60;
      if (availableTimeInSeconds < 0) availableTimeInSeconds = 0;
      await prefs.setInt(availableTimeKey, availableTimeInSeconds);
      if (service is ServiceInstance) service.invoke('update', {"available_time_seconds": availableTimeInSeconds});
    }
  });

  service.on('requestCurrentState').listen((event) {
    if (service is ServiceInstance) service.invoke('update', {"available_time_seconds": availableTimeInSeconds});
  });

  service.on('reloadSettings').listen((event) async {
    // print("Service: Received reloadSettings event."); // Zmniejszenie ilości logów
    final reloadedPrefs = await SharedPreferences.getInstance();
    _serviceBlockTime = TimeOfDay(hour: reloadedPrefs.getInt(prefKeyBlockTimeHour) ?? 15, minute: reloadedPrefs.getInt(prefKeyBlockTimeMinute) ?? 30);
    List<String> reloadedDaysIndices = reloadedPrefs.getStringList(prefKeyBlockDays) ?? [];
    _serviceBlockDays = { for (var i = 0; i < 7; i++) i: reloadedDaysIndices.contains(i.toString()) };
    if (reloadedDaysIndices.isEmpty && !_serviceBlockDays.values.any((e) => e)) _serviceBlockDays[2] = true;
    _serviceBlockedApps = reloadedPrefs.getStringList(prefKeyBlockedApps) ?? [];
    _serviceBlockedWebsites = reloadedPrefs.getStringList(prefKeyBlockedWebsites) ?? [];
    _serviceDeleteUncompletedTasks = reloadedPrefs.getBool(prefKeyDeleteUncompletedTasks) ?? false;
    // print("Service: Settings reloaded.");
  });

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    final now = DateTime.now();
    final todayDateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    if (_lastDailyResetDate != todayDateString) {
      // print("Service: New day detected ($todayDateString). Performing daily reset.");
      availableTimeInSeconds = 0;
      _lastDailyResetDate = todayDateString;
      await prefs.setInt(availableTimeKey, availableTimeInSeconds);
      await prefs.setString(prefKeyLastDailyReset, _lastDailyResetDate);
      if (_serviceDeleteUncompletedTasks) {
        List<Task> allTasks = await dbHelper.getAllTasks();
        for (Task task in allTasks) {
          if (!task.isCompleted) await dbHelper.deleteTask(task.id);
        }
         print("Service: Deleted uncompleted tasks for the new day.");
      } else {
        // print("Service: Uncompleted tasks from previous day are carried over.");
      }
      if (service is ServiceInstance) {
        service.invoke('update', {"available_time_seconds": availableTimeInSeconds});
        service.invoke('tasksPossiblyChanged');
      }
    }

    bool blockModeActive = checkIfBlockModeActive();
    if (blockModeActive) {
      String? currentAppPkg = await getCurrentAppInForeground();
      String? currentUrl = _lastDetectedUrl;

      bool appIsDirectlyBlocked = currentAppPkg != null && isAppBlocked(currentAppPkg);
      bool urlIsEffectivelyBlocked = currentUrl != null && isUrlBlocked(currentUrl);

      bool shouldBeBlocked = urlIsEffectivelyBlocked || (appIsDirectlyBlocked && !isBrowserApp(currentAppPkg)) || (appIsDirectlyBlocked && isBrowserApp(currentAppPkg) && currentUrl == null);


      if (shouldBeBlocked) {
        // String targetForLogging = urlIsEffectivelyBlocked ? currentUrl! : currentAppPkg!;
        // print("Service: Target '$targetForLogging' should be blocked.");
        if (availableTimeInSeconds > 0) {
          availableTimeInSeconds--;
          if (timer.tick % 10 == 0) await prefs.setInt(availableTimeKey, availableTimeInSeconds);
          if (await FlutterOverlayWindow.isActive()) FlutterOverlayWindow.shareData({'availableTimeInSeconds': availableTimeInSeconds});
        } else {
          if (!await FlutterOverlayWindow.isActive()) {
            // print("Time is up for target. Showing lock overlay.");
            await showLockOverlay(data: {'availableTimeInSeconds': 0});
          } else {
             FlutterOverlayWindow.shareData({'availableTimeInSeconds': 0});
          }
        }
      } else {
        if (await FlutterOverlayWindow.isActive()) {
            // print("Service: Target not blocked or app changed. Closing overlay if active.");
            await closeLockOverlay();
        }
      }

      if (currentAppPkg != null && !isBrowserApp(currentAppPkg)) {
        _lastDetectedUrl = null;
      }

    } else {
      if (await FlutterOverlayWindow.isActive()) {
        // print("Service: Block mode is NOT active. Closing overlay if active.");
        await closeLockOverlay();
      }
    }

    if (service is ServiceInstance) {
        service.invoke('update', {"available_time_seconds": availableTimeInSeconds});
    }
  });
}

bool checkIfBlockModeActive() {
  final now = DateTime.now();
  final currentDayMapKey = now.weekday - 1;
  if (_serviceBlockDays[currentDayMapKey] != true) return false;
  final nowInMinutes = now.hour * 60 + now.minute;
  final blockStartTimeInMinutes = _serviceBlockTime.hour * 60 + _serviceBlockTime.minute;
  return nowInMinutes >= blockStartTimeInMinutes;
}

Future<String?> getCurrentAppInForeground() async {
  if (_lastDetectedAppPackageName != null) {
    return _lastDetectedAppPackageName;
  }
  try {
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(const Duration(seconds: 10));
    List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);
    if (infoList.isNotEmpty) {
      AppUsageInfo lastUsedApp = infoList.first;
      if (lastUsedApp.lastForeground != null) {
         Duration difference = endDate.difference(lastUsedApp.lastForeground!);
         if (difference.inSeconds < 6) return lastUsedApp.packageName;
      }
    }
  } catch (exception) {
    // print('Error getting app usage (fallback): $exception');
  }
  return null;
}

bool isAppBlocked(String appPackageName) {
  return _serviceBlockedApps.contains(appPackageName);
}

bool isUrlBlocked(String? url) {
  if (url == null || url.isEmpty) return false;
  for (String blockedSite in _serviceBlockedWebsites) {
    if (url.toLowerCase().contains(blockedSite.toLowerCase())) {
      // print("Service: URL '$url' is considered blocked by rule '$blockedSite'.");
      return true;
    }
  }
  return false;
}

// Poprawiona funkcja pomocnicza w Dart
bool isBrowserApp(String? packageName) {
    if (packageName == null) return false;
    // Lista pakietów przeglądarek - można ją rozbudować
    final List<String> browserPackages = [
        "com.android.chrome", "org.mozilla.firefox", "com.opera.browser",
        "com.brave.browser", "com.duckduckgo.mobile.android", "com.microsoft.emmx",
        "com.sec.android.app.sbrowser", // Samsung Internet
        "com.UCMobile.intl" // UC Browser
    ];
    return browserPackages.contains(packageName.toLowerCase());
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'tasktime_service_channel',
      initialNotificationTitle: 'TaskTime Aktywny',
      initialNotificationContent: 'Monitorowanie Twojej produktywności.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration( // iOS nie jest celem, ale konfiguracja jest wymagana
      autoStart: true,
      onForeground: onStart,
      // onBackground: onIosBackground, // Jeśli potrzebna specyficzna obsługa tła iOS
    ),
  );
  print("Background service configured.");
}

void stopBackgroundService() {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
}
