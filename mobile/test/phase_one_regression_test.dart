import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';
import 'package:travel_os/features/auth/presentation/login_screen.dart';
import 'package:travel_os/features/trips/data/favorites_repository.dart';
import 'package:travel_os/features/trips/data/trips_repository.dart';
import 'package:travel_os/features/trips/presentation/favorites_screen.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository(this.loginResult);

  final String? loginResult;

  @override
  Future<String?> login(String email, String password) async => loginResult;
}

class RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final trip = {
      'id': 'trip-1',
      'title': 'Goa trip',
      'destination': 'Goa',
      'start_date': '2026-01-29',
      'end_date': '2026-02-02',
      'budget': 10000,
      'currency': '₹',
      'people_count': 2,
      'interests': <String>[],
      'status': 'planned',
      'itinerary': {
        'days': [
          {'day_number': 1, 'date': '2026-01-29', 'activities': []},
          {'day_number': 2, 'date': '2026-01-30', 'activities': []},
        ],
      },
    };
    return ResponseBody.fromString(jsonEncode(trip), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

Widget withProviders(Widget child, AuthRepository auth) {
  return ProviderScope(
    overrides: [authRepositoryPrv.overrideWith((ref) => auth)],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('login shows success state without an error', (tester) async {
    await tester.pumpWidget(withProviders(
      const LoginScreen(),
      FakeAuthRepository(null),
    ));
    await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Invalid email or password'), findsNothing);
  });

  testWidgets('login shows the repository failure message', (tester) async {
    await tester.pumpWidget(withProviders(
      const LoginScreen(),
      FakeAuthRepository('Invalid email or password'),
    ));
    await tester.enterText(find.byType(TextFormField).at(0), 'wrong@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
  });

  testWidgets('favorites renders mock items and filters to an empty state', (tester) async {
    final favorites = [
      Favorite(id: 'f-1', tripId: 'trip-1', type: 'hotel', name: 'Goa Stay', meta: const {}, tripDestination: 'Goa'),
    ];
    final auth = FakeAuthRepository(null);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryPrv.overrideWith((ref) => auth),
        globalFavoritesPrv.overrideWith((ref) async => favorites),
      ],
      child: const MaterialApp(home: FavoritesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Goa Stay'), findsOneWidget);
    await tester.tap(find.text('Restaurants'));
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet - start planning a trip to save some!'), findsOneWidget);
  });

  testWidgets('favorites renders the empty state with no mock items', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryPrv.overrideWith((ref) => FakeAuthRepository(null)),
        globalFavoritesPrv.overrideWith((ref) async => <Favorite>[]),
      ],
      child: const MaterialApp(home: FavoritesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No favorites yet - start planning a trip to save some!'), findsOneWidget);
  });

  test('itinerary repository sends add and remove day requests', () async {
    final auth = AuthRepository();
    final adapter = RecordingAdapter();
    auth.apiClient.dio.interceptors.clear();
    auth.apiClient.dio.httpClientAdapter = adapter;
    final repository = TripsRepository(auth);

    final added = await repository.addItineraryDay('trip-1');
    final removed = await repository.removeItineraryDay('trip-1', 2);

    expect(added?.itinerary?['days'], isA<List>());
    expect(removed?.itinerary?['days'], isA<List>());
    expect(adapter.requests.map((request) => request.method), ['POST', 'DELETE']);
    expect(adapter.requests.map((request) => request.path), [
      '/trips/trip-1/itinerary/days',
      '/trips/trip-1/itinerary/days/2',
    ]);
  });
}
