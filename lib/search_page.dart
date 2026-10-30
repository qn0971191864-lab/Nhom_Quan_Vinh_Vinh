import 'package:flutter/material.dart';

import 'auction_session.dart';
import 'category.dart';
import 'item.dart';
import 'phien_dau_gia.dart';
import 'services/firebase_service.dart';

const _ink = Color(0xFF14243A);
const _gold = Color(0xFFC49A55);

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _keywordController = TextEditingController();
  final Set<String> _selectedStatuses = {'Tất cả'};
  final Set<int> _selectedCategories = {};
  DateTime? _fromDate;
  DateTime? _toDate;
  String _sortOrder = 'Mới -> Cũ';

  static const _statuses = [
    'Tất cả',
    'Sắp diễn ra',
    'Đang diễn ra',
    'Đã kết thúc',
    'Đã bán',
  ];

  static const _categoryFallback = [
    'Tài sản nhà nước',
    'Bất động sản',
    'Phương tiện - xe cộ',
    'Sưu tầm - nghệ thuật',
    'Hàng hiệu xa xỉ',
    'Tang vật bị tịch thu',
    'Tài sản khác',
  ];

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text('Tìm kiếm tài sản'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Đặt lại bộ lọc',
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Item>>(
        stream: FirebaseService.instance.getItemsStream(),
        builder: (context, itemSnapshot) {
          return StreamBuilder<List<AuctionSession>>(
            stream: FirebaseService.instance.getAuctionSessionsStream(),
            builder: (context, sessionSnapshot) {
              return StreamBuilder<List<Category>>(
                stream: FirebaseService.instance.getCategoriesStream(),
                builder: (context, categorySnapshot) {
                  if (itemSnapshot.hasError ||
                      sessionSnapshot.hasError ||
                      categorySnapshot.hasError) {
                    return _message('Không thể tải dữ liệu tìm kiếm.');
                  }
                  if (!itemSnapshot.hasData ||
                      !sessionSnapshot.hasData ||
                      !categorySnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: _gold),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      final categories = categorySnapshot.data!;
                      final body = _buildResults(
                        itemSnapshot.data!,
                        sessionSnapshot.data!,
                        categories,
                      );
                      if (!isWide) {
                        return body;
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 300,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(18),
                              child: _buildFilterPanel(
                                categories,
                                inDrawer: false,
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: body),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildResults(
    List<Item> items,
    List<AuctionSession> sessions,
    List<Category> categories,
  ) {
    final sessionsByItem = <String, AuctionSession>{};
    for (final session in sessions) {
      final existing = sessionsByItem[session.itemId];
      if (existing == null ||
          _parseTime(session.startTime)
              .isAfter(_parseTime(existing.startTime))) {
        sessionsByItem[session.itemId] = session;
      }
    }

    final keyword = _keywordController.text.trim().toLowerCase();
    final results = <_SearchResult>[];
    for (final item in items) {
      final session =
          sessionsByItem[item.id.toString()] ??
          sessionsByItem[item.id == 0 ? '' : item.id.toString()];
      if (keyword.isNotEmpty &&
          !item.itemName.toLowerCase().contains(keyword) &&
          !item.description.toLowerCase().contains(keyword)) {
        continue;
      }
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(item.categoryId)) {
        continue;
      }
      if (!_selectedStatuses.contains('Tất cả') && session != null) {
        final status = _statusLabel(session.status);
        if (!_selectedStatuses.contains(status)) continue;
      }
      if (_fromDate != null &&
          session != null &&
          _parseTime(session.startTime).isBefore(_fromDate!)) {
        continue;
      }
      if (_toDate != null &&
          session != null &&
          _parseTime(session.endTime).isAfter(
            DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59),
          )) {
        continue;
      }
      results.add(_SearchResult(item, session));
    }

    results.sort((a, b) {
      final aTime = a.session == null
          ? DateTime(1970)
          : _parseTime(a.session!.startTime);
      final bTime = b.session == null
          ? DateTime(1970)
          : _parseTime(b.session!.startTime);
      if (_sortOrder == 'Giá tăng dần') {
        return a.item.startingPrice.compareTo(b.item.startingPrice);
      }
      if (_sortOrder == 'Giá giảm dần') {
        return b.item.startingPrice.compareTo(a.item.startingPrice);
      }
      return _sortOrder == 'Mới -> Cũ'
          ? bTime.compareTo(aTime)
          : aTime.compareTo(bTime);
    });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _keywordController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Nhập từ khóa...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _keywordController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _keywordController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!isWide)
                      OutlinedButton.icon(
                        onPressed: () => _openMobileFilters(categories),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Bộ lọc tài sản'),
                      ),
                    if (!isWide) const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${results.length} tài sản',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortOrder,
                            items: const [
                              DropdownMenuItem(
                                value: 'Mới -> Cũ',
                                child: Text('Mới -> Cũ'),
                              ),
                              DropdownMenuItem(
                                value: 'Cũ -> Mới',
                                child: Text('Cũ -> Mới'),
                              ),
                              DropdownMenuItem(
                                value: 'Giá tăng dần',
                                child: Text('Giá tăng dần'),
                              ),
                              DropdownMenuItem(
                                value: 'Giá giảm dần',
                                child: Text('Giá giảm dần'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _sortOrder = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (results.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Không tìm thấy tài sản phù hợp.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(18),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.crossAxisExtent >= 1100
                    ? 3
                    : constraints.crossAxisExtent >= 720
                    ? 2
                    : 1;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _AuctionCard(result: results[index]),
                    childCount: results.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: crossAxisCount == 1 ? 1.08 : 0.78,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterPanel(
    List<Category> categories, {
    required bool inDrawer,
  }) {
    final categoryNames = categories.isNotEmpty
        ? categories
        : _categoryFallback
              .asMap()
              .entries
              .map(
                (entry) => Category(
                  categoryId: entry.key + 1,
                  categoryName: entry.value,
                ),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bộ lọc tìm kiếm',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        const Text('Thời gian', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _dateButton('Từ ngày', _fromDate, (value) {
                setState(() => _fromDate = value);
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateButton('Đến ngày', _toDate, (value) {
                setState(() => _toDate = value);
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _ink),
          onPressed: () {
            setState(() {});
            if (inDrawer) Navigator.pop(context);
          },
          child: const Text('LỌC'),
        ),
        const Divider(height: 32),
        const Text(
          'Trạng thái tài sản',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        ..._statuses.map(
          (status) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(status),
            value: _selectedStatuses.contains(status),
            onChanged: (checked) {
              setState(() {
                if (status == 'Tất cả') {
                  _selectedStatuses
                    ..clear()
                    ..add('Tất cả');
                } else {
                  _selectedStatuses.remove('Tất cả');
                  if (checked == true) {
                    _selectedStatuses.add(status);
                  } else {
                    _selectedStatuses.remove(status);
                  }
                  if (_selectedStatuses.isEmpty) {
                    _selectedStatuses.add('Tất cả');
                  }
                }
              });
            },
          ),
        ),
        const Divider(height: 32),
        const Text(
          'Danh mục tài sản',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Tất cả'),
          value: _selectedCategories.isEmpty,
          onChanged: (_) => setState(() => _selectedCategories.clear()),
        ),
        ...categoryNames.map(
          (category) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(category.categoryName),
            value: _selectedCategories.contains(category.categoryId),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedCategories.add(category.categoryId);
                } else {
                  _selectedCategories.remove(category.categoryId);
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _dateButton(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return OutlinedButton(
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (selected != null) onChanged(selected);
      },
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
      child: Column(
        children: [
          Text(label),
          const SizedBox(height: 4),
          Icon(
            Icons.calendar_month_rounded,
            color: value == null ? Colors.grey : _ink,
          ),
          if (value != null)
            Text(
              '${value.day}/${value.month}/${value.year}',
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }

  void _openMobileFilters(List<Category> categories) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: _buildFilterPanel(categories, inDrawer: true),
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _keywordController.clear();
      _selectedStatuses
        ..clear()
        ..add('Tất cả');
      _selectedCategories.clear();
      _fromDate = null;
      _toDate = null;
      _sortOrder = 'Mới -> Cũ';
    });
  }

  String _statusLabel(String status) {
    return switch (status) {
      'scheduled' || 'upcoming' => 'Sắp diễn ra',
      'active' => 'Đang diễn ra',
      'sold' => 'Đã bán',
      'ended' || 'completed' || 'cancelled' => 'Đã kết thúc',
      _ => 'Đã kết thúc',
    };
  }

  DateTime _parseTime(String value) =>
      DateTime.tryParse(value)?.toLocal() ?? DateTime(1970);

  Widget _message(String text) => Center(child: Text(text));
}

class _SearchResult {
  final Item item;
  final AuctionSession? session;
  const _SearchResult(this.item, this.session);
}

class _AuctionCard extends StatelessWidget {
  final _SearchResult result;
  const _AuctionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final session = result.session;
    final price =
        session?.currentHighestBid ??
        session?.startingPrice ??
        item.startingPrice;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: session == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TrangDauGiaPage(sessionId: session.sessionId),
                ),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFEDEFF2),
                          child: Icon(Icons.image_outlined, size: 48),
                        )
                      : Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                                color: Color(0xFFEDEFF2),
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                ),
                              ),
                        ),
                  if (session != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _formatDate(session.startTime),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Giá khởi điểm : ${_formatPrice(price)} VNĐ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Trạng thái : ${_statusText(session?.status)}',
                      style: TextStyle(
                        color: session?.status == 'active'
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(String? status) {
    return switch (status) {
      'scheduled' || 'upcoming' => 'Sắp diễn ra',
      'active' => 'Đang diễn ra',
      'sold' => 'Đã bán',
      'ended' || 'completed' || 'cancelled' => 'Đã kết thúc',
      _ => 'Chưa đấu giá',
    };
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:00';
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }
}
