import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

class Trip {
  final String id;
  final String title;
  final String destination;
  final String startDate;
  final String endDate;
  final double budget;
  final String currency;
  final int peopleCount;
  final List<String> interests;
  final String status;
  final String? coverImage;
  final Map<String, dynamic>? itinerary;
  final String? shareToken;
  final String? sharedBy;

  Trip({
    required this.id,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.currency,
    required this.peopleCount,
    required this.interests,
    required this.status,
    this.coverImage,
    this.itinerary,
    this.shareToken,
    this.sharedBy,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      destination: json['destination'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? '₹',
      peopleCount: json['people_count'] as int? ?? 1,
      interests: List<String>.from(json['interests'] ?? []),
      status: json['status'] ?? 'planned',
      coverImage: json['cover_image'],
      itinerary: json['itinerary'],
      shareToken: json['share_token'],
      sharedBy: json['shared_by'],
    );
  }

  Trip copyWith({
    String? title,
    String? status,
    String? coverImage,
    Map<String, dynamic>? itinerary,
    String? shareToken,
    String? sharedBy,
  }) {
    return Trip(
      id: id,
      title: title ?? this.title,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      currency: currency,
      peopleCount: peopleCount,
      interests: interests,
      status: status ?? this.status,
      coverImage: coverImage ?? this.coverImage,
      itinerary: itinerary ?? this.itinerary,
      shareToken: shareToken ?? this.shareToken,
      sharedBy: sharedBy ?? this.sharedBy,
    );
  }
}

class TripsRepository {
  final AuthRepository _authRepo;

  TripsRepository(this._authRepo);

  Dio get _dio => _authRepo.apiClient.dio;

  Future<List<Trip>> getTrips({int page = 1, int limit = 12, String? search}) async {
    try {
      final response = await _dio.get(
        '/trips',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final items = response.data['items'] as List;
        return items.map((t) => Trip.fromJson(t)).toList();
      }
    } catch (e) {
      debugPrint('Error getting trips: $e');
    }
    return [];
  }

  Future<List<Trip>> getDeletedTrips() async {
    try {
      final response = await _dio.get('/trips/deleted');
      if (response.statusCode == 200 && response.data is Map) {
        final items = response.data['items'];
        if (items is List) {
          return items.map((trip) => Trip.fromJson(trip)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error getting deleted trips: $e');
    }
    return [];
  }

  Future<Trip?> getTrip(String id) async {
    try {
      final response = await _dio.get('/trips/$id');
      if (response.statusCode == 200) {
        return Trip.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error getting trip: $e');
    }
    return null;
  }

  Future<Trip?> getSharedTrip(String token) async {
    try {
      final response = await _dio.get('/trips/shared/$token');
      if (response.statusCode == 200) {
        return Trip.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error getting shared trip: $e');
    }
    return null;
  }

  Future<Trip?> planTrip({
    required String destination,
    required String startDate,
    required String endDate,
    required double budget,
    String currency = '₹',
    int peopleCount = 1,
    List<String> interests = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/trips/plan',
        data: {
          'destination': destination.trim(),
          'start_date': startDate,
          'end_date': endDate,
          'budget': budget,
          'currency': currency,
          'people_count': peopleCount,
          'interests': interests,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 300),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      if (response.statusCode == 200) {
        return Trip.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Plan request failed: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> getTripWeather(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId/weather');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (e) {
      debugPrint('Error getting weather: $e');
    }
    return {};
  }

  Future<Trip?> updateItinerary(String tripId, Map<String, dynamic> itinerary) async {
    try {
      final response = await _dio.put(
        '/trips/$tripId/itinerary',
        data: {'itinerary': itinerary},
      );
      if (response.statusCode == 200) {
        return Trip.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error updating itinerary: $e');
    }
    return null;
  }

  Future<Trip?> refineItinerary(String tripId, String instruction) async {
    try {
      final response = await _dio.post(
        '/trips/$tripId/refine',
        data: {'instruction': instruction.trim()},
        options: Options(
          receiveTimeout: const Duration(seconds: 300),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      if (response.statusCode == 200) {
        return Trip.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error refining itinerary: $e');
    }
    return null;
  }

  Future<Trip?> duplicateTrip(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/duplicate');
      if (response.statusCode == 200) {
        return Trip.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error duplicating trip: $e');
    }
    return null;
  }

  Future<String?> shareTrip(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/share');
      if (response.statusCode == 200) {
        return response.data['share_token'];
      }
    } catch (e) {
      debugPrint('Error sharing trip: $e');
    }
    return null;
  }

  Future<bool> deleteTrip(String id) async {
    try {
      final response = await _dio.delete('/trips/$id');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      return false;
    }
  }

  Future<bool> restoreTrip(String id) async {
    try {
      final response = await _dio.post('/trips/$id/restore');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error restoring trip: $e');
      return false;
    }
  }
}

final tripsRepositoryPrv = Provider<TripsRepository>((ref) {
  final authRepo = ref.watch(authRepositoryPrv);
  return TripsRepository(authRepo);
});

// A Simple FutureProvider to retrieve user trips
final userTripsPrv = FutureProvider.autoDispose<List<Trip>>((ref) async {
  return ref.watch(tripsRepositoryPrv).getTrips();
});
