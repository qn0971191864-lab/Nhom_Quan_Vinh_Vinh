const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const {
  auctionOutcome,
  auctionOutcomeWithReserve,
  calculateFinalWinningPrice,
  calculateOrderTotal,
  calculateWalletReservation,
  getExtendedEndTime,
  isBidWindowOpen,
  minimumBidAmount,
  releaseWalletReservation,
  resolveProxyBid,
} = require('./auction_logic');

initializeApp();

const db = getFirestore();
const sessions = db.collection('auction_sessions');
const items = db.collection('items');
const bids = db.collection('bids');
const bidProxies = db.collection('bid_proxies');
const orders = db.collection('orders');
const deposits = db.collection('deposits');
const walletReservations = db.collection('wallet_reservations');
const escrowTransactions = db.collection('escrow_transactions');
const secondChanceOffers = db.collection('second_chance_offers');
const notifications = db.collection('notifications');

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Đăng nhập để thực hiện thao tác này.');
  }
  return uid;
}

function requireAdmin(request) {
  const uid = requireUid(request);
  if (request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Chỉ quản trị viên mới được thực hiện thao tác này.');
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

async function getWalletReservation(transaction, sessionId, userUid) {
  const reservationRef = walletReservations.doc(`${sessionId}_${userUid}`);
  const reservationSnapshot = await transaction.get(reservationRef);
  if (!reservationSnapshot.exists ||
      reservationSnapshot.get('status') !== 'active') {
    return null;
  }
  const userRef = db.collection('users').doc(userUid);
  const userSnapshot = await transaction.get(userRef);
  if (!userSnapshot.exists) {
    throw new HttpsError(
      'failed-precondition',
      'Không tìm thấy hồ sơ người đang giữ tiền trong ví.',
    );
  }
  return { reservationRef, reservationSnapshot, userRef, userSnapshot };
}

async function getSessionWalletReservations(transaction, sessionId, proxies) {
  const reservations = await Promise.all(proxies.map((proxy) =>
    getWalletReservation(transaction, sessionId, proxy.bidderUid),
  ));
  return reservations.filter((reservation) => reservation != null);
}

function releaseSessionWalletReservations(
  transaction,
  reservations,
  { exceptUid = null, now = Timestamp.now() } = {},
) {
  for (const reservation of reservations) {
    const userUid = reservation.reservationSnapshot.get('userUid');
    if (userUid === exceptUid) continue;

    const currentReservedBalance =
      reservation.userSnapshot.get('walletReservedBalance') ?? 0;
    let updatedReservedBalance;
    try {
      updatedReservedBalance = releaseWalletReservation(
        currentReservedBalance,
        reservation.reservationSnapshot.get('amount'),
      );
    } catch (error) {
      if (!(error instanceof RangeError)) throw error;
      throw new HttpsError(
        'failed-precondition',
        'Số tiền đang giữ trong ví không khớp dữ liệu đấu giá.',
      );
    }

    transaction.update(reservation.userRef, {
      walletReservedBalance: updatedReservedBalance,
      walletUpdatedAt: now,
    });
    transaction.update(reservation.reservationRef, {
      status: 'released',
      releasedAt: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

function retainWinningWalletReservation(
  transaction,
  reservations,
  userUid,
  amount,
  now,
) {
  const reservation = reservations.find(
    (entry) => entry.reservationSnapshot.get('userUid') === userUid,
  );
  if (!reservation) return;

  const previousAmount = reservation.reservationSnapshot.get('amount');
  if (!Number.isSafeInteger(amount) ||
      amount <= 0 ||
      !Number.isSafeInteger(previousAmount) ||
      previousAmount < amount) {
    throw new HttpsError(
      'failed-precondition',
      'Số tiền giữ chỗ của người thắng không hợp lệ.',
    );
  }
  if (previousAmount === amount) return;

  const currentReservedBalance =
    reservation.userSnapshot.get('walletReservedBalance') ?? 0;
  let updatedReservedBalance;
  try {
    updatedReservedBalance = releaseWalletReservation(
      currentReservedBalance,
      previousAmount - amount,
    );
  } catch (error) {
    if (!(error instanceof RangeError)) throw error;
    throw new HttpsError(
      'failed-precondition',
      'Số tiền đang giữ trong ví không khớp dữ liệu đấu giá.',
    );
  }

  transaction.update(reservation.userRef, {
    walletReservedBalance: updatedReservedBalance,
    walletUpdatedAt: now,
  });
  transaction.update(reservation.reservationRef, {
    amount,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

exports.createWalletTopup = onCall(async (request) => {
  const uid = requireUid(request);
  const amount = requirePositiveInteger(request.data?.amount, 'amount');
  const userSnapshot = await db.collection('users').doc(uid).get();
  if (!userSnapshot.exists) {
    throw new HttpsError('failed-precondition', 'Hồ sơ tài khoản chưa sẵn sàng.');
  }

  const topupRef = db.collection('wallet_topups').doc();
  await topupRef.create({
    userUid: uid,
    email: userSnapshot.get('email') ?? request.auth.token.email ?? '',
    fullname: userSnapshot.get('fullname') ?? '',
    amount,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
    reviewedAt: null,
    reviewedBy: null,
  });
  return { requestId: topupRef.id, status: 'pending' };
});

exports.reviewWalletTopup = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const { requestId, decision } = request.data ?? {};
  if (typeof requestId !== 'string' || requestId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'requestId không hợp lệ.');
  }
  if (decision !== 'approve' && decision !== 'reject') {
    throw new HttpsError('invalid-argument', 'decision phải là approve hoặc reject.');
  }

  const topupRef = db.collection('wallet_topups').doc(requestId.trim());
  await db.runTransaction(async (transaction) => {
    const topupSnapshot = await transaction.get(topupRef);
    if (!topupSnapshot.exists) {
      throw new HttpsError('not-found', 'Không tìm thấy yêu cầu nạp tiền.');
    }
    const topup = topupSnapshot.data();
    if (topup.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Yêu cầu này đã được xử lý.');
    }

    let userRef;
    let userSnapshot;
    if (decision === 'approve') {
      if (!Number.isSafeInteger(topup.amount) || topup.amount <= 0 ||
          typeof topup.userUid !== 'string') {
        throw new HttpsError('failed-precondition', 'Dữ liệu yêu cầu nạp tiền không hợp lệ.');
      }
      userRef = db.collection('users').doc(topup.userUid);
      userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw new HttpsError('not-found', 'Không tìm thấy hồ sơ người dùng.');
      }
      const currentBalance = userSnapshot.get('walletBalance') ?? 0;
      if (!Number.isSafeInteger(currentBalance) || currentBalance < 0 ||
          !Number.isSafeInteger(currentBalance + topup.amount)) {
        throw new HttpsError('failed-precondition', 'Số dư ví không hợp lệ hoặc vượt giới hạn.');
      }
      transaction.set(userRef, {
        walletBalance: currentBalance + topup.amount,
        walletUpdatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    transaction.update(topupRef, {
      status: decision === 'approve' ? 'approved' : 'rejected',
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedBy: adminUid,
    });
  });
  return { requestId: requestId.trim(), status: decision === 'approve' ? 'approved' : 'rejected' };
});

exports.grantAdminRole = onCall(async (request) => {
  requireAdmin(request);
  const email = request.data?.email;
  if (typeof email !== 'string' || !email.trim()) {
    throw new HttpsError('invalid-argument', 'Email tài khoản không hợp lệ.');
  }

  let target;
  try {
    target = await getAuth().getUserByEmail(email.trim());
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError('not-found', 'Không tìm thấy tài khoản với email này.');
    }
    throw error;
  }

  await getAuth().setCustomUserClaims(target.uid, {
    ...target.customClaims,
    admin: true,
  });
  await db.collection('users').doc(target.uid).set({
    email: target.email,
    role: 'ADMIN',
  }, { merge: true });
  return { uid: target.uid, email: target.email, role: 'ADMIN' };
});

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
  const buyNowPrice = request.data.buyNowPrice == null
    ? null
    : requirePositiveInteger(request.data.buyNowPrice, 'buyNowPrice');
  const reservePrice = request.data.reservePrice == null
    ? null
    : requirePositiveInteger(request.data.reservePrice, 'reservePrice');
  const extensionWindowMinutes = Number.isSafeInteger(request.data.extensionWindowMinutes)
    ? Math.max(1, request.data.extensionWindowMinutes)
    : 2;
  const extensionMinutes = Number.isSafeInteger(request.data.extensionMinutes)
    ? Math.max(1, request.data.extensionMinutes)
    : 3;
  if (buyNowPrice != null && buyNowPrice <= startingPrice) {
    throw new HttpsError('invalid-argument', 'buyNowPrice phải lớn hơn giá khởi điểm.');
  }
  if (reservePrice != null && reservePrice < startingPrice) {
    throw new HttpsError('invalid-argument', 'reservePrice không được thấp hơn giá khởi điểm.');
  }
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
      buyNowPrice,
      reservePrice,
      reservePriceMet: reservePrice == null,
      originalEndTime: endTime,
      currentHighestBid: 0,
      highestBidderUid: null,
      startTime,
      endTime,
      status: 'scheduled',
      result: null,
      antiSnipingEnabled: request.data.antiSnipingEnabled !== false,
      extensionWindowMinutes,
      extensionMinutes,
      maxExtensions: Number.isSafeInteger(request.data.maxExtensions)
        ? Math.max(0, request.data.maxExtensions)
        : 10,
      extensionCount: 0,
      lastExtendedAt: null,
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
  const submittedMax = requirePositiveInteger(
    request.data.maxAmount ?? request.data.amount,
    'maxAmount',
  );
  const sessionRef = sessions.doc(sessionId.trim());
  const bidRef = bids.doc();
  const userRef = db.collection('users').doc(bidderUid);
  let acceptedAt;
  let result;

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

    const proxyRef = bidProxies.doc(`${sessionRef.id}_${bidderUid}`);
    const reservationRef = walletReservations.doc(`${sessionRef.id}_${bidderUid}`);
    const [userSnapshot, proxySnapshot, reservationSnapshot, proxiesSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(proxyRef),
      transaction.get(reservationRef),
      transaction.get(
        bidProxies
          .where('sessionId', '==', sessionRef.id)
          .where('isActive', '==', true),
      ),
    ]);

    if (!userSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'Hồ sơ tài khoản chưa sẵn sàng.');
    }
    const existingProxy = proxySnapshot.exists ? proxySnapshot.data() : null;
    const previousMax = existingProxy?.isActive === true
      ? existingProxy.maxAmount
      : 0;
    const existingReservation = reservationSnapshot.exists &&
      reservationSnapshot.get('status') === 'active'
      ? reservationSnapshot.data()
      : null;
    if (existingReservation != null &&
        (!Number.isSafeInteger(existingReservation.amount) ||
         existingReservation.amount <= 0)) {
      throw new HttpsError(
        'failed-precondition',
        'Dữ liệu giữ tiền trong ví không hợp lệ.',
      );
    }

    const proxies = proxiesSnapshot.docs
      .map((doc) => ({ uid: doc.id.includes('_')
        ? doc.data().bidderUid
        : doc.data().bidderUid, ...doc.data(), ref: doc.ref }))
      .filter((proxy) => proxy.isActive === true &&
        proxy.bidderUid !== bidderUid &&
        Number.isSafeInteger(proxy.maxAmount))
      .sort((a, b) => b.maxAmount - a.maxAmount ||
        (a.createdAt?.toMillis?.() ?? 0) - (b.createdAt?.toMillis?.() ?? 0));

    let leader = proxies[0] ?? null;
    let resolution;
    try {
      if (leader) {
        const threshold = minimumBidAmount({
          startingPrice: session.startingPrice,
          currentHighestBid: session.currentHighestBid,
          minimumIncrement: session.minimumIncrement,
        });
        if (submittedMax < threshold && submittedMax <= leader.maxAmount) {
          throw new HttpsError(
            'failed-precondition',
            `Giá tối đa tối thiểu là ${threshold} VNĐ.`,
          );
        }
      }

      resolution = resolveProxyBid({
        startingPrice: session.startingPrice,
        currentHighestBid: session.currentHighestBid,
        minimumIncrement: session.minimumIncrement,
        submittedMax,
        currentWinnerUid: session.highestBidderUid,
        currentPrice: session.currentHighestBid,
        currentWinnerMax: leader?.bidderUid === session.highestBidderUid
          ? leader.maxAmount
          : previousMax,
        challengerUid: bidderUid,
        challengerPreviousMax: previousMax,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (!(error instanceof RangeError)) throw error;
      throw new HttpsError(
        'failed-precondition',
        'Dữ liệu giá của phiên đấu giá không hợp lệ.',
      );
    }

    const effectiveMax = resolution.effectiveMax;
    let effectivePrice = resolution.effectivePrice;
    const buyNowPrice = Number.isSafeInteger(session.buyNowPrice)
      ? session.buyNowPrice
      : null;
    const buyNowTriggered = buyNowPrice != null && effectiveMax >= buyNowPrice;

    if (buyNowTriggered) {
      effectivePrice = buyNowPrice;
    }

    const walletReservationAmount = buyNowTriggered
      ? effectivePrice
      : effectiveMax;
    let walletReservation;
    try {
      walletReservation = calculateWalletReservation({
        walletBalance: userSnapshot.get('walletBalance'),
        walletReservedBalance: userSnapshot.get('walletReservedBalance') ?? 0,
        previousReservation: existingReservation?.amount ?? 0,
        newReservation: walletReservationAmount,
      });
    } catch (error) {
      if (!(error instanceof RangeError)) throw error;
      throw new HttpsError(
        'failed-precondition',
        'Số dư ví hoặc số tiền đang giữ không hợp lệ.',
      );
    }
    if (walletReservation == null) {
      throw new HttpsError(
        'failed-precondition',
        `Số dư khả dụng không đủ để giữ ${walletReservationAmount} VNĐ.`,
      );
    }

    const reservePrice = Number.isSafeInteger(session.reservePrice)
      ? session.reservePrice
      : null;
    const reservePriceMet = reservePrice == null || effectivePrice >= reservePrice;

    if (effectivePrice > submittedMax && effectiveMax === submittedMax) {
      throw new HttpsError(
        'failed-precondition',
        `Giá tối đa chưa đủ để dẫn đầu. Giá tối thiểu là ${effectivePrice} VNĐ.`,
      );
    }

    const buyNowReservations = buyNowTriggered
      ? await getSessionWalletReservations(transaction, sessionRef.id, proxies)
      : [];

    acceptedAt = now;
    transaction.create(bidRef, {
      sessionId: sessionRef.id,
      bidderUid,
      amount: effectivePrice,
      eventType: resolution.previousLeaderUnchanged
        ? 'proxy_auto'
        : 'effective_bid',
      bidTime: now,
      kind: 'proxy',
    });
    transaction.set(proxyRef, {
      sessionId: sessionRef.id,
      bidderUid,
      maxAmount: effectiveMax,
      isActive: true,
      createdAt: existingProxy?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(reservationRef, {
      sessionId: sessionRef.id,
      userUid: bidderUid,
      amount: walletReservationAmount,
      status: 'active',
      createdAt: existingReservation?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(userRef, {
      walletReservedBalance: walletReservation.walletReservedBalance,
      walletUpdatedAt: now,
    });
    if (buyNowTriggered) {
      releaseSessionWalletReservations(transaction, buyNowReservations, {
        exceptUid: bidderUid,
        now,
      });
    }
    const depositAmount = Math.max(
      session.startingPrice,
      Math.ceil(effectiveMax * 0.1),
    );
    transaction.set(deposits.doc(`${sessionRef.id}_${bidderUid}`), {
      sessionId: sessionRef.id,
      userUid: bidderUid,
      role: 'bidder',
      status: 'locked',
      amount: depositAmount,
      currency: 'VND',
      createdAt: existingProxy?.depositCreatedAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    let endTime = session.endTime.toMillis();
    let extensionCount = Number.isSafeInteger(session.extensionCount)
      ? session.extensionCount
      : 0;
    let lastExtendedAt = session.lastExtendedAt ?? null;
    if (session.antiSnipingEnabled !== false) {
      const extension = getExtendedEndTime({
        now: now.toMillis(),
        endTime,
        extensionWindowMs: (session.extensionWindowMinutes ?? 2) * 60 * 1000,
        extensionMs: (session.extensionMinutes ?? 3) * 60 * 1000,
        extensionCount,
        maxExtensions: Number.isSafeInteger(session.maxExtensions)
          ? session.maxExtensions
          : 10,
      });
      endTime = extension.endTime;
      if (extension.extended) {
        extensionCount = extension.extensionCount;
        lastExtendedAt = now;
      }
    }

    transaction.update(sessionRef, {
      currentHighestBid: effectivePrice,
      highestBidderUid: buyNowTriggered ? bidderUid : resolution.winnerUid,
      reservePriceMet,
      status: buyNowTriggered ? 'won' : 'active',
      result: buyNowTriggered ? 'sold' : null,
      winnerUid: buyNowTriggered ? bidderUid : null,
      winningBid: buyNowTriggered ? effectivePrice : null,
      ...(buyNowTriggered ? { orderId: `order_${sessionRef.id}` } : {}),
      endTime: Timestamp.fromMillis(endTime),
      extensionCount,
      lastExtendedAt,
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (buyNowTriggered) {
      const itemRef = items.doc(session.itemId ?? session.item_id);
      const platformFeeRate = Number.isFinite(session.platformFeeRate)
        ? session.platformFeeRate
        : 0.05;
      const shippingFee = Number.isSafeInteger(session.shippingFee)
        ? session.shippingFee
        : 0;
      const totalAmount = calculateOrderTotal({
        winningBid: effectivePrice,
        platformFeeRate,
        shippingFee,
        depositApplied: depositAmount,
      });
      const buyNowOrderRef = orders.doc(`order_${sessionRef.id}`);
      transaction.set(buyNowOrderRef, {
        auctionId: sessionRef.id,
        itemId: session.itemId ?? session.item_id,
        sellerUid: session.sellerUid,
        buyerUid: bidderUid,
        status: 'PENDING_PAYMENT',
        winningBid: effectivePrice,
        platformFeeRate,
        platformFee: Math.round(effectivePrice * platformFeeRate),
        shippingFee,
        depositApplied: depositAmount,
        totalAmount,
        paymentDeadline: Timestamp.fromMillis(now.toMillis() + 48 * 60 * 60 * 1000),
        shippingAddress: null,
        paymentReference: null,
        escrowStatus: 'LOCKED_BY_PAYMENT',
        createdAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(escrowTransactions.doc(`escrow_${buyNowOrderRef.id}`), {
        orderId: buyNowOrderRef.id,
        buyerUid: bidderUid,
        sellerUid: session.sellerUid,
        amount: depositAmount,
        status: 'LOCKED',
        createdAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(notifications.doc(), {
        userUid: bidderUid,
        type: 'AUCTION_WON',
        auctionId: sessionRef.id,
        orderId: buyNowOrderRef.id,
        title: 'Bạn đã thắng phiên đấu giá',
        content: 'Vui lòng thanh toán trong 48 giờ.',
        isRead: false,
        createdAt: now,
      });
      transaction.update(itemRef, {
        status: 'sold',
        winnerUid: bidderUid,
        soldPrice: effectivePrice,
        auctionSessionId: sessionRef.id,
      });
      result = {
        status: 'won',
        winnerUid: bidderUid,
        winningBid: effectivePrice,
        buyNowTriggered: true,
      };
    } else {
      result = {
        status: 'active',
        winnerUid: resolution.winnerUid,
        currentHighestBid: effectivePrice,
        extensionCount,
        endTime: new Date(endTime).toISOString(),
        buyNowTriggered: false,
      };
    }
  });

  return {
    bidId: bidRef.id,
    bidderUid,
    bidTime: acceptedAt.toDate().toISOString(),
    ...result,
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
      const endTime = session.endTime ?? session.end_time;
      const startTime = session.startTime ?? session.start_time;
      if (!(endTime instanceof Timestamp) || !(startTime instanceof Timestamp)) return;
      if (endTime.toMillis() > now.toMillis()) {
        if (session.status === 'scheduled' && startTime.toMillis() <= now.toMillis()) {
          transaction.update(sessionDoc.ref, { status: 'active', updatedAt: FieldValue.serverTimestamp() });
        }
        return;
      }

      const itemId = session.itemId ?? session.item_id;
      const itemRef = items.doc(itemId);
      const proxySnapshot = await transaction.get(
        bidProxies.where('sessionId', '==', sessionDoc.id).where('isActive', '==', true),
      );
      const proxies = proxySnapshot.docs
        .map((doc) => ({ id: doc.id, ...doc.data() }))
        .sort((a, b) => b.maxAmount - a.maxAmount ||
          (a.createdAt?.toMillis?.() ?? 0) - (b.createdAt?.toMillis?.() ?? 0));
      const sessionReservations = await getSessionWalletReservations(
        transaction,
        sessionDoc.id,
        proxies,
      );
      const winner = proxies[0] ?? null;
      const reservePrice = Number.isSafeInteger(session.reservePrice)
        ? session.reservePrice
        : null;
      if (!winner) {
        releaseSessionWalletReservations(transaction, sessionReservations, { now });
        transaction.update(sessionDoc.ref, {
          status: 'expired',
          result: 'no_bids',
          winnerUid: null,
          winningBid: 0,
          settledAt: now,
          updatedAt: FieldValue.serverTimestamp(),
        });

        transaction.update(itemRef, {
          status: 'available',
          winnerUid: FieldValue.delete(),
          soldPrice: FieldValue.delete(),
          auctionSessionId: FieldValue.delete(),
        });
        for (const proxy of proxies) {
          transaction.set(deposits.doc(`${sessionDoc.id}_${proxy.bidderUid}`), {
            status: 'released', releasedAt: now, updatedAt: FieldValue.serverTimestamp(),
          }, { merge: true });
        }
        return;
      }

      const runnerUp = proxies[1] ?? null;
      const winningBid = calculateFinalWinningPrice({
        startingPrice: session.startingPrice,
        minimumIncrement: session.minimumIncrement,
        highestMax: winner.maxAmount,
        secondMax: runnerUp?.maxAmount ?? 0,
      });
      const reserveMet = reservePrice == null || winningBid >= reservePrice;
      if (!reserveMet) {
        releaseSessionWalletReservations(transaction, sessionReservations, { now });
        transaction.update(sessionDoc.ref, {
          status: 'expired',
          result: 'reserve_not_met',
          winnerUid: null,
          winningBid: 0,
          settledAt: now,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(itemRef, {
          status: 'available',
          winnerUid: FieldValue.delete(),
          soldPrice: FieldValue.delete(),
          auctionSessionId: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        for (const proxy of proxies) {
          transaction.set(deposits.doc(`${sessionDoc.id}_${proxy.bidderUid}`), {
            status: 'released',
            releasedAt: now,
            updatedAt: FieldValue.serverTimestamp(),
          }, { merge: true });
        }
        return;
      }

      const platformFeeRate = Number.isFinite(session.platformFeeRate)
        ? session.platformFeeRate
        : 0.05;
      const shippingFee = Number.isSafeInteger(session.shippingFee)
        ? session.shippingFee
        : 0;
      const winnerDepositRef = deposits.doc(`${sessionDoc.id}_${winner.bidderUid}`);
      const winnerDepositSnapshot = await transaction.get(winnerDepositRef);
      const winnerDepositAmount = winnerDepositSnapshot.exists
        ? (winnerDepositSnapshot.data().amount ?? 0)
        : Math.max(session.startingPrice, Math.ceil(winner.maxAmount * 0.1));
      const totalAmount = calculateOrderTotal({
        winningBid,
        platformFeeRate,
        shippingFee,
        depositApplied: winnerDepositAmount,
      });
      const paymentDeadline = Timestamp.fromMillis(now.toMillis() + 48 * 60 * 60 * 1000);
      const orderRef = orders.doc(`order_${sessionDoc.id}`);

      releaseSessionWalletReservations(transaction, sessionReservations, {
        exceptUid: winner.bidderUid,
        now,
      });
      retainWinningWalletReservation(
        transaction,
        sessionReservations,
        winner.bidderUid,
        winningBid,
        now,
      );
      transaction.set(orderRef, {
        auctionId: sessionDoc.id,
        itemId,
        sellerUid: session.sellerUid,
        buyerUid: winner.bidderUid,
        status: 'PENDING_PAYMENT',
        winningBid,
        platformFeeRate,
        platformFee: Math.round(winningBid * platformFeeRate),
        shippingFee,
        depositApplied: winnerDepositAmount,
        totalAmount,
        paymentDeadline,
        shippingAddress: null,
        paymentReference: null,
        escrowStatus: 'LOCKED_BY_PAYMENT',
        createdAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (winnerDepositSnapshot.exists) {
        transaction.update(winnerDepositRef, {
          status: 'applied_to_order',
          orderId: orderRef.id,
          appliedAt: now,
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(winnerDepositRef, {
          sessionId: sessionDoc.id,
          userUid: winner.bidderUid,
          role: 'bidder',
          status: 'applied_to_order',
          amount: winnerDepositAmount,
          orderId: orderRef.id,
          currency: 'VND',
          createdAt: now,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.set(escrowTransactions.doc(`escrow_${orderRef.id}`), {
        orderId: orderRef.id,
        buyerUid: winner.bidderUid,
        sellerUid: session.sellerUid,
        amount: winnerDepositAmount,
        status: 'LOCKED',
        createdAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });

      for (const proxy of proxies) {
        if (proxy.bidderUid === winner.bidderUid) continue;
        transaction.set(deposits.doc(`${sessionDoc.id}_${proxy.bidderUid}`), {
          status: 'released', releasedAt: now, updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      transaction.update(sessionDoc.ref, {
        status: 'won',
        result: 'sold',
        winnerUid: winner.bidderUid,
        winningBid,
        currentHighestBid: winningBid,
        highestBidderUid: winner.bidderUid,
        orderId: orderRef.id,
        settledAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(itemRef, {
        status: 'sold',
        winnerUid: winner.bidderUid,
        soldPrice: winningBid,
        auctionSessionId: sessionDoc.id,
      });
      transaction.set(notifications.doc(), {
        userUid: winner.bidderUid,
        type: 'AUCTION_WON',
        auctionId: sessionDoc.id,
        orderId: orderRef.id,
        title: 'Bạn đã thắng phiên đấu giá',
        content: 'Vui lòng thanh toán trong 48 giờ.',
        isRead: false,
        createdAt: now,
      });
    }),
  ));
});

exports.confirmOrderAddress = onCall(async (request) => {
  const uid = requireUid(request);
  const { orderId, shippingAddress } = request.data ?? {};
  if (typeof orderId !== 'string' || !shippingAddress ||
      typeof shippingAddress !== 'object') {
    throw new HttpsError('invalid-argument', 'Thông tin đơn hàng không hợp lệ.');
  }
  const orderRef = orders.doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy đơn hàng.');
    const order = snapshot.data();
    if (order.buyerUid !== uid) throw new HttpsError('permission-denied', 'Bạn không sở hữu đơn hàng này.');
    if (order.status !== 'PENDING_PAYMENT') {
      throw new HttpsError('failed-precondition', 'Đơn hàng không còn chờ thanh toán.');
    }
    transaction.update(orderRef, { shippingAddress, updatedAt: FieldValue.serverTimestamp() });
  });
  return { orderId, status: 'PENDING_PAYMENT' };
});

exports.paymentWebhook = onCall(async (request) => {
  const uid = requireUid(request);
  const { orderId, paymentReference, status, paidAmount, paymentMethod } = request.data ?? {};
  if (typeof orderId !== 'string' || typeof paymentReference !== 'string' ||
      !Number.isSafeInteger(paidAmount)) {
    throw new HttpsError('invalid-argument', 'Webhook thanh toán không hợp lệ.');
  }
  const orderRef = orders.doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy đơn hàng.');
    const order = snapshot.data();
    if (order.buyerUid !== uid) {
      throw new HttpsError('permission-denied', 'Bạn không sở hữu đơn hàng này.');
    }
    if (order.status !== 'PENDING_PAYMENT') return;
    if (status !== 'PAID' || paidAmount < order.totalAmount) {
      throw new HttpsError('failed-precondition', 'Thanh toán chưa đủ hoặc không thành công.');
    }
    const now = Timestamp.now();
    if (now.toMillis() > order.paymentDeadline.toMillis()) {
      throw new HttpsError('failed-precondition', 'Đơn hàng đã hết hạn thanh toán.');
    }
    const walletReservation = await getWalletReservation(
      transaction,
      order.auctionId,
      order.buyerUid,
    );
    releaseSessionWalletReservations(
      transaction,
      walletReservation == null ? [] : [walletReservation],
      { now },
    );
    transaction.update(orderRef, {
      status: 'PAID',
      paymentReference,
      paidAmount,
      paidAt: now,
      paymentMethod: typeof paymentMethod === 'string' ? paymentMethod : null,
      escrowStatus: 'ESCROW_HELD',
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(escrowTransactions.doc(`escrow_${orderId}`), {
      status: 'ESCROW_HELD',
      paidAmount,
      paymentReference,
      paidAt: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { orderId, status: 'PAID' };
});

exports.shipOrder = onCall(async (request) => {
  const uid = requireUid(request);
  const { orderId, trackingCode } = request.data ?? {};
  if (typeof orderId !== 'string') throw new HttpsError('invalid-argument', 'orderId không hợp lệ.');
  const orderRef = orders.doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy đơn hàng.');
    const order = snapshot.data();
    if (order.sellerUid !== uid) throw new HttpsError('permission-denied', 'Bạn không phải người bán.');
    if (order.status !== 'PAID') throw new HttpsError('failed-precondition', 'Đơn chưa thanh toán.');
    transaction.update(orderRef, {
      status: 'SHIPPING',
      trackingCode: typeof trackingCode === 'string' ? trackingCode : null,
      shippedAt: Timestamp.now(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { orderId, status: 'SHIPPING' };
});

exports.confirmDelivery = onCall(async (request) => {
  const uid = requireUid(request);
  const { orderId } = request.data ?? {};
  if (typeof orderId !== 'string') throw new HttpsError('invalid-argument', 'orderId không hợp lệ.');
  const orderRef = orders.doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy đơn hàng.');
    const order = snapshot.data();
    if (order.buyerUid !== uid) throw new HttpsError('permission-denied', 'Bạn không phải người mua.');
    if (order.status !== 'SHIPPING') throw new HttpsError('failed-precondition', 'Đơn chưa ở trạng thái vận chuyển.');
    const now = Timestamp.now();
    transaction.update(orderRef, { status: 'DELIVERED', deliveredAt: now, updatedAt: FieldValue.serverTimestamp() });
    transaction.update(escrowTransactions.doc(`escrow_${orderId}`), {
      status: 'READY_FOR_RELEASE',
      deliveredAt: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { orderId, status: 'DELIVERED' };
});

exports.completeOrder = onCall(async (request) => {
  const uid = requireUid(request);
  const { orderId } = request.data ?? {};
  if (typeof orderId !== 'string') throw new HttpsError('invalid-argument', 'orderId không hợp lệ.');
  const orderRef = orders.doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy đơn hàng.');
    const order = snapshot.data();
    if (order.buyerUid !== uid && order.sellerUid !== uid) {
      throw new HttpsError('permission-denied', 'Không có quyền hoàn tất đơn hàng.');
    }
    if (order.status !== 'DELIVERED') throw new HttpsError('failed-precondition', 'Chỉ hoàn tất đơn đã giao.');
    const now = Timestamp.now();
    transaction.update(orderRef, { status: 'COMPLETED', completedAt: now, updatedAt: FieldValue.serverTimestamp() });
    transaction.update(escrowTransactions.doc(`escrow_${orderId}`), {
      status: 'RELEASED_TO_SELLER',
      releasedAt: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(items.doc(order.itemId), {
      status: 'sold',
      delivered: true,
      completedAt: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { orderId, status: 'COMPLETED' };
});

exports.handlePaymentTimeout = onSchedule('every 10 minutes', async () => {
  const now = Timestamp.now();
  const snapshot = await orders
    .where('status', '==', 'PENDING_PAYMENT')
    .where('paymentDeadline', '<=', now)
    .get();
  await Promise.all(snapshot.docs.map((orderDoc) =>
    db.runTransaction(async (transaction) => {
      const orderSnapshot = await transaction.get(orderDoc.ref);
      if (!orderSnapshot.exists) return;
      const order = orderSnapshot.data();
      if (order.status !== 'PENDING_PAYMENT') return;
      if (order.paymentDeadline.toMillis() > now.toMillis()) return;

      const proxySnapshot = await transaction.get(
        bidProxies.where('sessionId', '==', order.auctionId).where('isActive', '==', true),
      );
      const proxies = proxySnapshot.docs
        .map((doc) => ({ id: doc.id, ...doc.data() }))
        .sort((a, b) => b.maxAmount - a.maxAmount ||
          (a.createdAt?.toMillis?.() ?? 0) - (b.createdAt?.toMillis?.() ?? 0));
      const runnerUp = proxies.find((proxy) => proxy.bidderUid !== order.buyerUid);
      const walletReservation = await getWalletReservation(
        transaction,
        order.auctionId,
        order.buyerUid,
      );
      releaseSessionWalletReservations(
        transaction,
        walletReservation == null ? [] : [walletReservation],
        { now },
      );

      transaction.update(orderDoc.ref, {
        status: 'CANCELLED_NON_PAYMENT',
        cancelledAt: now,
        cancelledReason: 'PAYMENT_TIMEOUT',
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(deposits.doc(`${order.auctionId}_${order.buyerUid}`), {
        status: 'forfeited',
        forfeitedAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.update(escrowTransactions.doc(`escrow_${orderDoc.id}`), {
        status: 'FORFEITED',
        forfeitedAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(db.collection('users').doc(order.buyerUid), {
        reputationScore: FieldValue.increment(-10),
        nonPayingBidCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.update(items.doc(order.itemId), {
        status: 'relistable',
        winnerUid: FieldValue.delete(),
        soldPrice: FieldValue.delete(),
        auctionSessionId: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(sessions.doc(order.auctionId), {
        status: 'expired',
        result: 'winner_non_payment',
        winnerUid: null,
        winningBid: 0,
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (!runnerUp) return;
      const offerRef = secondChanceOffers.doc(`offer_${order.auctionId}_${runnerUp.bidderUid}`);
      transaction.set(offerRef, {
        auctionId: order.auctionId,
        itemId: order.itemId,
        originalWinnerUid: order.buyerUid,
        bidderUid: runnerUp.bidderUid,
        offerPrice: runnerUp.maxAmount,
        status: 'PENDING',
        expiresAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
        createdAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(notifications.doc(), {
        userUid: runnerUp.bidderUid,
        type: 'SECOND_CHANCE_OFFER',
        auctionId: order.auctionId,
        offerId: offerRef.id,
        title: 'Bạn có cơ hội mua vật phẩm',
        content: `Chấp nhận trong 24 giờ với giá ${runnerUp.maxAmount} VNĐ.`,
        isRead: false,
        createdAt: now,
      });
    }),
  ));
});

exports.respondSecondChance = onCall(async (request) => {
  const uid = requireUid(request);
  const { offerId, decision } = request.data ?? {};
  if (typeof offerId !== 'string' || !['ACCEPTED', 'REJECTED'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'Thông tin đề nghị không hợp lệ.');
  }
  const offerRef = secondChanceOffers.doc(offerId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(offerRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy đề nghị.');
    const offer = snapshot.data();
    if (offer.bidderUid !== uid) throw new HttpsError('permission-denied', 'Bạn không sở hữu đề nghị này.');
    if (offer.status !== 'PENDING') throw new HttpsError('failed-precondition', 'Đề nghị đã được xử lý.');
    const now = Timestamp.now();
    if (now.toMillis() > offer.expiresAt.toMillis()) {
      transaction.update(offerRef, { status: 'EXPIRED', updatedAt: FieldValue.serverTimestamp() });
      throw new HttpsError('failed-precondition', 'Đề nghị đã hết hạn.');
    }
    if (decision === 'REJECTED') {
      transaction.update(offerRef, {
        status: 'REJECTED',
        respondedAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(items.doc(offer.itemId), {
        status: 'relistable',
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const userRef = db.collection('users').doc(uid);
    const reservationRef = walletReservations.doc(`${offer.auctionId}_${uid}`);
    const [auctionSnapshot, userSnapshot, reservationSnapshot] = await Promise.all([
      transaction.get(sessions.doc(offer.auctionId)),
      transaction.get(userRef),
      transaction.get(reservationRef),
    ]);
    if (!auctionSnapshot.exists || !userSnapshot.exists) {
      throw new HttpsError(
        'failed-precondition',
        'Không tìm thấy hồ sơ tài khoản hoặc phiên đấu giá.',
      );
    }
    const auction = auctionSnapshot.data();
    const existingReservation = reservationSnapshot.exists &&
      reservationSnapshot.get('status') === 'active'
      ? reservationSnapshot.data()
      : null;
    let walletReservation;
    try {
      walletReservation = calculateWalletReservation({
        walletBalance: userSnapshot.get('walletBalance'),
        walletReservedBalance: userSnapshot.get('walletReservedBalance') ?? 0,
        previousReservation: existingReservation?.amount ?? 0,
        newReservation: offer.offerPrice,
      });
    } catch (error) {
      if (!(error instanceof RangeError)) throw error;
      throw new HttpsError(
        'failed-precondition',
        'Số dư ví hoặc số tiền đang giữ không hợp lệ.',
      );
    }
    if (walletReservation == null) {
      throw new HttpsError(
        'failed-precondition',
        `Số dư khả dụng không đủ để giữ ${offer.offerPrice} VNĐ.`,
      );
    }

    const paymentDeadline = Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000);
    const orderRef = orders.doc(`second_chance_${offer.auctionId}_${uid}`);
    transaction.set(userRef, {
      walletReservedBalance: walletReservation.walletReservedBalance,
      walletUpdatedAt: now,
    }, { merge: true });
    transaction.set(reservationRef, {
      sessionId: offer.auctionId,
      userUid: uid,
      amount: offer.offerPrice,
      status: 'active',
      createdAt: existingReservation?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(orderRef, {
      auctionId: offer.auctionId,
      itemId: offer.itemId,
      sellerUid: auction.sellerUid,
      buyerUid: uid,
      status: 'PENDING_PAYMENT',
      winningBid: offer.offerPrice,
      platformFeeRate: 0.05,
      platformFee: Math.round(offer.offerPrice * 0.05),
      shippingFee: 0,
      depositApplied: 0,
      totalAmount: Math.round(offer.offerPrice * 1.05),
      paymentDeadline,
      shippingAddress: null,
      paymentReference: null,
      escrowStatus: 'LOCKED_BY_PAYMENT',
      source: 'SECOND_CHANCE',
      createdAt: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(offerRef, {
      status: 'ACCEPTED',
      respondedAt: now,
      orderId: orderRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(items.doc(offer.itemId), {
      status: 'sold',
      winnerUid: uid,
      soldPrice: offer.offerPrice,
      auctionSessionId: offer.auctionId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(escrowTransactions.doc(`escrow_${orderRef.id}`), {
      orderId: orderRef.id,
      buyerUid: uid,
      sellerUid: auction.sellerUid,
      amount: 0,
      status: 'LOCKED',
      createdAt: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { offerId, status: decision };
});

exports.expireSecondChanceOffers = onSchedule('every 10 minutes', async () => {
  const now = Timestamp.now();
  const snapshot = await secondChanceOffers
    .where('status', '==', 'PENDING')
    .where('expiresAt', '<=', now)
    .get();
  await Promise.all(snapshot.docs.map((offerDoc) =>
    db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(offerDoc.ref);
      if (!snapshot.exists) return;
      const offer = snapshot.data();
      if (offer.status !== 'PENDING') return;
      transaction.update(offerDoc.ref, {
        status: 'EXPIRED',
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(items.doc(offer.itemId), {
        status: 'relistable',
        winnerUid: FieldValue.delete(),
        soldPrice: FieldValue.delete(),
        auctionSessionId: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }),
  ));
});
