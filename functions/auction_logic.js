function minimumBidAmount({ startingPrice, currentHighestBid, minimumIncrement }) {
  if (!Number.isSafeInteger(startingPrice) ||
      !Number.isSafeInteger(currentHighestBid) ||
      !Number.isSafeInteger(minimumIncrement) ||
      startingPrice <= 0 ||
      currentHighestBid < 0 ||
      minimumIncrement <= 0) {
    throw new RangeError('Auction prices must be positive safe integers.');
  }
  return currentHighestBid === 0
    ? startingPrice
    : currentHighestBid + minimumIncrement;
}

function isBidWindowOpen({ now, startTime, endTime, status }) {
  return (status === 'scheduled' || status === 'active') &&
    now >= startTime &&
    now < endTime;
}

function auctionOutcome({ currentHighestBid, highestBidderUid }) {
  if (!Number.isSafeInteger(currentHighestBid) || currentHighestBid < 0) {
    throw new RangeError('Current highest bid must be a non-negative safe integer.');
  }
  if (currentHighestBid === 0) {
    return { status: 'ended', result: 'no_bids', winnerUid: null, winningBid: 0 };
  }
  if (typeof highestBidderUid !== 'string' || highestBidderUid.trim().length === 0) {
    throw new TypeError('A winning bid must have a bidder UID.');
  }
  return {
    status: 'sold',
    result: 'sold',
    winnerUid: highestBidderUid,
    winningBid: currentHighestBid,
  };
}

module.exports = { auctionOutcome, isBidWindowOpen, minimumBidAmount };
