import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:device_apps/device_apps.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/theme_provider.dart';

// Klucze dla SharedPreferences (prefKeyThemeMode jest też w ThemeProvider)
const String prefKeyBlockTimeHour = 'blockTimeHour';
const String prefKeyBlockTimeMinute = 'blockTimeMinute';
const String prefKeyBlockDays = 'blockDays';
const String prefKeyBlockedApps = 'blockedAppsList';
const String prefKeyBlockedWebsites = 'blockedWebsitesList';
const String prefKeyDeleteUncompletedTasks = 'deleteUncompletedTasks'; // Nowy klucz

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay _selectedBlockTime = const TimeOfDay(hour: 15, minute: 30);
  Map<int, bool> _blockDays = { for (var i = 0; i < 7; i++) i: false };
  final List<String> _dayNames = ["Pon", "Wt", "Śr", "Czw", "Pt", "Sob", "Ndz"];

  final TextEditingController _blockedAppController = TextEditingController();
  List<String> _blockedApps = [];
  List<Application> _installedApps = [];
  bool _isLoadingApps = true;

  final TextEditingController _blockedWebsiteController = TextEditingController();
  List<String> _blockedWebsites = [];

  bool _deleteUncompletedTasks = false; // Nowa opcja

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    if (!mounted) return;
    setState(() { _isLoadingApps = true; });
    try {
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: true,
      );
      if (mounted) {
        setState(() {
          _installedApps = apps;
          _isLoadingApps = false;
        });
      }
    } catch (e) {
      print("Error loading installed apps: $e");
      if (mounted) {
        setState(() { _isLoadingApps = false; });
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedBlockTime = TimeOfDay(
        hour: prefs.getInt(prefKeyBlockTimeHour) ?? 15,
        minute: prefs.getInt(prefKeyBlockTimeMinute) ?? 30,
      );

      List<String> daysIndices = prefs.getStringList(prefKeyBlockDays) ?? [];
      _blockDays = { for (var i = 0; i < 7; i++) i: daysIndices.contains(i.toString()) };
      if (daysIndices.isEmpty && !_blockDays.values.any((e) => e)) {
         _blockDays[2] = true;
      }

      _blockedApps = prefs.getStringList(prefKeyBlockedApps) ?? [];
      _blockedWebsites = prefs.getStringList(prefKeyBlockedWebsites) ?? [];
      _deleteUncompletedTasks = prefs.getBool(prefKeyDeleteUncompletedTasks) ?? false;

      _isLoading = false;
    });
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return "Jasny";
      case ThemeMode.dark: return "Ciemny";
      case ThemeMode.system:
      default: return "Systemowy";
    }
  }

  Future<void> _saveBlockTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefKeyBlockTimeHour, _selectedBlockTime.hour);
    await prefs.setInt(prefKeyBlockTimeMinute, _selectedBlockTime.minute);
    FlutterBackgroundService().invoke("reloadSettings");
  }

  Future<void> _saveBlockDays() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> activeDayIndices = _blockDays.entries.where((e) => e.value).map((e) => e.key.toString()).toList();
    await prefs.setStringList(prefKeyBlockDays, activeDayIndices);
    FlutterBackgroundService().invoke("reloadSettings");
  }

  Future<void> _saveBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefKeyBlockedApps, _blockedApps);
    FlutterBackgroundService().invoke("reloadSettings");
  }

  Future<void> _saveBlockedWebsites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefKeyBlockedWebsites, _blockedWebsites);
    FlutterBackgroundService().invoke("reloadSettings");
  }

  Future<void> _saveDeleteUncompletedTasksSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyDeleteUncompletedTasks, _deleteUncompletedTasks);
    FlutterBackgroundService().invoke("reloadSettings"); // Usługa też musi wiedzieć o tej opcji
  }

  void _addBlockedWebsite() {
    final String url = _blockedWebsiteController.text.trim().toLowerCase();
    if (url.isNotEmpty && !_blockedWebsites.contains(url)) {
      setState(() {
        _blockedWebsites.add(url);
        _blockedWebsiteController.clear();
      });
      _saveBlockedWebsites();
    }
  }

  void _removeBlockedWebsite(String url) {
    setState(() {
      _blockedWebsites.remove(url);
    });
    _saveBlockedWebsites();
  }

   Future<void> _selectBlockTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedBlockTime,
    );
    if (picked != null && picked != _selectedBlockTime) {
      setState(() { _selectedBlockTime = picked; });
      _saveBlockTime();
    }
   }

  void _addBlockedApp() {
    final String appName = _blockedAppController.text.trim();
    if (appName.isNotEmpty && !_blockedApps.contains(appName)) {
      setState(() {
        _blockedApps.add(appName);
        _blockedAppController.clear();
      });
      _saveBlockedApps();
    }
  }

  void _removeBlockedApp(String appName) {
    setState(() {
      _blockedApps.remove(appName);
    });
    _saveBlockedApps();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Ustawienia')), body: const Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController( // Dodajemy DefaultTabController
      length: 3, // Liczba zakładek
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ustawienia'),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.hintColor,
            tabs: const [
              Tab(icon: Icon(Icons.schedule), text: 'Harmonogram'),
              Tab(icon: Icon(Icons.block), text: 'Blokady'),
              Tab(icon: Icon(Icons.tune), text: 'Inne'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildScheduleSettings(theme),
            _buildBlockedListsSettings(theme),
            _buildOtherSettings(theme, themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSettings(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Text('Harmonogram Blokady', style: theme.textTheme.headlineSmall), // Już w AppBar
        // const SizedBox(height: 16),
        Text('Aktywne dni blokady:', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0, runSpacing: 4.0,
          children: List<Widget>.generate(7, (int index) {
            return ChoiceChip(
              label: Text(_dayNames[index]), selected: _blockDays[index]!,
              selectedColor: theme.colorScheme.primary,
              labelStyle: TextStyle(color: _blockDays[index]! ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color),
              onSelected: (bool selected) { setState(() { _blockDays[index] = selected; }); _saveBlockDays(); },
            );
          }),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Godzina startu blokady'),
          subtitle: Text('${_selectedBlockTime.format(context)}'),
          trailing: Icon(Icons.edit, color: theme.colorScheme.primary),
          onTap: () => _selectBlockTime(context),
        ),
      ],
    );
  }

  Widget _buildBlockedListsSettings(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Text('Zarządzaj Blokowaną Listą', style: theme.textTheme.headlineSmall), // Już w AppBar
        // const SizedBox(height: 16),
        Text('Wybierz aplikacje do blokowania:', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _isLoadingApps
            ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
            : Container(
                height: 250,
                decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(8)),
                child: _installedApps.isEmpty
                ? Center(child: Text("Nie znaleziono aplikacji.", style: TextStyle(color: theme.hintColor)))
                : ListView.builder(
                  itemCount: _installedApps.length,
                  itemBuilder: (context, index) {
                    final app = _installedApps[index];
                    return CheckboxListTile(
                      title: Text(app.appName, style: theme.textTheme.bodyMedium),
                      subtitle: Text(app.packageName, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                      value: _blockedApps.contains(app.packageName),
                      activeColor: theme.colorScheme.primary,
                      onChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) { if (!_blockedApps.contains(app.packageName)) _blockedApps.add(app.packageName); }
                          else { _blockedApps.remove(app.packageName); }
                          _saveBlockedApps();
                        });
                      },
                    );
                  },
                ),
              ),
        const SizedBox(height: 16),
        Text('Dodaj ręcznie (ID pakietu):', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
         Row(children: [ Expanded(TextField(controller: _blockedAppController, decoration: const InputDecoration(hintText: 'np. com.instagram.android', border: OutlineInputBorder()))), const SizedBox(width: 8), ElevatedButton(onPressed: _addBlockedApp, style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary), child: Icon(Icons.add, color: theme.colorScheme.onPrimary))]),
        const SizedBox(height: 8),
         if (_blockedApps.isNotEmpty) ...[ Text("Aktualnie blokowane:", style: theme.textTheme.titleSmall), Wrap(spacing: 8.0, runSpacing: 4.0, children: _blockedApps.map((packageName) => Chip(label: Text(packageName), onDeleted: () => _removeBlockedApp(packageName), deleteIconColor: theme.colorScheme.error.withOpacity(0.7))).toList())],

        const Divider(height: 32),
        Text('Blokowane Strony WWW (domena)', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(children: [ Expanded(TextField(controller: _blockedWebsiteController, decoration: const InputDecoration(hintText: 'np. youtube.com', border: OutlineInputBorder()))), const SizedBox(width: 8), ElevatedButton(onPressed: _addBlockedWebsite, style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary), child: Icon(Icons.add, color: theme.colorScheme.onPrimary))]),
        const SizedBox(height: 8),
        if (_blockedWebsites.isNotEmpty) Wrap(spacing: 8.0, runSpacing: 4.0, children: _blockedWebsites.map((url) => Chip(label: Text(url), onDeleted: () => _removeBlockedWebsite(url), deleteIconColor: theme.colorScheme.error.withOpacity(0.7))).toList())
        else Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Brak stron do blokowania.', style: TextStyle(color: theme.hintColor))),
      ],
    );
  }

  Widget _buildOtherSettings(ThemeData theme, ThemeProvider themeProvider) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Text('Inne Ustawienia', style: theme.textTheme.headlineSmall), // Już w AppBar
        // const SizedBox(height: 8),
        ListTile(
          title: const Text('Wybór motywu'),
          subtitle: Text(_getThemeModeName(themeProvider.themeMode)),
          leading: const Icon(Icons.color_lens_outlined),
          onTap: () async {
            ThemeMode? selectedMode = await showDialog<ThemeMode>(
              context: context, builder: (BuildContext context) {
                return SimpleDialog(title: const Text('Wybierz motyw'), children: ThemeMode.values.map((mode) {
                  return SimpleDialogOption(onPressed: () { Navigator.pop(context, mode); }, child: Text(_getThemeModeName(mode)));
                }).toList());
              },
            );
            if (selectedMode != null) {
              context.read<ThemeProvider>().setThemeMode(selectedMode);
            }
          },
        ),
        SwitchListTile(
          title: const Text('Usuwaj niewykonane zadania'),
          subtitle: const Text('Codziennie o północy usuwa zadania, które nie zostały ukończone.'),
          value: _deleteUncompletedTasks,
          onChanged: (bool value) {
            setState(() { _deleteUncompletedTasks = value; });
            _saveDeleteUncompletedTasksSetting();
          },
          activeColor: theme.colorScheme.primary,
        ),
        ListTile(
          title: const Text('Zarządzanie powiadomieniami'),
          subtitle: const Text('Implementacja wkrótce'),
          leading: const Icon(Icons.notifications_outlined),
          onTap: () { /* TODO */ },
        ),
      ],
    );
  }
}
