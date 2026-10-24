import 'package:flutter/material.dart';

import 'Bid.dart';
import 'auction_session.dart';
import 'services/firebase_service.dart';

class TrangDauGiaPage extends StatefulWidget {
  final String sessionId;

  const TrangDauGiaPage({super.key, this.sessionId = 'P001'});

  @override
  State<TrangDauGiaPage> createState() => _TrangDauGiaPageState();
}

class _TrangDauGiaPageState extends State<TrangDauGiaPage> {
  // Dữ liệu dự phòng mặc định (dùng khi chưa kết nối Firebase hoặc trong môi trường test)
  late AuctionSession _currentSession;
  final List<Bid> _fallbackBids = [
    Bid(bidId: 1, userId: 101, bidAmount: 2500000, bidTime: '10:30 26/04/2026'),
    Bid(bidId: 2, userId: 102, bidAmount: 2300000, bidTime: '10:15 26/04/2026'),
    Bid(bidId: 3, userId: 103, bidAmount: 2100000, bidTime: '10:00 26/04/2026'),
  ];

  @override
  void initState() {
    super.initState();
    _currentSession = AuctionSession(
      sessionId: widget.sessionId,
      startingPrice: 2000000,
      currentHighestBid: 2500000,
      startTime: '08:00 26/04/2026',
      endTime: '12:00 26/04/2026',
      status: 'active',
    );
  }

  /// Xử lý sự kiện đặt giá nhanh (kết nối Firestore nếu khả dụng)
  Future<void> _handleQuickBid(AuctionSession session) async {
    const step = 100000;
    final currentBid = session.currentHighestBid > 0
        ? session.currentHighestBid
        : session.startingPrice;
    final nextBidAmount = currentBid + step;

    if (!FirebaseService.isFirebaseInitialized) {
      // Khi chưa khởi tạo Firebase (ví dụ: test widget hoặc offline)
      setState(() {
        _currentSession.currentHighestBid = nextBidAmount;
        _fallbackBids.insert(
          0,
          Bid(
            bidId: DateTime.now().millisecondsSinceEpoch,
            bidAmount: nextBidAmount,
            bidTime: DateTime.now().toIso8601String(),
            sessionId: session.sessionId,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã bấm Đặt Giá Nhanh! (Mức giá mới: ${nextBidAmount.toStringAsFixed(0)} VNĐ)',
          ),
        ),
      );
      return;
    }

    try {
      final newBid = Bid(
        bidAmount: nextBidAmount,
        sessionId: session.sessionId,
      );

      await FirebaseService.instance.placeBid(
        sessionId: session.sessionId,
        bid: newBid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Đặt giá thành công: ${nextBidAmount.toStringAsFixed(0)} VNĐ!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nếu Firebase đã được khởi tạo, lắng nghe Realtime Stream từ Firestore
    if (FirebaseService.isFirebaseInitialized) {
      return StreamBuilder<AuctionSession?>(
        stream: FirebaseService.instance.getAuctionSessionStream(
          widget.sessionId,
        ),
        builder: (context, sessionSnapshot) {
          final session = sessionSnapshot.data ?? _currentSession;
          return _buildScaffold(session);
        },
      );
    }

    // Nếu chưa khởi tạo Firebase, hiển thị dữ liệu mặc định
    return _buildScaffold(_currentSession);
  }

  Widget _buildScaffold(AuctionSession session) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiên Đấu Giá'),
        centerTitle: true,
        backgroundColor: Colors.grey[300],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Khung hiển thị ảnh sản phẩm
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  border: Border.all(color: Colors.black),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(size: Size.infinite, painter: CrossPainter()),
                    const Text(
                      'Featured Item Image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Card thông tin phiên đấu giá
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  border: Border.all(color: Colors.blueGrey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mã phiên: ${session.getMaPhien()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Bắt đầu: ${session.thoiGianBatDau}'),
                    Text('Kết thúc: ${session.thoiGianKetThuc}'),
                    if (session.currentHighestBid > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Giá cao nhất hiện tại: ${session.currentHighestBid.toStringAsFixed(0)} VNĐ',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Khung đếm ngược thời gian
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Live Countdown Timer',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'HH:MM:SS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Lịch sử trả giá (Realtime Firestore hoặc fallback)
              Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      color: Colors.grey[300],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Lịch sử trả giá',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Hiện tại: ${session.currentHighestBid.toStringAsFixed(0)} đ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black),
                    Expanded(child: _buildBidHistoryList(session.sessionId)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Nút Đặt Giá Nhanh
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => _handleQuickBid(session),
                  child: const Text(
                    'Nút Đặt Giá Nhanh',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget hiển thị danh sách các lượt đặt giá
  Widget _buildBidHistoryList(String sessionId) {
    if (!FirebaseService.isFirebaseInitialized) {
      return _renderBidListView(_fallbackBids);
    }

    return StreamBuilder<List<Bid>>(
      stream: FirebaseService.instance.getBidHistoryStream(sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final bids = snapshot.data ?? [];
        if (bids.isEmpty) {
          return const Center(
            child: Text(
              'Chưa có ai đặt giá',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return _renderBidListView(bids);
      },
    );
  }

  Widget _renderBidListView(List<Bid> bids) {
    return ListView.separated(
      itemCount: bids.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final bid = bids[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.account_circle, size: 24),
              const SizedBox(width: 8),
              Text(
                'User ${bid.bidderUid.isNotEmpty ? bid.bidderUid : bid.userId}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${bid.bidAmount} VNĐ',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1.0;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
