import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

class UserProfile {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? photoUrl;
  final int? age;
  final String? budgetPref;
  final String? foodPref;
  final List<String> languages;
  final List<String> favouriteDestinations;
  final int pastTrips;

  UserProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.photoUrl,
    this.age,
    this.budgetPref,
    this.foodPref,
    required this.languages,
    required this.favouriteDestinations,
    required this.pastTrips,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photo_url'],
      age: json['age'] as int?,
      budgetPref: json['budget_pref'],
      foodPref: json['food_pref'],
      languages: List<String>.from(json['languages'] ?? []),
      favouriteDestinations: List<String>.from(json['favourite_destinations'] ?? []),
      pastTrips: json['past_trips'] as int? ?? 0,
    );
  }
}

class ProfileRepository {
  final AuthRepository _authRepo;

  ProfileRepository(this._authRepo);

  Dio get _dio => _authRepo.apiClient.dio;

  Future<UserProfile?> getProfile() async {
    try {
      final response = await _dio.get('/profile');
      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error getting profile: $e');
    }
    return null;
  }

  Future<UserProfile?> updateProfile({
    String? name,
    String? photoUrl,
    int? age,
    String? budgetPref,
    String? foodPref,
    List<String>? languages,
    List<String>? favouriteDestinations,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (photoUrl != null) data['photo_url'] = photoUrl;
      if (age != null) data['age'] = age;
      if (budgetPref != null) data['budget_pref'] = budgetPref;
      if (foodPref != null) data['food_pref'] = foodPref;
      if (languages != null) data['languages'] = languages;
      if (favouriteDestinations != null) data['favourite_destinations'] = favouriteDestinations;

      final response = await _dio.put('/profile', data: data);
      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
    return null;
  }
}

final profileRepositoryPrv = Provider<ProfileRepository>((ref) {
  final authRepo = ref.watch(authRepositoryPrv);
  return ProfileRepository(authRepo);
});

final userProfilePrv = FutureProvider.autoDispose<UserProfile?>((ref) async {
  return ref.watch(profileRepositoryPrv).getProfile();
});
