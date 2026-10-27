import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'contact_page.dart';
import 'home_page.dart';
import 'phien_dau_gia.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyBB6rIBS04UJr4SQEpx9Z0Hu20_sPlCaYI",
    appId: "1:230200001665:android:885cf93911a49dd4e5b980",
    messagingSenderId: "230200001665",
    projectId: "app-dau-gia-36729",
  );
  Object? initializationError;
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    initializationError = e;
  }
  runApp(MyApp(firebaseInitializationError: initializationError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.firebaseInitializationError});

  final Object? firebaseInitializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ứng dụng Đấu giá Trực tuyến',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14243A))
            .copyWith(
              primary: const Color(0xFF14243A),
              secondary: const Color(0xFFC49A55),
              surface: const Color(0xFFF5F6F8),
            ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF14243A),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E6EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E6EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFC49A55), width: 1.5),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFECE5D8),
          elevation: 8,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: firebaseInitializationError == null
          ? const _AppNavigationShell()
          : _FirebaseUnavailablePage(error: firebaseInitializationError!),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _FirebaseUnavailablePage extends StatelessWidget {
  const _FirebaseUnavailablePage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Không thể kết nối Firebase. Dữ liệu trực tiếp không khả dụng.\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _AppNavigationShell extends StatefulWidget {
  const _AppNavigationShell();

  @override
  State<_AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<_AppNavigationShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    TrangDauGiaPage(),
    ContactPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel_rounded),
            label: 'Đấu giá',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
