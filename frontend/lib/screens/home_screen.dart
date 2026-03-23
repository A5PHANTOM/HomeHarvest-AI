import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/backend_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _myGardenStorageKey = 'my_garden_items';

  bool _loading = true;
  List<Map<String, dynamic>> _recommendedPlants = [];
  List<Map<String, dynamic>> _myGardenPlants = [];
  List<Map<String, dynamic>> _news = [];
  bool _newsRefreshing = false;
  String _selectedSpaceType = 'balcony';
  String _selectedSunlight = 'medium';
  final TextEditingController _locationController = TextEditingController(
    text: 'Kerala',
  );
  final TextEditingController _customPreferenceController =
      TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    _customPreferenceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadMyGardenFromStorage();
    _loadData();
  }

  Future<void> _loadMyGardenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_myGardenStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items = decoded
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
      if (!mounted) return;
      setState(() => _myGardenPlants = items);
    } catch (_) {
      // ignore corrupted local data
    }
  }

  Future<void> _persistMyGarden() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_myGardenStorageKey, jsonEncode(_myGardenPlants));
  }

  bool _isPlantInMyGarden(String name) {
    return _myGardenPlants.any(
      (plant) =>
          (plant['name'] ?? '').toString().toLowerCase() == name.toLowerCase(),
    );
  }

  Future<void> _addPlantToMyGarden(Map<String, dynamic> plant) async {
    final name = (plant['name'] ?? '').toString();
    if (name.isEmpty || _isPlantInMyGarden(name)) return;

    setState(() {
      _myGardenPlants = [..._myGardenPlants, plant];
    });
    await _persistMyGarden();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name added to My Garden')));
  }

  Future<void> _removePlantFromMyGarden(String name) async {
    setState(() {
      _myGardenPlants = _myGardenPlants
          .where(
            (plant) =>
                (plant['name'] ?? '').toString().toLowerCase() !=
                name.toLowerCase(),
          )
          .toList();
    });
    await _persistMyGarden();
  }

  Future<void> _showAddCustomPlantDialog() async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    String selectedColor = 'teal';

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Custom Plant'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Plant Name',
                      hintText: 'e.g. Mint',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Status / Notes',
                      hintText: 'e.g. Daily watering, custom pot',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedColor,
                    decoration: const InputDecoration(labelText: 'Card Color'),
                    items: const [
                      DropdownMenuItem(value: 'teal', child: Text('Teal')),
                      DropdownMenuItem(value: 'green', child: Text('Green')),
                      DropdownMenuItem(value: 'orange', child: Text('Orange')),
                      DropdownMenuItem(
                        value: 'lightGreen',
                        child: Text('Light Green'),
                      ),
                      DropdownMenuItem(value: 'red', child: Text('Red')),
                      DropdownMenuItem(
                        value: 'deepPurple',
                        child: Text('Deep Purple'),
                      ),
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
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldAdd != true) return;

    final name = nameController.text.trim();
    if (_isPlantInMyGarden(name)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name is already in My Garden')));
      return;
    }

    final customPlant = {
      'name': name,
      'status': notesController.text.trim().isEmpty
          ? 'Custom plant added by you'
          : notesController.text.trim(),
      'color': selectedColor,
      'isCustom': true,
    };

    setState(() {
      _myGardenPlants = [..._myGardenPlants, customPlant];
    });
    await _persistMyGarden();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name added to My Garden')));
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final recommend = await BackendApi.postJson('/api/recommend', {
        'space_type': _selectedSpaceType,
        'sunlight_level': _selectedSunlight,
        'location': _locationController.text.trim().isEmpty
            ? 'Unknown'
            : _locationController.text.trim(),
        'custom_query': _customPreferenceController.text.trim(),
      });
      final newsList = await BackendApi.getList('/api/home/news');

      final plants = (recommend['recommendations'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
          .toList();

      final news = newsList
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
          .toList();

      if (!mounted) return;
      setState(() {
        _recommendedPlants = plants;
        _news = news;
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

  Future<void> _refreshNewsOnly() async {
    setState(() => _newsRefreshing = true);
    try {
      final newsList = await BackendApi.getList('/api/home/news');
      final news = newsList
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
          .toList();

      if (!mounted) return;
      setState(() {
        _news = news;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _newsRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeHarvest AI'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Change Language',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Language switching available soon (English / Hindi / Malayalam)",
                  ),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeBanner(),
                    const SizedBox(height: 16),
                    _buildRecommendationInputs(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "My Garden",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: _showAddCustomPlantDialog,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add Custom'),
                            ),
                            TextButton(
                              onPressed: () async {
                                setState(() => _myGardenPlants = []);
                                await _persistMyGarden();
                              },
                              child: const Text("Clear All"),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildMyGardenHorizontalList(),
                    const SizedBox(height: 24),
                    const Text(
                      "Recommended For You",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRecommendedHorizontalList(),
                    const SizedBox(height: 24),
                    _buildNewsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Hello, Urban Gardener! 🌱",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Ready to grow some fresh produce today?",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade700,
            ),
            child: const Text("Get AI Recommendation"),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationInputs() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommendation Inputs',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSpaceType,
                    decoration: const InputDecoration(
                      labelText: 'Space',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'balcony',
                        child: Text('Balcony'),
                      ),
                      DropdownMenuItem(
                        value: 'terrace',
                        child: Text('Terrace'),
                      ),
                      DropdownMenuItem(value: 'indoor', child: Text('Indoor')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedSpaceType = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSunlight,
                    decoration: const InputDecoration(
                      labelText: 'Sunlight',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'full', child: Text('Full')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedSunlight = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Kerala',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customPreferenceController,
              decoration: const InputDecoration(
                labelText: 'Custom Preference (Optional)',
                hintText: 'e.g. tomato for balcony, low water winter crops',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyGardenHorizontalList() {
    if (_myGardenPlants.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'No plants added yet. Use + on recommendations to add plants to My Garden.',
        ),
      );
    }

    return SizedBox(
      height: 170,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _myGardenPlants
            .map(
              (plant) => _buildGardenPlantCard(
                (plant['name'] ?? '').toString(),
                (plant['status'] ?? '').toString(),
                _mapColor((plant['color'] ?? '').toString()),
                actionIcon: Icons.delete_outline,
                actionTooltip: 'Remove from My Garden',
                onActionTap: () =>
                    _removePlantFromMyGarden((plant['name'] ?? '').toString()),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildRecommendedHorizontalList() {
    if (_recommendedPlants.isEmpty) {
      return const Text('No recommendations available.');
    }

    return SizedBox(
      height: 170,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _recommendedPlants.map((plant) {
          final name = (plant['name'] ?? '').toString();
          final added = _isPlantInMyGarden(name);
          return _buildGardenPlantCard(
            name,
            (plant['status'] ?? '').toString(),
            _mapColor((plant['color'] ?? '').toString()),
            actionIcon: added ? Icons.check_circle : Icons.add_circle_outline,
            actionTooltip: added ? 'Already in My Garden' : 'Add to My Garden',
            onActionTap: added ? null : () => _addPlantToMyGarden(plant),
          );
        }).toList(),
      ),
    );
  }

  Color _mapColor(String color) {
    switch (color) {
      case 'orange':
        return Colors.orange;
      case 'lightGreen':
        return Colors.lightGreen;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'deepPurple':
        return Colors.deepPurple;
      case 'teal':
      default:
        return Colors.teal;
    }
  }

  Widget _buildGardenPlantCard(
    String name,
    String status,
    Color color, {
    IconData? actionIcon,
    String? actionTooltip,
    VoidCallback? onActionTap,
  }) {
    return Container(
      width: 165,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (actionIcon != null)
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: onActionTap,
                child: Tooltip(
                  message: actionTooltip ?? '',
                  child: Icon(actionIcon, color: color),
                ),
              ),
            ),
          Icon(Icons.local_florist, size: 40, color: color),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              status,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard({required String title, required String subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.article, color: Colors.green),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildNewsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gardening Tips & News',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _newsRefreshing ? null : _refreshNewsOnly,
                icon: _newsRefreshing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_news.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('No news available right now. Tap refresh.'),
            )
          else
            ..._news.map(
              (n) => _buildNewsCard(
                title: (n['title'] ?? '').toString(),
                subtitle: (n['subtitle'] ?? '').toString(),
              ),
            ),
        ],
      ),
    );
  }
}
