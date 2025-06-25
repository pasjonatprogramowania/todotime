import 'dart:ui'; // Dla DartPluginRegistrant
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:myapp/overlays/lock_screen_overlay.dart'; // Import naszego widgetu

// Ta adnotacja jest kluczowa dla pluginu flutter_overlay_window
@pragma("vm:entry-point")
void overlayMain() {
  // DartPluginRegistrant.ensureInitialized() jest potrzebne, jeśli widget nakładki
  // używa pluginów, które wymagają inicjalizacji (np. SharedPreferences w nakładce).
  // W naszym prostym przypadku może nie być konieczne, ale bezpiecznie jest dodać.
  // WidgetsFlutterBinding.ensureInitialized(); // To też może być potrzebne
  // DartPluginRegistrant.ensureInitialized(); // Jeśli używasz pluginów w overlay

  debugPrint("Overlay entry point 'overlayMain' called.");

  // Uruchomienie aplikacji Flutter dla nakładki
  // Ważne: Nakładka działa w osobnym izolacie Fluttera.
  runApp(const LockScreenOverlayApp());
}

// Możemy opakować nasz widget nakładki w prostą aplikację,
// aby zapewnić mu MaterialApp lub inny potrzebny kontekst.
class LockScreenOverlayApp extends StatelessWidget {
  const LockScreenOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    // LockScreenOverlayWidget już ma MaterialApp w sobie, więc tu może być prosto.
    // Jeśli LockScreenOverlayWidget nie miałby MaterialApp, trzeba by go dodać tutaj.
    return const LockScreenOverlayWidget();
  }
}

// Funkcja pomocnicza do pokazywania nakładki z opcjonalnymi danymi
// Tę funkcję będziemy wywoływać z naszej usługi w tle.
Future<void> showLockOverlay({Map<String, dynamic>? data}) async {
  if (await FlutterOverlayWindow.isActive()) {
    print("Overlay is already active. Sharing data if provided.");
    if (data != null) {
      await FlutterOverlayWindow.shareData(data);
    }
    return;
  }
  await FlutterOverlayWindow.showOverlay(
    height: FlutterOverlayWindow.matchParent, // Rozciągnij na cały ekran
    width: FlutterOverlayWindow.matchParent,
    alignment: OverlayAlignment.center,
    flag: OverlayFlag.focusPointer | OverlayFlag. όχιTouchable, // focusPointer pozwala na interakcję, notTouchable sprawia że tło jest nietykalne
    // overlayMessage: "TaskTime Lock Screen", // Wiadomość dla systemu
    // enableDrag: false, // Czy można przeciągać nakładkę
  );
  print("Requested to show overlay.");
  if (data != null) {
    // Krótkie opóźnienie, aby dać nakładce czas na zainicjowanie nasłuchiwania
    await Future.delayed(const Duration(milliseconds: 200));
    await FlutterOverlayWindow.shareData(data);
    print("Shared data to overlay: $data");
  }
}

// Funkcja pomocnicza do zamykania nakładki
Future<void> closeLockOverlay() async {
  if (await FlutterOverlayWindow.isActive()) {
    await FlutterOverlayWindow.closeOverlay();
    print("Requested to close overlay.");
  } else {
    print("Overlay is not active, no need to close.");
  }
}
