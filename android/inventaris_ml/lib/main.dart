import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'services/theme_service.dart';
import 'screens/form_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/maintenance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const InventarisApp());
}

class InventarisApp extends StatelessWidget {
  const InventarisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'ML Inventaris Non-Medis',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.light,
              seedColor: const Color(0xFF10B981),
              primary: const Color(0xFF10B981),
              surface: const Color(0xFFF8FAFC),
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            cardTheme: const CardThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: const Color(0xFF10B981),
              primary: const Color(0xFF10B981),
              surface: const Color(0xFF0F172A),
            ),
            scaffoldBackgroundColor: const Color(0xFF090D16),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF0F172A),
              surfaceTintColor: Colors.transparent,
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: const Color(0xFF0F172A),
              indicatorColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            ),
          ),
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    FormScreen(),
    RoomsScreen(),
    MaintenanceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: const Color(0xFF10B981).withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle, color: Color(0xFF10B981)),
            label: 'Input Prediksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room, color: Color(0xFF10B981)),
            label: 'Data Ruangan',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: Color(0xFF10B981)),
            label: 'Antrean Tugas',
          ),
        ],
      ),
    );
  }
}
