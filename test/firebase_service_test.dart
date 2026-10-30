import 'package:flutter_test/flutter_test.dart';
import 'package:quan_vinh_vinh_dau_gia/bid.dart';
import 'package:quan_vinh_vinh_dau_gia/auction_session.dart';
import 'package:quan_vinh_vinh_dau_gia/services/firebase_service.dart';

void main() {
  group('FirebaseService auction callables', () {
    late _FakeAuctionCallables callables;
    late FirebaseService service;

    setUp(() {
      callables = _FakeAuctionCallables();
      service = FirebaseService(callables: callables);
      FirebaseService.clearDisplayNameCache();
    });

    test('validates bid amount before calling the trusted backend', () async {
      for (final amount in [0, -1]) {
        await expectLater(
          service.placeBid(
            sessionId: 'session-1',
            bid: Bid(bidAmount: amount),
          ),
          throwsArgumentError,
        );
      }
      expect(callables.calls, isEmpty);
    });

    test(
      'sends only session and amount, then applies authoritative response',
      () async {
        callables.responses['placeBid'] = {
          'bidId': 'server-generated-id',
          'bidderUid': 'authenticated-uid',
          'bidTime': '2026-10-24T12:00:00.000Z',
        };
        final bid = Bid(
          bidAmount: 150,
          userId: 999999,
          bidderUid: 'spoofed-uid',
        );

        await service.placeBid(sessionId: 'session-1', bid: bid);

        expect(callables.calls.single.name, 'placeBid');
        expect(callables.calls.single.data, {
          'sessionId': 'session-1',
          'maxAmount': 150,
          'amount': 150,
        });
        expect(bid.sessionId, 'session-1');
        expect(bid.bidderUid, 'authenticated-uid');
        expect(bid.bidTime, '2026-10-24T12:00:00.000Z');
      },
    );

    test(
      'creates a session through the server and uses its generated identity',
      () async {
        callables.responses['createAuctionSession'] = {
          'sessionId': 'generated-session',
          'sellerUid': 'authenticated-seller',
        };
        final start = DateTime.now().toUtc().add(const Duration(days: 1));
        final end = start.add(const Duration(hours: 2));
        final session = AuctionSession(
          itemId: 'item-1',
          startingPrice: 100,
          minimumIncrement: 10,
          startTime: start.toIso8601String(),
          endTime: end.toIso8601String(),
        );

        final id = await service.createAuctionSession(session);

        expect(id, 'generated-session');
        expect(session.sessionId, id);
        expect(session.sellerUid, 'authenticated-seller');
        expect(session.currentHighestBid, 0);
        expect(session.status, 'scheduled');
        expect(callables.calls.single.name, 'createAuctionSession');
        expect(callables.calls.single.data['startingPrice'], 100);
        expect(callables.calls.single.data['minimumIncrement'], 10);
      },
    );

    test('rejects invalid session dates before a server call', () async {
      final session = AuctionSession(
        itemId: 'item-1',
        startingPrice: 100,
        startTime: '08:00 26/04/2026',
        endTime: '12:00 26/04/2026',
      );

      await expectLater(
        service.createAuctionSession(session),
        throwsArgumentError,
      );
      expect(callables.calls, isEmpty);
    });

    test('cancels a session through the trusted backend', () async {
      await service.cancelAuctionSession('session-1');

      expect(callables.calls.single.name, 'cancelAuctionSession');
      expect(callables.calls.single.data, {'sessionId': 'session-1'});
    });

    test('formatShortUid formats empty, short, and long UIDs correctly', () {
      expect(FirebaseService.formatShortUid(''), 'Người tham gia');
      expect(FirebaseService.formatShortUid('   '), 'Người tham gia');
      expect(FirebaseService.formatShortUid('abc12345'), 'abc12345');
      expect(
        FirebaseService.formatShortUid('AfVuzcugHAY2VtgQbiUAyH7HOZG3'),
        'AfVu...OZG3',
      );
      expect(FirebaseService.formatShortUid('user_vinh_001'), 'user..._001');
    });

    test(
      'getUserDisplayName falls back to short UID when uninitialized',
      () async {
        final name = await service.getUserDisplayName(
          'AfVuzcugHAY2VtgQbiUAyH7HOZG3',
        );
        expect(name, 'AfVu...OZG3');
        expect(
          FirebaseService.isCachedDisplayName('AfVuzcugHAY2VtgQbiUAyH7HOZG3'),
          isTrue,
        );
        expect(
          FirebaseService.getCachedDisplayName('AfVuzcugHAY2VtgQbiUAyH7HOZG3'),
          'AfVu...OZG3',
        );

        final emptyName = await service.getUserDisplayName('');
        expect(emptyName, 'Người tham gia');
      },
    );
  });
}

class _Callable {
  const _Callable(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;
}

class _FakeAuctionCallables implements AuctionCallableClient {
  final calls = <_Callable>[];
  final responses = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add(_Callable(name, Map<String, dynamic>.from(data)));
    return responses[name] ?? {};
  }
}
