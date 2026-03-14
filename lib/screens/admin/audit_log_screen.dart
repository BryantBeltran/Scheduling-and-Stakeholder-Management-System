import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<AuditLogModel> _logs = [];
  bool _isLoading = true;
  String? _error;
  String? _lastDocId;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getAuditLogs');
      final result = await callable.call<dynamic>({
        'limit': 50,
        if (_lastDocId != null && loadMore) 'startAfter': _lastDocId,
      });

      final data = (result.data as List<dynamic>)
          .map((e) => AuditLogModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      setState(() {
        if (loadMore) {
          _logs.addAll(data);
        } else {
          _logs = data;
        }
        _hasMore = data.length >= 50;
        if (data.isNotEmpty) _lastDocId = data.last.id;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audit Log',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load audit logs',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _loadLogs(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history,
                              size: 64, color: Theme.of(context).hintColor),
                          const SizedBox(height: 16),
                          Text(
                            'No audit log entries yet',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _lastDocId = null;
                        await _loadLogs();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _logs.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: TextButton(
                                  onPressed: () => _loadLogs(loadMore: true),
                                  child: const Text('Load more'),
                                ),
                              ),
                            );
                          }

                          final log = _logs[index];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Theme.of(context).dividerColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        _actionColor(log.action)
                                            .withValues(alpha: 0.15),
                                    child: Icon(
                                      _actionIcon(log.action),
                                      size: 18,
                                      color: _actionColor(log.action),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              log.actionLabel,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _formatTimestamp(log.createdAt),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          log.description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'by ${log.actorName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Color _actionColor(String action) {
    if (action.startsWith('create')) return Colors.green;
    if (action.startsWith('update')) return Colors.blue;
    if (action.startsWith('delete')) return Colors.red;
    if (action.startsWith('assign')) return Colors.orange;
    return Colors.grey;
  }

  IconData _actionIcon(String action) {
    if (action.contains('event')) return Icons.event;
    if (action.contains('stakeholder')) return Icons.people;
    if (action.contains('role')) return Icons.admin_panel_settings;
    return Icons.history;
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day';
  }
}
