import 'package:flutter_test/flutter_test.dart';
import 'package:quan_vinh_vinh_dau_gia/category.dart';
import 'package:quan_vinh_vinh_dau_gia/item.dart';
import 'package:quan_vinh_vinh_dau_gia/transaction.dart';
import 'package:quan_vinh_vinh_dau_gia/services/catalog_service.dart';
import 'package:quan_vinh_vinh_dau_gia/services/transaction_service.dart';

void main() {
  group('1. Category Mapping & Validation Tests', () {
    test('Category toMap và fromMap bảo toàn đầy đủ dữ liệu', () {
      final category = Category(
        categoryId: 10,
        categoryName: 'Đồng hồ cổ',
        iconUrl: 'vintage_watch.png',
      );

      final map = category.toMap();
      expect(map['categoryId'], 10);
      expect(map['categoryName'], 'Đồng hồ cổ');
      expect(map['iconUrl'], 'vintage_watch.png');

      final restored = Category.fromMap(map, '10');
      expect(restored.categoryId, 10);
      expect(restored.categoryName, 'Đồng hồ cổ');
      expect(restored.iconUrl, 'vintage_watch.png');
    });

    test('Category.fromMap fallback sang document ID khi thiếu categoryId', () {
      final map = <String, dynamic>{
        'categoryName': 'Trang sức',
        'iconUrl': 'jewelry.png',
      };

      final restored = Category.fromMap(map, '25');
      expect(restored.categoryId, 25);
      expect(restored.categoryName, 'Trang sức');
    });

    test('CatalogService.validateCategory chặn dữ liệu không hợp lệ', () {
      expect(
        () => CatalogService.validateCategory(
          Category(categoryId: 0, categoryName: 'Hợp lệ'),
        ),
        throwsArgumentError,
      );

      expect(
        () => CatalogService.validateCategory(
          Category(categoryId: 1, categoryName: '   '),
        ),
        throwsArgumentError,
      );
    });
  });

  group('2. Item Mapping & Validation Tests', () {
    test('Item toMap và fromMap hoạt động đúng với đầy đủ trường', () {
      final item = Item(
        id: 101,
        itemName: 'MacBook Pro M4',
        startingPrice: 35000000,
        description: 'Nguyên seal chính hãng',
        imageUrl: 'macbook.png',
        status: 'available',
        categoryId: 1,
      );

      final map = item.toMap();
      expect(map['id'], 101);
      expect(map['itemName'], 'MacBook Pro M4');
      expect(map['startingPrice'], 35000000);
      expect(map['status'], 'available');
      expect(map['categoryId'], 1);

      final restored = Item.fromMap(map, '101');
      expect(restored.id, 101);
      expect(restored.itemName, 'MacBook Pro M4');
      expect(restored.startingPrice, 35000000);
      expect(restored.status, 'available');
      expect(restored.categoryId, 1);
    });

    test('Item toMap ẩn categoryId nếu bằng null và fromMap đọc đúng fallback', () {
      final item = Item(
        id: 102,
        itemName: 'Bình gốm Chu Đậu',
        startingPrice: 5000000,
        status: 'in_auction',
        categoryId: null,
      );

      final map = item.toMap();
      expect(map.containsKey('categoryId'), isFalse);

      // Kiểm tra tương thích ngược với các khóa cũ ('title', 'price', 'image')
      final legacyMap = <String, dynamic>{
        'title': 'Tranh sơn dầu',
        'price': 12000000,
        'image': 'painting.jpg',
      };
      final restoredLegacy = Item.fromMap(legacyMap, '205');
      expect(restoredLegacy.id, 205);
      expect(restoredLegacy.itemName, 'Tranh sơn dầu');
      expect(restoredLegacy.startingPrice, 12000000.0);
      expect(restoredLegacy.imageUrl, 'painting.jpg');
      expect(restoredLegacy.status, 'available');
    });

    test(
      'CatalogService.validateItem kiểm tra giá, tên và trạng thái chuẩn',
      () {
        expect(
          () => CatalogService.validateItem(
            Item(id: 1, itemName: '', startingPrice: 100000),
          ),
          throwsArgumentError,
        );

        expect(
          () => CatalogService.validateItem(
            Item(id: 1, itemName: 'Áo cổ', startingPrice: -5000),
          ),
          throwsArgumentError,
        );

        expect(
          () => CatalogService.validateItem(
            Item(
              id: 1,
              itemName: 'Áo cổ',
              startingPrice: 100000,
              status: 'invalid_status',
            ),
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('3. TransactionModel Mapping & Validation Tests', () {
    test('TransactionModel giữ nguyên trạng thái được truyền vào (không giả lập thanh toán)', () {
      final pendingTx = TransactionModel(
        transactionId: 5001,
        amount: 2500000,
        paymentMethod: 'Chuyển khoản ngân hàng',
        status: 'Đang chờ xử lý',
        userUid: 'firebase-uid-7',
      );

      final payload = TransactionService.buildFirestorePayload(pendingTx);
      expect(payload['transactionId'], 5001);
      expect(payload['amount'], 2500000);
      expect(payload['paymentMethod'], 'Chuyển khoản ngân hàng');
      expect(payload['status'], 'Đang chờ xử lý');
      expect(payload['userUid'], 'firebase-uid-7');

      final restored = TransactionModel.fromMap(payload, '5001');
      expect(restored.transactionId, 5001);
      expect(restored.amount, 2500000);
      expect(restored.paymentMethod, 'Chuyển khoản ngân hàng');
      expect(restored.status, 'Đang chờ xử lý');
      expect(restored.userUid, 'firebase-uid-7');
    });

    test(
      'TransactionModel.fromMap đọc đúng document ID khi thiếu transactionId',
      () {
        final raw = <String, dynamic>{
          'amount': 1500000,
          'paymentMethod': 'Ví điện tử',
          'status': 'Thất bại',
        };

        final tx = TransactionModel.fromMap(raw, '9002');
        expect(tx.transactionId, 9002);
        expect(tx.amount, 1500000);
        expect(tx.status, 'Thất bại');
        expect(tx.userUid, isNull);
      },
    );

    test('TransactionService.validateTransaction từ chối số tiền <= 0 hoặc thiếu phương thức', () {
      expect(
        () => TransactionService.validateTransaction(
          TransactionModel(
            transactionId: 1,
            amount: 0,
            paymentMethod: 'Ví điện tử',
            status: 'Đang chờ',
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => TransactionService.validateTransaction(
          TransactionModel(
            transactionId: 1,
            amount: 500000,
            paymentMethod: '   ',
            status: 'Đang chờ',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('TransactionService requires Firebase UID ownership', () {
      expect(
        () => TransactionService.validateTransaction(
          TransactionModel(
            transactionId: 1,
            amount: 500000,
            paymentMethod: 'Ví điện tử',
            status: 'Đang chờ',
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
