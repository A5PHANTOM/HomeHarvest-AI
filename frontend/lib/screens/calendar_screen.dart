import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sowing Calendar & Reminders'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Upcoming Reminders",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildReminderCard(
            title: "Water Tomatoes 💧",
            time: "Today, 5:00 PM",
            icon: Icons.water_drop,
            color: Colors.blue,
          ),
          _buildReminderCard(
            title: "Add Organic Compost 🧴",
            time: "Tomorrow, 9:00 AM",
            icon: Icons.eco,
            color: Colors.brown,
          ),
          const SizedBox(height: 24),
          const Text(
            "My Garden Calendar",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildCalendarItem(
            plant: "Mint",
            action: "Harvest in",
            days: "10 Days",
            progress: 0.7,
            color: Colors.green,
          ),
          _buildCalendarItem(
            plant: "Tomatoes",
            action: "Harvest in",
            days: "25 Days",
            progress: 0.4,
            color: Colors.orange,
          ),
          _buildCalendarItem(
            plant: "Spinach",
            action: "Seeds Sown",
            days: "Today",
            progress: 0.05,
            color: Colors.lightGreen,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
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
                Text(plant, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  days,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
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
