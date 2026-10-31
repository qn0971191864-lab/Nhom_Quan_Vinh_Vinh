import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import 'bid.dart';
import 'auction_session.dart';
import 'contact_page.dart';
import 'create_auction_page.dart';
import 'item.dart';
import 'news_page.dart';
import 'auction_payment_page.dart';
import 'services/firebase_service.dart';

class TrangDauGiaPage extends StatefulWidget {
  final String? sessionId;

  const TrangDauGiaPage({super.key, this.sessionId});

  @override
  State<TrangDauGiaPage> createState() => _TrangDauGiaPageState();
}

class _TrangDauGiaPageState extends State<TrangDauGiaPage> {
  late String? _selectedSessionId;
  late final StreamSubscription<firebase_auth.User?> _authSubscription;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _selectedSessionId = widget.sessionId;
    _isSignedIn = firebase_auth.FirebaseAuth.instance.currentUser != null;
    _authSubscription = firebase_auth.FirebaseAuth.instance
        .authStateChanges()
        .listen(
          (user) {
            if (!mounted) return;
            setState(() {
              _isSignedIn = user != null;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Lỗi theo dõi trạng thái đăng nhập: $error');
          },
        );
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
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
    final now = DateTime.now();
    final startTime = DateTime.tryParse(session.startTime);
    final endTime = DateTime.tryParse(session.endTime);
    final canBid =
        (session.status == 'scheduled' || session.status == 'active') &&
        startTime != null &&
        endTime != null &&
        !now.isBefore(startTime) &&
        now.isBefore(endTime);
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
                    _UserDisplayName(
                      uid: session.highestBidderUid!,
                      prefix:
                          '${session.status == 'sold' ? 'Người thắng cuộc' : 'Người đang dẫn đầu'}: ',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  if (session.result == 'no_bids')
                    const Text('Kết quả: Không có lượt đặt giá'),
                ],
              ),
            ),
          ),
          if ((session.status == 'won' || session.status == 'sold') &&
              (session.winnerUid?.isNotEmpty == true ||
                  session.highestBidderUid?.isNotEmpty == true)) ...[
            Builder(
              builder: (context) {
                final currentUid =
                    firebase_auth.FirebaseAuth.instance.currentUser?.uid;
                final winnerUid =
                    session.winnerUid ?? session.highestBidderUid ?? '';
                if (currentUid == null || currentUid != winnerUid) {
                  return const SizedBox.shrink();
                }
                final orderId =
                    session.orderId?.trim().isNotEmpty == true
                        ? session.orderId!.trim()
                        : 'order_${session.sessionId}';
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.emoji_events_rounded),
                      title: const Text('Bạn đã thắng phiên đấu giá!'),
                      subtitle: const Text(
                        'Thanh toán trong 48 giờ để giữ vật phẩm.',
                      ),
                      trailing: FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AuctionPaymentPage(orderId: orderId),
                          ),
                        ),
                        child: const Text('Thanh toán'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
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
            child: Text(
              canBid
                  ? (_isSignedIn ? 'Đặt giá tối đa' : 'Đăng nhập để đặt giá')
                  : startTime != null && now.isBefore(startTime)
                  ? 'Phiên chưa bắt đầu'
                  : 'Phiên không nhận đặt giá',
            ),
          ),
          if (_isSessionOwner(session) && session.status == 'scheduled') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmCancelSession(session),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Xóa phiên tôi vừa tạo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isSessionOwner(AuctionSession session) {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    return currentUser != null && session.sellerUid == currentUser.uid;
  }

  Future<void> _confirmCancelSession(AuctionSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phiên đấu giá?'),
        content: const Text(
          'Phiên chưa bắt đầu sẽ bị xóa khỏi danh sách đấu giá. Không thể hoàn tác thao tác này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa phiên'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await FirebaseService.instance.cancelAuctionSession(session.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa phiên đấu giá.')));
      _backToSessions();
    } catch (error) {
      if (!mounted) return;
      if (error.toString().contains('liên kết ít nhất một ví')) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cần liên kết ví'),
            content: const Text(
              'Bạn cần liên kết ít nhất một ví đã xác thực trước khi đặt giá.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContactPage()),
                  );
                },
                child: const Text('Liên kết ví ngay'),
              ),
            ],
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _handleQuickBid(AuctionSession session) async {
    if (firebase_auth.FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đặt giá.')),
      );
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ContactPage()));
      return;
    }

    final suggestedAmount = session.currentHighestBid > 0
        ? session.currentHighestBid + session.minimumIncrement
        : session.startingPrice;
    final controller = TextEditingController(
      text: suggestedAmount.toString(),
    );
    final maxAmount = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đặt giá tự động'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Giá tối đa của bạn (VNĐ)',
              helperText:
                  'Hệ thống sẽ tự tăng giá thay bạn đến mức tối đa này.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Đặt giá'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (maxAmount == null) return;
    try {
      final bid = Bid(amount: maxAmount, sessionId: session.sessionId);
      final data = await FirebaseService.instance.placeBid(
        sessionId: session.sessionId,
        bid: bid,
      );
      if (!mounted) return;
      final currentBid = data['currentHighestBid'] as int?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentBid == null
                ? 'Đặt giá tự động thành công'
                : 'Giá đấu hiện tại: ${_formatPrice(currentBid)} VNĐ',
          ),
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
              title: _UserDisplayName(
                uid: bid.bidderUid,
                fallbackText: 'Người tham gia',
                style: const TextStyle(fontWeight: FontWeight.w600),
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
        actions: [
          IconButton(
            tooltip: 'Thông báo phiên đấu giá',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewsPage(initialTab: 1)),
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Tạo phiên đấu giá',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateAuctionPage()),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
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

/// Widget hiển thị tên người dùng:
/// Map UID với collection users trên Firestore: fullname -> email -> UID rút gọn.
class _UserDisplayName extends StatefulWidget {
  final String uid;
  final String? prefix;
  final String fallbackText;
  final TextStyle? style;

  const _UserDisplayName({
    required this.uid,
    this.prefix,
    this.fallbackText = 'Người tham gia',
    this.style,
  });

  @override
  State<_UserDisplayName> createState() => _UserDisplayNameState();
}

class _UserDisplayNameState extends State<_UserDisplayName> {
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _resolveName();
  }

  @override
  void didUpdateWidget(covariant _UserDisplayName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _resolveName();
    }
  }

  void _resolveName() {
    final uid = widget.uid.trim();
    if (uid.isEmpty) {
      _displayName = widget.fallbackText;
      return;
    }

    if (FirebaseService.isCachedDisplayName(uid)) {
      _displayName = FirebaseService.getCachedDisplayName(uid);
      return;
    }

    _displayName = FirebaseService.formatShortUid(uid);

    FirebaseService.instance
        .getUserDisplayName(uid)
        .then((name) {
          if (!mounted) return;
          setState(() {
            _displayName = name;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          final fallback = FirebaseService.formatShortUid(uid);
          setState(() {
            _displayName = fallback;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName ?? FirebaseService.formatShortUid(widget.uid);
    return Text(
      '${widget.prefix ?? ''}$name',
      style: widget.style,
      overflow: TextOverflow.ellipsis,
    );
  }
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
