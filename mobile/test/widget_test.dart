// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_os/features/auth/presentation/login_screen.dart';
import 'package:travel_os/features/trips/data/trips_repository.dart';
import 'package:travel_os/features/trips/presentation/shared_trip_screen.dart';

void main() {
  testWidgets('Travel OS renders the authentication shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('TRAVEL OS'), findsOneWidget);
  });

  testWidgets('Shared trip screen renders a public trip itinerary', (WidgetTester tester) async {
    final trip = Trip(
      id: 'trip-123',
      title: 'Paris Escape',
      destination: 'Paris',
      startDate: '2026-09-01',
      endDate: '2026-09-03',
      budget: 1200,
      currency: '€',
      peopleCount: 2,
      interests: ['food', 'culture'],
      status: 'planned',
      itinerary: {
        'summary': 'Three dreamy days in Paris.',
        'days': [
          {
            'day_number': 1,
            'title': 'Arrival',
            'activities': [
              {
                'time': '09:00',
                'title': 'Eiffel Tower visit',
                'description': 'Start with the classic skyline view.',
                'location': 'Eiffel Tower, Paris',
                'type': 'sightseeing',
              }
            ],
          }
        ],
      },
      shareToken: 'abc123',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SharedTripScreen(token: 'abc123', trip: trip),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Paris Escape'), findsOneWidget);
    expect(find.text('Three dreamy days in Paris.'), findsOneWidget);
    expect(find.text('Eiffel Tower visit'), findsOneWidget);
  });
}
