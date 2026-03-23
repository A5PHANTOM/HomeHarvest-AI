import 'package:flutter/material.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

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
        body: const TabBarView(
          children: [
            _MarketplaceListings(),
            _MapViewPlaceholder(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
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
  const _MarketplaceListings();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildListingItem(
          title: "Fresh Spinach - Grown Locally",
          price: "₹20 or Trade",
          distance: "0.5 km away",
          seller: "Rahul M.",
          time: "Posted 2 hrs ago",
        ),
        _buildListingItem(
          title: "Organic Tomato Seeds (10 pcs)",
          price: "Free",
          distance: "1.2 km away",
          seller: "Priya S.",
          time: "Posted 5 hrs ago",
        ),
        _buildListingItem(
          title: "Used Terracotta Pots (Medium)",
          price: "₹50 each",
          distance: "2.0 km away",
          seller: "Amit K.",
          time: "Posted 1 day ago",
        ),
      ],
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
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(distance, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(width: 12),
                      Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(seller, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
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
            )
          ],
        ),
      ),
    );
  }
}
