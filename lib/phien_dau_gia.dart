import 'package:flutter/material.dart';

import 'Bid.dart';
import 'auction_session.dart';
import 'item.dart';
import 'services/firebase_service.dart';

class TrangDauGiaPage extends StatefulWidget {
  final String? sessionId;

  const TrangDauGiaPage({super.key, this.sessionId});

  @override
  State<TrangDauGiaPage> createState() => _TrangDauGiaPageState();
}

class _TrangDauGiaPageState extends State<TrangDauGiaPage> {
  late String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _selectedSessionId = widget.sessionId;
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseService.isFirebaseInitialized) {
      return _scaffold(
        body: const Center(
          child: Text(
            'Firebase chưa được khởi tạo. Không thể tải phiên đấu giá.',
          ),
        ),
      );
    }
    if (_selectedSessionId != null) {
      return StreamBuilder<AuctionSession?>(
        stream: FirebaseService.instance.getAuctionSessionStream(
          _selectedSessionId!,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _scaffold(
              body: _message('Không thể tải phiên đấu giá: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return _scaffold(
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final session = snapshot.data;
          if (session == null) {
            return _scaffold(
              onBack: _backToSessions,
              body: const Center(child: Text('Không tìm thấy phiên đấu giá.')),
            );
          }
          if (session.itemId.trim().isEmpty) {
            return _scaffold(
              onBack: _backToSessions,
              body: const Center(
                child: Text('Phiên đấu giá không có mã sản phẩm hợp lệ.'),
              ),
            );
          }
          return StreamBuilder<Item?>(
            stream: FirebaseService.instance.getItemStream(session.itemId),
            builder: (context, itemSnapshot) {
              if (itemSnapshot.hasError) {
                return _scaffold(
                  onBack: _backToSessions,
                  body: _message(
                    'Không thể tải sản phẩm: ${itemSnapshot.error}',
                  ),
                );
              }
              if (!itemSnapshot.hasData) {
                return _scaffold(
                  onBack: _backToSessions,
                  body: const Center(child: CircularProgressIndicator()),
                );
              }
              return _buildSession(session, itemSnapshot.data);
            },
          );
        },
      );
    }
    return _buildSessionList();
  }

  Widget _buildSessionList() {
    return StreamBuilder<List<AuctionSession>>(
      stream: FirebaseService.instance.getAuctionSessionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _scaffold(
            body: _message('Không thể tải danh sách phiên: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return _scaffold(
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final sessions = [...snapshot.data!]
          ..sort((a, b) => _endTime(a).compareTo(_endTime(b)));
        if (sessions.isEmpty) {
          return _scaffold(
            body: const Center(child: Text('Chưa có phiên đấu giá nào.')),
          );
        }
        return _scaffold(
          body: ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return StreamBuilder<Item?>(
                stream: FirebaseService.instance.getItemStream(session.itemId),
                builder: (context, itemSnapshot) {
                  if (itemSnapshot.hasError) {
                    return ListTile(
                      title: Text('Phiên ${session.sessionId}'),
                      subtitle: Text(
                        'Không thể tải sản phẩm: ${itemSnapshot.error}',
                      ),
                    );
                  }
                  final item = itemSnapshot.data;
                  return ListTile(
                    leading: const Icon(Icons.gavel),
                    title: Text(item?.itemName ?? 'Phiên ${session.sessionId}'),
                    subtitle: Text(
                      'Phiên ${session.sessionId} · ${session.status} · '
                      'Kết thúc: ${_formatDate(session.endTime)}',
                    ),
                    trailing: Text(
                      '${_formatPrice(session.currentHighestBid > 0 ? session.currentHighestBid : session.startingPrice)} đ',
                    ),
                    onTap: () =>
                        setState(() => _selectedSessionId = session.sessionId),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSession(AuctionSession session, Item? item) {
    final canBid = session.status == 'active';
    return _scaffold(
      onBack: _backToSessions,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (item?.imageUrl.isNotEmpty == true)
            SizedBox(
              height: 190,
              child: Image.network(
                item!.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image_outlined, size: 48),
              ),
            )
          else
            const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.image_outlined, size: 48)),
            ),
          if (item != null) ...[
            Text(
              item.itemName,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(item.description, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mã phiên: ${session.sessionId}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Trạng thái: ${session.status}'),
                  Text('Bắt đầu: ${_formatDate(session.startTime)}'),
                  Text('Kết thúc: ${_formatDate(session.endTime)}'),
                  Text(
                    'Giá hiện tại: ${_formatPrice(session.currentHighestBid > 0 ? session.currentHighestBid : session.startingPrice)} VNĐ',
                  ),
                  if (session.highestBidderUid?.isNotEmpty == true)
                    Text(
                      '${session.status == 'sold' ? 'Người thắng cuộc' : 'Người đang dẫn đầu'}: ${session.highestBidderUid}',
                    ),
                  if (session.result == 'no_bids')
                    const Text('Kết quả: Không có lượt đặt giá'),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Lịch sử trả giá'),
                    subtitle: Text(
                      'Giá cao nhất: ${_formatPrice(session.currentHighestBid)} đ',
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _buildBidHistoryList(session.sessionId)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: canBid ? () => _handleQuickBid(session) : null,
            child: Text(canBid ? 'Đặt giá nhanh' : 'Phiên không nhận đặt giá'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQuickBid(AuctionSession session) async {
    final amount = session.currentHighestBid > 0
        ? session.currentHighestBid + session.minimumIncrement
        : session.startingPrice;
    try {
      final bid = Bid(amount: amount, sessionId: session.sessionId);
      await FirebaseService.instance.placeBid(
        sessionId: session.sessionId,
        bid: bid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đặt giá thành công: ${_formatPrice(amount)} VNĐ'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget _buildBidHistoryList(String sessionId) {
    return StreamBuilder<List<Bid>>(
      stream: FirebaseService.instance.getBidHistoryStream(sessionId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Không thể tải lịch sử: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bids = snapshot.data!;
        if (bids.isEmpty) {
          return const Center(child: Text('Chưa có ai đặt giá'));
        }
        return ListView.separated(
          itemCount: bids.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final bid = bids[index];
            return ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(
                bid.bidderUid.isEmpty ? 'Người tham gia' : bid.bidderUid,
              ),
              subtitle: Text(_formatDate(bid.bidTime)),
              trailing: Text(
                '${_formatPrice(bid.bidAmount)} VNĐ',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _scaffold({required Widget body, VoidCallback? onBack}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đấu giá'),
        leading: onBack == null
            ? null
            : IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
      ),
      body: body,
    );
  }

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  void _backToSessions() => setState(() => _selectedSessionId = null);
}

DateTime _endTime(AuctionSession session) =>
    DateTime.tryParse(session.endTime) ??
    DateTime.fromMillisecondsSinceEpoch(0);

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return date.toLocal().toString();
}

String _formatPrice(int price) => price.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (match) => '.',
);
