# Money v3 Execution Checklist (Agent)

Практический чеклист разработки для реализации `docs/money3.md`.
Формат: задачи, порядок, DoD (definition of done), риски.

---

## 0) Правила исполнения

- [ ] Все entitlement-проверки делать на backend.
- [ ] Любой платежный webhook обрабатывать идемпотентно.
- [ ] Любая операция изменения подписки логируется в audit/event таблицу.
- [ ] Никаких paywall/ads в core тренировочном потоке.
- [ ] Для iOS подписок использовать StoreKit/IAP-контур.

---

## 1) Спринт 1 — Billing Core (schema + domain + guards)

## 1.1 Миграции и БД

- [ ] Добавить миграции:
  - [ ] `billing_plans`
  - [ ] `user_subscriptions`
  - [ ] `payment_methods`
  - [ ] `billing_payments`
  - [ ] `billing_provider_events`
  - [ ] `billing_refunds`
- [ ] Добавить индексы, unique-констрейнты, FK.
- [ ] Seed базовых планов (`free_user`, `premium_user`, `free_coach`, `coach_pro`).

DoD:
- [ ] `go test ./...` проходит.
- [ ] Миграции накатываются/откатываются локально без ошибок.

## 1.2 Domain / repository / usecase

- [ ] Создать модуль `internal/billing`:
  - [ ] `domain` (entities, statuses, transitions)
  - [ ] `repository` (postgres)
  - [ ] `usecase` (entitlements + subscription lifecycle)
- [ ] Реализовать `EntitlementService`:
  - [ ] `HasPremium(userID)`
  - [ ] `HasCoachPro(userID)`
  - [ ] `CanAddClient(trainerID)` (лимит 5 для free coach)
- [ ] Добавить API:
  - [ ] `GET /api/v1/billing/plans`
  - [ ] `GET /api/v1/me/billing/entitlements`
  - [ ] `GET /api/v1/me/billing/subscription`

DoD:
- [ ] Все новые endpoints покрыты happy-path + forbidden cases.
- [ ] Ограничения free работают серверно.

## 1.3 Guards в существующих модулях

- [ ] Ограничить premium-аналитику (history > 14 days).
- [ ] Ограничить coach clients > 5.
- [ ] Вставить бизнес-ошибки с понятными кодами:
  - [ ] `ErrPremiumRequired`
  - [ ] `ErrCoachProRequired`

DoD:
- [ ] UI может корректно показать paywall по коду ошибки.

---

## 2) Спринт 2 — Тинькофф СБП (web/android) + renew worker

## 2.1 Checkout API

- [ ] Реализовать `POST /api/v1/me/billing/checkout`:
  - [ ] validate `plan_code`
  - [ ] create payment in provider
  - [ ] persist `billing_payments` as `created/pending`
  - [ ] вернуть `payment_id + sbp_url/qr_payload`
- [ ] Реализовать `GET /api/v1/me/billing/payments/:id`.

DoD:
- [ ] С web/android клиент может начать оплату и получить статус.

## 2.2 Webhook Тинькофф

- [ ] Endpoint `POST /api/v1/billing/webhooks/tinkoff`.
- [ ] Проверка подписи/секрета.
- [ ] Идемпотентность по `provider_event_id` и `provider_payment_id`.
- [ ] Статусная машина:
  - [ ] `paid` -> активировать/продлить подписку
  - [ ] `failed/canceled` -> корректно завершить payment
- [ ] Запись raw payload в `billing_provider_events`.

DoD:
- [ ] Повторная доставка webhook не ломает данные.
- [ ] Изменения subscription и payment консистентны.

## 2.3 Автопродление

- [ ] Добавить worker `subscription_renewal_worker`.
- [ ] Retry policy: +1/+3/+7 days.
- [ ] Переходы `past_due -> grace -> expired`.
- [ ] Scheduled reconcile job для зависших `pending`.

DoD:
- [ ] Есть e2e сценарий renew success/fail/grace.

---

## 3) Спринт 3 — iOS IAP серверный контур

## 3.1 Receipt / transaction validation

- [ ] Endpoint для подтверждения iOS-транзакции.
- [ ] Серверная валидация у Apple.
- [ ] Маппинг iOS product -> internal plan.
- [ ] Создание/обновление `user_subscriptions` и `billing_payments`.

## 3.2 Apple notifications

- [ ] Endpoint `POST /api/v1/billing/webhooks/apple`.
- [ ] Идемпотентность и обработка renew/cancel/refund.

DoD:
- [ ] iOS-покупка активирует entitlement без клиентских хакапов.

---

## 4) Спринт 4 — Возвраты + фискализация + админка

## 4.1 Возвраты

- [ ] Реализовать `POST /api/v1/admin/billing/refunds`.
- [ ] Поддержать full/partial refund.
- [ ] Обновлять `billing_refunds` и `billing_payments`.
- [ ] Пересчет entitlement при полном возврате по правилам.

DoD:
- [ ] Возврат отражается в истории и влияет на доступ.

## 4.2 Фискализация

- [ ] Интеграция с онлайн-кассой (CloudKassir/АТОЛ).
- [ ] Продажа -> чек продажи.
- [ ] Возврат -> чек возврата.
- [ ] Хранить фискальные атрибуты (номер чека/ФН/ФД/ФП).

DoD:
- [ ] На каждую успешную оплату/возврат есть фискальный след.

## 4.3 Админка billing

- [ ] Список платежей/подписок/возвратов.
- [ ] Фильтры по статусам и датам.
- [ ] Ручная коррекция подписки (force status) с аудитом.

DoD:
- [ ] Операции поддержки закрываются без SQL руками.

---

## 5) Mobile/Web UI checklist

## 5.1 Общий UI

- [ ] `plans` экран.
- [ ] Paywall (user/coach).
- [ ] Экран статуса платежа (pending/success/fail).
- [ ] Экран текущей подписки (план, auto-renew, next date).

## 5.2 Ограничения free

- [ ] Аналитика > 14 дней -> paywall.
- [ ] 6-й клиент тренера -> paywall.
- [ ] Все блокировки показывают понятный CTA на оплату.

## 5.3 Платформенные различия

- [ ] iOS: путь оплаты через StoreKit.
- [ ] Android/Web: путь оплаты через SBP/Tinkoff.

DoD:
- [ ] UX непрерывный: после успешной оплаты entitlement обновляется автоматически.

---

## 6) Analytics + observability

- [ ] События:
  - [ ] `paywall_view`
  - [ ] `checkout_start`
  - [ ] `payment_pending`
  - [ ] `payment_success`
  - [ ] `payment_failed`
  - [ ] `trial_start`
  - [ ] `renew_success`
  - [ ] `renew_failed`
  - [ ] `refund_success`
- [ ] Дашборды:
  - [ ] checkout conversion
  - [ ] trial -> paid
  - [ ] renewal success rate
  - [ ] refund rate
- [ ] Алерты:
  - [ ] webhook 5xx spike
  - [ ] pending > threshold
  - [ ] renew failure spike

DoD:
- [ ] Можно оперативно понять, где теряется выручка.

---

## 7) QA regression checklist

- [ ] Free user не получает premium access.
- [ ] Premium user не видит ad/paywall в premium экранах.
- [ ] Free coach не может >5 активных клиентов.
- [ ] Coach pro может >5 клиентов.
- [ ] SBP payment success/fail/cancel.
- [ ] iOS purchase success/restore/cancel.
- [ ] Refund full/partial.
- [ ] Subscription expiry + grace.
- [ ] Дубли webhook не создают дублей списаний/подписок.

---

## 8) Release readiness gate

- [ ] Миграции прогнаны на staging snapshot.
- [ ] Secrets/keys выставлены через env, не в коде.
- [ ] Все webhook endpoints защищены и проверяют подпись.
- [ ] Feature flags на монетизацию включаются поэтапно.
- [ ] Rollback plan на случай проблем с платежами.
- [ ] Актуализированы оферта/политика возвратов/публичные условия.

---

## 9) Порядок фактической реализации агентом (обязательный)

1. DB migrations + billing domain.
2. Entitlements + guards.
3. Checkout + payment status API.
4. Tinkoff webhook + idempotency.
5. Renewal worker + grace.
6. Mobile/web paywall and flows.
7. iOS IAP backend validation.
8. Refunds + admin.
9. Fiscal receipts.
10. Analytics, alerts, hardening.

---

## 10) Границы MVP (чтобы не расползся scope)

В MVP входит:

- подписки и entitlements;
- web/android СБП;
- iOS IAP;
- автопродление, базовые возвраты;
- free/paid ограничения.

В MVP не входит:

- сложная партнерка;
- dynamic pricing engine;
- продвинутые B2B-контракты и white-label биллинг.

