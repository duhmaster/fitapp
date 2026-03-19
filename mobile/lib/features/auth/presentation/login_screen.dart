import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/locale/locale_repository.dart';
import 'package:fitflow/core/theme/theme_provider.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/widgets/barbell_logo.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/auth/domain/auth_models.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _trySubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final login = ref.read(loginProvider);
      await login(LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ));
      if (!mounted) return;
      ref.read(authRedirectNotifierProvider).setLoggedIn(true);
      final me = await ref.read(authRepositoryProvider).getMe();
      await applyMePreferences(
        me,
        setTheme: (key) => ref.read(selectedThemeKeyProvider.notifier).update((_) => key),
        setLocale: (code) => ref.read(selectedLocaleCodeProvider.notifier).update((_) => code),
        localeRepo: ref.read(localeRepositoryProvider),
      );
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      String msg;
      if (e.error is AppException) {
        msg = (e.error! as AppException).message;
      } else if (e.response?.data is Map) {
        final d = e.response!.data as Map;
        msg = (d['error'] ?? d['message'] ?? e.message)?.toString() ?? 'Invalid email or password';
      } else {
        msg = e.message ?? 'Invalid email or password';
      }
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      if (mounted) setState(() => _error = e is AppException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final wide = constraints.maxWidth >= 900;

                  final landingSide = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BarbellLogo(size: 72),
                      const SizedBox(height: 12),
                      Text(
                        tr('login_landing_headline'),
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr('login_landing_body'),
                        style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 18),
                      _LandingFeature(icon: Icons.playlist_add_check, text: tr('login_feature_templates')),
                      _LandingFeature(icon: Icons.show_chart, text: tr('login_feature_statistics')),
                      _LandingFeature(icon: Icons.fitness_center, text: tr('login_feature_exercises')),
                    ],
                  );

                  final formCard = Card(
                    elevation: 0,
                    color: scheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              tr('sign_in'),
                              style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('login_form_subtitle'),
                              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            if (_error != null) ...[
                              Text(_error!, style: TextStyle(color: scheme.error)),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              decoration: InputDecoration(
                                labelText: tr('email'),
                                hintText: tr('placeholder_email'),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return tr('enter_email');
                                return null;
                              },
                              onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              decoration: InputDecoration(
                                labelText: tr('password'),
                                hintText: tr('placeholder_password'),
                                border: const OutlineInputBorder(),
                              ),
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              validator: (v) {
                                if (v == null || v.isEmpty) return tr('enter_password');
                                return null;
                              },
                              onFieldSubmitted: (_) => _trySubmit(),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _loading ? null : _trySubmit,
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(tr('sign_in')),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: _loading ? null : () => context.push('/register'),
                              child: Text(tr('create_account')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Padding(padding: const EdgeInsets.only(right: 24), child: landingSide),
                        ),
                        Expanded(flex: 1, child: formCard),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      landingSide,
                      const SizedBox(height: 18),
                      formCard,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingFeature extends StatelessWidget {
  const _LandingFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
