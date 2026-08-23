import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/trips/data/trips_repository.dart';

class SharedTripScreen extends ConsumerStatefulWidget {
  final String token;
  final Trip? trip;

  const SharedTripScreen({
    super.key,
    required this.token,
    this.trip,
  });

  @override
  ConsumerState<SharedTripScreen> createState() => _SharedTripScreenState();
}

class _SharedTripScreenState extends ConsumerState<SharedTripScreen> {
  late Future<Trip?> _tripFuture;

  @override
  void initState() {
    super.initState();
    _tripFuture = widget.trip != null
        ? Future.value(widget.trip)
        : ref.read(tripsRepositoryPrv).getSharedTrip(widget.token);
  }

  String _formatDate(String dateText) {
    if (dateText.isEmpty) return '';
    try {
      final date = DateTime.parse(dateText);
      return DateFormat('MMM d, y').format(date);
    } catch (_) {
      return dateText;
    }
  }

  Future<void> _launchMap(String location) async {
    final encoded = Uri.encodeComponent(location);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Trip?>(
      future: _tripFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }

        final trip = snapshot.data;
        if (snapshot.hasError || trip == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Shared trip not found or link expired',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final itinerary = trip.itinerary ?? {'days': <Map<String, dynamic>>[]};
        final days = List<Map<String, dynamic>>.from(itinerary['days'] ?? []);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: AppTheme.primary,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    trip.title,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (trip.coverImage != null)
                        Image.network(trip.coverImage!, fit: BoxFit.cover)
                      else
                        Container(color: AppTheme.secondary),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.destination,
                        style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.mutedText),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatDate(trip.startDate)} - ${_formatDate(trip.endDate)}',
                            style: GoogleFonts.dmSans(color: AppTheme.mutedText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trip.itinerary?['summary'] ?? 'Shared itinerary',
                        style: GoogleFonts.dmSans(fontSize: 15, color: AppTheme.mutedText),
                      ),
                      const SizedBox(height: 20),
                      if (trip.sharedBy != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Shared by ${trip.sharedBy ?? 'a traveller'}',
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppTheme.primary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (days.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No itinerary has been shared yet.'),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final day = days[index];
                    final activities = List<Map<String, dynamic>>.from(day['activities'] ?? []);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${day['day_number'] ?? index + 1}',
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          if ((day['title'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 10),
                              child: Text(
                                day['title'],
                                style: GoogleFonts.dmSans(color: AppTheme.mutedText),
                              ),
                            ),
                          ...activities.map((activity) {
                            final title = activity['title']?.toString() ?? 'Activity';
                            final time = activity['time']?.toString() ?? '';
                            final description = activity['description']?.toString();
                            final location = activity['location']?.toString();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (time.isNotEmpty)
                                    SizedBox(
                                      width: 52,
                                      child: Text(
                                        time,
                                        style: GoogleFonts.dmSans(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        if (description != null && description.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              description,
                                              style: GoogleFonts.dmSans(color: AppTheme.mutedText),
                                            ),
                                          ),
                                        if (location != null && location.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 10),
                                            child: InkWell(
                                              onTap: () => _launchMap(location),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.primary),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      location,
                                                      style: GoogleFonts.dmSans(
                                                        color: AppTheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }, childCount: days.length),
                ),
            ],
          ),
        );
      },
    );
  }
}
