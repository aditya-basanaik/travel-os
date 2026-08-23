import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';
import 'package:travel_os/features/profile/data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _destinationsController;
  late TextEditingController _languagesController;
  
  String? _selectedBudget;
  String? _selectedFood;

  final List<String> _budgetOptions = ['budget', 'moderate', 'luxury'];
  final List<String> _foodOptions = ['veg', 'nonveg', 'both'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _destinationsController = TextEditingController();
    _languagesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _destinationsController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  void _populateFields(UserProfile profile) {
    _nameController.text = profile.name;
    _ageController.text = profile.age?.toString() ?? '';
    _destinationsController.text = profile.favouriteDestinations.join(', ');
    _languagesController.text = profile.languages.join(', ');
    _selectedBudget = profile.budgetPref?.toLowerCase();
    final foodPreference = profile.foodPref?.trim().toLowerCase();
    _selectedFood = switch (foodPreference) {
      'veg' || 'vegetarian' || 'vegan' => 'veg',
      'nonveg' || 'non-veg' || 'non vegetarian' => 'nonveg',
      'both' => 'both',
      _ => null,
    };
  }

  Future<void> _save(UserProfile currentProfile) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text);
    final favDests = _destinationsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final langs = _languagesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final updated = await ref.read(profileRepositoryPrv).updateProfile(
          name: name,
          age: age,
          budgetPref: _selectedBudget,
          foodPref: _selectedFood,
          favouriteDestinations: favDests,
          languages: langs,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (updated != null) {
          _isEditing = false;
        }
      });
      if (updated != null) ref.invalidate(userProfilePrv);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfilePrv);
    final authUser = ref.watch(authRepositoryPrv).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile Preferences',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.foreground),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.accent),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authRepositoryPrv).logout(),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          if (!_isEditing && !_isSaving) {
            _populateFields(profile);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Profile picture / Badge
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.secondary,
                          backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                          child: profile.photoUrl == null
                              ? Text(
                                  profile.name.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : null,
                        ),
                        if (_isEditing)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats overview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatColumn('Past Trips', profile.pastTrips.toString()),
                      Container(width: 1, height: 24, color: const Color(0xFFE0DCD3), margin: const EdgeInsets.symmetric(horizontal: 24)),
                      _buildStatColumn('Role', (authUser?.role ?? 'explorer').toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Fields wrapper
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Personal Details',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppTheme.foreground,
                                ),
                              ),
                              if (!_isEditing)
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                                  onPressed: () => setState(() => _isEditing = true),
                                ),
                            ],
                          ),
                          const Divider(height: 24, color: Color(0x0D000000)),
                          
                          // Name Field
                          _buildFieldLabel('Full Name'),
                          const SizedBox(height: 6),
                          _isEditing
                              ? TextFormField(
                                  controller: _nameController,
                                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                                  decoration: const InputDecoration(hintText: 'Enter name'),
                                )
                              : _buildDetailValue(profile.name),
                          const SizedBox(height: 18),

                          // Age Field
                          _buildFieldLabel('Age'),
                          const SizedBox(height: 6),
                          _isEditing
                              ? TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v != null && v.isNotEmpty) {
                                      final a = int.tryParse(v);
                                      if (a == null || a <= 0 || a > 120) return 'Enter a valid age';
                                    }
                                    return null;
                                  },
                                  decoration: const InputDecoration(hintText: 'Enter age'),
                                )
                              : _buildDetailValue(profile.age?.toString() ?? 'Not specified'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Travel Preferences Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Travel Settings',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.foreground,
                            ),
                          ),
                          const Divider(height: 24, color: Color(0x0D000000)),

                          // Budget Preference Dropdown
                          _buildFieldLabel('Budget Preference'),
                          const SizedBox(height: 6),
                          _isEditing
                              ? DropdownButtonFormField<String>(
                                  value: _selectedBudget,
                                  items: _budgetOptions
                                      .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedBudget = v),
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                                )
                              : _buildDetailValue(profile.budgetPref?.toUpperCase() ?? 'Not specified'),
                          const SizedBox(height: 18),

                          // Food Preference Dropdown
                          _buildFieldLabel('Food Preference'),
                          const SizedBox(height: 6),
                          _isEditing
                              ? DropdownButtonFormField<String>(
                                  value: _foodOptions.contains(_selectedFood) ? _selectedFood : null,
                                  items: _foodOptions
                                      .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedFood = v),
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                                )
                              : _buildDetailValue(profile.foodPref?.toUpperCase() ?? 'Not specified'),
                          const SizedBox(height: 18),

                          // Favorite Destinations
                          _buildFieldLabel('Favourite Destinations (comma separated)'),
                          const SizedBox(height: 6),
                          _isEditing
                              ? TextFormField(
                                  controller: _destinationsController,
                                  decoration: const InputDecoration(hintText: 'Goa, Tokyo, Paris'),
                                )
                              : _buildChipsList(profile.favouriteDestinations),
                          const SizedBox(height: 18),

                          // Languages Spoken
                          _buildFieldLabel('Languages'),
                          const SizedBox(height: 6),
                          _isEditing
                              ? TextFormField(
                                  controller: _languagesController,
                                  decoration: const InputDecoration(hintText: 'English, Hindi, Japanese'),
                                )
                              : _buildChipsList(profile.languages),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (_isEditing) ...[
                    ElevatedButton(
                      onPressed: _isSaving ? null : () => _save(profile),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: Color(0xFFE0DCD3)),
                        foregroundColor: AppTheme.mutedText,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (err, stack) => Center(
          child: Text('Failed to load profile details: $err'),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppTheme.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.mutedText,
      ),
    );
  }

  Widget _buildDetailValue(String val) {
    return Text(
      val,
      style: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppTheme.foreground,
      ),
    );
  }

  Widget _buildChipsList(List<String> items) {
    if (items.isEmpty) {
      return Text(
        'None specified',
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: AppTheme.mutedText,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((item) {
        return Chip(
          label: Text(
            item,
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.foreground, fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppTheme.secondary.withOpacity(0.5),
          side: BorderSide.none,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }
}
