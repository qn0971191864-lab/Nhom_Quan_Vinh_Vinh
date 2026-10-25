const test = require('node:test');
const assert = require('node:assert/strict');
const {
  auctionOutcome,
  isBidWindowOpen,
  minimumBidAmount,
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
