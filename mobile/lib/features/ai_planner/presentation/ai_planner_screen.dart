import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/trips/data/trips_repository.dart';

class AIPlannerScreen extends ConsumerStatefulWidget {
  const AIPlannerScreen({super.key});

  @override
  ConsumerState<AIPlannerScreen> createState() => _AIPlannerScreenState();
}

class _AIPlannerScreenState extends ConsumerState<AIPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController(text: '25000');
  final _naturalRequestController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  int _peopleCount = 1;
  
  final List<String> _selectedInterests = [];
  final List<String> _interestOptions = [
    'Nature',
    'Adventure',
    'Food',
    'Culture',
    'Relaxation',
    'Nightlife',
    'History',
    'Shopping'
  ];

  bool _isGenerating = false;

  @override
  void dispose() {
    _destinationController.dispose();
    _budgetController.dispose();
    _naturalRequestController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.foreground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select travel dates')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    final dest = _destinationController.text.trim();
    final budget = double.tryParse(_budgetController.text) ?? 25000.0;
    final formatter = DateFormat('yyyy-MM-dd');
    final sDate = formatter.format(_startDate!);
    final eDate = formatter.format(_endDate!);

    final trip = await ref.read(tripsRepositoryPrv).planTrip(
          destination: dest,
          startDate: sDate,
          endDate: eDate,
          budget: budget,
          peopleCount: _peopleCount,
          interests: _selectedInterests,
        );

    if (mounted) {
      setState(() => _isGenerating = false);
      if (trip != null) {
        // Refresh the provider so the new trip shows in lists
        ref.refresh(userTripsPrv);
        // Navigate to the trip detail view
        context.go('/trips/${trip.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate plan. Please try again.'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    }
  }

  Future<void> _submitNatural() async {
    final request = _naturalRequestController.text.trim();
    if (request.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe your trip in a little more detail.')),
      );
      return;
    }
    setState(() => _isGenerating = true);
    final trip = await ref.read(tripsRepositoryPrv).planTripNaturally(request);
    if (!mounted) return;
    setState(() => _isGenerating = false);
    if (trip != null) {
      ref.refresh(userTripsPrv);
      context.go('/trips/${trip.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not understand that trip request.'), backgroundColor: AppTheme.accent),
      );
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) {
      return _buildGeneratingState();
    }

    final dateLabel = _startDate == null || _endDate == null
        ? 'Select travel dates'
        : '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)} (${_endDate!.difference(_startDate!).inDays + 1} Days)';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Itinerary Planner',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.foreground),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 120),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Plan from a description',
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.foreground),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try: A peaceful 3-day trip near Bangalore under ₹12,000 for two.',
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.mutedText),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _naturalRequestController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(hintText: 'Tell us about the trip you want...'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _submitNatural,
                      child: const Text('Plan from description'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              
              // Intro
              Text(
                'Let AI arrange your next travel adventure.',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: AppTheme.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // Destination
              Text(
                'Where would you like to go?',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _destinationController,
                validator: (val) => val!.isEmpty ? 'Destination is required' : null,
                decoration: const InputDecoration(
                  hintText: 'e.g. Manali, Paris, Tokyo',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 24),

              // Date Range Picker Button
              Text(
                'When are you going?',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDateRange,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE0DCD3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          dateLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: _startDate == null ? AppTheme.mutedText : AppTheme.foreground,
                            fontWeight: _startDate == null ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Travellers Counter & Budget
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Travellers Counter
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Travellers',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFE0DCD3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: _peopleCount > 1
                                    ? () => setState(() => _peopleCount--)
                                    : null,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.secondary.withOpacity(0.5),
                                  child: const Icon(Icons.remove, size: 16, color: AppTheme.primary),
                                ),
                              ),
                              Text(
                                '$_peopleCount',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.foreground,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _peopleCount++),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.secondary.withOpacity(0.5),
                                  child: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Total Budget
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget (₹)',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _budgetController,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required';
                            if (double.tryParse(val) == null || double.tryParse(val)! <= 0) return 'Invalid';
                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: 'e.g. 25000',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Interests Custom Chip Grid
              Text(
                'What are your interests?',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _interestOptions.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return GestureDetector(
                    onTap: () => _toggleInterest(interest),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.secondary,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        interest,
                        style: GoogleFonts.dmSans(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.foreground,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 36),

              // Submit Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Generate with AI',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingState() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinning Compass / Globe
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppTheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Consulting Claude...',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We are building your custom day-by-day travel plan, selecting top local hotels, restaurants, and activity points.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppTheme.mutedText,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
