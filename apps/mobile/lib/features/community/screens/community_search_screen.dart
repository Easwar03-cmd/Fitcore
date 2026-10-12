import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../providers/community_provider.dart';

class CommunitySearchScreen extends ConsumerStatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  ConsumerState<CommunitySearchScreen> createState() =>
      _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends ConsumerState<CommunitySearchScreen> {
  final _search = TextEditingController();
  final _code = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _joining;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v);
    });
  }

  Future<void> _join(String communityId) async {
    setState(() => _joining = communityId);
    try {
      final status = await ref
          .read(communityListProvider.notifier)
          .join(communityId: communityId);
      if (!mounted) return;
      if (status == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request sent. The admin needs to approve it.'),
        ));
        context.pop();
      } else {
        context.pushReplacement(AppRoutes.communityChatPath(communityId));
      }
    } on CommunityException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _joining = null);
    }
  }

  void _openCode() {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) return;
    context.push(AppRoutes.communityJoinPath(code));
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(communitySearchProvider(_query));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Find a community')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _search,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search by community name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_query.trim().length >= 2)
            results.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(e.toString()),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No communities found. Private communities '
                          'can only be joined with an invite code.'),
                    )
                  : Column(
                      children: [
                        for (final c in list)
                          Card(
                            child: ListTile(
                              title: Text(c.name),
                              subtitle: Text(
                                '${c.memberCount} members'
                                '${c.description == null ? '' : ' · ${c.description}'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: FilledButton.tonal(
                                onPressed:
                                    _joining == null ? () => _join(c.id) : null,
                                child: Text(
                                    c.requireApproval ? 'Request' : 'Join'),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          const SizedBox(height: 24),
          Text('Have an invite code?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter code',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _openCode(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _openCode, child: const Text('Continue')),
            ],
          ),
        ],
      ),
    );
  }
}
