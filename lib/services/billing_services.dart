import 'package:cloud_firestore/cloud_firestore.dart';
import 'rate_service.dart';

class BillingService {

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final RateService _rateService =
      RateService();

  // GENERATE BILL
  Future<Map<String, dynamic>> generateBill({

    required String accountNumber,
    required double currentReading,
    required String tellerId,
    required String tellerName,

  }) async {

    // FIND CONSUMER
    QuerySnapshot consumerQuery =
        await _firestore
            .collection('users')
            .where(
              'account_number',
              isEqualTo: accountNumber,
            )
            .where(
              'user_type',
              isEqualTo: 'consumer',
            )
            .limit(1)
            .get();

    if (consumerQuery.docs.isEmpty) {

      throw Exception(
        'Consumer not found',
      );
    }

    final consumerDoc =
        consumerQuery.docs.first;

    final consumerData =
        consumerDoc.data()
            as Map<String, dynamic>;

    final consumerId =
        consumerDoc.id;

    // GET PREVIOUS READING
    double previousReading =
        await _getPreviousReading(
          consumerId,
        );

    // VALIDATION
    if (currentReading <
        previousReading) {

      throw Exception(
        'Current reading must be greater than previous reading',
      );
    }

    // COMPUTATION
    double consumption =
        currentReading -
            previousReading;

    double ratePerKwh =
        await _rateService
            .getCurrentRate();

    double totalBill =
        consumption *
            ratePerKwh;

    // BILL ID
    String billId =
        _firestore
            .collection('bills')
            .doc()
            .id;

    // BILL DATA
    Map<String, dynamic> billData = {

      'bill_id': billId,

      'consumer_id': consumerId,

      'consumer_name':
          consumerData['full_name'],

      'account_number':
          accountNumber,

      'previous_reading':
          previousReading,

      'current_reading':
          currentReading,

      'consumption':
          consumption,

      'rate':
          ratePerKwh,

      'total_bill':
          totalBill,

      'billing_period':
          _getBillingPeriod(),

      'due_date':
          _getDueDate(),

      'status':
          'unpaid',

      'generated_by':
          tellerName,

      'generated_by_id':
          tellerId,

      'created_at':
          FieldValue.serverTimestamp(),
    };

    // SAVE TO FIRESTORE
    await _firestore
        .collection('bills')
        .doc(billId)
        .set(billData);

    return billData;
  }

  // GET LAST READING
  Future<double> _getPreviousReading(
    String consumerId,
  ) async {

    QuerySnapshot lastBill =
        await _firestore
            .collection('bills')
            .where(
              'consumer_id',
              isEqualTo: consumerId,
            )
            .orderBy(
              'created_at',
              descending: true,
            )
            .limit(1)
            .get();

    if (lastBill.docs.isEmpty) {

      return 0;
    }

    final data =
        lastBill.docs.first.data()
            as Map<String, dynamic>;

    return (data['current_reading'] ?? 0)
        .toDouble();
  }

  // BILLING PERIOD
  String _getBillingPeriod() {

    DateTime now = DateTime.now();

    return '${_getMonthName(now.month)} ${now.year}';
  }

  // MONTH NAME
  String _getMonthName(int month) {

    const months = [

      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  // DUE DATE
  DateTime _getDueDate() {

    return DateTime.now().add(
      const Duration(days: 15),
    );
  }

  // GET CONSUMER BILLS
  Stream<List<Map<String, dynamic>>>
      getConsumerBills(
    String consumerId,
  ) {

    return _firestore
        .collection('bills')
        .where(
          'consumer_id',
          isEqualTo: consumerId,
        )
        .orderBy(
          'created_at',
          descending: true,
        )
        .snapshots()
        .map(

          (snapshot) => snapshot.docs
              .map(
                (doc) => doc.data(),
              )
              .toList(),
        );
  }

  // GET ALL BILLS
  Stream<List<Map<String, dynamic>>>
      getAllBills() {

    return _firestore
        .collection('bills')
        .orderBy(
          'created_at',
          descending: true,
        )
        .snapshots()
        .map(

          (snapshot) => snapshot.docs
              .map(
                (doc) => doc.data(),
              )
              .toList(),
        );
  }

  // UPDATE STATUS
  Future<void> updateBillStatus(

    String billId,
    String status,

  ) async {

    await _firestore
        .collection('bills')
        .doc(billId)
        .update({

      'status': status,

      'updated_at':
          FieldValue.serverTimestamp(),
    });
  }
}