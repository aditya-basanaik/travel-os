import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

class Favorite {
  final String id;
  final String tripId;
  final String type; // "hotel", "restaurant", or "attraction"
  final String name;
  final String? externalId;
  final Map<String, dynamic> meta;

  Favorite({
    required this.id,
    required this.tripId,
    required this.type,
    required this.name,
    this.externalId,
    required this.meta,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] ?? json['_id'] ?? '',
      tripId: json['trip_id'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      externalId: json['external_id'],
      meta: Map<String, dynamic>.from(json['meta'] ?? {}),
    );
  }
}

class FavoritesRepository {
  final AuthRepository _authRepo;

  FavoritesRepository(this._authRepo);

  Dio get _dio => _authRepo.apiClient.dio;

  Future<List<Favorite>> getFavorites(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId/favorites');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((f) => Favorite.fromJson(f)).toList();
      }
    } catch (e) {
      debugPrint('Error getting favorites: $e');
    }
    return [];
  }

  Future<Favorite?> addFavorite({
    required String tripId,
    required String type,
    required String name,
    String? externalId,
    Map<String, dynamic> meta = const {},
  }) async {
    try {
      final response = await _dio.post(
        '/trips/$tripId/favorites',
        data: {
          'type': type,
          'name': name,
          if (externalId != null) 'external_id': externalId,
          'meta': meta,
        },
      );
      if (response.statusCode == 200) {
        return Favorite.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error adding favorite: $e');
    }
    return null;
  }

  Future<bool> removeFavorite(String favId) async {
    try {
      final response = await _dio.delete('/favorites/$favId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      return false;
    }
  }
}

final favoritesRepositoryPrv = Provider<FavoritesRepository>((ref) {
  final authRepo = ref.watch(authRepositoryPrv);
  return FavoritesRepository(authRepo);
});

// Family provider keyed by tripId — call ref.invalidate(favoritesPrv(tripId)) to refresh
final favoritesPrv = FutureProvider.autoDispose.family<List<Favorite>, String>((ref, tripId) async {
  return ref.watch(favoritesRepositoryPrv).getFavorites(tripId);
});
