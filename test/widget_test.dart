import 'package:flutter_test/flutter_test.dart';

import 'package:quan_vinh_vinh_dau_gia/auction_session.dart';
import 'package:quan_vinh_vinh_dau_gia/Bid.dart';
import 'package:quan_vinh_vinh_dau_gia/Category.dart';
import 'package:quan_vinh_vinh_dau_gia/item.dart';
import 'package:quan_vinh_vinh_dau_gia/Notification.dart';
import 'package:quan_vinh_vinh_dau_gia/Transaction.dart';
import 'package:quan_vinh_vinh_dau_gia/main.dart';
import 'package:quan_vinh_vinh_dau_gia/project_model.dart';
import 'package:quan_vinh_vinh_dau_gia/user.dart';

void main() {
  test('các model không khởi tạo bằng dữ liệu mẫu', () {
    final user = User();
    final item = Item();
    final phien = PhienDauGia();

    expect(user.getUserFullname(), isEmpty);
    expect(item.getItemName(), isEmpty);
    expect(item.startingPrice, 0);
    expect(phien.getMaPhien(), isEmpty);
  });

  test('các class cập nhật dữ liệu qua setter', () {
    final user = User();
    final item = Item();
    final phien = PhienDauGia();

    user.setUser(
      2,
      'Nguyễn Văn A',
      'a@example.com',
      'secret',
      'ADMIN',
      'a.png',
      '22/09/2026',
    );
    item.setItem('Laptop', 15000000, 'Hàng mới');
    phien.setPhienDauGia('P002', '09:00 27/04/2026', '13:00 27/04/2026');

    expect(user.getUserFullname(), 'Nguyễn Văn A');
    expect(user.role, 'ADMIN');
    expect(item.getItemName(), 'Laptop');
    expect(item.startingPrice, 15000000);
    expect(phien.getMaPhien(), 'P002');
    expect(phien.thoiGianKetThuc, '13:00 27/04/2026');
  });

  test('các model kế thừa lớp generic và cung cấp thông tin kiểu runtime', () {
    final ProjectModel<int> user = User();
    final ProjectModel<int> item = Item();
    final ProjectModel<int> bid = Bid();
    final ProjectModel<int> category = Category();
    final ProjectModel<int> notification = AppNotification();
    final ProjectModel<int> transaction = TransactionModel();
    final ProjectModel<String> phien = PhienDauGia();

    expect(user.id, 0);
    expect(user.object, same(user));
    expect(user.classType, User);
    expect(item.id, 0);
    expect(item.classType, Item);
    expect(bid.id, 0);
    expect(bid.classType, Bid);
    expect(category.id, 0);
    expect(category.classType, Category);
    expect(notification.id, 0);
    expect(notification.classType, AppNotification);
    expect(transaction.id, 0);
    expect(transaction.classType, TransactionModel);
    expect(phien.id, isEmpty);
    expect(phien.classType, PhienDauGia);
  });

  testWidgets('Firebase initialization errors are shown instead of mock data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MyApp(firebaseInitializationError: FormatException('test')),
    );

    expect(find.textContaining('Không thể kết nối Firebase'), findsOneWidget);
    expect(find.textContaining('test'), findsOneWidget);
  });
}
