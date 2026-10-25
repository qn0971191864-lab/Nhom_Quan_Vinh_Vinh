const { initializeApp } = require('firebase-admin/app');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const {
  auctionOutcome,
  isBidWindowOpen,
  minimumBidAmount,
} = require('./auction_logic');

initializeApp();

const db = getFirestore();
const sessions = db.collection('auction_sessions');
const items = db.collection('items');
const bids = db.collection('bids');

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Đăng nhập để thực hiện thao tác này.');
  }
  return uid;
}

function parseTimestamp(value, fieldName) {
  if (typeof value !== 'string' ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/i.test(value)) {
    throw new HttpsError('invalid-argument', `${fieldName} phải là chuỗi ISO-8601.`);
  }
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new HttpsError('invalid-argument', `${fieldName} không hợp lệ.`);
  }
  return Timestamp.fromDate(date);
}

function requirePositiveInteger(value, fieldName) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new HttpsError('invalid-argument', `${fieldName} phải là số nguyên dương.`);
  }
  return value;
}

exports.createAuctionSession = onCall(async (request) => {
  const uid = requireUid(request);
  const { itemId } = request.data ?? {};
  if (typeof itemId !== 'string' || itemId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'itemId không hợp lệ.');
  }
  const startingPrice = requirePositiveInteger(
    request.data.startingPrice,
    'startingPrice',
  );
  const minimumIncrement = requirePositiveInteger(
    request.data.minimumIncrement,
    'minimumIncrement',
  );
  const startTime = parseTimestamp(request.data.startTime, 'startTime');
  const endTime = parseTimestamp(request.data.endTime, 'endTime');
  const now = Timestamp.now();
  if (startTime.toMillis() <= now.toMillis() ||
      endTime.toMillis() <= startTime.toMillis()) {
    throw new HttpsError(
      'invalid-argument',
      'Thời gian bắt đầu phải ở tương lai và trước thời gian kết thúc.',
    );
  }

  const itemRef = items.doc(itemId.trim());
  const sessionRef = sessions.doc();
  await db.runTransaction(async (transaction) => {
    const itemSnapshot = await transaction.get(itemRef);
    if (!itemSnapshot.exists) {
      throw new HttpsError('not-found', 'Không tìm thấy sản phẩm.');
    }
    const item = itemSnapshot.data();
    if (item.ownerUid !== uid) {
      throw new HttpsError('permission-denied', 'Bạn không sở hữu sản phẩm này.');
    }
    if (item.status !== 'available') {
      throw new HttpsError('failed-precondition', 'Sản phẩm không sẵn sàng đấu giá.');
    }
    transaction.create(sessionRef, {
      itemId: itemId.trim(),
      sellerUid: uid,
      startingPrice,
      minimumIncrement,
      currentHighestBid: 0,
      highestBidderUid: null,
      startTime,
      endTime,
      status: 'scheduled',
      result: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(itemRef, { status: 'in_auction' });
  });

  return { sessionId: sessionRef.id, sellerUid: uid };
});

exports.placeBid = onCall(async (request) => {
  const bidderUid = requireUid(request);
  const { sessionId } = request.data ?? {};
  if (typeof sessionId !== 'string' || sessionId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'sessionId không hợp lệ.');
  }
  const amount = requirePositiveInteger(request.data.amount, 'amount');
  const sessionRef = sessions.doc(sessionId.trim());
  const bidRef = bids.doc();
  let acceptedAt;

  await db.runTransaction(async (transaction) => {
    const now = Timestamp.now();
    const sessionSnapshot = await transaction.get(sessionRef);
    if (!sessionSnapshot.exists) {
      throw new HttpsError('not-found', 'Không tìm thấy phiên đấu giá.');
    }
    const session = sessionSnapshot.data();
    if (!(session.startTime instanceof Timestamp) ||
        !(session.endTime instanceof Timestamp)) {
      throw new HttpsError('failed-precondition', 'Thời gian phiên không hợp lệ.');
    }
    if (!isBidWindowOpen({
      now: now.toMillis(),
      startTime: session.startTime.toMillis(),
      endTime: session.endTime.toMillis(),
      status: session.status,
    })) {
      throw new HttpsError(
        'failed-precondition',
        'Phiên chưa bắt đầu hoặc đã kết thúc.',
      );
    }
    if (session.sellerUid === bidderUid) {
      throw new HttpsError('permission-denied', 'Người bán không thể tự đặt giá.');
    }
    let threshold;
    try {
      threshold = minimumBidAmount({
        startingPrice: session.startingPrice,
        currentHighestBid: session.currentHighestBid,
        minimumIncrement: session.minimumIncrement,
      });
    } catch (error) {
      if (!(error instanceof RangeError)) throw error;
      throw new HttpsError(
        'failed-precondition',
        'Dữ liệu giá của phiên đấu giá không hợp lệ.',
      );
    }
    if (!Number.isSafeInteger(threshold) || amount < threshold) {
      throw new HttpsError(
        'failed-precondition',
        `Giá đặt tối thiểu là ${threshold} VNĐ.`,
      );
    }
    acceptedAt = now;
    transaction.create(bidRef, {
      sessionId: sessionRef.id,
      bidderUid,
      amount,
      bidTime: now,
    });
    transaction.update(sessionRef, {
      currentHighestBid: amount,
      highestBidderUid: bidderUid,
      status: 'active',
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    bidId: bidRef.id,
    bidderUid,
    bidTime: acceptedAt.toDate().toISOString(),
  };
});

exports.cancelAuctionSession = onCall(async (request) => {
  const uid = requireUid(request);
  const { sessionId } = request.data ?? {};
  if (typeof sessionId !== 'string' || sessionId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'sessionId không hợp lệ.');
  }
  const sessionRef = sessions.doc(sessionId.trim());
  const now = Timestamp.now();

  await db.runTransaction(async (transaction) => {
    const sessionSnapshot = await transaction.get(sessionRef);
    if (!sessionSnapshot.exists) {
      throw new HttpsError('not-found', 'Không tìm thấy phiên đấu giá.');
    }
    const session = sessionSnapshot.data();
    if (session.sellerUid !== uid) {
      throw new HttpsError('permission-denied', 'Bạn không sở hữu phiên này.');
    }
    if (session.status !== 'scheduled' ||
        !(session.startTime instanceof Timestamp) ||
        now.toMillis() >= session.startTime.toMillis()) {
      throw new HttpsError(
        'failed-precondition',
        'Chỉ có thể hủy phiên chưa bắt đầu.',
      );
    }
    const bidSnapshot = await transaction.get(
      bids.where('sessionId', '==', sessionRef.id).limit(1),
    );
    if (!bidSnapshot.empty) {
      throw new HttpsError(
        'failed-precondition',
        'Không thể hủy phiên đã có lượt đặt giá.',
      );
    }
    transaction.update(sessionRef, {
      status: 'cancelled',
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(items.doc(session.itemId), { status: 'available' });
  });

  return { sessionId: sessionId.trim(), status: 'cancelled' };
});

exports.updateAuctionStatuses = onSchedule('every 1 minutes', async () => {
  const now = Timestamp.now();
  const snapshot = await sessions
    .where('status', 'in', ['scheduled', 'active'])
    .get();
  await Promise.all(snapshot.docs.map((sessionDoc) =>
    db.runTransaction(async (transaction) => {
      const latest = await transaction.get(sessionDoc.ref);
      if (!latest.exists) return;
      const session = latest.data();
      if (session.status !== 'active' && session.status !== 'scheduled') return;

      const endTime = session.endTime ?? session.end_time;
      const startTime = session.startTime ?? session.start_time;
      if (!(endTime instanceof Timestamp) || !(startTime instanceof Timestamp)) {
        return;
      }
      if (endTime.toMillis() > now.toMillis()) {
        if (session.status === 'scheduled' && startTime.toMillis() <= now.toMillis()) {
          transaction.update(sessionDoc.ref, {
            status: 'active',
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      const currentHighestBid =
        session.currentHighestBid ?? session.current_highest_bid ?? 0;
      const highestBidderUid =
        session.highestBidderUid ??
        session.highest_bidder_uid ??
        session.highestBidderId ??
        null;
      const outcome = auctionOutcome({
        currentHighestBid,
        highestBidderUid,
      });
      const itemId = session.itemId ?? session.item_id;
      if (typeof itemId !== 'string' || itemId.length === 0) {
        throw new Error(`Auction session ${sessionDoc.id} has no valid item ID.`);
      }
      const itemRef = items.doc(itemId);
      const itemSnapshot = await transaction.get(itemRef);
      if (!itemSnapshot.exists) {
        throw new Error(
          `Auction session ${sessionDoc.id} references missing item ${itemId}.`,
        );
      }

      transaction.update(sessionDoc.ref, {
        status: outcome.status,
        result: outcome.result,
        winnerUid: outcome.winnerUid,
        winningBid: outcome.winningBid,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(itemRef, outcome.winnerUid
        ? {
          status: 'sold',
          winnerUid: outcome.winnerUid,
          soldPrice: outcome.winningBid,
          auctionSessionId: sessionDoc.id,
        }
        : {
          status: 'available',
          winnerUid: FieldValue.delete(),
          soldPrice: FieldValue.delete(),
          auctionSessionId: FieldValue.delete(),
        });
    }),
  ));
});
