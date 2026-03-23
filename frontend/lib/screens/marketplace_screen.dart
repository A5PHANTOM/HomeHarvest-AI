import 'package:flutter/material.dart';
import '../config/api_config.dart';
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
    final descriptionController = TextEditingController();
    final imageUrlController = TextEditingController();

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
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price *'),
              ),
              TextField(
                controller: distanceController,
                decoration: const InputDecoration(labelText: 'Distance'),
              ),
              TextField(
                controller: sellerController,
                decoration: const InputDecoration(labelText: 'Seller'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 2,
              ),
              TextField(
                controller: imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                ),
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
        'description': descriptionController.text.trim(),
        'image_url': imageUrlController.text.trim(),
        'is_out_of_stock': 0,
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
                context: context,
                itemId: int.tryParse((item['id'] ?? '').toString()) ?? 0,
                title: (item['title'] ?? '').toString(),
                price: (item['price'] ?? '').toString(),
                distance: (item['distance'] ?? '').toString(),
                seller: (item['seller'] ?? '').toString(),
                time: (item['time_posted'] ?? '').toString(),
                description: (item['description'] ?? '').toString(),
                imageUrl: (item['image_url'] ?? '').toString(),
                isOutOfStock:
                    int.tryParse((item['is_out_of_stock'] ?? '0').toString()) ??
                    0,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showBuyNowDialog(
    BuildContext context, {
    required int itemId,
    required String itemTitle,
    required bool isOutOfStock,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (isOutOfStock) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This item is currently out of stock.')),
      );
      return;
    }

    final emailController = TextEditingController();
    final messageController = TextEditingController();

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buy Now'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send request for: $itemTitle'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Your Gmail ID',
                hintText: 'example@gmail.com',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'I want to buy this item',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (shouldSend != true) return;

    final email = emailController.text.trim().toLowerCase();
    if (!email.endsWith('@gmail.com')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid Gmail ID.')),
      );
      return;
    }

    try {
      await BackendApi.postJson('/api/marketplace/buy', {
        'item_id': itemId,
        'buyer_email': email,
        'buyer_message': messageController.text.trim(),
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Request sent to admin successfully.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildListingItem({
    required BuildContext context,
    required int itemId,
    required String title,
    required String price,
    required String distance,
    required String seller,
    required String time,
    String description = '',
    String imageUrl = '',
    int isOutOfStock = 0,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageUrl.isNotEmpty && imageUrl != ''
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl.startsWith('http')
                            ? imageUrl
                            : '${ApiConfig.baseUrl}$imageUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.eco,
                              size: 60,
                              color: Colors.green,
                            ),
                          );
                        },
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.eco, size: 60, color: Colors.green),
                    ),
            ),
            const SizedBox(height: 12),
            // Title with stock badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOutOfStock == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Out of Stock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Description
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Price
            Text(
              price,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            // Location and Seller
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  distance,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    seller,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isOutOfStock == 1
                    ? null
                    : () => _showBuyNowDialog(
                        context,
                        itemId: itemId,
                        itemTitle: title,
                        isOutOfStock: isOutOfStock == 1,
                      ),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: Text(isOutOfStock == 1 ? 'Out of Stock' : 'Buy Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock == 1
                      ? Colors.grey.shade400
                      : Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
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
