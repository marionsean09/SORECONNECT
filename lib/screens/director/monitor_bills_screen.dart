import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonitorBillsScreen extends StatelessWidget {
  const MonitorBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Bills'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('bills')
            .orderBy('generatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Text('Loading...'));
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final bills = snapshot.data!.docs;
          
          if (bills.isEmpty) {
            return const Center(child: Text('No bills found'));
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final data = bills[index].data();
              return Card(
                child: ListTile(
                  leading: Icon(
                    data['status'] == 'paid' ? Icons.check_circle : Icons.pending,
                    color: data['status'] == 'paid' ? const Color.fromARGB(255, 236, 213, 5) : Colors.orange,
                  ),
                  title: Text(data['consumerName'] ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account: ${data['accountNumber'] ?? 'N/A'}'),
                      Text('Period: ${data['billingPeriod'] ?? 'N/A'}'),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '₱${(data['totalAmount'] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: data['status'] == 'paid' ? const Color.fromARGB(255, 225, 152, 5) : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data['status']?.toUpperCase() ?? 'UNPAID',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
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
  }
}