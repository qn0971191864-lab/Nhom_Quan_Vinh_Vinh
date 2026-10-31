import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'auction_session.dart';
import 'contact_page.dart';
import 'item.dart';
import 'services/firebase_service.dart';

class CreateAuctionPage extends StatefulWidget {
  const CreateAuctionPage({super.key});

  @override
  State<CreateAuctionPage> createState() => _CreateAuctionPageState();
}

class _CreateAuctionPageState extends State<CreateAuctionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _incrementController = TextEditingController(text: '100000');
  final _buyNowController = TextEditingController();
  final _reserveController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;
  bool _busy = false;
  bool _uploadingImage = false;
  int _uploadProgressPercent = 0;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String _imageUrl = '';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _incrementController.dispose();
    _buyNowController.dispose();
    _reserveController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initial = isStart
        ? _startTime ?? DateTime.now().add(const Duration(hours: 1))
        : _endTime ?? DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        _startTime = selected;
      } else {
        _endTime = selected;
      }
    });
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploadingImage) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Không thể đọc dữ liệu ảnh.');
      }
      if (bytes.length >= 10 * 1024 * 1024) {
        throw Exception('Ảnh phải nhỏ hơn 10 MB.');
      }

      setState(() {
        _uploadingImage = true;
        _uploadProgressPercent = 0;
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Vui lòng đăng nhập lại.');

      final extension = file.extension?.toLowerCase();
      final safeExtension = extension != null && extension.isNotEmpty
          ? '.$extension'
          : '';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      final storageRef = FirebaseStorage.instance.ref().child(
        'auction_images/${user.uid}/$fileName$safeExtension',
      );
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: _contentType(extension)),
      );
      var lastReportedPercent = -1;
      final progressSubscription = uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (!mounted || snapshot.totalBytes == 0) return;
          final percent =
              (snapshot.bytesTransferred / snapshot.totalBytes * 100).round();
          if (percent == lastReportedPercent) return;
          lastReportedPercent = percent;
          setState(() => _uploadProgressPercent = percent);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Image upload progress error: $error');
        },
      );
      try {
        await uploadTask.timeout(const Duration(minutes: 2));
      } on TimeoutException {
        await uploadTask.cancel();
        throw TimeoutException(
          'Tải ảnh quá lâu. Vui lòng kiểm tra kết nối mạng và thử lại.',
        );
      } finally {
        await progressSubscription.cancel();
      }
      final downloadUrl = await storageRef.getDownloadURL().timeout(
        const Duration(seconds: 30),
      );
      if (!mounted) return;
      setState(() {
        _imageUrl = downloadUrl;
        _uploadProgressPercent = 100;
      });
    } catch (error) {
      debugPrint('Image upload failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Không thể tải ảnh lên: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _uploadProgressPercent = 0;
        });
      }
    }
  }

  String? _contentType(String? extension) => switch (extension) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    _ => null,
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để tạo phiên đấu giá.'),
        ),
      );
      return;
    }
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn thời gian bắt đầu và kết thúc.'),
        ),
      );
      return;
    }
    if (!_endTime!.isAfter(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thời gian kết thúc phải sau thời gian bắt đầu.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final price = int.parse(_priceController.text.trim());
      final increment = int.parse(_incrementController.text.trim());
      final buyNowPrice = int.tryParse(_buyNowController.text.trim());
      final reservePrice = int.tryParse(_reserveController.text.trim());
      final itemId = DateTime.now().millisecondsSinceEpoch;
      await FirebaseService.instance.addItem(
        Item(
          id: itemId,
          itemName: _nameController.text.trim(),
          startingPrice: price,
          description: _descriptionController.text.trim(),
          imageUrl: _imageUrl,
          ownerUid: user.uid,
          status: 'available',
        ),
      );
      await FirebaseService.instance.createAuctionSession(
        AuctionSession(
          itemId: itemId.toString(),
          startingPrice: price,
          minimumIncrement: increment,
          buyNowPrice: buyNowPrice,
          reservePrice: reservePrice,
          startTime: _startTime!.toUtc().toIso8601String(),
          endTime: _endTime!.toUtc().toIso8601String(),
          status: 'scheduled',
        ),
      );
      if (!mounted) return;
      _formKey.currentState!.reset();
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _incrementController.text = '100000';
      setState(() {
        _startTime = null;
        _endTime = null;
        _selectedImageBytes = null;
        _selectedImageName = null;
        _imageUrl = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo phiên đấu giá thành công.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tạo phiên: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseService.isFirebaseInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tạo phiên đấu giá')),
        body: const Center(child: Text('Firebase chưa được khởi tạo.')),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!authSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tạo phiên đấu giá')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn cần đăng nhập để tạo phiên đấu giá.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ContactPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Đăng nhập ngay'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Tạo phiên đấu giá')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Thông tin vật phẩm',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên vật phẩm',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập tên vật phẩm'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedImageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _selectedImageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedImageName ?? 'Đã chọn hình ảnh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickAndUploadImage,
                  icon: _uploadingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_rounded),
                  label: Text(
                    _uploadingImage
                        ? 'Đang tải ảnh lên... $_uploadProgressPercent%'
                        : _imageUrl.isEmpty
                        ? 'Chọn và tải ảnh lên'
                        : 'Đổi ảnh',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Cấu hình đấu giá',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá khởi điểm (VNĐ)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (value) {
                    final price = int.tryParse(value?.trim() ?? '');
                    return price == null || price <= 0
                        ? 'Giá không hợp lệ'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _incrementController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bước giá tối thiểu (VNĐ)',
                    prefixIcon: Icon(Icons.trending_up),
                  ),
                  validator: (value) {
                    final increment = int.tryParse(value?.trim() ?? '');
                    return increment == null || increment <= 0
                        ? 'Bước giá không hợp lệ'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _buyNowController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá mua ngay (VNĐ, tùy chọn)',
                    prefixIcon: Icon(Icons.flash_on_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final price = int.tryParse(value.trim());
                    return price == null || price <= 0
                        ? 'Giá mua ngay không hợp lệ'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reserveController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá sàn bảo lưu (VNĐ, tùy chọn)',
                    prefixIcon: Icon(Icons.security_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final price = int.tryParse(value.trim());
                    return price == null || price <= 0
                        ? 'Giá bảo lưu không hợp lệ'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                _timeTile(
                  icon: Icons.play_circle_outline,
                  title: 'Thời gian bắt đầu',
                  value: _startTime,
                  onTap: () => _pickDateTime(true),
                ),
                const SizedBox(height: 10),
                _timeTile(
                  icon: Icons.stop_circle_outlined,
                  title: 'Thời gian kết thúc',
                  value: _endTime,
                  onTap: () => _pickDateTime(false),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.gavel_rounded),
                  label: Text(_busy ? 'Đang tạo...' : 'Tạo phiên đấu giá'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _timeTile({
    required IconData icon,
    required String title,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252526) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE2E6EB),
          ),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
            Text(
              value == null ? 'Chọn' : _formatDate(value),
              style: TextStyle(
                color: value == null ? Colors.grey : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
