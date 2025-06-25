import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class LockScreenOverlayWidget extends StatefulWidget {
  const LockScreenOverlayWidget({super.key});

  @override
  State<LockScreenOverlayWidget> createState() => _LockScreenOverlayWidgetState();
}

class _LockScreenOverlayWidgetState extends State<LockScreenOverlayWidget> {
  // Domyślny stan, jeśli dane nie zostaną przekazane
  Duration _availableTime = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Nasłuchiwanie danych przekazywanych do nakładki
    // To jest przykład, jak można odbierać dane.
    // W naszym przypadku, usługa w tle będzie musiała wysłać te dane.
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (mounted && data is Map) {
        setState(() {
          _availableTime = Duration(seconds: data['availableTimeInSeconds'] ?? 0);
          _isLoading = false;
        });
      }
    });

    // Można też od razu poprosić o dane, jeśli usługa już je wysłała wcześniej
    // np. FlutterOverlayWindow.shareData({'action': 'requestInitialData'});
    // Ale to wymaga, aby główna aplikacja/usługa nasłuchiwała i odpowiadała.
    // Na razie zakładamy, że dane przyjdą przez listener.
    // Dla uproszczenia, jeśli dane nie przyjdą szybko, pokażemy stan domyślny.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isLoading) {
        setState(() { _isLoading = false; });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // Używamy MaterialApp, aby mieć dostęp do kontekstu motywu, nawigacji itp.
    // Nawet jeśli to tylko nakładka.
    // Można by tu zdefiniować bardzo prosty motyw.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith( // Przykładowy ciemny motyw dla nakładki
        scaffoldBackgroundColor: Colors.black.withOpacity(0.85), // Półprzezroczyste tło
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00C853), // Zielony akcent
          onPrimary: Colors.black,
        )
      ),
      home: Scaffold(
        // backgroundColor: Colors.transparent, // Jeśli chcemy, aby tło było całkowicie przezroczyste
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.redAccent[100]),
                const SizedBox(height: 24),
                Text(
                  'Dostęp Zablokowany!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent[100],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aby korzystać z tej aplikacji, wykonaj zadania i zdobądź więcej czasu w TaskTime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
                else
                  Text(
                    'Dostępny czas: ${_formatDuration(_availableTime)}',
                    style: TextStyle(
                      fontSize: 18,
                      color: _availableTime > Duration.zero
                             ? Theme.of(context).colorScheme.primary
                             : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Wróć do TaskTime'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    // Wyślij wiadomość do głównej aplikacji/usługi, że użytkownik chce wrócić
                    // Główna aplikacja powinna wtedy zamknąć nakładkę i otworzyć TaskTime.
                    FlutterOverlayWindow.shareData({'action': 'closeOverlayAndOpenApp'});
                    // Sama nakładka nie powinna próbować otwierać aplikacji bezpośrednio,
                    // ani zamykać siebie, jeśli nie ma pewności, że główna apka to obsłuży.
                    // FlutterOverlayWindow.closeOverlay(); // To można wywołać z głównej aplikacji
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
