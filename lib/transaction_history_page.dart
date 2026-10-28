import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
            appBar: AppBar(title: const Text('Lịch sử giao dịch')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lịch sử giao dịch')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Vui lòng đăng nhập để xem lịch sử giao dịch.'),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Lịch sử giao dịch')),
          body: StreamBuilder<List<TransactionModel>>(
            stream: TransactionService.instance.getTransactionsStream(
              userUid: user.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Không thể tải giao dịch: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final transactions = snapshot.data!;
              if (transactions.isEmpty) {
                return const Center(child: Text('Bạn chưa có giao dịch nào.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: transactions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final isPaid =
                      transaction.status.toLowerCase().contains('paid') ||
                      transaction.status.toLowerCase().contains('complete');
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPaid
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        child: Icon(
                          isPaid ? Icons.check_circle_outline : Icons.schedule,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text('Giao dịch #${transaction.transactionId}'),
                      subtitle: Text(
                        '${transaction.paymentMethod.isEmpty ? 'Thanh toán đấu giá' : transaction.paymentMethod}\n'
                        '${transaction.createdAt == null ? '' : _formatDate(transaction.createdAt!)}',
                      ),
                      isThreeLine: transaction.createdAt != null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_formatPrice(transaction.amount)} đ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            transaction.status,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _messageScaffold(String message) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử giao dịch')),
    body: Center(child: Text(message)),
  );

  static String _formatPrice(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
