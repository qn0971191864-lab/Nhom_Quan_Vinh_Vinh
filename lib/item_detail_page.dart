import 'package:flutter/material.dart';

import 'auction_session.dart';
import 'item.dart';
import 'phien_dau_gia.dart';
import 'services/firebase_service.dart';

const _ink = Color(0xFF14243A);
const _gold = Color(0xFFC49A55);

class ItemDetailPage extends StatelessWidget {
  final Item item;
  final AuctionSession? session;

  const ItemDetailPage({
    super.key,
    required this.item,
    this.session,
  });

  String _formatPrice(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatDate(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString.isEmpty ? 'Chưa xác định' : isoString;
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPrice = (session != null && session!.currentHighestBid > 0)
        ? session!.currentHighestBid
        : (session?.startingPrice ?? item.startingPrice);

    final statusText = switch (session?.status) {
      'active' => 'ĐANG DIỄN RA',
      'scheduled' => 'SẮP DIỄN RA',
      'sold' => 'ĐÃ BÁN',
      'ended' => 'ĐÃ KẾT THÚC',
      'cancelled' => 'ĐÃ HỦY',
      _ => item.status == 'in_auction' ? 'ĐANG ĐẤU GIÁ' : 'SẴN SÀNG',
    };

    final statusColor = switch (session?.status) {
      'active' => const Color(0xFF2E7D32),
      'scheduled' => const Color(0xFF1565C0),
      'sold' || 'ended' => const Color(0xFF757575),
      'cancelled' => const Color(0xFFC62828),
      _ => _gold,
    };

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF181818) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Chi tiết vật phẩm',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Yêu thích',
            icon: const Icon(Icons.favorite_border_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã thêm vào danh sách quan tâm!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Chia sẻ',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép liên kết vật phẩm!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. KHUNG ẢNH LỚN VẬT PHẨM ──────────────────────────────────
            Container(
              width: double.infinity,
              height: 300,
              color: isDark ? const Color(0xFF252526) : Colors.white,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.contain,
                          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey),
                        ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. KHỐI THÔNG TIN TÊN & GIÁ ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              color: isDark ? const Color(0xFF202020) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName.isEmpty ? 'Vật phẩm chưa đặt tên' : item.itemName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _gold.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Mã sản phẩm: #${item.id}',
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Danh mục #${item.categoryId ?? 1}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2A2D34), const Color(0xFF202228)]
                            : [const Color(0xFFFBF8F2), const Color(0xFFF3EAD9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _gold.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session != null && session!.currentHighestBid > 0
                              ? 'GIÁ CAO NHẤT HIỆN TẠI'
                              : 'GIÁ KHỞI ĐIỂM ĐẤU GIÁ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: isDark ? const Color(0xFFD4B16A) : const Color(0xFF8C6621),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${_formatPrice(currentPrice)} ',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : _ink,
                              ),
                            ),
                            Text(
                              'VNĐ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.grey[300] : _gold,
                              ),
                            ),
                          ],
                        ),
                        if (session != null) ...[
                          const SizedBox(height: 8),
                          Divider(color: _gold.withValues(alpha: 0.2), height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bước giá tối thiểu: +${_formatPrice(session!.minimumIncrement)} đ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF555555),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Kết thúc: ${_formatDate(session!.endTime)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── 3. KHỐI THÔNG TIN NGƯỜI BÁN (SELLER INFO) ────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              color: isDark ? const Color(0xFF202020) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THÔNG TIN NGƯỜI BÁN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: _gold,
                        child: Text(
                          (item.ownerUid != null && item.ownerUid!.isNotEmpty)
                              ? item.ownerUid![0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.ownerUid != null && item.ownerUid!.isNotEmpty
                                        ? 'Chủ sở hữu: ${FirebaseService.formatShortUid(item.ownerUid!)}'
                                        : 'Người bán hệ thống',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : _ink,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF1E88E5)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              '⭐⭐⭐⭐⭐ · Đã xác thực danh tính & Ví',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── 4. KHỐI MÔ TẢ CHI TIẾT SẢN PHẨM ────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: isDark ? const Color(0xFF202020) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MÔ TẢ VẬT PHẨM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.description.trim().isEmpty
                        ? 'Chưa có thông tin mô tả chi tiết cho vật phẩm này từ người bán.'
                        : item.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 20, color: _gold),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cam kết kiểm định vật phẩm chính hãng và bảo hành thanh toán an toàn qua Escrow.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100), // Khoảng trống cho bottom bar
          ],
        ),
      ),

      // ── 5. NÚT CHUYỂN HƯỚNG SANG PHIÊN ĐẤU GIÁ (BOTTOM BAR) ────────────
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202020) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: session != null
              ? SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.gavel_rounded, color: _gold),
                    label: const Text(
                      'Tham gia phiên đấu giá',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrangDauGiaPage(sessionId: session!.sessionId),
                        ),
                      );
                    },
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.access_time_rounded),
                    label: const Text(
                      'Chưa mở phiên đấu giá cho sản phẩm này',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: null,
                  ),
                ),
        ),
      ),
    );
  }
}
