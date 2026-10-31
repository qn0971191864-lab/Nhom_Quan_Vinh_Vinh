const test = require('node:test');
const assert = require('node:assert/strict');
const {
  auctionOutcome,
  auctionOutcomeWithReserve,
  calculateFinalWinningPrice,
  calculateOrderTotal,
  getExtendedEndTime,
  hasSufficientWalletBalance,
  isBidWindowOpen,
  minimumBidAmount,
  resolveProxyBid,
} = require('../auction_logic');

test('expired auction with bids records a winner and sold result', () => {
  assert.deepEqual(
    auctionOutcome({ currentHighestBid: 150, highestBidderUid: 'winner-1' }),
    {
      status: 'sold',
      result: 'sold',
      winnerUid: 'winner-1',
      winningBid: 150,
    },
  );
});

test('expired auction without bids ends with no_bids', () => {
  assert.deepEqual(
    auctionOutcome({ currentHighestBid: 0, highestBidderUid: null }),
    {
      status: 'ended',
      result: 'no_bids',
      winnerUid: null,
      winningBid: 0,
    },
  );
});

test('winning bid without a bidder UID is rejected', () => {
  assert.throws(
    () => auctionOutcome({ currentHighestBid: 150, highestBidderUid: null }),
    TypeError,
  );
});

test('first bid threshold is starting price', () => {
  assert.equal(
    minimumBidAmount({
      startingPrice: 100,
      currentHighestBid: 0,
      minimumIncrement: 10,
    }),
    100,
  );
});

test('subsequent bid threshold includes the configured increment', () => {
  assert.equal(
    minimumBidAmount({
      startingPrice: 100,
      currentHighestBid: 150,
      minimumIncrement: 10,
    }),
    160,
  );
});

test('wallet balance must cover the maximum proxy bid', () => {
  assert.equal(hasSufficientWalletBalance(99, 100), false);
  assert.equal(hasSufficientWalletBalance(100, 100), true);
  assert.equal(hasSufficientWalletBalance(101, 100), true);
  assert.equal(hasSufficientWalletBalance(100, 0), false);
  assert.equal(hasSufficientWalletBalance(-1, 100), false);
});

test('invalid price configuration is rejected', () => {
  assert.throws(
    () => minimumBidAmount({
      startingPrice: 100,
      currentHighestBid: 0,
      minimumIncrement: 0,
    }),
    RangeError,
  );
});

test('bid window includes start and excludes end', () => {
  const window = {
    startTime: 100,
    endTime: 200,
    status: 'scheduled',
  };
  assert.equal(isBidWindowOpen({ ...window, now: 100 }), true);
  assert.equal(isBidWindowOpen({ ...window, now: 199 }), true);
  assert.equal(isBidWindowOpen({ ...window, now: 200 }), false);
});

test('closed sessions never accept bids', () => {
  for (const status of ['ended', 'cancelled', 'invalid']) {
    assert.equal(
      isBidWindowOpen({
        now: 150,
        startTime: 100,
        endTime: 200,
        status,
      }),
      false,
    );
  }
});

test('first proxy bid sets the starting price as effective price', () => {
  const result = resolveProxyBid({
    startingPrice: 100000,
    minimumIncrement: 5000,
    submittedMax: 150000,
    currentWinnerUid: null,
    currentPrice: 0,
    currentWinnerMax: 0,
    challengerUid: 'A',
  });
  assert.equal(result.winnerUid, 'A');
  assert.equal(result.effectivePrice, 100000);
});

test('higher proxy beats the leader by only one increment when possible', () => {
  const result = resolveProxyBid({
    startingPrice: 100000,
    minimumIncrement: 5000,
    submittedMax: 130000,
    currentWinnerUid: 'A',
    currentPrice: 105000,
    currentWinnerMax: 120000,
    challengerUid: 'B',
  });
  assert.equal(result.winnerUid, 'B');
  assert.equal(result.effectivePrice, 125000);
});

test('lower proxy keeps the first leader and raises the effective price', () => {
  const result = resolveProxyBid({
    startingPrice: 100000,
    minimumIncrement: 5000,
    submittedMax: 115000,
    currentWinnerUid: 'A',
    currentPrice: 105000,
    currentWinnerMax: 130000,
    challengerUid: 'B',
  });
  assert.equal(result.winnerUid, 'A');
  assert.equal(result.effectivePrice, 120000);
});

test('equal proxy maximum keeps the first bidder as winner', () => {
  const result = resolveProxyBid({
    startingPrice: 100000,
    minimumIncrement: 5000,
    submittedMax: 130000,
    currentWinnerUid: 'A',
    currentPrice: 130000,
    currentWinnerMax: 130000,
    challengerUid: 'B',
  });
  assert.equal(result.winnerUid, 'A');
});

test('soft-close extends by three minutes in the final window', () => {
  const result = getExtendedEndTime({
    now: 1000000,
    endTime: 1060000,
    extensionWindowMs: 2 * 60 * 1000,
    extensionMs: 3 * 60 * 1000,
    extensionCount: 2,
    maxExtensions: 10,
  });
  assert.equal(result.extended, true);
  assert.equal(result.extensionCount, 3);
  assert.equal(result.endTime, 1180000);
});

test('soft-close stops at the configured maximum', () => {
  const result = getExtendedEndTime({
    now: 1000000,
    endTime: 1060000,
    extensionWindowMs: 2 * 60 * 1000,
    extensionMs: 3 * 60 * 1000,
    extensionCount: 10,
    maxExtensions: 10,
  });
  assert.equal(result.extended, false);
});

test('final winning price uses one increment above the runner-up max', () => {
  assert.equal(calculateFinalWinningPrice({
    startingPrice: 100000,
    minimumIncrement: 5000,
    highestMax: 250000,
    secondMax: 180000,
  }), 185000);
});

test('single bidder wins at the starting price', () => {
  assert.equal(calculateFinalWinningPrice({
    startingPrice: 100000,
    minimumIncrement: 5000,
    highestMax: 250000,
  }), 100000);
});

test('order total adds shipping and subtracts winner deposit without charging fee twice', () => {
  assert.equal(calculateOrderTotal({
    winningBid: 185000,
    platformFeeRate: 0.05,
    shippingFee: 30000,
    depositApplied: 18500,
  }), 196500);
});

test('reserve not met expires the auction', () => {
  const result = auctionOutcomeWithReserve({
    currentHighestBid: 900000,
    highestBidderUid: 'A',
    reservePrice: 1000000,
  });
  assert.equal(result.status, 'expired');
  assert.equal(result.result, 'reserve_not_met');
  assert.equal(result.winnerUid, null);
});
