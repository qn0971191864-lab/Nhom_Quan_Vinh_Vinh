import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/firebase_service.dart';
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

  @override
  void initState() {
    super.initState();
    if (FirebaseService.isFirebaseInitialized) {
      _auth = AuthService();
    }
  }

  @override
  void dispose() {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Tài Khoản & Cá Nhân')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(user.fullname.isEmpty ? 'Người dùng' : user.fullname),
            subtitle: Text(user.email),
          ),
          ListTile(
            title: const Text('UID tài khoản'),
            subtitle: Text(user.firebaseUid ?? ''),
          ),
          const Divider(),
          const ListTile(title: Text('Lịch sử giao dịch')),
          const ListTile(title: Text('Vật phẩm đã thắng')),
          const ListTile(title: Text('Cài đặt tài khoản')),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: _auth.signOut,
          ),
        ],
      ),
    );
  }

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
