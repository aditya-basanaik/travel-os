import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/expenses/data/expenses_repository.dart';
import 'package:travel_os/features/trips/data/trips_repository.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String? _selectedTripId;

  void _showAddExpenseModal(String tripId) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String category = 'food';
    final categories = ['food', 'stay', 'transport', 'activities', 'misc'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add New Expense',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 16),
                
                // Amount Field
                Text('Amount (₹)', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'e.g. 1200'),
                ),
                const SizedBox(height: 16),

                // Category Chips
                Text('Category', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: categories.map((cat) {
                    final isSelected = category == cat;
                    return ChoiceChip(
                      label: Text(cat.toUpperCase()),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.secondary,
                      labelStyle: GoogleFonts.dmSans(
                        color: isSelected ? Colors.white : AppTheme.foreground,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      onSelected: (_) => setModalState(() => category = cat),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Note Field
                Text('Note (Optional)', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(hintText: 'e.g. Dinner at local cafe'),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text);
                    if (amt == null || amt <= 0) return;
                    
                    Navigator.pop(context);
                    await ref.read(expensesRepositoryPrv).addExpense(
                          tripId: tripId,
                          category: category,
                          amount: amt,
                          note: noteController.text.trim(),
                        );
                  },
                  child: const Text('Save Expense'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(userTripsPrv);
    ref.watch(expensesRepositoryPrv); // Watch to trigger UI rebuilds on changes

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trip Expenses',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.foreground),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppTheme.primary),
            tooltip: 'Sync Offline Queue',
            onPressed: () async {
              await ref.read(expensesRepositoryPrv).syncOfflineQueue();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline sync checked.')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: tripsAsync.when(
          data: (trips) {
            if (trips.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Create a trip first to track expenses.',
                    style: GoogleFonts.dmSans(color: AppTheme.mutedText),
                  ),
                ),
              );
            }

            _selectedTripId ??= trips.first.id;
            final currentTrip = trips.firstWhere(
              (t) => t.id == _selectedTripId,
              orElse: () => trips.first,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Trip Dropdown Selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0DCD3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTripId,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
                        items: trips.map((t) {
                          return DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              '${t.title} (${t.destination})',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedTripId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Summary Header Card
                  FutureBuilder<ExpenseSummary?>(
                    future: ref.read(expensesRepositoryPrv).getSummary(currentTrip.id),
                    builder: (context, snapshot) {
                      final summary = snapshot.data;
                      final budget = summary?.budget ?? currentTrip.budget;
                      final spent = summary?.spent ?? 0.0;
                      final remaining = summary?.remaining ?? budget;
                      final percent = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Budget Usage', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mutedText)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${currentTrip.currency}${spent.toStringAsFixed(0)}',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 26, color: percent > 0.9 ? AppTheme.accent : AppTheme.primary),
                                  ),
                                  Text(
                                    'of ${currentTrip.currency}${budget.toStringAsFixed(0)}',
                                    style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 10,
                                  backgroundColor: AppTheme.secondary,
                                  color: percent > 0.9 ? AppTheme.accent : AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Remaining: ${currentTrip.currency}${remaining.toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12, color: remaining < 0 ? AppTheme.accent : AppTheme.foreground)),
                                  Text('${(percent * 100).toStringAsFixed(0)}% spent', style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.mutedText)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Individual Expenses List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Expense History', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                      ElevatedButton.icon(
                        onPressed: () => _showAddExpenseModal(currentTrip.id),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  FutureBuilder<List<Expense>>(
                    future: ref.read(expensesRepositoryPrv).getExpenses(currentTrip.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                      }
                      final expenses = snapshot.data ?? [];
                      if (expenses.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text('No expenses logged for this trip yet.', style: GoogleFonts.dmSans(color: AppTheme.mutedText)),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: expenses.length,
                        itemBuilder: (context, idx) {
                          final exp = expenses[idx];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.secondary,
                                child: Icon(_getCategoryIcon(exp.category), color: AppTheme.primary, size: 20),
                              ),
                              title: Text(
                                exp.note ?? exp.category.toUpperCase(),
                                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: exp.isPendingSync
                                  ? Row(
                                      children: [
                                        const Icon(Icons.sync, size: 12, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text('Queued offline', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.orange)),
                                      ],
                                    )
                                  : Text(exp.category.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.mutedText)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${currentTrip.currency}${exp.amount.toStringAsFixed(0)}',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.foreground),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.mutedText),
                                    onPressed: () => ref.read(expensesRepositoryPrv).deleteExpense(exp.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (err, stack) => Center(child: Text('Error loading trips: $err')),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'stay':
        return Icons.hotel_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'activities':
        return Icons.local_activity_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }
}
