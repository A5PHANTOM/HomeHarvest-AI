import 'package:flutter/material.dart';
import '../services/backend_api.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final data = await BackendApi.getList('/api/marketplace/items');
      if (!mounted) return;
      setState(() {
        _items = data
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

  Future<void> _showPostDialog() async {
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final distanceController = TextEditingController(text: 'Nearby');
    final sellerController = TextEditingController(text: 'Community User');

    final shouldPost = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              TextField(
                controller: distanceController,
                decoration: const InputDecoration(labelText: 'Distance'),
              ),
              TextField(
                controller: sellerController,
                decoration: const InputDecoration(labelText: 'Seller'),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (shouldPost != true) return;

    try {
      await BackendApi.postJson('/api/marketplace/share', {
        'title': titleController.text.trim(),
        'price': priceController.text.trim(),
        'distance': distanceController.text.trim(),
        'seller': sellerController.text.trim(),
        'time_posted': 'Posted just now',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing posted successfully')),
      );
      _loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community Marketplace'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.shopping_bag), text: "Listings"),
              Tab(icon: Icon(Icons.map), text: "Map View"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MarketplaceListings(
              items: _items,
              loading: _loading,
              onRefresh: _loadItems,
            ),
            const _MapViewPlaceholder(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showPostDialog,
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text("Post Item"),
        ),
      ),
    );
  }
}

class _MarketplaceListings extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool loading;
  final Future<void> Function() onRefresh;

  const _MarketplaceListings({
    required this.items,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: items
            .map(
              (item) => _buildListingItem(
                title: (item['title'] ?? '').toString(),
                price: (item['price'] ?? '').toString(),
                distance: (item['distance'] ?? '').toString(),
                seller: (item['seller'] ?? '').toString(),
                time: (item['time_posted'] ?? '').toString(),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildListingItem({
    required String title,
    required String price,
    required String distance,
    required String seller,
    required String time,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, size: 40, color: Colors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        seller,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapViewPlaceholder extends StatelessWidget {
  const _MapViewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 100, color: Colors.green.shade200),
            const SizedBox(height: 16),
            const Text(
              "Interactive Map View",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Shows nearby sellers, nurseries, and community gardens. (Google Maps integration pending API key)",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.my_location),
              label: const Text("Use My Current Location"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
