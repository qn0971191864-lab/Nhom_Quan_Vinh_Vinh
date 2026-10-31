import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auction_session.dart';
import 'item.dart';
import 'phien_dau_gia.dart';
import 'services/firebase_service.dart';

const _ink = Color(0xFF14243A);
const _gold = Color(0xFFC49A55);

class NewsPage extends StatefulWidget {
  const NewsPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _articles = [
    _NewsArticle(
      source: 'VnExpress',
      title: 'Đấu giá tài sản nhà nước: quy trình, lợi ích và lưu ý',
      description: 'Hướng dẫn người dân tiếp cận phiên đấu giá tài sản công, quyền lợi và các rủi ro cần lưu ý.',
      url: 'https://vnexpress.net/tag/dau-gia-tai-san-2351282',
      topic: 'Tài sản công',
      age: 'Tin mới',
      imageUrl: 'https://images.unsplash.com/photo-1589994965851-a8f479c573a9?auto=format&fit=crop&w=900&q=80',
    ),
    _NewsArticle(
      source: 'Thanh Niên',
      title: 'Những điểm mới trong đấu giá tài sản trực tuyến',
      description: 'Nền tảng trực tuyến giúp việc mua sắm tài sản đấu giá minh bạch và thuận tiện hơn.',
      url: 'https://thanhnien.vn/dau-gia.htm',
      topic: 'Đấu giá trực tuyến',
      age: 'Tin nổi bật',
      imageUrl: 'https://images.unsplash.com/photo-1523995462485-3d171b5c8fa9?auto=format&fit=crop&w=900&q=80',
    ),
    _NewsArticle(
      source: 'Tuổi Trẻ',
      title: 'Bất động sản được đưa ra đấu giá công khai qua mạng',
      description: 'Cập nhật xu hướng sử dụng nền tảng trực tuyến để đấu giá nhà đất và tài sản.',
      url: 'https://tuoitre.vn/dau-gia.htm',
      topic: 'Bất động sản',
      age: 'Hôm nay',
      imageUrl: 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=900&q=80',
    ),
    _NewsArticle(
      source: 'Báo Chính phủ',
      title: 'Quy định và chính sách mới liên quan đấu giá tài sản',
      description: 'Thông tin chính thống về quản lý, tổ chức và giám sát hoạt động đấu giá.',
      url: 'https://baochinhphu.vn/dau-gia.htm',
      topic: 'Chính sách',
      age: 'Tin chính thống',
      imageUrl: 'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?auto=format&fit=crop&w=900&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text('Tin tức & Thông báo'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFBFC9D5),
          tabs: const [
            Tab(icon: Icon(Icons.newspaper_rounded), text: 'Tin tức'),
            Tab(icon: Icon(Icons.notifications_rounded), text: 'Thông báo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNews(), _buildAuctionNotifications()],
      ),
    );
  }

  Widget _buildNews() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._articles.map(
          (article) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ArticleCard(article: article),
          ),
        ),
      ],
    );
  }

  Widget _buildAuctionNotifications() {
    return StreamBuilder<List<AuctionSession>>(
      stream: FirebaseService.instance.getAuctionSessionsStream(),
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.hasError) {
          return Center(
            child: Text('Không thể tải thông báo: ${sessionSnapshot.error}'),
          );
        }
        if (!sessionSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }
        return StreamBuilder<List<Item>>(
          stream: FirebaseService.instance.getItemsStream(),
          builder: (context, itemSnapshot) {
            final items = {
              for (final item in itemSnapshot.data ?? const <Item>[])
                item.id.toString(): item,
            };
            final sessions = [...sessionSnapshot.data!]
              ..sort(
                (a, b) =>
                    _parseSessionTime(a.startTime)
                        .compareTo(_parseSessionTime(b.startTime)),
              );

            if (sessions.isEmpty) {
              return const Center(
                child: Text('Chưa có thông báo phiên đấu giá.'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final item = items[session.itemId];
                final now = DateTime.now();
                final start = _parseSessionTime(session.startTime);
                final end = DateTime.tryParse(session.endTime)?.toLocal();
                final (icon, title, color) = switch (session.status) {
                  'active' => (
                    Icons.gavel_rounded,
                    'Phiên đang diễn ra',
                    const Color(0xFFC94E4E),
                  ),
                  'scheduled' => (
                    Icons.schedule_rounded,
                    start.isAfter(now)
                        ? 'Phiên sắp bắt đầu'
                        : 'Phiên đã đến thời gian mở',
                    const Color(0xFFB9863A),
                  ),
                  'sold' => (
                    Icons.emoji_events_rounded,
                    'Phiên đã có kết quả',
                    const Color(0xFF3E8E6D),
                  ),
                  'won' => (
                    Icons.emoji_events_rounded,
                    'Phiên đã có người trúng đấu giá',
                    const Color(0xFF3E8E6D),
                  ),
                  _ => (
                    Icons.notifications_none_rounded,
                    'Phiên đã kết thúc',
                    const Color(0xFF64748B),
                  ),
                };
                return Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TrangDauGiaPage(sessionId: session.sessionId),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.12),
                            foregroundColor: color,
                            child: Icon(icon),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item?.itemName ??
                                      'Phiên đấu giá #${session.sessionId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  end == null
                                      ? 'Bắt đầu: ${_formatDate(start)}'
                                      : 'Bắt đầu: ${_formatDate(start)} • Kết thúc: ${_formatDate(end)}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  DateTime _parseSessionTime(String value) =>
      DateTime.tryParse(value)?.toLocal() ?? DateTime(1970);

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _NewsArticle {
  final String source;
  final String title;
  final String description;
  final String url;
  final String topic;
  final String age;
  final String imageUrl;

  const _NewsArticle({
    required this.source,
    required this.title,
    required this.description,
    required this.url,
    required this.topic,
    required this.age,
    required this.imageUrl,
  });
}

class _ArticleCard extends StatelessWidget {
  final _NewsArticle article;
  const _ArticleCard({required this.article});

  Future<void> _openArticle() async {
    final uri = Uri.parse(article.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: _openArticle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.network(
                article.imageUrl,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xFFEDEFF2),
                  child: Icon(Icons.broken_image_outlined, size: 42),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        article.source.toUpperCase(),
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        article.age,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Chip(
                        label: Text(article.topic),
                        visualDensity: VisualDensity.compact,
                      ),
                      const Spacer(),
                      const Icon(Icons.open_in_new_rounded, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
