import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';
import 'package:travel_os/features/trips/data/trips_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authRepositoryPrv);
    final tripsAsync = ref.watch(userTripsPrv);
    final user = authState.currentUser;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(userTripsPrv.future),
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120), // Bottom nav overlap buffer
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Profile Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HELLO, ${user?.name.toUpperCase() ?? "TRAVELLER"}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  letterSpacing: 2,
                                  color: AppTheme.mutedText,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Where next?',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                ),
                          ),
                        ],
                      ),
                      // Profile Avatar
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.secondary,
                          backgroundImage: user?.picture != null ? NetworkImage(user!.picture!) : null,
                          child: user?.picture == null
                              ? Text(
                                  user?.name.substring(0, 1).toUpperCase() ?? 'T',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),

                // AI Planner Hero CTA Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -30,
                          bottom: -30,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 180,
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'AI TRIP PLANNER',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Create a custom\nitinerary in seconds',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tell Claude your budget, destination, and interests, and let it build a complete calendar.',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => context.go('/plan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Start Planning',
                                      style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Saved Trips Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Trips',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/trips'),
                        child: Text(
                          'View all',
                          style: GoogleFonts.dmSans(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Horizontally Scrollable Trip Cards
                SizedBox(
                  height: 260,
                  child: tripsAsync.when(
                    data: (trips) {
                      final activeTrips = trips.take(5).toList();
                      if (activeTrips.isEmpty) {
                        return _buildEmptyTripsState(context);
                      }
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: activeTrips.length,
                        itemBuilder: (context, idx) {
                          final trip = activeTrips[idx];
                          return _buildTripCard(context, trip);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Failed to load trips',
                        style: GoogleFonts.dmSans(color: AppTheme.accent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    return GestureDetector(
      onTap: () => context.go('/trips/${trip.id}'),
      child: Container(
        width: 220,
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x0D000000)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Expanded(
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
                  
                  // Gradient shadow overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black45],
                          stops: [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Budget Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${trip.currency}${trip.budget.toStringAsFixed(0)}',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foreground,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Text Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.destination.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.mutedText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${trip.startDate} to ${trip.endDate}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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

  Widget _buildEmptyTripsState(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.secondary),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.map_rounded,
            size: 40,
            color: AppTheme.mutedText,
          ),
          const SizedBox(height: 12),
          Text(
            'No trips planned yet',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use the AI Planner above to create your first travel itinerary.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
