import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quan_vinh_vinh_dau_gia/AuctionSession.dart';
import 'package:quan_vinh_vinh_dau_gia/Bid.dart';
import 'package:quan_vinh_vinh_dau_gia/Category.dart';
import 'package:quan_vinh_vinh_dau_gia/item.dart';
import 'package:quan_vinh_vinh_dau_gia/Notification.dart';
import 'package:quan_vinh_vinh_dau_gia/Transaction.dart';
import 'package:quan_vinh_vinh_dau_gia/main.dart';
import 'package:quan_vinh_vinh_dau_gia/project_model.dart';
import 'package:quan_vinh_vinh_dau_gia/user.dart';

void main() {
  test('các class khởi tạo dữ liệu mặc định', () {
    final user = User();
    final item = Item();
    final phien = PhienDauGia();

    expect(user.getUserFullname(), 'Phạm Quang Vinh');
    expect(item.getItemName(), 'Điện thoại thông minh');
    expect(item.startingPrice, 2000000);
    expect(phien.getMaPhien(), 'P001');
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

    expect(user.id, 1);
    expect(user.object, same(user));
    expect(user.classType, User);
    expect(item.id, 1);
    expect(item.classType, Item);
    expect(bid.id, 1);
    expect(bid.classType, Bid);
    expect(category.id, 1);
    expect(category.classType, Category);
    expect(notification.id, 1);
    expect(notification.classType, AppNotification);
    expect(transaction.id, 1);
    expect(transaction.classType, TransactionModel);
    expect(phien.id, 'P001');
    expect(phien.classType, PhienDauGia);
  });

  testWidgets('bottom navigation chuyển đổi giữa các màn hình', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Trang Chủ & Vật Phẩm'), findsOneWidget);
    expect(find.text('Phiên Đấu Giá'), findsNothing);
    expect(find.text('Tài Khoản & Cá Nhân'), findsNothing);

    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).onTap!(
      1,
    );
    await tester.pumpAndSettle();
    expect(find.text('Phiên Đấu Giá'), findsOneWidget);
    expect(find.text('Mã phiên: P001'), findsOneWidget);
    expect(find.text('Bắt đầu: 08:00 26/04/2026'), findsOneWidget);
    expect(find.text('Kết thúc: 12:00 26/04/2026'), findsOneWidget);

    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).onTap!(
      2,
    );
    await tester.pumpAndSettle();
    expect(find.text('Tài Khoản & Cá Nhân'), findsOneWidget);
    expect(find.text('Phiên Đấu Giá'), findsNothing);

    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).onTap!(
      0,
    );
    await tester.pumpAndSettle();
    expect(find.text('Trang Chủ & Vật Phẩm'), findsOneWidget);
    expect(find.text('Tài Khoản & Cá Nhân'), findsNothing);
  });
}
