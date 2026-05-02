import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/errors/app_exceptions.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';

class PaywallRequiredWidget extends ConsumerWidget {
  const PaywallRequiredWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final appError = _extractAppError(error);
    if (appError == null ||
        (!appError.isPremiumRequired && !appError.isCoachProRequired)) {
      return ErrorStateWidget(
        message: appError?.message ?? error.toString(),
        onRetry: onRetry,
      );
    }
    final isCoach = appError.isCoachProRequired;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              isCoach
                  ? tr('coach_pro_required_error')
                  : tr('premium_required_error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go(
                '/billing/paywall?required=${isCoach ? 'coach_pro' : 'premium'}',
              ),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(tr('paywall_open')),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: Text(tr('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  AppException? _extractAppError(Object e) {
    if (e is AppException) return e;
    if (e is DioException && e.error is AppException) {
      return e.error as AppException;
    }
    return null;
  }
}
