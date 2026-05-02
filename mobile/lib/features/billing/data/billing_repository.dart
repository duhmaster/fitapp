import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/network/api_client.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(dio: ref.watch(apiClientProvider));
});

class BillingRepository {
  BillingRepository({required this.dio});
  final Dio dio;

  Future<List<BillingPlan>> listPlans() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/billing/plans');
    final list = res.data?['plans'] as List<dynamic>? ?? [];
    return list
        .map((e) => BillingPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BillingPayment> createCheckout({
    required String planCode,
    String platform = 'mobile',
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/me/billing/checkout',
      data: <String, dynamic>{
        'plan_code': planCode,
        'platform': platform,
      },
    );
    final json = res.data ?? const <String, dynamic>{};
    return BillingPayment.fromJson(json);
  }

  Future<BillingPayment> getPayment(String paymentId) async {
    final res = await dio
        .get<Map<String, dynamic>>('/api/v1/me/billing/payments/$paymentId');
    final json = res.data ?? const <String, dynamic>{};
    return BillingPayment.fromJson(json);
  }

  Future<void> mockConfirmPayment(String paymentId) async {
    await dio.post<void>('/api/v1/me/billing/payments/$paymentId/mock-confirm');
  }

  Future<BillingEntitlements> getMyEntitlements() async {
    final res =
        await dio.get<Map<String, dynamic>>('/api/v1/me/billing/entitlements');
    final json = res.data?['entitlements'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return BillingEntitlements.fromJson(json);
  }
}

class BillingPlan {
  BillingPlan({
    required this.code,
    required this.title,
    required this.billingPeriod,
    required this.priceMinor,
    required this.currency,
  });

  final String code;
  final String title;
  final String billingPeriod;
  final int priceMinor;
  final String currency;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    return BillingPlan(
      code: (json['code'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      billingPeriod: (json['billing_period'] as String?) ?? 'month',
      priceMinor: (json['price_minor'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?) ?? 'RUB',
    );
  }
}

class BillingPayment {
  BillingPayment({
    required this.paymentId,
    required this.status,
    required this.provider,
    required this.checkoutUrl,
    required this.amountMinor,
    required this.currency,
  });

  final String paymentId;
  final String status;
  final String provider;
  final String checkoutUrl;
  final int amountMinor;
  final String currency;

  factory BillingPayment.fromJson(Map<String, dynamic> json) {
    return BillingPayment(
      paymentId: (json['payment_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      provider: (json['provider'] as String?) ?? 'tinkoff',
      checkoutUrl: (json['checkout_url'] as String?) ?? '',
      amountMinor: (json['amount_minor'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?) ?? 'RUB',
    );
  }
}

class BillingEntitlements {
  BillingEntitlements({
    required this.premiumUser,
    required this.coachPro,
  });

  final bool premiumUser;
  final bool coachPro;

  factory BillingEntitlements.fromJson(Map<String, dynamic> json) {
    return BillingEntitlements(
      premiumUser: (json['premium_user'] as bool?) ?? false,
      coachPro: (json['coach_pro'] as bool?) ?? false,
    );
  }
}
