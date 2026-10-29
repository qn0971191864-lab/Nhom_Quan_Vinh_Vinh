import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import 'auction_session.dart';
import 'item.dart';
import 'services/firebase_service.dart';

const _ink = Color(0xFF14243A);
const _gold = Color(0xFFC49A55);
const _canvas = Color(0xFFF5F6F8);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  late final StreamSubscription<firebase_auth.User?> _authSubscription;
  Stream<List<Item>>? _itemsStream;
  Stream<List<AuctionSession>>? _sessionsStream;
  String? _streamUid;
  Object? _authError;
  bool _authReady = false;
  String _searchText = '';
  String _selectedFilter = 'Tất cả';

  static const _filters = [
    'Tất cả',
    'Đang diễn ra',
    'Sắp diễn ra',
    'Đã kết thúc',
  ];

  @override
  void initState() {
    super.initState();
    _authSubscription = firebase_auth.FirebaseAuth.instance
        .authStateChanges()
        .listen(
          (user) {
            if (!mounted) return;
            setState(() {
              _authReady = true;
              _authError = null;
              if (user == null) {
                _streamUid = null;
                _itemsStream = null;
                _sessionsStream = null;
              } else if (_streamUid != user.uid) {
                _streamUid = user.uid;
                _itemsStream = FirebaseService.instance.getItemsStream();
                _sessionsStream =
                    FirebaseService.instance.getAuctionSessionsStream();
              }
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) return;
            setState(() {
              _authReady = true;
              _authError = error;
            });
          },
        );
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QVV',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.15,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'SÀN ĐẤU GIÁ TRỰC TUYẾN',
              style: TextStyle(
                color: Color(0xFFD8C39C),
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.gavel_rounded, color: Color(0xFFE0C48F)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Item>>(
        stream: _itemsStream,
        builder: (context, itemSnapshot) {
          if (!_authReady) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_authError != null) {
            return _message('Không thể kiểm tra đăng nhập: $_authError');
          }
          if (_itemsStream == null || _sessionsStream == null) {
            return _message('Vui lòng đăng nhập để xem sản phẩm.');
          }
          if (itemSnapshot.hasError) {
            return _message('Không thể tải sản phẩm: ${itemSnapshot.error}');
          }
          if (!itemSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }

          return StreamBuilder<List<AuctionSession>>(
            stream: _sessionsStream,
            builder: (context, sessionSnapshot) {
              if (sessionSnapshot.hasError) {
                return _message(
                  'Không thể tải phiên đấu giá: ${sessionSnapshot.error}',
                );
              }
              if (!sessionSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _gold),
                );
              }

              final allItems = itemSnapshot.data!;
              final sessionsByItem = <String, AuctionSession>{};
              for (final session in sessionSnapshot.data!) {
                final existing = sessionsByItem[session.itemId];
                if (existing == null ||
                    _sessionEnd(session).isAfter(_sessionEnd(existing))) {
                  sessionsByItem[session.itemId] = session;
                }
              }

              final items = allItems.where((item) {
                final matchesSearch = item.itemName.toLowerCase().contains(
                  _searchText,
                );
                final session = sessionsByItem[item.id.toString()];
                final matchesFilter = switch (_selectedFilter) {
                  'Đang diễn ra' => session?.status == 'active',
                  'Sắp diễn ra' => session?.status == 'scheduled',
                  'Đã kết thúc' =>
                    session?.status == 'sold' ||
                        session?.status == 'ended' ||
                        session?.status == 'completed',
                  _ => true,
                };
                return matchesSearch && matchesFilter;
              }).toList();
              final activeCount = sessionSnapshot.data!
                  .where((session) => session.status == 'active')
                  .length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: _AuctionHero(
                        activeCount: activeCount,
                        itemCount: allItems.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm tác phẩm, sản phẩm...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchText.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Xóa tìm kiếm',
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE7E9ED),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE7E9ED),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 58,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final selected = filter == _selectedFilter;
                          return ChoiceChip(
                            label: Text(filter),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _selectedFilter = filter),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedColor: _ink,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: selected ? _ink : const Color(0xFFE7E9ED),
                            ),
                            shape: const StadiumBorder(),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tác phẩm nổi bật',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${items.length} sản phẩm',
                            style: const TextStyle(
                              color: Color(0xFF7A8492),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width >= 1000
                              ? 4
                              : width >= 650
                              ? 3
                              : 2;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.67,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = items[index];
                              return _ItemCard(
                                item: item,
                                session: sessionsByItem[item.id.toString()],
                              );
                            }, childCount: items.length),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  DateTime _sessionEnd(AuctionSession session) =>
      DateTime.tryParse(session.endTime) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 44, color: _gold),
          const SizedBox(height: 12),
          const Text(
            'Chưa tìm thấy sản phẩm phù hợp',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _selectedFilter = 'Tất cả');
            },
            child: const Text('Xóa bộ lọc'),
          ),
        ],
      ),
    ),
  );

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _AuctionHero extends StatelessWidget {
  const _AuctionHero({required this.activeCount, required this.itemCount});

  final int activeCount;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1C3452), Color(0xFF101D30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFFE4C68F),
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  'SÀN ĐẤU GIÁ UY TÍN',
                  style: TextStyle(
                    color: Color(0xFFE4C68F),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Giá trị xứng tầm.\nCuộc chơi minh bạch.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Khám phá những phiên đấu giá đang được quan tâm.',
            style: TextStyle(color: Color(0xFFCFD7E1), fontSize: 12),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(
                icon: Icons.sensors_rounded,
                value: '$activeCount',
                label: 'Đang đấu giá',
              ),
              const SizedBox(width: 22),
              _HeroMetric(
                icon: Icons.inventory_2_outlined,
                value: '$itemCount',
                label: 'Tác phẩm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE4C68F), size: 19),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFCFD7E1), fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.session});

  final Item item;
  final AuctionSession? session;

  @override
  Widget build(BuildContext context) {
    final isLive = session?.status == 'active';
    final price = session != null && session!.currentHighestBid > 0
        ? session!.currentHighestBid
        : session?.startingPrice ?? item.startingPrice;
    final status = switch (session?.status) {
      'active' => 'ĐANG ĐẤU',
      'scheduled' => 'SẮP MỞ',
      'sold' || 'ended' || 'completed' => 'ĐÃ KẾT THÚC',
      _ => _itemStatus(item.status),
    };

    return Card(
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE9EBEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFEDEFF2),
                        child: Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: Color(0xFF9AA3AE),
                        ),
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: Color(0xFFEDEFF2),
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 36,
                                color: Color(0xFF9AA3AE),
                              ),
                            ),
                      ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isLive ? const Color(0xFFC94E4E) : _ink,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLive) ...[
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      height: 1.2,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isLive ? 'GIÁ HIỆN TẠI' : 'GIÁ KHỞI ĐIỂM',
                    style: const TextStyle(
                      color: Color(0xFF7A8492),
                      fontSize: 9,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_formatPrice(price)} đ',
                      maxLines: 1,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: _gold,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _sessionTimeLabel(session!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF7A8492),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _itemStatus(String status) => switch (status) {
  'available' => 'SẴN SÀNG',
  'in_auction' => 'ĐANG ĐẤU',
  'sold' => 'ĐÃ BÁN',
  _ => status.toUpperCase(),
};

String _sessionTimeLabel(AuctionSession session) {
  final value = session.status == 'scheduled'
      ? session.startTime
      : session.endTime;
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? 'Thông tin phiên đấu giá' : value;
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return session.status == 'scheduled'
      ? 'Mở phiên $day/$month lúc $hour:$minute'
      : 'Kết thúc $day/$month lúc $hour:$minute';
}

String _formatPrice(int price) => price.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (match) => '.',
);
