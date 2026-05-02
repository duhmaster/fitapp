import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/billing/data/billing_repository.dart';

final billingPaymentProvider =
    FutureProvider.family<BillingPayment, String>((ref, paymentId) {
  return ref.watch(billingRepositoryProvider).getPayment(paymentId);
});

class BillingPaymentStatusScreen extends ConsumerWidget {
  const BillingPaymentStatusScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final paymentAsync = ref.watch(billingPaymentProvider(paymentId));
    return Scaffold(
      appBar: AppBar(title: Text(tr('paywall_status_title'))),
      body: paymentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (payment) {
          final status = payment.status.toLowerCase();
          final isSuccess = status == 'paid';
          final isFailed = status == 'failed' || status == 'canceled';
          final icon = isSuccess
              ? Icons.check_circle
              : isFailed
                  ? Icons.error_outline
                  : Icons.timelapse;
          final color = isSuccess
              ? Colors.green
              : isFailed
                  ? Colors.red
                  : Colors.orange;
          final title = isSuccess
              ? tr('paywall_status_success')
              : isFailed
                  ? tr('paywall_status_failed')
                  : tr('paywall_status_pending');
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(icon, color: color, size: 64),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(payment.amountMinor / 100).toStringAsFixed(0)} ${payment.currency}',
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(billingPaymentProvider(paymentId)),
                  child: Text(tr('refresh')),
                ),
                if (!isSuccess && !isFailed) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(billingRepositoryProvider)
                          .mockConfirmPayment(paymentId);
                      ref.invalidate(billingPaymentProvider(paymentId));
                    },
                    child: Text(tr('paywall_mock_confirm')),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: Text(tr('go_home')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
