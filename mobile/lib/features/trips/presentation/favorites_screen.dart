import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/trips/data/favorites_repository.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _filter = 'all';

  String _label(String type) {
    switch (type) {
      case 'hotel':
        return 'Hotels';
      case 'restaurant':
        return 'Restaurants';
      case 'attraction':
        return 'Attractions';
      default:
        return type;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'hotel':
        return Icons.hotel_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'attraction':
        return Icons.photo_camera_outlined;
      default:
        return Icons.favorite_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(globalFavoritesPrv);

    return Scaffold(
      appBar: AppBar(
        title: Text('Your favorites', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(error),
        data: (favorites) {
          final visible = favorites.where((favorite) => _filter == 'all' || favorite.type == _filter).toList();
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => ref.invalidate(globalFavoritesPrv),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                Text('Saved places', style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text('Every place you have saved across your trips.', style: GoogleFonts.dmSans(color: AppTheme.mutedText)),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'hotel', 'restaurant', 'attraction'].map((type) {
                      final selected = _filter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type == 'all' ? 'All' : _label(type)),
                          selected: selected,
                          onSelected: (_) => setState(() => _filter = type),
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.foreground, fontWeight: FontWeight.bold),
                          backgroundColor: AppTheme.secondary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                if (visible.isEmpty)
                  _buildEmpty()
                else
                  ...visible.map((favorite) => _buildFavoriteCard(context, favorite)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.accent, size: 42),
            const SizedBox(height: 12),
            Text('Could not load favorites.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text(error.toString(), textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: AppTheme.mutedText)),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: () => ref.invalidate(globalFavoritesPrv), child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          const Icon(Icons.favorite_border_rounded, color: AppTheme.primary, size: 48),
          const SizedBox(height: 14),
          Text('No favorites yet - start planning a trip to save some!', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, Favorite favorite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: favorite.tripId.isEmpty ? null : () => context.go('/trips/${favorite.tripId}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
                child: Icon(_icon(favorite.type), color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(favorite.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17))),
                        const SizedBox(width: 8),
                        Text(favorite.type, style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(favorite.tripDestination ?? 'Saved trip', style: GoogleFonts.dmSans(color: AppTheme.mutedText)),
                    const SizedBox(height: 3),
                    Text(favorite.tripTitle ?? 'Open originating trip', style: GoogleFonts.dmSans(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
