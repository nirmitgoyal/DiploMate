import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../theme/tokens.dart';
import '../shell/dm_toast.dart';

/// D19 opt-out. Plan 5's notification service watches this (same name).
final reminderEnabledProvider = StateProvider<bool>((ref) => true);

final _lastSyncedProvider = StreamProvider<DateTime?>(
    (ref) => ref.watch(syncServiceProvider).lastSyncedAt());

final _specialityNameProvider = FutureProvider<String?>((ref) async {
  final id = ref.watch(sessionUserProvider)?.specialityId;
  if (id == null) return null;
  final specs = await ref.watch(contentRepositoryProvider).specialities();
  for (final s in specs) {
    if (s.id == id) return s.name;
  }
  return null;
});

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  String _syncLabel(DateTime? at) {
    if (at == null) return 'Not synced yet';
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'Last synced today';
    if (days == 1) return 'Last synced 1 day ago';
    return 'Last synced $days days ago';
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final dm = context.dm;
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This permanently removes your recall history, bookmarks and profile from DiploMate. There is no undo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (step1 != true || !context.mounted) return;
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('This is permanent'),
        content: const Text(
            'Your account and all data are deleted immediately. You would start again from zero.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep my account')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete account', style: TextStyle(color: dm.examRed))),
        ],
      ),
    );
    if (step2 != true || !context.mounted) return;
    await ref.read(authRepositoryProvider).deleteAccount();
    if (context.mounted) showDmToast(context, 'Account deleted');
    ref.read(sessionUserProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = context.dm;
    final user = ref.watch(sessionUserProvider);
    final syncedAt = ref.watch(_lastSyncedProvider).valueOrNull;
    final specName = ref.watch(_specialityNameProvider).valueOrNull;
    final changeUsed = (user?.specialityChangeCount ?? 0) >= 1;
    final stale =
        syncedAt == null || DateTime.now().difference(syncedAt).inDays > 7;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
          children: [
            const SizedBox(height: DmSpace.sm),
            Text('Account', style: DmType.title.copyWith(color: dm.ink)),
            const SizedBox(height: DmSpace.xl2),
            Row(
              children: [
                _Avatar(name: user?.name, photoUrl: user?.photoUrl, dm: dm),
                const SizedBox(width: DmSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '',
                          style: DmType.bodyUi.copyWith(color: dm.ink)),
                      Text(user?.email ?? '',
                          style: DmType.meta.copyWith(color: dm.ink3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DmSpace.sm),
            Text(_syncLabel(syncedAt),
                style: DmType.meta.copyWith(color: stale ? dm.amber : dm.ink3)),
            const SizedBox(height: DmSpace.lg),
            _Row(
              dm: dm,
              title: 'Exam speciality',
              subtitle: specName,
              trailing: changeUsed
                  ? Text('one-time change used',
                      style: DmType.meta.copyWith(color: dm.ink3))
                  : Icon(Icons.chevron_right, color: dm.ink3),
              enabled: !changeUsed,
              onTap: () => context.go('/speciality?mode=change'),
            ),
            _Row(
              dm: dm,
              title: 'Daily reminder',
              trailing: Switch(
                value: ref.watch(reminderEnabledProvider),
                activeTrackColor: dm.teal,
                onChanged: (v) =>
                    ref.read(reminderEnabledProvider.notifier).state = v,
              ),
            ),
            _Row(
              dm: dm,
              title: 'Sign out',
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                ref.read(sessionUserProvider.notifier).state = null;
              },
            ),
            _Row(
              dm: dm,
              title: 'Delete account',
              titleColor: dm.examRed,
              leadingIcon: Icons.delete_outline,
              onTap: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl, required this.dm});
  final String? name, photoUrl;
  final DmColors dm;

  @override
  Widget build(BuildContext context) {
    final letter = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?';
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: dm.tealSoft, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null
          ? Center(
              child: Text(letter, style: DmType.bodyUi.copyWith(color: dm.tealInk)))
          : Image.network(photoUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                  child: Text(letter,
                      style: DmType.bodyUi.copyWith(color: dm.tealInk)))),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.dm,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap,
      this.enabled = true,
      this.titleColor,
      this.leadingIcon});
  final DmColors dm;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? titleColor;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: dm.rule))),
        padding: const EdgeInsets.symmetric(vertical: DmSpace.md),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: titleColor ?? dm.ink2),
              const SizedBox(width: DmSpace.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: DmType.bodyUi.copyWith(
                          color: titleColor ?? (enabled ? dm.ink : dm.ink3))),
                  if (subtitle != null)
                    Text(subtitle!, style: DmType.meta.copyWith(color: dm.ink3)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
