import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:travel_os/core/network/api_client.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/trips/data/trips_repository.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  late Future<List<Trip>> _deletedTripsFuture;

  @override
  void initState() {
    super.initState();
    _deletedTripsFuture = ref.read(tripsRepositoryPrv).getDeletedTrips();
  }

  void _refreshDeletedTrips() {
    setState(() {
      _deletedTripsFuture = ref.read(tripsRepositoryPrv).getDeletedTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(userTripsPrv);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Trips',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.foreground),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(userTripsPrv.future),
          color: AppTheme.primary,
          child: tripsAsync.when(
            data: (trips) {
              return ListView.builder(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 120, top: 10),
                itemCount: trips.length + 1,
                itemBuilder: (context, idx) {
                  if (idx == trips.length) {
                    return _buildDeletedTripsSection(context, ref);
                  }
                  final trip = trips[idx];
                  return _buildTripRowCard(context, ref, trip);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
            error: (err, stack) => Center(
              child: Text('Failed to load trips: $err'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripRowCard(BuildContext context, WidgetRef ref, Trip trip) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0D000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/trips/${trip.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Image Side
              SizedBox(
                width: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (trip.coverImage != null)
                      Image.network(
                        trip.coverImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, __) => Container(
                          color: AppTheme.secondary,
                          child: const Icon(Icons.landscape_rounded, color: AppTheme.mutedText),
                        ),
                      )
                    else
                      Container(color: AppTheme.secondary),
                    
                    // Shadow overlay
                    Container(color: Colors.black.withOpacity(0.1)),
                  ],
                ),
              ),

              // Content Details Side
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              trip.destination.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          _buildActionsMenu(context, ref, trip),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.date_range_rounded, size: 13, color: AppTheme.mutedText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${trip.startDate} - ${trip.endDate}',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.wallet_rounded, size: 13, color: AppTheme.mutedText),
                          const SizedBox(width: 6),
                          Text(
                            'Budget: ${trip.currency}${trip.budget.toStringAsFixed(0)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.people_alt_rounded, size: 13, color: AppTheme.mutedText),
                          const SizedBox(width: 6),
                          Text(
                            '${trip.peopleCount} ${trip.peopleCount > 1 ? "people" : "person"}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsMenu(BuildContext context, WidgetRef ref, Trip trip) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.mutedText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 120),
      onSelected: (value) async {
        if (value == 'duplicate') {
          final dup = await ref.read(tripsRepositoryPrv).duplicateTrip(trip.id);
          if (dup == null || !context.mounted) return;
          ref.invalidate(userTripsPrv);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip duplicated successfully!')),
          );
        } else if (value == 'delete') {
          final ok = await ref.read(tripsRepositoryPrv).deleteTrip(trip.id);
          if (!ok || !context.mounted) return;
          ref.invalidate(userTripsPrv);
          _refreshDeletedTrips();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip archived. Restore within 30 days.')),
          );
        } else if (value == 'share') {
          final token = await ref.read(tripsRepositoryPrv).shareTrip(trip.id);
          if (token != null && context.mounted) {
            final shareUrl = '${ApiClient.webAppUrl}/shared/$token';
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: Colors.white,
                title: Text('Share Trip', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Copy this read-only link to share your itinerary:', style: GoogleFonts.dmSans(fontSize: 14)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectableText(shareUrl, style: GoogleFonts.dmSans(fontSize: 12)),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: shareUrl));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share link copied.')),
                        );
                      }
                    },
                    child: Text('Copy link', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'share',
          child: Row(
            children: [
              const Icon(Icons.share_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text('Share', style: GoogleFonts.dmSans(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'duplicate',
          child: Row(
            children: [
              const Icon(Icons.copy_rounded, size: 18, color: Colors.blue),
              const SizedBox(width: 10),
              Text('Duplicate', style: GoogleFonts.dmSans(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text('Delete', style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.accent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeletedTripsSection(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Trip>>(
      future: _deletedTripsFuture,
      builder: (context, snapshot) {
        final deletedTrips = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting && deletedTrips.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        if (deletedTrips.isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Recently Deleted',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Restore trips within 30 days.',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.mutedText),
            ),
            const SizedBox(height: 8),
            ...deletedTrips.map((trip) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(trip.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(trip.destination),
                    trailing: TextButton(
                      onPressed: () async {
                        final restored = await ref.read(tripsRepositoryPrv).restoreTrip(trip.id);
                        if (!context.mounted) return;
                        if (restored) {
                          ref.invalidate(userTripsPrv);
                          _refreshDeletedTrips();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trip restored successfully.')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not restore this trip.')),
                          );
                        }
                      },
                      child: const Text('Restore'),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.card_travel_rounded, size: 64, color: AppTheme.mutedText),
            const SizedBox(height: 16),
            Text(
              'No trips yet',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All your AI-planned and saved itineraries will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/plan'),
              child: const Text('Create Plan'),
            ),
          ],
        ),
      ),
    );
  }
}
