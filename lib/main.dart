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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Đấu giá'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}
