import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/trips/data/trips_repository.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailScreen({
    super.key,
    required this.tripId,
  });

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _weatherForecast = {};
  bool _loadingWeather = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchWeather();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    try {
      final forecast = await ref.read(tripsRepositoryPrv).getTripWeather(widget.tripId);
      if (mounted) {
        setState(() {
          _weatherForecast = forecast;
          _loadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingWeather = false);
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Trip?>(
      future: ref.watch(tripsRepositoryPrv).getTrip(widget.tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        final trip = snapshot.data;
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Trip not found')),
          );
        }

        final itinerary = trip.itinerary ?? {};
        final days = List<Map<String, dynamic>>.from(itinerary['days'] ?? []);
        final hotels = List<Map<String, dynamic>>.from(itinerary['hotels'] ?? []);
        final restaurants = List<Map<String, dynamic>>.from(itinerary['restaurants'] ?? []);

        return Scaffold(
          body: DefaultTabController(
            length: 4,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 220,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppTheme.primary,
                    iconTheme: const IconThemeData(color: Colors.white),
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        trip.destination,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 22,
                          shadows: [
                            const Shadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4),
                          ],
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (trip.coverImage != null)
                            Image.network(trip.coverImage!, fit: BoxFit.cover)
                          else
                            Container(color: AppTheme.secondary),
                          // Gradient dark overlay
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black38, Colors.black54],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.mutedText,
                        indicatorColor: AppTheme.primary,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(text: 'Itinerary', icon: Icon(Icons.calendar_month_outlined, size: 20)),
                          Tab(text: 'Hotels', icon: Icon(Icons.hotel_outlined, size: 20)),
                          Tab(text: 'Dining', icon: Icon(Icons.restaurant_outlined, size: 20)),
                          Tab(text: 'Map', icon: Icon(Icons.map_outlined, size: 20)),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildItineraryTab(days),
                  _buildHotelsTab(hotels),
                  _buildRestaurantsTab(restaurants),
                  _buildMapTab(trip),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItineraryTab(List<Map<String, dynamic>> days) {
    if (days.isEmpty) {
      return const Center(child: Text('No daily itinerary generated.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: days.length,
      itemBuilder: (context, dIdx) {
        final day = days[dIdx];
        final activities = List<Map<String, dynamic>>.from(day['activities'] ?? []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'DAY ${day['day_number']}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      day['title'] ?? '',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Vertical Timeline of Activities
            ...activities.map((activity) => _buildActivityTimelineRow(activity)),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildActivityTimelineRow(Map<String, dynamic> act) {
    IconData getIcon(String? type) {
      switch (type?.toLowerCase()) {
        case 'food':
          return Icons.restaurant_rounded;
        case 'stay':
          return Icons.hotel_rounded;
        case 'transport':
          return Icons.directions_bus_rounded;
        case 'nature':
          return Icons.forest_rounded;
        case 'nightlife':
          return Icons.nightlife_rounded;
        case 'culture':
          return Icons.museum_rounded;
        case 'relaxation':
          return Icons.spa_rounded;
        case 'adventure':
          return Icons.explore_rounded;
        default:
          return Icons.event_note_rounded;
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time & Connector Line
          SizedBox(
            width: 70,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  act['time'] ?? '12:00',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0DCD3),
                      // Mocking dashes via double list border logic or minimal line
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Circle Marker Icon
          Column(
            children: [
              const SizedBox(height: 6),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.secondary,
                child: Icon(getIcon(act['type']), size: 16, color: AppTheme.primary),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(width: 16),

          // Details Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        act['title'] ?? '',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        act['description'] ?? '',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppTheme.mutedText,
                          height: 1.4,
                        ),
                      ),
                      if (act['location'] != null && act['location'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.mutedText),
                            const SizedBox(width: 4),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _launchUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(act['location'])}'),
                                child: Text(
                                  act['location'],
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelsTab(List<Map<String, dynamic>> hotels) {
    if (hotels.isEmpty) {
      return const Center(child: Text('No hotel recommendations found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: hotels.length,
      itemBuilder: (context, idx) {
        final hotel = hotels[idx];
        final amenities = List<String>.from(hotel['amenities'] ?? []);
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hotel['name'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${hotel['rating'] ?? "4.0"}',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hotel['description'] ?? '',
                  style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                
                // Amenities tags
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: amenities.map((a) => Chip(
                    label: Text(a, style: GoogleFonts.dmSans(fontSize: 10)),
                    backgroundColor: AppTheme.secondary,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
                const SizedBox(height: 16),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '~₹${hotel['price_per_night']?.toStringAsFixed(0) ?? "5000"}/night',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppTheme.foreground, fontSize: 15),
                    ),
                    ElevatedButton(
                      onPressed: () => _launchUrl('https://www.booking.com/searchresults.html?ss=${Uri.encodeComponent(hotel['name'])}'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Book Now', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestaurantsTab(List<Map<String, dynamic>> restaurants) {
    if (restaurants.isEmpty) {
      return const Center(child: Text('No restaurant recommendations found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: restaurants.length,
      itemBuilder: (context, idx) {
        final rest = restaurants[idx];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        rest['name'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${rest['rating'] ?? "4.0"}',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  rest['description'] ?? '',
                  style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rest['cuisine'] ?? 'Local',
                            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (rest['veg_friendly'] == true) ...[
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'Veg Friendly',
                            child: Icon(Icons.eco_rounded, color: Colors.green, size: 18),
                          ),
                        ],
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _launchUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(rest['name'])}'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('View Maps', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapTab(Trip trip) {
    final days = List<Map<String, dynamic>>.from(trip.itinerary?['days'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weather Row
          Text(
            'Weather Forecast',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.foreground),
          ),
          const SizedBox(height: 12),
          _loadingWeather
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _weatherForecast.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Weather forecast only available in real-time when API keys are configured.',
                        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.mutedText),
                      ),
                    )
                  : SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: days.map((d) {
                          final dateStr = d['date'] ?? '';
                          final weatherInfo = _weatherForecast[dateStr];
                          final emoji = weatherInfo != null ? weatherInfo['emoji'] : '🌤️';
                          final temp = weatherInfo != null && weatherInfo['temp'] != null ? '${weatherInfo['temp']}°C' : '--';
                          final desc = weatherInfo != null ? weatherInfo['desc'] : 'no forecast';
                          
                          // Format simple display date (e.g. Aug 15)
                          String dispDate = dateStr;
                          try {
                            dispDate = DateFormat('MMM d').format(DateTime.parse(dateStr));
                          } catch (_) {}

                          return Container(
                            width: 100,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0x0D000000)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(dispDate, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mutedText)),
                                const SizedBox(height: 4),
                                Text(emoji, style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 4),
                                Text(temp, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
          
          const SizedBox(height: 28),

          // Map Placeholder / Blur overlay
          Text(
            'Interactive Map Route',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.foreground),
          ),
          const SizedBox(height: 12),
          
          // Typography map mockup
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1732783384071-0cdb7bbbad94?crop=entropy&cs=srgb&fm=jpg&ixid=M3w4NjAzMzJ8MHwxfHNlYXJjaHwxfHxtYXAlMjB0b3BvZ3JhcGh5fGVufDB8fHx8MTc4NjAyNTU5Mnww&ixlib=rb-4.1.0&q=85',
                    fit: BoxFit.cover,
                  ),
                  Container(color: Colors.black.withOpacity(0.08)),
                  
                  // Blur overlay card
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_rounded, color: AppTheme.primary, size: 24),
                            const SizedBox(height: 6),
                            Text(
                              'Interactive Map Route',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Google Maps Platform API Key required for native mapping.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.mutedText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white.withOpacity(0.95), // Premium translucent effect
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
