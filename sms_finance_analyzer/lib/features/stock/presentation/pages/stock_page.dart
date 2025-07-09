import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _controller = TextEditingController();
  String? _ltp;
  String? _error;
  bool _loading = false;

  Future<void> fetchStockLTP(String symbol) async {
    setState(() {
      _loading = true;
      _error = null;
      _ltp = null;
    });
    try {
      // Replace with your backend endpoint and pass the symbol as a query param
      final response = await http.get(Uri.parse('https://api-deploy-render-wihd.onrender.com/ltp?symbol=$symbol'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _ltp = data['ltp'].toString();
        });
      } else {
        setState(() {
          _error = 'Failed to fetch data';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Market')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter Stock Symbol (e.g. TATAMOTORS)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () {
                      final symbol = _controller.text.trim();
                      if (symbol.isNotEmpty) {
                        fetchStockLTP(symbol);
                      }
                    },
              child: _loading ? const CircularProgressIndicator() : const Text('Get LTP'),
            ),
            const SizedBox(height: 24),
            if (_ltp != null)
              Text('Latest Price: ₹$_ltp', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
