import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/billing/data/billing_repository.dart';

final billingPlansProvider = FutureProvider<List<BillingPlan>>((ref) {
  return ref.watch(billingRepositoryProvider).listPlans();
});

class BillingPaywallScreen extends ConsumerWidget {
  const BillingPaywallScreen({
    super.key,
    this.requiredPlan = 'premium',
  });

  final String requiredPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final plansAsync = ref.watch(billingPlansProvider);
    final needCoach = requiredPlan == 'coach_pro';
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('paywall_title')),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (plans) {
          final filtered = plans.where((p) {
            if (needCoach) return p.code.contains('coach_pro');
            return p.code.contains('premium_user');
          }).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                needCoach
                    ? tr('coach_pro_required_error')
                    : tr('premium_required_error'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                tr('paywall_subtitle'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              if (filtered.isEmpty)
                Card(
                  child: ListTile(
                    title: Text(tr('loading')),
                    subtitle: Text(tr('paywall_plans_empty')),
                  ),
                )
              else
                ...filtered.map(
                  (p) => Card(
                    child: ListTile(
                      title: Text(p.title),
                      subtitle: Text(_formatPrice(p)),
                      trailing: FilledButton(
                        onPressed: () async {
                          try {
                            final payment = await ref
                                .read(billingRepositoryProvider)
                                .createCheckout(planCode: p.code);
                            if (!context.mounted) return;
                            context.go(
                              '/billing/payment/${payment.paymentId}',
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(tr('paywall_checkout_coming'))),
                            );
                          }
                        },
                        child: Text(tr('paywall_select_plan')),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    context.pop();
                    return;
                  }
                  context.go('/home');
                },
                child: Text(tr('close')),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatPrice(BillingPlan plan) {
    final amount = (plan.priceMinor / 100).toStringAsFixed(0);
    final period = plan.billingPeriod == 'year' ? 'year' : 'month';
    return '$amount ${plan.currency}/$period';
  }
}
