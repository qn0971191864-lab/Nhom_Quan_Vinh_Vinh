import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quan_vinh_vinh_dau_gia/bid.dart';
import 'package:quan_vinh_vinh_dau_gia/auction_session.dart';
import 'package:quan_vinh_vinh_dau_gia/user.dart';

void main() {
  group('Bid serialization', () {
    test('toMap uses the canonical Firestore fields', () {
      final bid = Bid(
        bidId: 21,
        bidAmount: 2750000,
        bidTime: '2026-10-24T10:30:00.000Z',
        userId: 8,
        bidderUid: 'firebase-user-8',
        sessionId: 'session-21',
      );

      final map = bid.toMap();
      expect(map.keys.toSet(), {'sessionId', 'bidderUid', 'amount', 'bidTime'});
      expect(map['sessionId'], 'session-21');
      expect(map['bidderUid'], 'firebase-user-8');
      expect(map['amount'], 2750000);
      expect(
        (map['bidTime'] as Timestamp).toDate().toUtc(),
        DateTime.parse(bid.bidTime).toUtc(),
      );

      final restored = Bid.fromMap(map, 'document-id');
      expect(restored.bidId, 0);
      expect(restored.bidAmount, 2750000);
      expect(restored.bidTime, bid.bidTime);
      expect(restored.userId, 0);
      expect(restored.bidderUid, 'firebase-user-8');
      expect(restored.documentId, 'document-id');
      expect(restored.sessionId, 'session-21');
    });

    test('fromMap falls back to document ID and legacy auctionId', () {
      final bid = Bid.fromMap({
        'amount': 3000000,
        'auctionId': 'legacy-session',
      }, '22');

      expect(bid.bidId, 22);
      expect(bid.bidAmount, 3000000);
      expect(bid.sessionId, 'legacy-session');
    });
  });

  group('User serialization', () {
    test('toMap omits password and fromMap never restores one', () {
      final user = User(
        id: 32,
        firebaseUid: 'firebase-uid-32',
        fullname: 'Nguyen An',
        email: 'an@example.com',
        password: 'must-not-be-stored',
        role: 'USER',
        avatar: 'an.png',
        createdAt: '2026-10-24T12:00:00Z',
      );

      final map = user.toMap();
      expect(map, isNot(contains('password')));
      expect(map, isNot(contains('id')));
      expect(map['firebaseUid'], 'firebase-uid-32');
      expect(map['fullname'], 'Nguyen An');
      expect(map['email'], 'an@example.com');

      final restored = User.fromMap(map, 'document-id');
      expect(restored.id, 0);
      expect(restored.firebaseUid, 'firebase-uid-32');
      expect(restored.fullname, 'Nguyen An');
      expect(restored.email, 'an@example.com');
      expect(restored.role, 'USER');
      expect(restored.avatar, 'an.png');
      expect(
        DateTime.parse(restored.createdAt).toUtc(),
        DateTime.parse('2026-10-24T12:00:00Z').toUtc(),
      );
      expect(restored.password, isEmpty);
    });

    test('toMap omits a missing Firebase UID and fromMap falls back to document ID', () {
      final map = User(id: 33).toMap();
      expect(map, isNot(contains('firebaseUid')));

      final restored = User.fromMap({
        'name': 'Legacy Name',
        'email': 'legacy@example.com',
      }, '34');
      expect(restored.id, 34);
      expect(restored.fullname, 'Legacy Name');
      expect(restored.password, isEmpty);
    });
  });

  group('AuctionSession serialization', () {
    test('toMap and fromMap preserve canonical Firestore fields', () {
      final session = AuctionSession(
        sessionId: 'session-41',
        itemId: 'item-41',
        sellerUid: 'seller-1',
        startingPrice: 100000,
        minimumIncrement: 5000,
        currentHighestBid: 125000,
        highestBidderUid: 'firebase-user-5',
        startTime: '2026-10-24T12:00:00.000Z',
        endTime: '2026-10-25T12:00:00.000Z',
        status: 'active',
      );

      final map = session.toMap();
      expect(map.keys.toSet(), {
        'itemId',
        'sellerUid',
        'startingPrice',
        'minimumIncrement',
        'buyNowPrice',
        'reservePrice',
        'reservePriceMet',
        'currentHighestBid',
        'highestBidderUid',
        'startTime',
        'endTime',
        'status',
        'result',
        'antiSnipingEnabled',
        'extensionWindowMinutes',
        'extensionMinutes',
        'maxExtensions',
        'extensionCount',
      });
      expect(map['sellerUid'], 'seller-1');
      expect(map['minimumIncrement'], 5000);
      expect(
        (map['startTime'] as Timestamp).toDate().toUtc(),
        DateTime.parse(session.startTime).toUtc(),
      );

      final restored = AuctionSession.fromMap(map, 'document-id');
      expect(restored.sessionId, 'document-id');
      expect(restored.itemId, 'item-41');
      expect(restored.sellerUid, 'seller-1');
      expect(restored.startingPrice, 100000);
      expect(restored.minimumIncrement, 5000);
      expect(restored.currentHighestBid, 125000);
      expect(restored.highestBidderUid, 'firebase-user-5');
      expect(
        DateTime.parse(restored.startTime).toUtc(),
        DateTime.parse(session.startTime).toUtc(),
      );
      expect(
        DateTime.parse(restored.endTime).toUtc(),
        DateTime.parse(session.endTime).toUtc(),
      );
      expect(restored.status, 'active');
    });

    test('fromMap uses model fields when no document ID is supplied', () {
      final session = AuctionSession.fromMap({
        'sessionId': 'session-from-map',
        'startingPrice': 50000,
        'currentHighestBid': 50000,
      });

      expect(session.sessionId, 'session-from-map');
      expect(session.startingPrice, 50000);
      expect(session.currentHighestBid, 50000);
      expect(session.status, 'scheduled');
    });

    test('fromMap accepts legacy snake_case auction fields', () {
      final start = Timestamp.fromDate(DateTime.utc(2026, 10, 24));
      final end = Timestamp.fromDate(DateTime.utc(2026, 10, 25));
      final session = AuctionSession.fromMap({
        'item_id': 'item-1',
        'seller_uid': 'seller-1',
        'starting_price': 100,
        'minimum_increment': 10,
        'current_highest_bid': 150,
        'highest_bidder_uid': 'winner-1',
        'start_time': start,
        'end_time': end,
      }, 'session-1');

      expect(session.sessionId, 'session-1');
      expect(session.itemId, 'item-1');
      expect(session.sellerUid, 'seller-1');
      expect(session.startingPrice, 100);
      expect(session.minimumIncrement, 10);
      expect(session.currentHighestBid, 150);
      expect(session.highestBidderUid, 'winner-1');
      expect(DateTime.parse(session.endTime).toUtc(), end.toDate().toUtc());
    });
  });
}
