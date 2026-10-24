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

module.exports = { isBidWindowOpen, minimumBidAmount };
