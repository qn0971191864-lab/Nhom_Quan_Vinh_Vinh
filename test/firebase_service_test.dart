// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quan_vinh_vinh_dau_gia/Bid.dart';
import 'package:quan_vinh_vinh_dau_gia/services/firebase_service.dart';

void main() {
  group('FirebaseService.placeBid', () {
    late _FakeFirestore firestore;
    late FirebaseService service;

    setUp(() {
      firestore = _FakeFirestore();
      service = FirebaseService(firestore: firestore);
      firestore.documents['auction_sessions/session-1'] = {
        'status': 'active',
        'startingPrice': 100,
        'currentHighestBid': 100,
      };
    });

    test('từ chối phiên không tồn tại', () async {
      final bid = Bid(bidAmount: 150, userId: 2);

      await expectLater(
        service.placeBid(sessionId: 'missing', bid: bid),
        throwsA(isA<Exception>()),
      );

      expect(firestore.documents['bids'], isNull);
      expect(bid.sessionId, isEmpty);
      expect(
        firestore.documents['auction_sessions/session-1']!['currentHighestBid'],
        100,
      );
    });

    test('chỉ cho phép đặt giá khi phiên active', () async {
      for (final status in [
        'scheduled',
        'upcoming',
        'ended',
        'cancelled',
        null,
      ]) {
        firestore.documents['auction_sessions/session-1']!['status'] = status;

        await expectLater(
          service.placeBid(
            sessionId: 'session-1',
            bid: Bid(bidAmount: 150, userId: 2),
          ),
          throwsA(isA<Exception>()),
          reason: 'status=$status',
        );
      }

      expect(firestore.documents['bids'], isNull);
    });

    test('từ chối giá không hợp lệ', () async {
      for (final amount in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        await expectLater(
          service.placeBid(
            sessionId: 'session-1',
            bid: Bid(bidAmount: amount, userId: 2),
          ),
          throwsA(isA<Exception>()),
          reason: 'amount=$amount',
        );
      }

      expect(firestore.documents['bids'], isNull);
      expect(
        firestore.documents['auction_sessions/session-1']!['currentHighestBid'],
        100,
      );
    });

    test('từ chối giá bằng hoặc thấp hơn giá cao nhất hiện tại', () async {
      for (final amount in [100.0, 99.0]) {
        await expectLater(
          service.placeBid(
            sessionId: 'session-1',
            bid: Bid(bidAmount: amount, userId: 2),
          ),
          throwsA(isA<Exception>()),
          reason: 'amount=$amount',
        );
      }

      expect(firestore.documents['bids'], isNull);
    });

    test('từ chối giá không vượt giá khởi điểm khi chưa có bid', () async {
      firestore.documents['auction_sessions/session-1']!['currentHighestBid'] =
          0;

      await expectLater(
        service.placeBid(
          sessionId: 'session-1',
          bid: Bid(bidAmount: 100, userId: 2),
        ),
        throwsA(isA<Exception>()),
      );

      expect(firestore.documents['bids'], isNull);
    });

    test('chặn seller đặt giá theo dữ liệu của phiên hoặc sản phẩm', () async {
      firestore.documents['auction_sessions/session-1']!['sellerUid'] = '7';
      await expectLater(
        service.placeBid(
          sessionId: 'session-1',
          bid: Bid(bidAmount: 150, userId: 7),
        ),
        throwsA(isA<Exception>()),
      );

      firestore.documents['auction_sessions/session-1']!
        ..remove('sellerUid')
        ..['itemId'] = 'item-1';
      firestore.documents['items/item-1'] = {'owner_id': 7};
      await expectLater(
        service.placeBid(
          sessionId: 'session-1',
          bid: Bid(bidAmount: 150, userId: 7),
        ),
        throwsA(isA<Exception>()),
      );

      expect(firestore.documents['bids'], isNull);
      expect(
        firestore.documents['auction_sessions/session-1']!['currentHighestBid'],
        100,
      );
    });

    test('cập nhật phiên và lưu bid trong cùng transaction', () async {
      final bid = Bid(bidAmount: 150, userId: 2);

      await service.placeBid(sessionId: 'session-1', bid: bid);

      final session = firestore.documents['auction_sessions/session-1']!;
      expect(session['currentHighestBid'], 150);
      expect(session['highestBidderId'], '2');
      expect(session['status'], 'active');

      final savedBids = firestore.documents.entries
          .where((entry) => entry.key.startsWith('bids/'))
          .toList();
      expect(savedBids, hasLength(1));
      expect(savedBids.single.value['bidAmount'], 150);
      expect(savedBids.single.value['userId'], 2);
      expect(savedBids.single.value['sessionId'], 'session-1');
      expect(bid.sessionId, 'session-1');
    });

    test(
      'đọc lại giá trong transaction để xử lý các lượt đặt đồng thời',
      () async {
        Future<bool> place(double amount) async {
          try {
            await service.placeBid(
              sessionId: 'session-1',
              bid: Bid(bidAmount: amount, userId: amount.toInt()),
            );
            return true;
          } on Exception {
            return false;
          }
        }

        final outcomes = await Future.wait([place(150), place(140)]);

        expect(outcomes, [true, false]);
        expect(
          firestore
              .documents['auction_sessions/session-1']!['currentHighestBid'],
          150,
        );
        expect(
          firestore.documents.keys.where((path) => path.startsWith('bids/')),
          hasLength(1),
        );
      },
    );
  });
}

class _FakeFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> documents = {};
  Future<void> _transactionQueue = Future<void>.value();
  int _nextBidId = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionReference(this, collectionPath);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final previousTransaction = _transactionQueue;
    final completed = Completer<void>();
    _transactionQueue = completed.future;
    await previousTransaction;

    try {
      final transaction = _FakeTransaction(this);
      final result = await transactionHandler(transaction);
      transaction.commit();
      return result;
    } finally {
      completed.complete();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this.firestore, this.path);

  @override
  final _FakeFirestore firestore;

  @override
  final String path;

  @override
  String get id => path.split('/').last;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final id = path ?? 'generated-${firestore._nextBidId++}';
    return _FakeDocumentReference(firestore, this.path, id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference(this.firestore, this.collectionPath, this.id);

  @override
  final _FakeFirestore firestore;

  final String collectionPath;

  @override
  final String id;

  @override
  String get path => '$collectionPath/$id';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransaction implements Transaction {
  _FakeTransaction(this.firestore);

  final _FakeFirestore firestore;
  final List<void Function()> _pendingWrites = [];

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final data = firestore.documents[documentReference.path];
    return _FakeDocumentSnapshot<T>(documentReference.id, data as T?);
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    _pendingWrites.add(() {
      firestore.documents[documentReference.path]!.addAll(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    });
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _pendingWrites.add(() {
      firestore.documents[documentReference.path] = Map<String, dynamic>.from(
        data as Map,
      );
    });
    return this;
  }

  void commit() {
    for (final write in _pendingWrites) {
      write();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentSnapshot<T> implements DocumentSnapshot<T> {
  _FakeDocumentSnapshot(this.id, this._data);

  @override
  final String id;

  final T? _data;

  @override
  bool get exists => _data != null;

  @override
  T? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
