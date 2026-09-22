import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quan_vinh_vinh_dau_gia/AuctionSession.dart';
import 'package:quan_vinh_vinh_dau_gia/Item.dart';
import 'package:quan_vinh_vinh_dau_gia/main.dart';
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

    user.setUser(2, 'Nguyễn Văn A', 'a@example.com', 'secret', 'ADMIN', 'a.png', '22/09/2026');
    item.setItem('Laptop', 15000000, 'Hàng mới');
    phien.setPhienDauGia('P002', '09:00 27/04/2026', '13:00 27/04/2026');

    expect(user.getUserFullname(), 'Nguyễn Văn A');
    expect(user.role, 'ADMIN');
    expect(item.getItemName(), 'Laptop');
    expect(item.startingPrice, 15000000);
    expect(phien.getMaPhien(), 'P002');
    expect(phien.thoiGianKetThuc, '13:00 27/04/2026');
  });

  testWidgets('màn hình hiển thị dữ liệu của các class', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Phạm Quang Vinh'), findsOneWidget);
    expect(find.text('Điện thoại thông minh'), findsOneWidget);
    expect(find.text('Mã phiên: P001'), findsOneWidget);
  });
}
