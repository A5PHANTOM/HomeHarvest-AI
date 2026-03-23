import 'package:flutter/material.dart';
import '../services/backend_api.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _calendarItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final reminders = await BackendApi.getList('/api/calendar/reminders');
      final calendar = await BackendApi.getList('/api/calendar/progress');

      if (!mounted) return;
      setState(() {
        _reminders = reminders
            .whereType<Map>()
            .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
        _calendarItems = calendar
            .whereType<Map>()
            .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addReminderDialog() async {
    final titleController = TextEditingController();
    final timeController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Reminder title'),
            ),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: 'Time (e.g. Tomorrow, 8:00 AM)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) return;

    try {
      await BackendApi.postJson('/api/calendar/reminders', {
        'title': titleController.text.trim(),
        'time': timeController.text.trim(),
        'icon': 'schedule',
        'color': 'green',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reminder added')));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sowing Calendar & Reminders'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text(
                    "Upcoming Reminders",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._reminders.map(
                    (item) => _buildReminderCard(
                      title: (item['title'] ?? '').toString(),
                      time: (item['time'] ?? '').toString(),
                      icon: _iconFromName((item['icon'] ?? '').toString()),
                      color: _colorFromName((item['color'] ?? '').toString()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "My Garden Calendar",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._calendarItems.map(
                    (item) => _buildCalendarItem(
                      plant: (item['plant'] ?? '').toString(),
                      action: (item['action'] ?? '').toString(),
                      days: (item['days'] ?? '').toString(),
                      progress: (item['progress'] is num)
                          ? (item['progress'] as num).toDouble()
                          : 0.0,
                      color: _colorFromName((item['color'] ?? '').toString()),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminderDialog,
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  IconData _iconFromName(String icon) {
    switch (icon) {
      case 'eco':
        return Icons.eco;
      case 'schedule':
        return Icons.schedule;
      case 'water_drop':
      default:
        return Icons.water_drop;
    }
  }

  Color _colorFromName(String color) {
    switch (color) {
      case 'brown':
        return Colors.brown;
      case 'orange':
        return Colors.orange;
      case 'lightGreen':
        return Colors.lightGreen;
      case 'green':
        return Colors.green;
      case 'blue':
      default:
        return Colors.blue;
    }
  }

  Widget _buildReminderCard({
    required String title,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(time),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildCalendarItem({
    required String plant,
    required String action,
    required String days,
    required double progress,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plant,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  days,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(action, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
