import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'contact_page.dart';
import 'home_page.dart';
import 'news_page.dart';
import 'phien_dau_gia.dart';
import 'search_page.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyBB6rIBS04UJr4SQEpx9Z0Hu20_sPlCaYI",
    appId: "1:230200001665:android:885cf93911a49dd4e5b980",
    messagingSenderId: "230200001665",
    projectId: "app-dau-gia-36729",
    storageBucket: "app-dau-gia-36729.firebasestorage.app",
  );
  Object? initializationError;
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    initializationError = e;
  }
  await AppThemeController.instance.load();
  runApp(MyApp(firebaseInitializationError: initializationError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.firebaseInitializationError});

  final Object? firebaseInitializationError;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Ứng dụng Đấu giá Trực tuyến',
          themeMode: AppThemeController.instance.themeMode,
          theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF14243A))
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
                borderSide: const BorderSide(
                  color: Color(0xFFC49A55),
                  width: 1.5,
                ),
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
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme:
                ColorScheme.fromSeed(
                  seedColor: const Color(0xFF007ACC),
                  brightness: Brightness.dark,
                ).copyWith(
                  primary: const Color(0xFF007ACC),
                  secondary: const Color(0xFFC49A55),
                  surface: const Color(0xFF252526),
                  surfaceContainerLowest: const Color(0xFF181818),
                  surfaceContainerLow: const Color(0xFF1E1E1E),
                  surfaceContainer: const Color(0xFF252526),
                  surfaceContainerHigh: const Color(0xFF2D2D2D),
                  outline: const Color(0xFF3C3C3C),
                ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF1E1E1E),
            canvasColor: const Color(0xFF1E1E1E),
            cardColor: const Color(0xFF252526),
            dividerColor: const Color(0xFF3C3C3C),
            textTheme: Typography.material2021().white.apply(
              bodyColor: const Color(0xFFCCCCCC),
              displayColor: const Color(0xFFFFFFFF),
            ),
            iconTheme: const IconThemeData(color: Color(0xFFCCCCCC)),
            listTileTheme: const ListTileThemeData(
              textColor: Color(0xFFCCCCCC),
              iconColor: Color(0xFFCCCCCC),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF181818),
              foregroundColor: Color(0xFFCCCCCC),
              centerTitle: false,
              elevation: 0,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF252526),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF3C3C3C)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF3C3C3C)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF007ACC),
                  width: 1.5,
                ),
              ),
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF252526),
              surfaceTintColor: Colors.transparent,
            ),
            segmentedButtonTheme: SegmentedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF007ACC);
                  }
                  return const Color(0xFF252526);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return const Color(0xFFCCCCCC);
                }),
                iconColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return const Color(0xFFCCCCCC);
                }),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: Color(0xFF3C3C3C)),
                ),
              ),
            ),
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Color(0xFF181818),
              indicatorColor: Color(0xFF37373D),
              elevation: 0,
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
      },
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
    NewsPage(),
    SearchPage(),
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
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper_rounded),
            label: 'Tin tức',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Tìm kiếm',
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
