import 'package:flutter/material.dart';

import 'auction_session.dart';
import 'item.dart';
import 'services/firebase_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  late final Stream<List<Item>> _itemsStream;
  late final Stream<List<AuctionSession>> _sessionsStream;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _itemsStream = FirebaseService.instance.getItemsStream();
    _sessionsStream = FirebaseService.instance.getAuctionSessionsStream();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vật phẩm'),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Item>>(
        stream: _itemsStream,
        builder: (context, itemSnapshot) {
          if (itemSnapshot.hasError) {
            return _message('Không thể tải sản phẩm: ${itemSnapshot.error}');
          }
          if (!itemSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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
                return const Center(child: CircularProgressIndicator());
              }

              final items = itemSnapshot.data!
                  .where(
                    (item) => item.itemName.toLowerCase().contains(_searchText),
                  )
                  .toList();
              final sessionsByItem = <String, AuctionSession>{};
              for (final session in sessionSnapshot.data!) {
                final existing = sessionsByItem[session.itemId];
                if (existing == null ||
                    _sessionEnd(session).isAfter(_sessionEnd(existing))) {
                  sessionsByItem[session.itemId] = session;
                }
              }

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm sản phẩm',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Không có sản phẩm phù hợp.')),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final session = sessionsByItem[item.id.toString()];
                        return _ItemCard(item: item, session: session);
                      },
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

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.session});

  final Item item;
  final AuctionSession? session;

  @override
  Widget build(BuildContext context) {
    final price = session != null && session!.currentHighestBid > 0
        ? session!.currentHighestBid
        : item.startingPrice;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: item.imageUrl.isEmpty
                  ? const Center(child: Icon(Icons.image_outlined, size: 40))
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Giá hiện tại: ${_formatPrice(price)} VNĐ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('Trạng thái: ${item.status}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPrice(int price) => price.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (match) => '.',
);
