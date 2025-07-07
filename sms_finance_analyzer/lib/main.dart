import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const SMSFinanceAnalyzerApp());
}

class SMSFinanceAnalyzerApp extends StatelessWidget {
  const SMSFinanceAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Finance Analyzer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SMSHomePage(),
    );
  }
}

class SMSHomePage extends StatefulWidget {
  const SMSHomePage({super.key});

  @override
  State<SMSHomePage> createState() => _SMSHomePageState();
}

class _SMSHomePageState extends State<SMSHomePage> {
  bool _loading = false;
  String? _error;
  List<FinancialSMS> _allSMS = [];
  List<FinancialSMS> _filteredSMS = [];
  String _selectedYear = 'All Years';
  String _selectedMonth = 'All Months';
  String _selectedCategory = 'All Categories';

  // Categories and keywords
  final Map<String, List<String>> categories = {
    'Food': ['grocery', 'supermarket', 'restaurant', 'cafe'],
    'Housing': ['rent', 'mortgage', 'utilities'],
    'Transportation': ['gas', 'bus', 'train', 'taxi', 'avenue zipcash', 'phonepe recharge'],
    'Entertainment': ['movie', 'concert', 'game'],
    'Bills': ['olamoney', 'postpaid', 'recharge'],
    'Other': []
  };

  // Financial keywords
  final List<String> financialKeywords = [
    "debited", "credited", "transaction", "purchase", "withdrawn", "paid"
  ];

  // Regex patterns
  final RegExp amountRegex = RegExp(r'(INR|Rs\.?|₹)\s?([\d,]+\.\d{2})', caseSensitive: false);
  final RegExp balanceRegex = RegExp(r'Avl Bal (\d+\.\d{2})\b', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    _fetchSMS();
  }

  Future<void> _fetchSMS() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var status = await Permission.sms.request();
      if (!status.isGranted) {
        setState(() {
          _error = 'SMS permission denied. Please allow SMS access.';
          _loading = false;
        });
        return;
      }

      final Telephony telephony = Telephony.instance;
      List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );

      List<FinancialSMS> financialSMS = [];
      double latestBalance = 0.0;

      for (var sms in messages) {
        String body = sms.body?.toLowerCase() ?? '';
        String address = sms.address ?? '';
        DateTime? date = sms.date != null ? DateTime.fromMillisecondsSinceEpoch(sms.date!) : null;

        // Filter financial messages
        if (financialKeywords.any((k) => body.contains(k)) || address.contains('BOIIND')) {
          // Extract amount
          double amount = 0.0;
          var amountMatch = amountRegex.firstMatch(sms.body ?? '');
          if (amountMatch != null) {
            amount = double.tryParse(amountMatch.group(2)!.replaceAll(',', '')) ?? 0.0;
          }

          // Transaction type and description
          String transactionType = 'other';
          String description = (sms.body ?? '').substring(0, (sms.body ?? '').length > 100 ? 100 : (sms.body ?? '').length);

          if (body.contains('credited')) {
            transactionType = 'credit';
            if (body.contains('by ')) {
              description = body.split('by ').last.split('.').first;
            }
          } else if (['debited', 'withdrawn', 'purchase', 'paid'].any((k) => body.contains(k))) {
            transactionType = 'debit';
            amount = -amount;
            if (body.contains('from ')) {
              description = body.split('from ').last.split('.').first;
            }
          }

          // Extract balance
          double? balance;
          var balanceMatch = balanceRegex.firstMatch(sms.body ?? '');
          if (balanceMatch != null) {
            balance = double.tryParse(balanceMatch.group(1) ?? '');
            if (balance != null) {
              latestBalance = latestBalance > balance ? latestBalance : balance;
            }
          }

          if (amount != 0.0 || balance != null) {
            financialSMS.add(FinancialSMS(
              text: sms.body ?? '',
              date: date,
              amount: amount,
              type: transactionType,
              balance: balance,
              description: description,
              category: _categorize(description),
            ));
          }
        }
      }

      setState(() {
        _allSMS = financialSMS;
        _filteredSMS = financialSMS;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error fetching SMS: $e';
        _loading = false;
      });
    }
  }

  String _categorize(String description) {
    String descLower = description.toLowerCase();
    for (var entry in categories.entries) {
      if (entry.value.any((k) => descLower.contains(k))) {
        return entry.key;
      }
    }
    return 'Other';
  }

  void _applyFilters() {
    setState(() {
      _filteredSMS = _allSMS.where((sms) {
        bool yearMatch = _selectedYear == 'All Years' ||
            (sms.date != null && sms.date!.year.toString() == _selectedYear);
        bool monthMatch = _selectedMonth == 'All Months' ||
            (sms.date != null && DateFormat('MMMM').format(sms.date!) == _selectedMonth);
        bool categoryMatch = _selectedCategory == 'All Categories' ||
            sms.category == _selectedCategory;
        return yearMatch && monthMatch && categoryMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Collect filter options
    final years = [
      'All Years',
      ..._allSMS
          .where((sms) => sms.date != null)
          .map((sms) => sms.date!.year.toString())
          .toSet()
          .toList()
        ..sort()
    ];
    final months = [
      'All Months',
      ..._allSMS
          .where((sms) => sms.date != null)
          .map((sms) => DateFormat('MMMM').format(sms.date!))
          .toSet()
          .toList()
        ..sort((a, b) => DateFormat('MMMM').parse(a).month.compareTo(DateFormat('MMMM').parse(b).month))
    ];
    final categoriesList = [
      'All Categories',
      ..._allSMS.map((sms) => sms.category).toSet().toList()..sort()
    ];

    // Analysis
    double totalExpense = 0.0;
    double totalCredits = 0.0;
    double currentBalance = 0.0;
    double initialBalance = 0.0;
    Map<String, double> expenditureByCategory = {};
    Map<String, double> expenditureByMonth = {};
    String topSpendingCategory = 'None';
    double topSpendingAmount = 0.0;
    double averageMonthlySpending = 0.0;
    FinancialSMS? largestTransaction;

    if (_filteredSMS.isNotEmpty) {
      for (var sms in _filteredSMS) {
        if (sms.type == 'debit') {
          totalExpense += sms.amount.abs();
          expenditureByCategory[sms.category] = (expenditureByCategory[sms.category] ?? 0) + sms.amount.abs();
          if (sms.date != null) {
            String month = DateFormat('yyyy-MM').format(sms.date!);
            expenditureByMonth[month] = (expenditureByMonth[month] ?? 0) + sms.amount.abs();
          }
        } else if (sms.type == 'credit') {
          totalCredits += sms.amount;
        }
        if (sms.balance != null && sms.balance! > currentBalance) {
          currentBalance = sms.balance!;
        }
      }
      initialBalance = currentBalance - (totalCredits - totalExpense);
      if (expenditureByCategory.isNotEmpty) {
        topSpendingCategory = expenditureByCategory.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        topSpendingAmount = expenditureByCategory[topSpendingCategory]!;
      }
      if (expenditureByMonth.isNotEmpty) {
        averageMonthlySpending = expenditureByMonth.values.reduce((a, b) => a + b) / expenditureByMonth.length;
      }
      if (_filteredSMS.where((sms) => sms.type == 'debit').isNotEmpty) {
        largestTransaction = _filteredSMS
            .where((sms) => sms.type == 'debit')
            .reduce((a, b) => a.amount < b.amount ? a : b);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SMS Finance Analyzer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Filters
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedYear,
                              items: years
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _selectedYear = v!);
                                _applyFilters();
                              },
                              isExpanded: true,
                              hint: const Text('Year'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedMonth,
                              items: months
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _selectedMonth = v!);
                                _applyFilters();
                              },
                              isExpanded: true,
                              hint: const Text('Month'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              items: categoriesList
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _selectedCategory = v!);
                                _applyFilters();
                              },
                              isExpanded: true,
                              hint: const Text('Category'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Summary
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Current Balance: ₹${currentBalance.toStringAsFixed(2)}"),
                              Text("Initial Balance: ₹${initialBalance.toStringAsFixed(2)}"),
                              Text("Total Credits: ₹${totalCredits.toStringAsFixed(2)}"),
                              Text("Total Debits: ₹${totalExpense.toStringAsFixed(2)}"),
                              Text("Average Monthly Spending: ₹${averageMonthlySpending.toStringAsFixed(2)}"),
                              Text("Top Spending Category: $topSpendingCategory (₹${topSpendingAmount.toStringAsFixed(2)})"),
                              if (largestTransaction != null)
                                Text(
                                    "Largest Transaction: ${largestTransaction.description} on ${largestTransaction.date != null ? DateFormat('yyyy-MM-dd').format(largestTransaction.date!) : ''} (₹${largestTransaction.amount.abs().toStringAsFixed(2)})"),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Charts
                      // if (expenditureByCategory.isNotEmpty)
                      //   SizedBox(
                      //     height: 200,
                      //     child: charts.BarChart(
                      //       [
                      //         charts.Series<MapEntry<String, double>, String>(
                      //           id: 'SpendingByCategory',
                      //           colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
                      //           domainFn: (entry, _) => entry.key,
                      //           measureFn: (entry, _) => entry.value,
                      //           data: expenditureByCategory.entries.toList(),
                      //         )
                      //       ],
                      //       animate: true,
                      //     ),
                      //   ),
                      // if (expenditureByMonth.isNotEmpty)
                      //   SizedBox(
                      //     height: 200,
                      //     child: charts.TimeSeriesChart(
                      //       [
                      //         charts.Series<MapEntry<String, double>, DateTime>(
                      //           id: 'MonthlySpending',
                      //           colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
                      //           domainFn: (entry, _) => DateFormat('yyyy-MM').parse(entry.key),
                      //           measureFn: (entry, _) => entry.value,
                      //           data: expenditureByMonth.entries.toList(),
                      //         )
                      //       ],
                      //       animate: true,
                      //     ),
                      //   ),
                      const SizedBox(height: 8),
                      // Transaction Table
                      Expanded(
                        child: _filteredSMS.isEmpty
                            ? const Center(child: Text('No transactions found.'))
                            : ListView.builder(
                                itemCount: _filteredSMS.length,
                                itemBuilder: (context, i) {
                                  final sms = _filteredSMS[i];
                                  return Card(
                                    child: ListTile(
                                      title: Text(
                                          "${sms.type == 'debit' ? '-' : '+'}₹${sms.amount.abs().toStringAsFixed(2)} | ${sms.category}"),
                                      subtitle: Text(
                                          "${sms.description}\n${sms.date != null ? DateFormat('yyyy-MM-dd HH:mm').format(sms.date!) : ''}"),
                                      isThreeLine: true,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchSMS,
        tooltip: 'Refresh SMS',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class FinancialSMS {
  final String text;
  final DateTime? date;
  final double amount;
  final String type;
  final double? balance;
  final String description;
  final String category;

  FinancialSMS({
    required this.text,
    required this.date,
    required this.amount,
    required this.type,
    required this.balance,
    required this.description,
    required this.category,
  });
}
