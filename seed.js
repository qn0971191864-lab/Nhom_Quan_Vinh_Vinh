/**
 * seed.js
 * Script tự động khởi tạo dữ liệu mẫu (Seeder) lên Firebase Firestore
 * Dự án: app-dau-gia-36729
 * 
 * Script này sử dụng Firestore REST API v1 (Node.js fetch native),
 * không cần cài đặt thêm thư viện hay cấu hình service account private key phức tạp.
 * 
 * Khởi tạo đầy đủ 6 collections chuẩn khớp 100% với code Backend (Functions & Flutter):
 * 1. categories
 * 2. items
 * 3. auction_sessions
 * 4. bids
 * 5. users
 * 6. transactions
 */

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'app-dau-gia-36729';
const API_KEY = process.env.FIREBASE_API_KEY || 'AIzaSyBB6rIBS04UJr4SQEpx9Z0Hu20_sPlCaYI';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// Helper chuyển đổi giá trị JS sang kiểu dữ liệu Firestore REST API
function toFirestoreValue(val) {
  if (val === null || val === undefined) {
    return { nullValue: null };
  }
  if (val instanceof Date) {
    return { timestampValue: val.toISOString() };
  }
  if (typeof val === 'number') {
    if (Number.isInteger(val)) {
      return { integerValue: String(val) };
    }
    return { doubleValue: val };
  }
  if (typeof val === 'boolean') {
    return { booleanValue: val };
  }
  if (typeof val === 'string') {
    // Nếu là chuỗi ISO datetime
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(val)) {
      return { timestampValue: new Date(val).toISOString() };
    }
    return { stringValue: val };
  }
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [key, value] of Object.entries(obj)) {
    if (value !== undefined) {
      fields[key] = toFirestoreValue(value);
    }
  }
  return { fields };
}

async function setDocument(collection, docId, data) {
  const url = `${BASE_URL}/${collection}/${encodeURIComponent(docId)}?key=${API_KEY}`;
  const body = JSON.stringify(toFirestoreFields(data));

  const response = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: body,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Lỗi khi tạo doc ${collection}/${docId} (${response.status}): ${errorText}`);
  }

  console.log(`  [OK] Đã tạo document: ${collection}/${docId}`);
}

async function runSeed() {
  console.log('===============================================================');
  console.log(`Đang chạy Seed dữ liệu lên Cloud Firestore: [${PROJECT_ID}]`);
  console.log('===============================================================');

  const now = new Date();
  const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
  const oneDayLater = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const twoDaysLater = new Date(now.getTime() + 48 * 60 * 60 * 1000);

  // ---------------------------------------------------------------------------
  // 1. USERS
  // Khớp với validUserProfile trong firestore.rules và User model
  // ---------------------------------------------------------------------------
  console.log('\n1. Khởi tạo Collection [users]...');
  const users = [
    {
      id: 1,
      firebaseUid: 'user_vinh_001',
      fullname: 'Phạm Quang Vinh',
      email: 'vinh@example.com',
      role: 'USER',
      avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      createdAt: oneHourAgo,
    },
    {
      id: 2,
      firebaseUid: 'user_quan_002',
      fullname: 'Đỗ Hồng Quân',
      email: 'quan@example.com',
      role: 'USER',
      avatar: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
      createdAt: oneHourAgo,
    },
    {
      id: 3,
      firebaseUid: 'user_admin_001',
      fullname: 'Quản trị viên Hệ thống',
      email: 'admin@daugiatructuyen.vn',
      role: 'USER',
      avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
      createdAt: oneHourAgo,
    },
  ];

  for (const u of users) {
    await setDocument('users', u.firebaseUid, u);
  }

  // ---------------------------------------------------------------------------
  // 2. CATEGORIES
  // Khớp với validCategory trong firestore.rules và Category model
  // ---------------------------------------------------------------------------
  console.log('\n2. Khởi tạo Collection [categories]...');
  const categories = [
    { categoryId: 1, categoryName: 'Đồ điện tử & Công nghệ', iconUrl: 'https://cdn-icons-png.flaticon.com/512/3659/3659899.png' },
    { categoryId: 2, categoryName: 'Đồng hồ & Trang sức', iconUrl: 'https://cdn-icons-png.flaticon.com/512/3109/3109848.png' },
    { categoryId: 3, categoryName: 'Đồ cổ & Sưu tầm', iconUrl: 'https://cdn-icons-png.flaticon.com/512/2857/2857432.png' },
    { categoryId: 4, categoryName: 'Nghệ thuật & Hội họa', iconUrl: 'https://cdn-icons-png.flaticon.com/512/2972/2972046.png' },
    { categoryId: 5, categoryName: 'Xe cộ & Phụ tùng', iconUrl: 'https://cdn-icons-png.flaticon.com/512/3202/3202926.png' },
  ];

  for (const c of categories) {
    await setDocument('categories', String(c.categoryId), c);
  }

  // ---------------------------------------------------------------------------
  // 3. ITEMS
  // Khớp với validItem trong firestore.rules và Item model
  // (Đồng bộ cả dữ liệu cũ "Đồng hồ cổ Vintage" của bạn sang schema chuẩn)
  // ---------------------------------------------------------------------------
  console.log('\n3. Khởi tạo Collection [items]...');
  const items = [
    {
      id: 1,
      itemName: 'Đồng hồ cổ Vintage',
      description: 'Đồng hồ nguyên bản chạy tốt, mặt kính sapphire bọc vàng 18K cổ điển.',
      startingPrice: 1000000,
      imageUrl: 'https://images.unsplash.com/photo-1524805444758-089113d48a6d?w=500',
      status: 'in_auction',
      categoryId: 2,
      ownerUid: 'user_vinh_001',
    },
    {
      id: 2,
      itemName: 'iPhone 15 Pro Max 256GB Titan Tự Nhiên',
      description: 'Máy mới 100% nguyên seal chưa kích hoạt bảo hành chính hãng Apple VN.',
      startingPrice: 20000000,
      imageUrl: 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=500',
      status: 'in_auction',
      categoryId: 1,
      ownerUid: 'user_quan_002',
    },
    {
      id: 3,
      itemName: 'Tranh sơn dầu Phố Cổ Hà Nội 1990',
      description: 'Tác phẩm gốc của họa sĩ Bùi Xuân Phái vẽ bằng chất liệu sơn dầu trên toan.',
      startingPrice: 15000000,
      imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=500',
      status: 'in_auction',
      categoryId: 4,
      ownerUid: 'user_vinh_001',
    },
    {
      id: 4,
      itemName: 'Bình gốm Chu Đậu thời Lê sơ thế kỷ 15',
      description: 'Bình hoa lam vẽ chim thiên nga cổ vật quý hiếm có chứng nhận thẩm định.',
      startingPrice: 50000000,
      imageUrl: 'https://images.unsplash.com/photo-1615529182904-14819c35db37?w=500',
      status: 'available',
      categoryId: 3,
      ownerUid: 'user_admin_001',
    },
    {
      id: 5,
      itemName: 'Máy ảnh cơ Leica M6 TTL 0.72x Black',
      description: 'Hình thức Like New 99%, hoạt động đo sáng hoàn hảo kèm ống kính Summicron 35mm.',
      startingPrice: 45000000,
      imageUrl: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=500',
      status: 'available',
      categoryId: 1,
      ownerUid: 'user_quan_002',
    },
  ];

  for (const item of items) {
    await setDocument('items', String(item.id), item);
  }

  // ---------------------------------------------------------------------------
  // 4. AUCTION SESSIONS
  // Khớp với Functions createAuctionSession/placeBid và AuctionSession model
  // Có phiên 'P001' phục vụ màn hình phien_dau_gia.dart mặc định
  // ---------------------------------------------------------------------------
  console.log('\n4. Khởi tạo Collection [auction_sessions]...');
  const sessions = [
    {
      sessionId: 'P001',
      itemId: '1', // Đồng hồ cổ Vintage
      sellerUid: 'user_vinh_001',
      startingPrice: 1000000,
      minimumIncrement: 50000,
      currentHighestBid: 1200000,
      highestBidderUid: 'user_quan_002',
      startTime: oneHourAgo,
      endTime: oneDayLater,
      status: 'active',
      result: null,
      createdAt: oneHourAgo,
      updatedAt: now,
    },
    {
      sessionId: 'session-002',
      itemId: '2', // iPhone 15 Pro Max
      sellerUid: 'user_quan_002',
      startingPrice: 20000000,
      minimumIncrement: 500000,
      currentHighestBid: 21500000,
      highestBidderUid: 'user_vinh_001',
      startTime: oneHourAgo,
      endTime: twoDaysLater,
      status: 'active',
      result: null,
      createdAt: oneHourAgo,
      updatedAt: now,
    },
    {
      sessionId: 'session-003',
      itemId: '3', // Tranh sơn dầu
      sellerUid: 'user_vinh_001',
      startingPrice: 15000000,
      minimumIncrement: 500000,
      currentHighestBid: 0,
      highestBidderUid: null,
      startTime: now,
      endTime: twoDaysLater,
      status: 'scheduled',
      result: null,
      createdAt: now,
      updatedAt: now,
    },
  ];

  for (const s of sessions) {
    await setDocument('auction_sessions', s.sessionId, s);
  }

  // ---------------------------------------------------------------------------
  // 5. BIDS
  // Khớp với collection 'bids' trong functions và Bid model
  // ---------------------------------------------------------------------------
  console.log('\n5. Khởi tạo Collection [bids]...');
  const bids = [
    {
      bidId: 1,
      sessionId: 'P001',
      bidderUid: 'user_quan_002',
      amount: 1050000,
      bidTime: new Date(now.getTime() - 40 * 60 * 1000),
    },
    {
      bidId: 2,
      sessionId: 'P001',
      bidderUid: 'user_admin_001',
      amount: 1100000,
      bidTime: new Date(now.getTime() - 30 * 60 * 1000),
    },
    {
      bidId: 3,
      sessionId: 'P001',
      bidderUid: 'user_quan_002',
      amount: 1200000,
      bidTime: new Date(now.getTime() - 10 * 60 * 1000),
    },
    {
      bidId: 4,
      sessionId: 'session-002',
      bidderUid: 'user_vinh_001',
      amount: 21000000,
      bidTime: new Date(now.getTime() - 25 * 60 * 1000),
    },
    {
      bidId: 5,
      sessionId: 'session-002',
      bidderUid: 'user_admin_001',
      amount: 21500000,
      bidTime: new Date(now.getTime() - 5 * 60 * 1000),
    },
  ];

  for (const b of bids) {
    const docId = `bid_${b.sessionId}_${b.bidId}`;
    await setDocument('bids', docId, b);
  }

  // ---------------------------------------------------------------------------
  // 6. TRANSACTIONS
  // Khớp với TransactionService và TransactionModel
  // ---------------------------------------------------------------------------
  console.log('\n6. Khởi tạo Collection [transactions]...');
  const transactions = [
    {
      transactionId: 1001,
      amount: 5000000,
      paymentMethod: 'Ví MoMo',
      status: 'Thành công',
      userUid: 'user_vinh_001',
      createdAt: oneHourAgo,
    },
    {
      transactionId: 1002,
      amount: 20000000,
      paymentMethod: 'Chuyển khoản Vietcombank',
      status: 'Thành công',
      userUid: 'user_quan_002',
      createdAt: now,
    },
  ];

  for (const t of transactions) {
    await setDocument('transactions', String(t.transactionId), t);
  }

  console.log('\n===============================================================');
  console.log(' SEED DỮ LIỆU HOÀN TẤT THÀNH CÔNG 100%!');
  console.log(` Cả 6 collections trên Firebase [${PROJECT_ID}] đã sẵn sàng.`);
  console.log('===============================================================\n');
}

runSeed().catch((err) => {
  console.error('\n[LỖI KHI CHẠY SEED]:', err.message);
  process.exit(1);
});

