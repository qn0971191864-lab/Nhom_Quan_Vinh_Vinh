import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auction_session.dart';
import 'item.dart';
import 'services/catalog_service.dart';
import 'services/firebase_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _adminEmailController = TextEditingController();
  late final Future<bool> _adminAccess;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _adminAccess =
        user?.getIdTokenResult().then(
          (token) => token.claims?['admin'] == true,
        ) ??
        Future<bool>.value(false);
  }

  @override
  void dispose() {
    _adminEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminAccess,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _accessMessage(
            'Không thể xác minh quyền quản trị: ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Quản trị')),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != true) {
          return _accessMessage(
            'Chỉ tài khoản quản trị viên mới được truy cập.',
          );
        }
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Quản trị'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    text: 'Nạp tiền',
                  ),
                  Tab(icon: Icon(Icons.gavel_outlined), text: 'Phiên đấu giá'),
                  Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Vật phẩm'),
                  Tab(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    text: 'Tài khoản',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _topupsTab(),
                _sessionsTab(),
                _itemsTab(),
                _grantAdminTab(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _accessMessage(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản trị')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _topupsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('wallet_topups')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorMessage('Không thể tải yêu cầu nạp: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Không có yêu cầu nạp tiền đang chờ.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((request) {
            final data = request.data();
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            final email = data['email'] as String? ?? '';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatPrice(amount)} đ',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isEmpty
                          ? 'UID: ${data['userUid'] ?? 'không rõ'}'
                          : email,
                    ),
                    Text('Gửi lúc ${_formatTimestamp(data['createdAt'])}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busyAction == null
                              ? () => _reviewWalletTopup(request.id, 'reject')
                              : null,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Từ chối'),
                        ),
                        FilledButton.icon(
                          onPressed: _busyAction == null
                              ? () => _reviewWalletTopup(request.id, 'approve')
                              : null,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Duyệt cộng tiền'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _sessionsTab() {
    return StreamBuilder<List<AuctionSession>>(
      stream: FirebaseService.instance.getAuctionSessionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorMessage(
            'Không thể tải phiên đấu giá: ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Chưa có phiên đấu giá nào.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.map((session) {
            return Card(
              child: ListTile(
                title: Text('Phiên ${session.sessionId}'),
                subtitle: Text(
                  'Vật phẩm: ${session.itemId}\n'
                  'Giá khởi điểm: ${_formatPrice(session.startingPrice)} đ · '
                  '${_sessionStatus(session.status)}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Xóa phiên',
                  onPressed: _busyAction == null
                      ? () => _deleteSession(session)
                      : null,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _itemsTab() {
    return StreamBuilder<List<Item>>(
      stream: CatalogService.instance.getItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorMessage('Không thể tải vật phẩm: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Chưa có vật phẩm nào.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.map((item) {
            return Card(
              child: ListTile(
                title: Text(item.itemName),
                subtitle: Text(
                  'Mã: ${item.id} · Giá khởi điểm: ${_formatPrice(item.startingPrice)} đ\n'
                  'Trạng thái: ${_itemStatus(item.status)}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Xóa vật phẩm',
                  onPressed: _busyAction == null
                      ? () => _deleteItem(item)
                      : null,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _grantAdminTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Cấp quyền cho tài khoản đã đăng ký.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _adminEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email tài khoản cần cấp quyền admin',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busyAction == null ? _grantAdminRole : null,
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: Text(
            _busyAction == 'grant-admin' ? 'Đang xử lý...' : 'Cấp quyền admin',
          ),
        ),
      ],
    );
  }

  Widget _errorMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Future<void> _grantAdminRole() async {
    final email = _adminEmailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Vui lòng nhập email tài khoản đã đăng ký.');
      return;
    }
    await _runAdminAction('grant-admin', () async {
      await FirebaseFunctions.instance.httpsCallable('grantAdminRole').call({
        'email': email,
      });
      if (mounted) _adminEmailController.clear();
      _showMessage('Đã cấp quyền admin cho $email.');
    }, 'Không thể cấp quyền admin');
  }

  Future<void> _reviewWalletTopup(String requestId, String decision) async {
    await _runAdminAction('topup-$requestId', () async {
      await FirebaseFunctions.instance.httpsCallable('reviewWalletTopup').call({
        'requestId': requestId,
        'decision': decision,
      });
      _showMessage(
        decision == 'approve'
            ? 'Đã duyệt và cộng tiền vào ví.'
            : 'Đã từ chối yêu cầu nạp tiền.',
      );
    }, 'Không thể xử lý yêu cầu nạp');
  }

  Future<void> _deleteSession(AuctionSession session) async {
    final confirmed = await _confirmDelete(
      title: 'Xóa phiên đấu giá?',
      message:
          'Phiên ${session.sessionId} sẽ bị xóa vĩnh viễn. Phiên có lượt đặt giá, '
          'đơn hàng hoặc tiền cọc liên quan sẽ không thể xóa.',
    );
    if (!confirmed) return;
    await _runAdminAction('delete-session-${session.sessionId}', () async {
      await FirebaseService.instance.deleteAuctionSession(session.sessionId);
      _showMessage('Đã xóa phiên ${session.sessionId}.');
    }, 'Không thể xóa phiên');
  }

  Future<void> _deleteItem(Item item) async {
    final confirmed = await _confirmDelete(
      title: 'Xóa vật phẩm?',
      message:
          '“${item.itemName}” sẽ bị xóa vĩnh viễn. Hãy xóa phiên liên quan trước; '
          'vật phẩm có lịch sử đơn hàng sẽ được giữ lại.',
    );
    if (!confirmed) return;
    await _runAdminAction('delete-item-${item.id}', () async {
      await FirebaseService.instance.deleteAuctionItem(item.id);
      _showMessage('Đã xóa vật phẩm “${item.itemName}”.');
    }, 'Không thể xóa vật phẩm');
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runAdminAction(
    String action,
    Future<void> Function() run,
    String errorPrefix,
  ) async {
    setState(() => _busyAction = action);
    try {
      await run();
    } catch (error) {
      _showMessage('$errorPrefix: $error');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatPrice(int price) => price.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );

  String _formatTimestamp(Object? value) {
    if (value is! Timestamp) return 'Đang cập nhật thời gian';
    final date = value.toDate().toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String _sessionStatus(String status) => switch (status) {
    'scheduled' => 'Sắp diễn ra',
    'active' => 'Đang diễn ra',
    'sold' => 'Đã bán',
    'ended' => 'Đã kết thúc',
    'cancelled' => 'Đã hủy',
    'expired' => 'Hết hạn',
    _ => status,
  };

  String _itemStatus(String status) => switch (status) {
    'available' => 'Có sẵn',
    'in_auction' => 'Đang đấu giá',
    'sold' => 'Đã bán',
    _ => status,
  };
}
