import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

class HelpMessage {
  final bool fromUser;
  final String text;
  final List<String> sources;

  const HelpMessage({required this.fromUser, required this.text, this.sources = const []});
}

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  static const _starters = [
    'How do I save a trip?',
    'How do I add an expense?',
    'How do I share a trip?',
    'How does Maps work?',
  ];

  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final List<HelpMessage> _messages = [];
  bool _asking = false;
  String? _error;

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask([String? starter]) async {
    final question = (starter ?? _questionController.text).trim();
    if (question.isEmpty || _asking) return;

    _questionController.clear();
    setState(() {
      _error = null;
      _asking = true;
      _messages.add(HelpMessage(fromUser: true, text: question));
    });
    _scrollToBottom();

    try {
      final response = await ref.read(authRepositoryPrv).apiClient.dio.post(
        '/rag/ask',
        data: {'question': question},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final sources = (data['sources'] as List? ?? [])
          .map((source) => (source as Map)['title']?.toString() ?? '')
          .where((title) => title.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _messages.add(HelpMessage(
          fromUser: false,
          text: data['answer']?.toString() ?? 'I do not have enough information to answer that.',
          sources: sources,
        ));
      });
      _scrollToBottom();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.response?.data?['detail']?.toString() ?? 'Could not reach Travel OS Help.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach Travel OS Help. Please try again.');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Travel OS Help', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.foreground)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  if (_messages.isEmpty) _buildWelcome(),
                  ..._messages.map(_buildMessage),
                  if (_asking) _buildLoading(),
                  if (_error != null) _buildError(),
                ],
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: AppTheme.primary,
                  child: Icon(Icons.auto_awesome_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Ask how Travel OS works', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Answers come from the Travel OS help library. Unsupported questions will be identified clearly.',
              style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _starters.map((starter) => ActionChip(
                label: Text(starter, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: AppTheme.secondary,
                side: BorderSide.none,
                onPressed: () => _ask(starter),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(HelpMessage message) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: message.fromUser ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: message.fromUser ? null : [const BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.text, style: GoogleFonts.dmSans(color: message.fromUser ? Colors.white : AppTheme.foreground, fontSize: 14, height: 1.4)),
          if (message.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Sources', style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(message.sources.join(' · '), style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 11)),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: message.fromUser
            ? [bubble, const SizedBox(width: 8), const Icon(Icons.person_outline_rounded, color: AppTheme.mutedText, size: 22)]
            : [const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 22), const SizedBox(width: 8), bubble],
      ),
    );
  }

  Widget _buildLoading() {
    return Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 22),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: Text('Checking the help library…', style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(_error!, style: GoogleFonts.dmSans(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              enabled: !_asking,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(),
              decoration: const InputDecoration(hintText: 'Ask about Travel OS…'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _asking ? null : _ask,
            icon: const Icon(Icons.send_rounded),
            tooltip: 'Ask Travel OS Help',
            style: IconButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
