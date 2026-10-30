import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auction_session.dart';
import 'bid.dart';
import 'item.dart';
import 'services/firebase_service.dart';
import 'services/transaction_service.dart';
import 'transaction.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirebaseService.isFirebaseInitialized) {
      return _messageScaffold('Firebase chưa được khởi tạo.');
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hoạt động & giao dịch')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hoạt động & giao dịch')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Vui lòng đăng nhập để xem lịch sử hoạt động.'),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Hoạt động & giao dịch')),
          body: StreamBuilder<List<Bid>>(
            stream: FirebaseFirestore.instance
                .collection('bids')
                .where('bidderUid', isEqualTo: user.uid)
                .snapshots()
                .map(
                  (snapshot) => snapshot.docs
                      .map((doc) => Bid.fromMap(doc.data(), doc.id))
                      .toList(),
                ),
            builder: (context, bidSnapshot) {
              return StreamBuilder<List<AuctionSession>>(
                stream: FirebaseFirestore.instance
                    .collection('auction_sessions')
                    .where('sellerUid', isEqualTo: user.uid)
                    .snapshots()
                    .map(
                      (snapshot) => snapshot.docs
                          .map(
                            (doc) => AuctionSession.fromMap(doc.data(), doc.id),
                          )
                          .toList(),
                    ),
                builder: (context, sessionSnapshot) {
                  return StreamBuilder<List<TransactionModel>>(
                    stream: TransactionService.instance.getTransactionsStream(
                      userUid: user.uid,
                    ),
                    builder: (context, transactionSnapshot) {
                      final loading =
                          !bidSnapshot.hasData ||
                          !sessionSnapshot.hasData ||
                          !transactionSnapshot.hasData;
                      final firstError =
                          bidSnapshot.error ??
                          sessionSnapshot.error ??
                          transactionSnapshot.error;
                      if (firstError != null) {
                        return Center(
                          child: Text('Không thể tải lịch sử: $firstError'),
                        );
                      }
                      if (loading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final entries = <_ActivityEntry>[];
                      for (final bid in bidSnapshot.data!) {
                        entries.add(_ActivityEntry.bid(bid));
                      }
                      for (final session in sessionSnapshot.data!) {
                        entries.add(_ActivityEntry.session(session));
                      }
                      for (final transaction in transactionSnapshot.data!) {
                        entries.add(_ActivityEntry.transaction(transaction));
                      }
                      entries.sort((a, b) => b.time.compareTo(a.time));

                      if (entries.isEmpty) {
                        return const Center(
                          child: Text('Bạn chưa có hoạt động nào.'),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _activityTile(context, entries[index]),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _activityTile(BuildContext context, _ActivityEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF252526) : null,
      child: ListTile(
        onTap: () => _showActivityDetails(context, entry),
        leading: CircleAvatar(
          backgroundColor: entry.color.withValues(alpha: 0.16),
          child: Icon(entry.icon, color: entry.color),
        ),
        title: Text(
          entry.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${entry.subtitle}\n${_formatDate(entry.time)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Future<void> _showActivityDetails(
    BuildContext context,
    _ActivityEntry entry,
  ) async {
    String itemName = '';
    Item? item;
    AuctionSession? session;
    if (entry.bid != null || entry.session != null) {
      session = entry.session;
      if (entry.bid != null) {
        session = await FirebaseFirestore.instance
            .collection('auction_sessions')
            .doc(entry.bid!.sessionId)
            .get()
            .then(
              (doc) => doc.exists
                  ? AuctionSession.fromMap(doc.data()!, doc.id)
                  : null,
            );
      }
      if (session != null) {
        item = await FirebaseFirestore.instance
            .collection('items')
            .doc(session.itemId)
            .get()
            .then(
              (doc) => doc.exists ? Item.fromMap(doc.data()!, doc.id) : null,
            );
      }
      itemName =
          item?.itemName ??
          (session == null ? 'Không xác định' : 'Sản phẩm #${session.itemId}');
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    entry.detailTitle,
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  ...entry
                      .details(itemName)
                      .map(
                        (detail) =>
                            _detailRow(sheetContext, detail.$1, detail.$2),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _messageScaffold(String message) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử giao dịch')),
    body: Center(child: Text(message)),
  );

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

enum _ActivityType { transaction, bid, session }

class _ActivityEntry {
  _ActivityEntry._({
    required this.type,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.detailTitle,
    required this.icon,
    required this.color,
    this.bid,
    this.session,
    this.transaction,
  });

  final _ActivityType type;
  final DateTime time;
  final String title;
  final String subtitle;
  final String detailTitle;
  final IconData icon;
  final Color color;
  final Bid? bid;
  final AuctionSession? session;
  final TransactionModel? transaction;

  factory _ActivityEntry.transaction(TransactionModel transaction) {
    return _ActivityEntry._(
      type: _ActivityType.transaction,
      time: transaction.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      title: 'Giao dịch #${transaction.transactionId}',
      subtitle:
          '${transaction.amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ • ${transaction.status}',
      detailTitle: 'Chi tiết giao dịch',
      icon: Icons.receipt_long_outlined,
      color: const Color(0xFF4D9EE8),
      transaction: transaction,
    );
  }

  factory _ActivityEntry.bid(Bid bid) {
    return _ActivityEntry._(
      type: _ActivityType.bid,
      time:
          DateTime.tryParse(bid.bidTime)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title:
          'Đặt giá ${bid.amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ',
      subtitle: 'Phiên đấu giá #${bid.sessionId}',
      detailTitle: 'Chi tiết lượt đặt giá',
      icon: Icons.gavel_rounded,
      color: const Color(0xFFC49A55),
      bid: bid,
    );
  }

  factory _ActivityEntry.session(AuctionSession session) {
    final start =
        DateTime.tryParse(session.startTime)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return _ActivityEntry._(
      type: _ActivityType.session,
      time: start,
      title: 'Tạo phiên đấu giá',
      subtitle: 'Phiên #${session.sessionId} • ${session.status}',
      detailTitle: 'Chi tiết phiên đã tạo',
      icon: Icons.add_circle_outline_rounded,
      color: const Color(0xFF6AA84F),
      session: session,
    );
  }

  List<(String, String)> details(String itemName) {
    switch (type) {
      case _ActivityType.bid:
        final bid = this.bid!;
        return [
          ('Hoạt động', 'Đặt giá đấu giá'),
          ('Sản phẩm', itemName),
          ('Mã phiên', bid.sessionId),
          (
            'Số tiền đặt',
            '${bid.amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ',
          ),
          ('Thời gian', TransactionHistoryPage._formatDate(time)),
          (
            'Mã lượt đặt',
            bid.bidId > 0 ? bid.bidId.toString() : bid.documentId,
          ),
        ];
      case _ActivityType.session:
        final session = this.session!;
        final start = DateTime.tryParse(session.startTime);
        final end = DateTime.tryParse(session.endTime);
        return [
          ('Hoạt động', 'Tạo phiên đấu giá'),
          ('Sản phẩm', itemName),
          ('Mã phiên', session.sessionId),
          ('Mã vật phẩm', session.itemId),
          (
            'Giá khởi điểm',
            '${session.startingPrice.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ',
          ),
          (
            'Bước giá tối thiểu',
            '${session.minimumIncrement.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ',
          ),
          (
            'Bắt đầu',
            start == null
                ? session.startTime
                : TransactionHistoryPage._formatDate(start),
          ),
          (
            'Kết thúc',
            end == null
                ? session.endTime
                : TransactionHistoryPage._formatDate(end),
          ),
          ('Trạng thái', session.status),
        ];
      case _ActivityType.transaction:
        final transaction = this.transaction!;
        return [
          ('Hoạt động', 'Thanh toán / giao dịch'),
          ('Mã giao dịch', transaction.transactionId.toString()),
          (
            'Số tiền',
            '${transaction.amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ',
          ),
          (
            'Phương thức',
            transaction.paymentMethod.isEmpty
                ? 'Thanh toán đấu giá'
                : transaction.paymentMethod,
          ),
          ('Trạng thái', transaction.status),
          ('Thời gian', TransactionHistoryPage._formatDate(time)),
        ];
    }
  }
}
