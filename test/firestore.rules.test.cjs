const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { Timestamp, doc, getDoc, setDoc } = require('firebase/firestore');

const projectId = 'demo-auction-rules';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'categories/1'), {
      categoryId: 1,
      categoryName: 'Books',
      iconUrl: '',
    });
    await setDoc(doc(db, 'items/1'), {
      id: 1,
      itemName: 'Book',
      startingPrice: 10,
      description: '',
      imageUrl: '',
      status: 'available',
      ownerUid: 'alice',
    });
    await setDoc(doc(db, 'auction_sessions/session-1'), {
      itemId: '1',
      sellerUid: 'alice',
      startingPrice: 10,
      minimumIncrement: 2,
      currentHighestBid: 0,
      highestBidderUid: null,
      startTime: Timestamp.fromDate(new Date('2026-10-24T12:00:00Z')),
      endTime: Timestamp.fromDate(new Date('2026-10-25T12:00:00Z')),
      status: 'scheduled',
      result: null,
    });
    await setDoc(doc(db, 'transactions/tx-1'), {
      transactionId: 1,
      userUid: 'alice',
      amount: 10,
      status: 'pending',
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test('denies unauthenticated catalog reads and all unknown paths', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'categories/1')));
  await assertFails(getDoc(doc(db, 'unlisted/secret')));
});

test('signed-in users read the catalog but cannot manage it', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'categories/1')));
  await assertSucceeds(getDoc(doc(db, 'items/1')));
  await assertFails(setDoc(doc(db, 'items/1'), {
    id: 1,
    itemName: 'Changed',
    startingPrice: 10,
    description: '',
    imageUrl: '',
    status: 'available',
    ownerUid: 'admin',
  }));
});

test('only an admin claim can manage valid categories and items', async () => {
  const db = testEnv.authenticatedContext('admin', { admin: true }).firestore();
  await assertSucceeds(setDoc(doc(db, 'categories/2'), {
    categoryId: 2,
    categoryName: 'Toys',
    iconUrl: '',
  }));
  await assertFails(setDoc(doc(db, 'items/2'), {
    id: 2,
    itemName: 'Invalid item',
    startingPrice: -1,
    description: '',
    imageUrl: '',
    status: 'available',
    ownerUid: 'admin',
  }));
  await assertSucceeds(setDoc(doc(db, 'items/2'), {
    id: 2,
    itemName: 'Valid item',
    startingPrice: 10,
    description: '',
    imageUrl: '',
    status: 'available',
  }));
});

test('users read and create only their own UID profile without role escalation', async () => {
  const db = testEnv.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  const ownProfile = doc(db, 'users/alice');
  const createdAt = Timestamp.now();
  await assertSucceeds(setDoc(ownProfile, {
    firebaseUid: 'alice',
    fullname: 'Alice',
    email: 'alice@example.com',
    role: 'USER',
    avatar: '',
    createdAt,
  }));
  await assertSucceeds(getDoc(ownProfile));
  await assertSucceeds(setDoc(ownProfile, {
    firebaseUid: 'alice',
    fullname: 'Alice Updated',
    email: 'alice@example.com',
    role: 'USER',
    avatar: '',
    createdAt,
  }));
  await assertFails(getDoc(doc(db, 'users/bob')));
  await assertFails(setDoc(doc(db, 'users/bob'), {
    firebaseUid: 'alice',
    fullname: 'Impersonated',
    email: 'alice@example.com',
    role: 'USER',
    avatar: '',
    createdAt: Timestamp.now(),
  }));
  await assertFails(setDoc(ownProfile, {
    firebaseUid: 'alice',
    fullname: 'Alice',
    email: 'alice@example.com',
    role: 'ADMIN',
    avatar: '',
    createdAt: '2026-10-24T12:00:00Z',
  }));
});

test('clients and admins cannot write auction state or bids directly', async () => {
  const userDb = testEnv.authenticatedContext('alice').firestore();
  const adminDb = testEnv.authenticatedContext('admin', { admin: true }).firestore();
  await assertSucceeds(getDoc(doc(userDb, 'auction_sessions/session-1')));
  await assertFails(setDoc(doc(userDb, 'auction_sessions/session-1'), {
    itemId: '1',
    sellerUid: 'alice',
    startingPrice: 10,
    minimumIncrement: 2,
    currentHighestBid: 999,
    highestBidderUid: 'alice',
    startTime: Timestamp.fromDate(new Date('2026-10-24T12:00:00Z')),
    endTime: Timestamp.fromDate(new Date('2026-10-25T12:00:00Z')),
    status: 'active',
  }));
  await assertFails(setDoc(doc(adminDb, 'auction_sessions/session-1'), {
    itemId: '1',
    sellerUid: 'admin',
    startingPrice: 10,
    minimumIncrement: 1,
    currentHighestBid: 0,
    highestBidderUid: null,
    startTime: Timestamp.fromDate(new Date('2026-10-24T12:00:00Z')),
    endTime: Timestamp.fromDate(new Date('2026-10-25T12:00:00Z')),
    status: 'scheduled',
    result: null,
  }));
  await assertFails(setDoc(doc(adminDb, 'bids/bid-1'), {
    bidderUid: 'alice',
    sessionId: 'session-1',
    amount: 20,
    bidTime: Timestamp.now(),
  }));
});

test('transaction reads are restricted to the owning Firebase UID', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(aliceDb, 'transactions/tx-1')));
  await assertFails(getDoc(doc(bobDb, 'transactions/tx-1')));
  await assertFails(setDoc(doc(aliceDb, 'transactions/tx-2'), {
    transactionId: 2,
    userUid: 'alice',
    amount: 100,
    status: 'success',
  }));
});
