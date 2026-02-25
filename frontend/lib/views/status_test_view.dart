import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../models/status_response.dart';
import '../services/base_service.dart';
import '../services/status_service.dart';

class StatusTestView extends StatefulWidget {
  const StatusTestView({super.key});

  @override
  State<StatusTestView> createState() => _StatusTestViewState();
}

class _StatusTestViewState extends State<StatusTestView> {
  late final StatusService _statusService;
  StatusResponse? _response;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final tokenStorage = InMemoryTokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final baseService = BaseService(apiClient);
    _statusService = StatusService(baseService);
  }

  Future<void> _callStatus() async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await _statusService.getStatus();
      if (!mounted) return;
      setState(() {
        _response = response;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _response?.status ?? '-';
    final messageText = _response?.message ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _callStatus,
              child: Text(_loading ? 'Loading...' : 'Call /api/status'),
            ),
            const SizedBox(height: 16),
            Text('status: $statusText'),
            const SizedBox(height: 8),
            Text('message: $messageText'),
          ],
        ),
      ),
    );
  }
}
