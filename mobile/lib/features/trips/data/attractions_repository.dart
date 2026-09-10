import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

class Attraction {
  final String id;
  final String name;
  final String description;
  final String category;
  final String city;
  final String country;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final double rating;
  final double estimatedCost;
  final List<String> images;
  final String? openingHours;
  final String? externalUrl;

  const Attraction({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.city,
    required this.country,
    required this.address,
    this.latitude,
    this.longitude,
    this.placeId,
    required this.rating,
    required this.estimatedCost,
    required this.images,
    this.openingHours,
    this.externalUrl,
  });

  factory Attraction.fromJson(Map<String, dynamic> json) {
    return Attraction(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeId: json['place_id'],
      rating: (json['rating'] as num? ?? 0).toDouble(),
      estimatedCost: (json['estimated_cost'] as num? ?? 0).toDouble(),
      images: List<String>.from(json['images'] ?? const []),
      openingHours: json['opening_hours'],
      externalUrl: json['external_url'],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'city': city,
        'country': country,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'place_id': placeId,
        'rating': rating,
        'estimated_cost': estimatedCost,
        'images': images,
        'opening_hours': openingHours,
        'external_url': externalUrl,
      };
}

class AttractionsRepository {
  final AuthRepository _authRepo;

  AttractionsRepository(this._authRepo);

  Dio get _dio => _authRepo.apiClient.dio;

  Future<List<Attraction>> search(String city, {String? category}) async {
    try {
      final response = await _dio.get('/attractions', queryParameters: {
        'city': city,
        if (category != null && category.isNotEmpty) 'category': category,
      });
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => Attraction.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (error) {
      debugPrint('Error getting attractions: $error');
    }
    return [];
  }
}

final attractionsRepositoryPrv = Provider<AttractionsRepository>((ref) {
  return AttractionsRepository(ref.watch(authRepositoryPrv));
});

final attractionsPrv =
    FutureProvider.autoDispose.family<List<Attraction>, String>((ref, city) {
  return ref.watch(attractionsRepositoryPrv).search(city);
});
