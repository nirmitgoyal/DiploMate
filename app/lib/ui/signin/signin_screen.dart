import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/repos/auth_repository.dart';
import '../../theme/tokens.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _inFlight = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _inFlight = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      ref.read(sessionUserProvider.notifier).state = user;
    } on AuthOffline {
      setState(() => _error = "You're offline - connect and retry.");
    } on SignInCancelled {
      // DESIGN.md State Spec 2: cancel returns to idle, no error shown.
    } catch (_) {
      setState(() => _error = 'Sign-in failed - try again.');
    } finally {
      if (mounted) setState(() => _inFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text('DiploMate',
                  textAlign: TextAlign.center,
                  style: DmType.display.copyWith(color: dm.ink)),
              const SizedBox(height: DmSpace.xs),
              Text('Written by Doctors. Solved for Success!',
                  textAlign: TextAlign.center,
                  style: DmType.label.copyWith(color: dm.tealInk)),
              const SizedBox(height: DmSpace.xl2),
              Text('Master DNB theory answers by recalling them, not rereading them.',
                  textAlign: TextAlign.center,
                  style: DmType.bodyUi.copyWith(color: dm.ink2)),
              const SizedBox(height: DmSpace.xl2),
              const ExcludeSemantics(child: _Specimen()),
              const Spacer(flex: 3),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: DmSpace.sm),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: DmType.meta.copyWith(color: dm.examRed)),
                ),
              Semantics(
                label: _inFlight ? 'Signing in' : null,
                child: FilledButton(
                  onPressed: _inFlight ? null : _signIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: dm.teal,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DmRadius.md)),
                  ),
                  child: _inFlight
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Continue with Google',
                          style: DmType.bodyUi.copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(height: DmSpace.md),
              // plan 6: url_launcher wires these to /legal/terms + /legal/privacy
              Text('Terms of Service · Privacy Policy',
                  textAlign: TextAlign.center,
                  style: DmType.meta.copyWith(color: dm.ink3)),
              const SizedBox(height: DmSpace.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cropped structured model-answer specimen - the sign-in visual anchor.
/// Answer-on-white material code + examiner red margin (signature moves).
class _Specimen extends StatelessWidget {
  const _Specimen();

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Container(
      decoration: BoxDecoration(
        color: dm.elevated,
        borderRadius: BorderRadius.circular(DmRadius.sm),
        border: Border.all(color: dm.rule),
      ),
      padding: const EdgeInsets.all(DmSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DEFINITION', style: DmType.label.copyWith(color: dm.ink3)),
                const SizedBox(height: DmSpace.xs),
                Text(
                  'The TAP block is a fascial plane block depositing local '
                  'anaesthetic between internal oblique and transversus abdominis...',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: DmType.body.copyWith(color: dm.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: DmSpace.md),
          Text('1', style: DmType.meta.copyWith(color: dm.examRed)),
        ],
      ),
    );
  }
}
