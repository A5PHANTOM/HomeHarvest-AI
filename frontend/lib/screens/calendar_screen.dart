import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/backend_api.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const String _completedReminderIdsKey = 'completed_reminder_ids';
  static const String _myGardenStorageKey = 'my_garden_items';

  bool _loading = true;
  bool _savingReminder = false;
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _calendarItems = [];
  List<Map<String, dynamic>> _myGardenPlants = [];
  Set<int> _completedReminderIds = {};
  DateTime? _lastPlanGeneratedAt;

  @override
  void initState() {
    super.initState();
    _loadCompletedReminderIds();
    _loadData();
  }

  Future<List<Map<String, dynamic>>> _loadMyGardenPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_myGardenStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = raw;
      final parsed = (decoded.isNotEmpty ? decoded : '[]');
      final list = (parsed.isNotEmpty ? parsed : '[]');
      final dynamic jsonList = jsonDecode(list);
      if (jsonList is List) {
        return jsonList
            .whereType<Map>()
            .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadCompletedReminderIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_completedReminderIdsKey) ?? [];
    if (!mounted) return;
    setState(() {
      _completedReminderIds = stored.map(int.tryParse).whereType<int>().toSet();
    });
  }

  Future<void> _persistCompletedReminderIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _completedReminderIdsKey,
      _completedReminderIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final gardenPlants = await _loadMyGardenPlants();

      if (gardenPlants.isEmpty) {
        if (!mounted) return;
        setState(() {
          _myGardenPlants = [];
          _reminders = [];
          _calendarItems = [];
          _lastPlanGeneratedAt = null;
        });
        return;
      }

      final plan = await BackendApi.postJson('/api/calendar/optimize', {
        'plants': gardenPlants
            .map(
              (p) => {
                'name': (p['name'] ?? '').toString(),
                'status': (p['status'] ?? '').toString(),
                'color': (p['color'] ?? '').toString(),
              },
            )
            .toList(),
      });

      final reminders = (plan['reminders'] as List<dynamic>? ?? []);
      final calendar = (plan['calendar'] as List<dynamic>? ?? []);

      if (!mounted) return;
      setState(() {
        _myGardenPlants = gardenPlants;
        _reminders = reminders
            .whereType<Map>()
            .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
            .where((item) {
              final id = item['id'];
              if (id is! int) return true;
              return !_completedReminderIds.contains(id);
            })
            .toList();
        _calendarItems = calendar
            .whereType<Map>()
            .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
        _lastPlanGeneratedAt = DateTime.now();
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
    String selectedIcon = 'schedule';
    String selectedColor = 'green';

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Reminder title',
                  ),
                ),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time (e.g. Tomorrow, 8:00 AM)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  decoration: const InputDecoration(labelText: 'Icon'),
                  items: const [
                    DropdownMenuItem(
                      value: 'schedule',
                      child: Text('Schedule'),
                    ),
                    DropdownMenuItem(value: 'water_drop', child: Text('Water')),
                    DropdownMenuItem(value: 'eco', child: Text('Eco')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedIcon = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedColor,
                  decoration: const InputDecoration(labelText: 'Color'),
                  items: const [
                    DropdownMenuItem(value: 'green', child: Text('Green')),
                    DropdownMenuItem(value: 'blue', child: Text('Blue')),
                    DropdownMenuItem(value: 'brown', child: Text('Brown')),
                    DropdownMenuItem(value: 'orange', child: Text('Orange')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedColor = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    timeController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;

    final customReminder = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'title': titleController.text.trim(),
      'time': timeController.text.trim(),
      'icon': selectedIcon,
      'color': selectedColor,
    };

    setState(() {
      _reminders = [customReminder, ..._reminders];
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reminder added')));
  }

  Future<void> _completeReminder(Map<String, dynamic> reminder) async {
    final id = reminder['id'];
    if (id is int) {
      _completedReminderIds.add(id);
      await _persistCompletedReminderIds();
    }

    setState(() {
      _reminders = _reminders.where((r) => r != reminder).toList();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reminder marked as done ✅')));
  }

  Future<void> _regeneratePlan() async {
    await _loadData();
    if (!mounted) return;
    if (_myGardenPlants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add plants in My Garden first.')),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI plan regenerated ✅')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sowing Calendar & Reminders'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _regeneratePlan,
            tooltip: 'Regenerate AI plan',
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
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
                  if (_lastPlanGeneratedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        'Plan generated at: ${_formatTime(_lastPlanGeneratedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_reminders.isEmpty)
                    _buildEmptyHint(
                      _myGardenPlants.isEmpty
                          ? 'No plants in My Garden. Add plants from Home page first.'
                          : 'No pending reminders. Tap refresh or add one using + button.',
                    )
                  else
                    ..._reminders.map(
                      (item) => _buildReminderCard(
                        reminder: item,
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
                  if (_calendarItems.isEmpty)
                    _buildEmptyHint(
                      _myGardenPlants.isEmpty
                          ? 'No plants in My Garden. Calendar plan appears after adding plants.'
                          : 'No calendar progress data available.',
                    )
                  else
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
        onPressed: _savingReminder ? null : _addReminderDialog,
        backgroundColor: Colors.green.shade700,
        child: _savingReminder
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyHint(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$min';
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
    required Map<String, dynamic> reminder,
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
          onPressed: () => _completeReminder(reminder),
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
                Flexible(
                  child: Text(
                    plant,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
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
              value: progress.clamp(0.0, 1.0),
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
