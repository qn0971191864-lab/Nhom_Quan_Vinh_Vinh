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

function hasSufficientWalletBalance(walletBalance, requiredAmount) {
  return Number.isSafeInteger(walletBalance) &&
    walletBalance >= 0 &&
    Number.isSafeInteger(requiredAmount) &&
    requiredAmount > 0 &&
    walletBalance >= requiredAmount;
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

function resolveProxyBid({
  startingPrice,
  minimumIncrement,
  submittedMax,
  currentWinnerUid,
  currentPrice,
  currentWinnerMax,
  challengerUid,
  challengerPreviousMax = 0,
}) {
  if (!Number.isSafeInteger(submittedMax) || submittedMax <= 0) {
    throw new RangeError('The submitted proxy maximum must be a positive safe integer.');
  }
  if (!Number.isSafeInteger(minimumIncrement) || minimumIncrement <= 0) {
    throw new RangeError('Minimum increment must be a positive safe integer.');
  }

  const effectiveMax = Math.max(submittedMax, challengerPreviousMax);
  if (effectiveMax < startingPrice) {
    throw new RangeError(`Proxy maximum must be at least ${startingPrice}.`);
  }

  if (!currentWinnerUid) {
    return {
      winnerUid: challengerUid,
      effectivePrice: startingPrice,
      effectiveMax,
      previousLeaderUnchanged: false,
    };
  }

  if (effectiveMax > currentWinnerMax) {
    return {
      winnerUid: challengerUid,
      effectivePrice: Math.max(
        startingPrice,
        Math.min(effectiveMax, currentWinnerMax + minimumIncrement),
      ),
      effectiveMax,
      previousLeaderUnchanged: false,
    };
  }

  return {
    winnerUid: currentWinnerUid,
    effectivePrice: Math.max(
      currentPrice,
      Math.min(currentWinnerMax, effectiveMax + minimumIncrement),
    ),
    effectiveMax,
    previousLeaderUnchanged: true,
  };
}

function auctionOutcomeWithReserve({
  currentHighestBid,
  highestBidderUid,
  reservePrice = null,
}) {
  const basic = auctionOutcome({
    currentHighestBid,
    highestBidderUid,
  });
  if (basic.result === 'no_bids') return { ...basic, status: 'expired', result: 'no_bids' };
  if (Number.isSafeInteger(reservePrice) &&
      reservePrice > 0 &&
      currentHighestBid < reservePrice) {
    return {
      status: 'expired',
      result: 'reserve_not_met',
      winnerUid: null,
      winningBid: currentHighestBid,
    };
  }
  return { ...basic, status: 'won', result: 'sold' };
}

function calculateFinalWinningPrice({
  startingPrice,
  minimumIncrement,
  highestMax,
  secondMax = 0,
}) {
  if (!Number.isSafeInteger(highestMax) || highestMax < startingPrice) {
    throw new RangeError('Highest proxy max is invalid.');
  }
  if (!Number.isSafeInteger(minimumIncrement) || minimumIncrement <= 0) {
    throw new RangeError('Minimum increment is invalid.');
  }
  if (secondMax <= 0) return startingPrice;
  return Math.max(
    startingPrice,
    Math.min(highestMax, secondMax + minimumIncrement),
  );
}

function calculateOrderTotal({
  winningBid,
  platformFeeRate = 0,
  shippingFee = 0,
  depositApplied = 0,
}) {
  return Math.max(
    0,
    winningBid + shippingFee - depositApplied,
  );
}

function calculateSellerSettlement({ winningBid, platformFeeRate = 0.05 }) {
  if (!Number.isSafeInteger(winningBid) || winningBid < 0) {
    throw new RangeError('Winning bid must be a non-negative safe integer.');
  }
  if (!Number.isFinite(platformFeeRate) || platformFeeRate < 0 || platformFeeRate >= 1) {
    throw new RangeError('Platform fee rate is invalid.');
  }
  const platformFee = Math.round(winningBid * platformFeeRate);
  return {
    platformFee,
    netAmount: Math.max(0, winningBid - platformFee),
  };
}

function getExtendedEndTime({
  now,
  endTime,
  extensionWindowMs,
  extensionMs,
  extensionCount,
  maxExtensions,
}) {
  if (extensionCount >= maxExtensions ||
      now >= endTime ||
      endTime - now > extensionWindowMs) {
    return { endTime, extensionCount, extended: false };
  }

  const extendedEndTime = Math.max(endTime, now + extensionMs);
  if (extendedEndTime <= endTime) {
    return { endTime, extensionCount, extended: false };
  }
  return {
    endTime: extendedEndTime,
    extensionCount: extensionCount + 1,
    extended: true,
  };
}

module.exports = {
  auctionOutcome,
  auctionOutcomeWithReserve,
  getExtendedEndTime,
  hasSufficientWalletBalance,
  isBidWindowOpen,
  minimumBidAmount,
  resolveProxyBid,
  calculateFinalWinningPrice,
  calculateOrderTotal,
  calculateSellerSettlement,
};
