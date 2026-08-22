import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

class Expense {
  final String id;
  final String tripId;
  final String userId;
  final String category; // food | stay | transport | activities | misc
  final double amount;
  final String? note;
  final String createdAt;
  final bool isPendingSync;
  final String? clientId;

  Expense({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.category,
    required this.amount,
    this.note,
    required this.createdAt,
    this.isPendingSync = false,
    this.clientId,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      tripId: json['trip_id'] ?? '',
      userId: json['user_id'] ?? '',
      category: json['category'] ?? 'misc',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      note: json['note'],
      createdAt: json['created_at'] ?? '',
      isPendingSync: json['is_pending_sync'] ?? false,
      clientId: json['client_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'user_id': userId,
      'category': category,
      'amount': amount,
      'note': note,
      'created_at': createdAt,
      'is_pending_sync': isPendingSync,
      'client_id': clientId,
    };
  }

  Expense copyWith({String? category, double? amount, String? note}) {
    return Expense(
      id: id,
      tripId: tripId,
      userId: userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt,
      isPendingSync: isPendingSync,
      clientId: clientId,
    );
  }
}

class ExpenseSummary {
  final double budget;
  final String currency;
  final double spent;
  final double remaining;
  final Map<String, double> byCategory;

  ExpenseSummary({
    required this.budget,
    required this.currency,
    required this.spent,
    required this.remaining,
    required this.byCategory,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    final catMap = <String, double>{};
    if (json['by_category'] != null) {
      (json['by_category'] as Map<String, dynamic>).forEach((k, v) {
        catMap[k] = (v as num).toDouble();
      });
    }
    return ExpenseSummary(
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? '₹',
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
      byCategory: catMap,
    );
  }
}

class ExpensesRepository extends ChangeNotifier {
  final AuthRepository _authRepo;
  static const String _queueKey = 'offline_expenses_queue';

  ExpensesRepository(this._authRepo);

  Dio get _dio => _authRepo.apiClient.dio;

  Future<List<Expense>> getExpenses(String tripId) async {
    List<Expense> remoteExpenses = [];
    try {
      final response = await _dio.get('/trips/$tripId/expenses');
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List;
        remoteExpenses = list.map((e) => Expense.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error getting remote expenses: $e');
    }

    // Merge offline pending items
    final pendingQueue = await _loadOfflineQueue();
    final tripPending = pendingQueue.where((e) => e.tripId == tripId).toList();

    return [...tripPending, ...remoteExpenses];
  }

  Future<ExpenseSummary?> getSummary(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId/expenses/summary');
      if (response.statusCode == 200) {
        return ExpenseSummary.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error getting expense summary: $e');
    }
    return null;
  }

  Future<bool> addExpense({
    required String tripId,
    required String category,
    required double amount,
    String? note,
  }) async {
    try {
      final response = await _dio.post(
        '/trips/$tripId/expenses',
        data: {'category': category, 'amount': amount, 'note': note, 'client_id': 'mobile_${DateTime.now().microsecondsSinceEpoch}'},
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Offline fallback: Queue locally
      debugPrint('Network error adding expense; queuing locally: $e');
      final localItem = Expense(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        tripId: tripId,
        userId: _authRepo.currentUser?.id ?? '',
        category: category,
        amount: amount,
        note: note,
        createdAt: DateTime.now().toIso8601String(),
        isPendingSync: true,
        clientId: 'mobile_${DateTime.now().microsecondsSinceEpoch}',
      );
      await _addToOfflineQueue(localItem);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteExpense(String expenseId) async {
    // Check if it's a local pending item
    if (expenseId.startsWith('local_')) {
      await _removeFromOfflineQueue(expenseId);
      notifyListeners();
      return true;
    }

    try {
      final response = await _dio.delete('/expenses/$expenseId');
      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting expense: $e');
    }
    return false;
  }

  Future<bool> updateExpense({
    required Expense expense,
    required String category,
    required double amount,
    String? note,
  }) async {
    final updated = expense.copyWith(category: category, amount: amount, note: note);
    if (expense.id.startsWith('local_')) {
      final queue = await _loadOfflineQueue();
      final index = queue.indexWhere((item) => item.id == expense.id);
      if (index == -1) return false;
      queue[index] = updated;
      await _saveOfflineQueue(queue);
      notifyListeners();
      return true;
    }

    try {
      final response = await _dio.put(
        '/expenses/${expense.id}',
        data: {'category': category, 'amount': amount, 'note': note},
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating expense: $e');
    }
    return false;
  }

  Future<void> syncOfflineQueue() async {
    final queue = await _loadOfflineQueue();
    if (queue.isEmpty) return;

    final remaining = <Expense>[];
    for (final exp in queue) {
      try {
        final res = await _dio.post(
          '/trips/${exp.tripId}/expenses',
          data: {'category': exp.category, 'amount': exp.amount, 'note': exp.note, 'client_id': exp.clientId},
        );
        if (res.statusCode != 200) {
          remaining.add(exp);
        }
      } catch (e) {
        remaining.add(exp);
      }
    }
    await _saveOfflineQueue(remaining);
    notifyListeners();
  }

  // --- Shared Preferences Queue Helpers ---
  Future<List<Expense>> _loadOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    return raw.map((item) => Expense.fromJson(jsonDecode(item))).toList();
  }

  Future<void> _addToOfflineQueue(Expense exp) async {
    final queue = await _loadOfflineQueue();
    queue.add(exp);
    await _saveOfflineQueue(queue);
  }

  Future<void> _removeFromOfflineQueue(String id) async {
    final queue = await _loadOfflineQueue();
    queue.removeWhere((e) => e.id == id);
    await _saveOfflineQueue(queue);
  }

  Future<void> _saveOfflineQueue(List<Expense> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = queue.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_queueKey, raw);
  }
}

final expensesRepositoryPrv = ChangeNotifierProvider<ExpensesRepository>((ref) {
  final authRepo = ref.watch(authRepositoryPrv);
  return ExpensesRepository(authRepo);
});
