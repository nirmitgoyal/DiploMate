import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../data/repos/auth_repository.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';
import '../shell/dm_toast.dart';

class SpecialityScreen extends ConsumerStatefulWidget {
  const SpecialityScreen({super.key, required this.changeMode});
  final bool changeMode;

  @override
  ConsumerState<SpecialityScreen> createState() => _SpecialityScreenState();
}

class _SpecialityScreenState extends ConsumerState<SpecialityScreen> {
  List<SpecialityRow> _all = const [];
  String _query = '';
  String? _selectedId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(contentRepositoryProvider).specialities().then((s) {
      if (!mounted) return;
      setState(() {
        _all = s;
        if (widget.changeMode) {
          _selectedId = ref.read(sessionUserProvider)?.specialityId;
        }
      });
    });
  }

  String _label(SpecialityRow s) => '${s.name} (${s.examType})';

  List<SpecialityRow> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return [for (final s in _all) if (_label(s).toLowerCase().contains(q)) s];
  }

  Future<void> _commit() async {
    final id = _selectedId;
    if (id == null) return;
    final current = ref.read(sessionUserProvider)?.specialityId;
    if (widget.changeMode && id != current) {
      final oldMatches = _all.where((s) => s.id == current);
      final oldName = oldMatches.isEmpty ? '' : _label(oldMatches.first);
      final newName = _all.where((s) => s.id == id).map(_label).first;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Use your one change?'),
          content: Text('$oldName -> $newName. You can change your speciality once - this is that change.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change speciality')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).setSpeciality(id);
      ref.read(sessionUserProvider.notifier).state = user;
      if (!mounted) return;
      if (widget.changeMode) {
        showDmToast(context, 'Speciality updated');
        context.pop();
      }
      // Onboard mode: the router redirect releases the gate to /home.
    } on ChangeLimitReached {
      setState(() => _error = 'One-time change already used.');
    } on AuthOffline {
      setState(() => _error = "You're offline - your speciality wasn't saved. Retry.");
    } catch (_) {
      setState(() => _error = "Couldn't save your speciality - retry.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final filtered = _filtered;
    final dnb = [for (final s in filtered) if (s.examType == 'DNB') s];
    final drnb = [for (final s in filtered) if (s.examType == 'DrNB') s];
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam speciality', style: DmType.title.copyWith(color: dm.ink)),
        // onboard: no back, no skip. Explicit leading (not
        // automaticallyImplyLeading) so the button shows regardless of
        // navigator-stack depth - change mode is always reached by push.
        leading: widget.changeMode ? const BackButton() : null,
        automaticallyImplyLeading: false,
        backgroundColor: dm.paper,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DmSpace.gutter, DmSpace.sm, DmSpace.gutter, DmSpace.xs),
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (v) => setState(() => _query = v.trim()),
              onSubmitted: (_) {
                final top = _filtered.isEmpty ? null : _filtered.first;
                if (top != null) setState(() => _selectedId = top.id);
              },
              decoration: InputDecoration(
                hintText: 'Search - e.g. cardio, ENT, DrNB…',
                hintStyle: DmType.bodyUi.copyWith(color: dm.ink3),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DmRadius.sm),
                    borderSide: BorderSide(color: dm.ruleStrong)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${filtered.length} of ${_all.length} tracks',
                  style: DmType.meta.copyWith(color: dm.ink3)),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No matches. Try a shorter term - e.g. "cardio".',
                        style: DmType.bodyUi.copyWith(color: dm.ink2)))
                : FocusTraversalGroup(
                    child: ListView(
                      children: [
                        if (dnb.isNotEmpty) const _GroupHeader('DNB - Broad Specialities'),
                        for (final s in dnb) _row(s, dm),
                        if (drnb.isNotEmpty) const _GroupHeader('DrNB - Super Specialities'),
                        for (final s in drnb) _row(s, dm),
                      ],
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(DmSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DmSpace.sm),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: DmType.meta.copyWith(color: dm.examRed)),
                    ),
                  FilledButton(
                    onPressed: _selectedId == null || _saving ? null : _commit,
                    style: FilledButton.styleFrom(
                      backgroundColor: dm.teal,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DmRadius.md)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.changeMode ? 'Save change' : 'Continue',
                            style: DmType.bodyUi.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(SpecialityRow s, DmColors dm) {
    final selected = s.id == _selectedId;
    final label = _label(s);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: InkWell(
        onTap: () => setState(() => _selectedId = s.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
              horizontal: DmSpace.gutter, vertical: DmSpace.sm),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: dm.rule))),
          child: Row(
            children: [
              Expanded(child: _highlighted(label, dm)),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20, color: selected ? dm.teal : dm.ink3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _highlighted(String label, DmColors dm) {
    if (_query.isEmpty) return Text(label, style: DmType.bodyUi.copyWith(color: dm.ink));
    final q = _query.toLowerCase();
    final i = label.toLowerCase().indexOf(q);
    if (i < 0) return Text(label, style: DmType.bodyUi.copyWith(color: dm.ink));
    return Text.rich(TextSpan(children: [
      TextSpan(text: label.substring(0, i), style: DmType.bodyUi.copyWith(color: dm.ink)),
      TextSpan(
          text: label.substring(i, i + q.length),
          style: DmType.bodyUi.copyWith(color: dm.tealInk, fontWeight: FontWeight.w700)),
      TextSpan(text: label.substring(i + q.length), style: DmType.bodyUi.copyWith(color: dm.ink)),
    ]));
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Container(
      width: double.infinity,
      color: dm.sunk,
      padding: const EdgeInsets.symmetric(
          horizontal: DmSpace.gutter, vertical: DmSpace.xs),
      child: Text(text, style: DmType.label.copyWith(color: dm.ink3)),
    );
  }
}
