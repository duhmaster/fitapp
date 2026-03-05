import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/locale/locale_repository.dart';
import 'package:fitflow/core/theme/theme_provider.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/auth/domain/auth_models.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final register = ref.read(registerProvider);
      await register(RegisterRequest(
        name: _nameController.text.trim(),
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
        msg = (d['error'] ?? d['message'] ?? e.message)?.toString() ?? 'Registration failed';
      } else {
        msg = e.message ?? 'Registration failed';
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
    return Scaffold(
      appBar: AppBar(title: Text(tr('create_account'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: tr('name'),
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return tr('enter_name');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: tr('email'),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return tr('enter_email');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: tr('password'),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return tr('enter_password');
                    if (v.length < 6) return tr('at_least_6_chars');
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            _submit();
                          }
                        },
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr('register')),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(tr('back_to_sign_in')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
