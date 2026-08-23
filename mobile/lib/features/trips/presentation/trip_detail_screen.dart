import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/expenses/data/expenses_repository.dart';
import 'package:travel_os/features/trips/data/favorites_repository.dart';
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
  late Future<Trip?> _tripFuture;
  Trip? _tripOverride;
  Map<String, dynamic> _weatherForecast = {};
  bool _loadingWeather = true;
  bool _editingItinerary = false;
  bool _savingItinerary = false;
  bool _refiningItinerary = false;
  Map<String, dynamic>? _draftItinerary;
  final _refineController = TextEditingController();
  final String _mapsApiKey = const String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tripFuture = ref.read(tripsRepositoryPrv).getTrip(widget.tripId);
    _fetchWeather();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refineController.dispose();
    super.dispose();
  }

  void _startItineraryEdit(Trip trip) {
    setState(() {
      _draftItinerary = jsonDecode(jsonEncode(trip.itinerary ?? {'days': []}));
      _editingItinerary = true;
    });
  }

  Future<void> _saveItinerary() async {
    if (_draftItinerary == null) return;
    setState(() => _savingItinerary = true);
    final updated = await ref.read(tripsRepositoryPrv).updateItinerary(widget.tripId, _draftItinerary!);
    if (!mounted) return;
    setState(() {
      _savingItinerary = false;
      if (updated != null) {
        _tripOverride = updated;
        _editingItinerary = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated == null ? 'Could not save itinerary.' : 'Itinerary updated.')),
    );
  }

  Future<void> _refineItinerary([String? instruction]) async {
    final request = (instruction ?? _refineController.text).trim();
    if (request.length < 3 || _refiningItinerary) return;
    setState(() => _refiningItinerary = true);
    final updated = await ref.read(tripsRepositoryPrv).refineItinerary(widget.tripId, request);
    if (!mounted) return;
    setState(() {
      _refiningItinerary = false;
      if (updated != null) {
        _tripOverride = updated;
        _refineController.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated == null ? 'Could not refine itinerary.' : 'Itinerary refined.')),
    );
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

  Future<void> _configureMapMarkers(Trip trip) async {
    if (!mounted) return;

    final activities = trip.itinerary?['days'] ?? [];
    final nextMarkers = <Marker>{};

    for (final day in activities) {
      final dayActivities = day['activities'] ?? [];
      for (int index = 0; index < dayActivities.length; index++) {
        final activity = dayActivities[index];
        final location = activity['location'];
        if (location is String && location.trim().isNotEmpty) {
          final title = activity['title'] ?? 'Stop';
          nextMarkers.add(
            Marker(
              markerId: MarkerId('${title}_$index'),
              position: const LatLng(12.9716, 77.5946),
              infoWindow: InfoWindow(title: title, snippet: location),
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _markers.addAll(nextMarkers));
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
    final favoritesAsync = ref.watch(favoritesPrv(widget.tripId));
    return FutureBuilder<Trip?>(
      future: _tripFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        final trip = _tripOverride ?? snapshot.data;
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Trip not found')),
          );
        }

        if (_markers.isEmpty && (trip.itinerary?['days'] ?? []).isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _configureMapMarkers(trip));
        }

        final itinerary = _editingItinerary ? (_draftItinerary ?? trip.itinerary ?? {}) : (trip.itinerary ?? {});
        final days = List<Map<String, dynamic>>.from(itinerary['days'] ?? []);
        final hotels = List<Map<String, dynamic>>.from(itinerary['hotels'] ?? []);
        final restaurants = List<Map<String, dynamic>>.from(itinerary['restaurants'] ?? []);

        return Scaffold(
          body: DefaultTabController(
            length: 5,
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
                        isScrollable: true,
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
                          Tab(text: 'Expenses', icon: Icon(Icons.account_balance_wallet_outlined, size: 20)),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildItineraryTab(trip, days),
                  _buildHotelsTab(hotels, favoritesAsync.value ?? const []),
                  _buildRestaurantsTab(restaurants, favoritesAsync.value ?? const []),
                  _buildMapTab(trip),
                  _buildExpensesTab(trip),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItineraryTab(Trip trip, List<Map<String, dynamic>> days) {
    if (days.isEmpty) {
      return const Center(child: Text('No daily itinerary generated.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: days.length + 1,
      itemBuilder: (context, dIdx) {
        if (dIdx == 0) {
          return _buildItineraryControls(trip);
        }
        final dayIndex = dIdx - 1;
        final day = days[dayIndex];
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
            ...activities.asMap().entries.map((entry) => _buildActivityTimelineRow(entry.value, dayIndex, entry.key)),
            if (_editingItinerary)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showActivityEditor(dayIndex),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add activity'),
                ),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Future<void> _showActivityEditor(int dayIndex, {int? activityIndex}) async {
    final draft = _draftItinerary;
    if (draft == null) return;
    final days = List<Map<String, dynamic>>.from(draft['days'] ?? []);
    final existing = activityIndex == null
        ? <String, dynamic>{
            'time': '12:00',
            'title': 'New activity',
            'description': '',
            'type': 'activity',
            'estimated_cost': 0,
            'location': '',
          }
        : Map<String, dynamic>.from(List<Map<String, dynamic>>.from(days[dayIndex]['activities'] ?? [])[activityIndex]);
    final timeController = TextEditingController(text: existing['time']?.toString() ?? '12:00');
    final titleController = TextEditingController(text: existing['title']?.toString() ?? '');
    final descriptionController = TextEditingController(text: existing['description']?.toString() ?? '');
    final costController = TextEditingController(text: '${existing['estimated_cost'] ?? 0}');
    final locationController = TextEditingController(text: existing['location']?.toString() ?? '');
    var type = existing['type']?.toString() ?? 'activity';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(activityIndex == null ? 'Add activity' : 'Edit activity'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: timeController, decoration: const InputDecoration(labelText: 'Time'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const ['activity', 'food', 'culture', 'nature', 'transport', 'stay', 'nightlife', 'relaxation', 'adventure']
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => setDialogState(() => type = value ?? type),
                      ),
                    ),
                  ],
                ),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimated cost')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(dialogContext, {
                  ...existing,
                  'time': timeController.text.trim(),
                  'title': title,
                  'description': descriptionController.text.trim(),
                  'location': locationController.text.trim(),
                  'type': type,
                  'estimated_cost': double.tryParse(costController.text) ?? 0,
                });
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    timeController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    costController.dispose();
    locationController.dispose();
    if (result == null || !mounted) return;
    final updatedDays = List<Map<String, dynamic>>.from(days);
    final updatedActivities = List<Map<String, dynamic>>.from(updatedDays[dayIndex]['activities'] ?? []);
    if (activityIndex == null) {
      updatedActivities.add(result);
    } else {
      updatedActivities[activityIndex] = result;
    }
    updatedDays[dayIndex] = {...updatedDays[dayIndex], 'activities': updatedActivities};
    setState(() => _draftItinerary = {...draft, 'days': updatedDays});
  }

  Future<void> _removeActivity(int dayIndex, int activityIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove activity?'),
        content: const Text('This change will be applied when you save the itinerary.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted || _draftItinerary == null) return;
    final days = List<Map<String, dynamic>>.from(_draftItinerary!['days'] ?? []);
    final activities = List<Map<String, dynamic>>.from(days[dayIndex]['activities'] ?? [])..removeAt(activityIndex);
    days[dayIndex] = {...days[dayIndex], 'activities': activities};
    setState(() => _draftItinerary = {..._draftItinerary!, 'days': days});
  }

  Widget _buildItineraryControls(Trip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_editingItinerary) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startItineraryEdit(trip),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit itinerary'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _refiningItinerary ? null : () => _refineItinerary('Make it cheaper'),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_refiningItinerary ? 'Refining...' : 'Make it cheaper'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _refineController,
            maxLength: 500,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _refineItinerary(),
            decoration: InputDecoration(
              labelText: 'Refine this itinerary',
              hintText: 'Add more adventure or make it family friendly',
              suffixIcon: IconButton(
                tooltip: 'Refine itinerary',
                onPressed: _refiningItinerary ? null : () => _refineItinerary(),
                icon: const Icon(Icons.auto_awesome),
              ),
            ),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _savingItinerary ? null : () => setState(() => _editingItinerary = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _savingItinerary ? null : _saveItinerary,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(_savingItinerary ? 'Saving...' : 'Save changes'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActivityTimelineRow(Map<String, dynamic> act, int dayIndex, int activityIndex) {
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              act['title'] ?? '',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.foreground,
                              ),
                            ),
                          ),
                          if (_editingItinerary)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit activity',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showActivityEditor(dayIndex, activityIndex: activityIndex),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Remove activity',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _removeActivity(dayIndex, activityIndex),
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (act['image_url'] != null && act['image_url'].toString().trim().isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            act['image_url'],
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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

  Widget _buildHotelsTab(List<Map<String, dynamic>> hotels, List<Favorite> favorites) {
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
                        _buildFavoriteButton('hotel', hotel, favorites),
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

  Widget _buildRestaurantsTab(List<Map<String, dynamic>> restaurants, List<Favorite> favorites) {
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
                        _buildFavoriteButton('restaurant', rest, favorites),
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

  Widget _buildFavoriteButton(
    String type,
    Map<String, dynamic> item,
    List<Favorite> favorites,
  ) {
    final name = item['name']?.toString() ?? '';
    final favorite = favorites.where((fav) => fav.type == type && fav.name == name).firstOrNull;
    return IconButton(
      tooltip: favorite == null ? 'Save favorite' : 'Remove favorite',
      icon: Icon(
        favorite == null ? Icons.favorite_border_rounded : Icons.favorite_rounded,
        color: favorite == null ? AppTheme.mutedText : AppTheme.accent,
        size: 20,
      ),
      onPressed: () async {
        final repository = ref.read(favoritesRepositoryPrv);
        final success = favorite == null
            ? await repository.addFavorite(
                tripId: widget.tripId,
                type: type,
                name: name,
                meta: item,
              ) != null
            : await repository.removeFavorite(favorite.id);
        if (!mounted) return;
        if (success) {
          ref.invalidate(favoritesPrv(widget.tripId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(favorite == null ? 'Saved to favorites.' : 'Removed from favorites.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update favorite.')),
          );
        }
      },
    );
  }

  Widget _buildExpensesTab(Trip trip) {
    final repository = ref.read(expensesRepositoryPrv);
    return FutureBuilder<List<Expense>>(
      future: repository.getExpenses(trip.id),
      builder: (context, expensesSnapshot) {
        return FutureBuilder<ExpenseSummary?>(
          future: repository.getSummary(trip.id),
          builder: (context, summarySnapshot) {
            final expenses = expensesSnapshot.data ?? const <Expense>[];
            final summary = summarySnapshot.data;
            final budget = summary?.budget ?? trip.budget;
            final spent = summary?.spent ?? expenses.fold<double>(0, (total, item) => total + item.amount);
            final remaining = summary?.remaining ?? budget - spent;
            final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Budget usage', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppTheme.mutedText)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${trip.currency}${spent.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                            Text('of ${trip.currency}${budget.toStringAsFixed(0)}', style: GoogleFonts.dmSans(color: AppTheme.mutedText)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(value: progress, minHeight: 9, color: progress > .9 ? AppTheme.accent : AppTheme.primary, backgroundColor: AppTheme.secondary),
                        ),
                        const SizedBox(height: 10),
                        Text('Remaining: ${trip.currency}${remaining.toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: remaining < 0 ? AppTheme.accent : AppTheme.foreground)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Expense history', style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () => _showExpenseEditor(trip),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (expensesSnapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                else if (expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No expenses recorded yet.', style: GoogleFonts.dmSans(color: AppTheme.mutedText))),
                  )
                else
                  ...expenses.map((expense) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: AppTheme.secondary, child: Icon(_expenseIcon(expense.category), color: AppTheme.primary, size: 20)),
                      title: Text(expense.note?.isNotEmpty == true ? expense.note! : expense.category.toUpperCase(), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                      subtitle: Text('${expense.category}${expense.isPendingSync ? ' - pending sync' : ''}', style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.mutedText)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${trip.currency}${expense.amount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') _showExpenseEditor(trip, expense: expense);
                              if (action == 'delete') _deleteExpense(expense);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
              ],
            );
          },
        );
      },
    );
  }

  IconData _expenseIcon(String category) {
    switch (category) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'stay':
        return Icons.hotel_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'activities':
        return Icons.local_activity_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Future<void> _showExpenseEditor(Trip trip, {Expense? expense}) async {
    final amountController = TextEditingController(text: expense?.amount.toString() ?? '');
    final noteController = TextEditingController(text: expense?.note ?? '');
    var category = expense?.category ?? 'food';
    const categories = ['food', 'stay', 'transport', 'activities', 'misc'];
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(expense == null ? 'Add expense' : 'Edit expense', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(controller: amountController, keyboardType: TextInputType.number, autofocus: expense == null, decoration: const InputDecoration(labelText: 'Amount')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: categories.map((value) => ChoiceChip(
                  label: Text(value.toUpperCase()),
                  selected: category == value,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(color: category == value ? Colors.white : AppTheme.foreground, fontSize: 11, fontWeight: FontWeight.bold),
                  onSelected: (_) => setSheetState(() => category = value),
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) return;
                  final repository = ref.read(expensesRepositoryPrv);
                  final success = expense == null
                      ? await repository.addExpense(tripId: trip.id, category: category, amount: amount, note: noteController.text.trim())
                      : await repository.updateExpense(expense: expense, category: category, amount: amount, note: noteController.text.trim());
                  if (sheetContext.mounted) Navigator.pop(sheetContext, success);
                },
                child: Text(expense == null ? 'Save expense' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
    amountController.dispose();
    noteController.dispose();
    if (result == true && mounted) setState(() {});
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await ref.read(expensesRepositoryPrv).deleteExpense(expense.id);
      if (success && mounted) setState(() {});
    }
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
