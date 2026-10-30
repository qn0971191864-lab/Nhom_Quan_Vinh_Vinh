import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import 'auction_session.dart';
import 'item.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'theme_controller.dart';
import 'transaction_history_page.dart';
import 'user.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullnameController = TextEditingController();
  late final AuthService _auth;
  bool _registering = false;
  bool _busy = false;
  String? _error;
  int _profileSection = 2;

  @override
  void initState() {
    super.initState();
    AppThemeController.instance.addListener(_themeChanged);
    if (FirebaseService.isFirebaseInitialized) {
      _auth = AuthService();
    }
  }

  void _themeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppThemeController.instance.removeListener(_themeChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _fullnameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await _auth.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullname: _fullnameController.text.trim(),
        );
      } else {
        await _auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseService.isFirebaseInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tài Khoản & Cá Nhân')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Firebase chưa được khởi tạo. Đăng nhập và các thao tác backend '
              'chỉ khả dụng sau khi cấu hình Firebase.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageScreen(
            'Không thể tải hồ sơ Firebase: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return _buildAuthenticationForm();
        return _buildProfile(user);
      },
    );
  }

  Widget _buildAuthenticationForm() {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài Khoản & Cá Nhân')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _registering ? 'Tạo tài khoản' : 'Đăng nhập',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (_registering) ...[
            TextField(
              controller: _fullnameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) {
              if (!_busy) _submit();
            },
            decoration: const InputDecoration(labelText: 'Mật khẩu'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(
              _busy
                  ? 'Đang xử lý...'
                  : _registering
                  ? 'Đăng ký'
                  : 'Đăng nhập',
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _registering = !_registering;
                    _error = null;
                  }),
            child: Text(
              _registering
                  ? 'Đã có tài khoản? Đăng nhập'
                  : 'Chưa có tài khoản? Đăng ký',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(User user) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: const Text('HỒ SƠ NHÀ ĐẤU GIÁ')),
      body: Padding(
        padding: EdgeInsets.all(width >= 700 ? 24 : 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final verticalRail = constraints.maxWidth < 560;
            if (verticalRail) {
              return Column(
                children: [
                  _accountHeader(user),
                  const SizedBox(height: 10),
                  _profileMenu(user, horizontal: true),
                  const SizedBox(height: 10),
                  Expanded(child: _profileContent(user)),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      _accountHeader(user),
                      const SizedBox(height: 12),
                      _profileMenu(user),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _profileContent(user)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _accountHeader(User user) {
    return InkWell(
      onTap: () => setState(() => _profileSection = 0),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _gamePanel(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFC49A55),
              child: Text(
                user.fullname.isEmpty
                    ? 'U'
                    : user.fullname.trim()[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullname.isEmpty ? 'Người dùng' : user.fullname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFAEB8C7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFAEB8C7)),
          ],
        ),
      ),
    );
  }

  Widget _profileMenu(User user, {bool horizontal = false}) {
    final items = <(IconData, String, int)>[
      (Icons.receipt_long_outlined, 'Giao dịch', 1),
      (Icons.emoji_events_outlined, 'Đã thắng', 2),
      (Icons.settings_outlined, 'Cài đặt', 3),
    ];
    final menu = Container(
      padding: const EdgeInsets.all(8),
      decoration: _gamePanel(),
      child: horizontal
          ? Row(
              children: items.map((item) {
                final selected = _profileSection == item.$3;
                return Expanded(
                  child: InkWell(
                    onTap: () => _selectProfileSection(item.$3),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF245B7A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: const Color(0xFF5EA7C8))
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.$1, color: Colors.white, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          : Column(
              children: [
                ...items.map(
                  (item) => _gameMenuItem(item.$1, item.$2, item.$3),
                ),
                const Divider(color: Color(0xFF344A64)),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFFFA5A5),
                  ),
                  title: const Text(
                    'Đăng xuất',
                    style: TextStyle(color: Color(0xFFFFA5A5)),
                  ),
                  onTap: _auth.signOut,
                ),
              ],
            ),
    );
    return menu;
  }

  void _selectProfileSection(int index) {
    if (index == 1) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TransactionHistoryPage()));
      return;
    }
    setState(() => _profileSection = index);
  }

  Widget _gameMenuItem(IconData icon, String label, int index) {
    final selected = _profileSection == index;
    return ListTile(
      onTap: () => _selectProfileSection(index),
      selected: selected,
      selectedTileColor: const Color(0xFF245B7A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selected
            ? const BorderSide(color: Color(0xFF5EA7C8))
            : BorderSide.none,
      ),
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: selected
          ? const Icon(Icons.chevron_right, color: Color(0xFFBDE0EF))
          : null,
    );
  }

  Widget _profileContent(User user) {
    return Container(
      decoration: _gamePanel(),
      child: switch (_profileSection) {
        0 => _accountDetailsContent(user),
        3 => _settingsContent(user),
        _ => _wonItemsContent(user),
      },
    );
  }

  Widget _accountDetailsContent(User user) {
    final uid =
        user.firebaseUid ??
        firebase_auth.FirebaseAuth.instance.currentUser?.uid ??
        '';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'THÔNG TIN TÀI KHOẢN',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        _detailRow(
          Icons.badge_outlined,
          'Họ tên',
          user.fullname.isEmpty ? 'Người dùng' : user.fullname,
        ),
        _detailRow(Icons.alternate_email_rounded, 'Email', user.email),
        _detailRow(Icons.fingerprint_rounded, 'UID tài khoản', uid),
        _detailRow(
          Icons.shield_outlined,
          'Vai trò',
          user.role.isEmpty ? 'USER' : user.role,
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF172A43),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF40536B)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFC49A55)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF98A8BC),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wonItemsContent(User user) {
    final uid =
        user.firebaseUid ??
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(
        child: Text(
          'Không xác định tài khoản',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    return StreamBuilder<List<AuctionSession>>(
      stream: FirebaseService.instance.getAuctionSessionsStream(status: 'sold'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Không thể tải: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final won = snapshot.data!
            .where((session) => session.highestBidderUid == uid)
            .toList();
        if (won.isEmpty) {
          return const Center(
            child: Text(
              'Bạn chưa thắng vật phẩm nào.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: won.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final session = won[index];
            return StreamBuilder<Item?>(
              stream: FirebaseService.instance.getItemStream(session.itemId),
              builder: (context, itemSnapshot) {
                final item = itemSnapshot.data;
                return ListTile(
                  tileColor: const Color(0xFF172A43),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF40536B)),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFC49A55),
                    child: Icon(Icons.emoji_events, color: Colors.white),
                  ),
                  title: Text(
                    item?.itemName ?? 'Phiên ${session.sessionId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Giá thắng: ${_formatPrice(session.currentHighestBid)} đ',
                    style: const TextStyle(color: Color(0xFFC5CFDB)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _settingsContent(User user) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'CÀI ĐẶT TÀI KHOẢN',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        _themeSettingsTile(),
        _settingTile(
          Icons.badge_outlined,
          'Họ tên hiển thị',
          user.fullname.isEmpty ? 'Người dùng' : user.fullname,
          () => _editDisplayName(user),
        ),
        _settingTile(Icons.email_outlined, 'Email đăng nhập', user.email, null),
        _settingTile(
          Icons.lock_outline_rounded,
          'Mật khẩu',
          'Đổi mật khẩu',
          () => _showPasswordReset(),
        ),
        _settingTile(
          Icons.logout_rounded,
          'Phiên đăng nhập',
          'Đăng xuất khỏi tài khoản',
          () => _auth.signOut(),
          danger: true,
        ),
      ],
    );
  }

  Widget _themeSettingsTile() {
    final isDark = AppThemeController.instance.isDark;
    final cardColor = isDark
        ? const Color(0xFF252526)
        : const Color(0xFFF7F9FC);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_outlined, color: Color(0xFFC49A55)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cài đặt giao diện',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF172A43),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Sáng'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Tối'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {isDark},
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return isDark
                          ? const Color(0xFF007ACC)
                          : const Color(0xFF14243A);
                    }
                    return isDark ? const Color(0xFF252526) : Colors.white;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? Colors.white
                        : (isDark
                              ? const Color(0xFFCCCCCC)
                              : const Color(0xFF172A43));
                  }),
                  iconColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? Colors.white
                        : (isDark
                              ? const Color(0xFFCCCCCC)
                              : const Color(0xFF172A43));
                  }),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      color: isDark
                          ? const Color(0xFF3C3C3C)
                          : const Color(0xFFCBD3DE),
                    ),
                  ),
                ),
                onSelectionChanged: (selection) {
                  AppThemeController.instance.setThemeMode(
                    selection.first ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingTile(
    IconData icon,
    String title,
    String value,
    VoidCallback? onTap, {
    bool danger = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF252526) : const Color(0xFF172A43),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: danger ? const Color(0xFFFFA5A5) : const Color(0xFFC49A55),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: danger ? const Color(0xFFFFA5A5) : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(value, style: const TextStyle(color: Color(0xFFAEB8C7))),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right, color: Color(0xFFAEB8C7)),
      ),
    );
  }

  Future<void> _editDisplayName(User user) async {
    final controller = TextEditingController(text: user.fullname);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi họ tên hiển thị'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Họ tên'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final uid =
        user.firebaseUid ??
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fullname': name,
      }, SetOptions(merge: true));
      await firebase_auth.FirebaseAuth.instance.currentUser?.updateDisplayName(
        name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã cập nhật họ tên.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể cập nhật: $error')));
      }
    }
  }

  Future<void> _showPasswordReset() async {
    final email = firebase_auth.FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      return;
    }
    try {
      await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi liên kết đổi mật khẩu tới $email')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi liên kết: $error')),
        );
      }
    }
  }

  BoxDecoration _gamePanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF252526) : const Color(0xFF10213A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFF314B68),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  String _formatPrice(int price) => price.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );

  Widget _messageScreen(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài Khoản & Cá Nhân')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
