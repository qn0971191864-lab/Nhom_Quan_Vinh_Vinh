import 'package:flutter/material.dart';
import './item.dart' show Item;
import './user.dart' show User; // Import thêm class của bạn

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // Sửa lỗi cú pháp .fromSeed
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Bài tập Nhóm Đấu Giá'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  
  // Khởi tạo các class để lấy dữ liệu hiển thị lên màn hình
  String testUser = User().getUserFullname();
  String testItem = Item().getItemName();

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          // Sửa lỗi cú pháp .center
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hiển thị phần của bạn
            const Text('Người dùng (Class User):', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(testUser, style: const TextStyle(fontSize: 20, color: Colors.blue)),
            
            const SizedBox(height: 30), // Tạo khoảng trống
            
            // Hiển thị phần của bạn kia
            const Text('Vật phẩm (Class Item):', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(testItem, style: const TextStyle(fontSize: 20, color: Colors.red)),
            
            const SizedBox(height: 50),
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}