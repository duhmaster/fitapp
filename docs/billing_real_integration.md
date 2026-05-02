# Billing: текущая реализация и план подключения реального провайдера

Документ описывает:

- что уже реализовано в billing-контуре проекта;
- какие шаги нужны для перехода с mock/stub на реальный `СБП Тинькофф`;
- порядок работ для production-ready запуска.

---

## 1) Что уже реализовано

## Backend (billing core + checkout + webhook scaffold)

- Миграции billing-ядра:
  - `billing_plans`
  - `user_subscriptions`
  - `payment_methods`
  - `billing_payments`
  - `billing_provider_events`
  - `billing_refunds`
- Дополнительная миграция связи платежа и плана:
  - `billing_payments.plan_code`
  - `billing_payments.checkout_url`
- Entitlements:
  - `GET /api/v1/me/billing/entitlements`
  - `GET /api/v1/me/billing/subscription`
- Checkout/status:
  - `POST /api/v1/me/billing/checkout`
  - `GET /api/v1/me/billing/payments/:payment_id`
- Webhook endpoint:
  - `POST /api/v1/billing/webhook/provider`
- Idempotency webhook-событий:
  - запись в `billing_provider_events`
  - дедупликация по `(provider, provider_event_id)`
- Базовая валидация подписи:
  - `X-Billing-Signature` + `BILLING_WEBHOOK_SECRET`
- Активация подписки при подтвержденном платеже:
  - обновление `billing_payments.status = paid`
  - создание `user_subscriptions` со статусом `active`
  - установка периода по `billing_plans.billing_period`

## Mobile (paywall + status flow)

- Экран paywall с выбором тарифа.
- Кнопка «Выбрать» вызывает checkout.
- Экран статуса платежа (`pending/success/fail`).
- Временная тестовая кнопка для локальной проверки:
  - `POST /api/v1/me/billing/payments/:payment_id/mock-confirm`

---

## 2) Текущее ограничение (что еще не production)

Сейчас используется промежуточный scaffold:

- checkout не создает реальную сессию/операцию в API Тинькофф;
- webhook универсальный (`/provider`), без нативной валидации по спецификации Тинькофф;
- нет полного цикла автопродления и retry-policy;
- нет reconcile-job для «зависших» `pending` платежей;
- нет полной фискализации (чек продажи/чек возврата) в runtime-пайплайне.
- не реализованы недельные лимиты free-тарифов:
  - `Free User`: не более 3 тренировок/неделя (обычные + групповые);
  - `Free Coach`: не более 3 созданных групповых тренировок/неделя.

---

## 3) Шаги подключения реального Тинькофф СБП

Ниже рекомендуемый порядок внедрения.

## Шаг 1. Provider adapter (Tinkoff API client)

- Добавить модуль, например `internal/billing/provider/tinkoff`:
  - `CreatePayment(...)` / `Init(...)`
  - `GetPaymentState(...)`
  - helper для маппинга статусов провайдера в внутренние.
- Конфиг:
  - `BILLING_TINKOFF_TERMINAL_KEY`
  - `BILLING_TINKOFF_PASSWORD`
  - `BILLING_TINKOFF_BASE_URL`
  - (опционально) `BILLING_TINKOFF_TIMEOUT`
- В `POST /me/billing/checkout`:
  - создавать платеж у Тинькофф;
  - сохранять `provider_payment_id`, `order_id`, `checkout_url`/`sbp_url`;
  - возвращать клиенту ссылку/данные для оплаты.

## Шаг 2. Нативный webhook endpoint для Тинькофф

- Выделить endpoint:
  - `POST /api/v1/billing/webhooks/tinkoff`
- Валидация:
  - проверка подписи строго по правилам Тинькофф;
  - reject при invalid signature.
- Идемпотентность:
  - ключ события: `provider + provider_event_id` (или безопасный fallback);
  - обязательная запись сырого payload в `billing_provider_events`.

## Шаг 3. Статусная машина платежей/подписок

- Маппинг статусов Тинькофф:
  - `CONFIRMED` (или эквивалент) -> `paid`
  - `CANCELED/REJECTED` -> `failed/canceled`
  - промежуточные -> `pending`
- Бизнес-правила:
  - повторные webhook должны быть no-op (idempotent);
  - подтвержденный платеж должен:
    - обновить payment,
    - активировать/продлить подписку,
    - корректно закрыть предыдущий период, если требуется.

## Шаг 4. Renewal worker

- Добавить фоновый worker `subscription_renewal_worker`:
  - обработка auto-renew;
  - retry policy (+1 / +3 / +7 дней);
  - переходы `past_due -> grace -> expired`.
- Добавить reconcile-job:
  - проверка «долгих» `pending`;
  - синхронизация статусов с провайдером.

## Шаг 5. Фискализация и возвраты

- Интеграция с онлайн-кассой/OFD:
  - чек продажи на успешную оплату;
  - чек возврата при refund.
- Возвраты:
  - full / partial;
  - отражение в `billing_refunds`, `billing_payments`;
  - пересчет entitlement по бизнес-правилам.

## Шаг 6. Frontend hardening для billing UX

- Единая доступность страницы тарифов:
  - кнопка на `home`;
  - переход из профиля пользователя (под блоком статуса подписки);
  - переход из профиля тренера.
- Единый paywall flow:
  - `premium_required` -> premium paywall;
  - `coach_pro_required` -> coach pro paywall;
  - без raw backend ошибок в snackbar.
- Навигационная устойчивость:
  - без падений при повторном открытии paywall/payment экранов;
  - fallback поведение для `close/back`.
- UX статусов:
  - явный статус free/pro в профиле;
  - быстрый CTA на тарифы рядом со статусом.

---

## 4) Минимальные критерии production readiness

- Реальный checkout в Тинькофф работает с web/android.
- Webhook валидирует подпись по официальной схеме Тинькофф.
- Повторная доставка webhook не создает дублей и не ломает статус.
- Подписка активируется/продлевается консистентно.
- Работают retry + grace + expiration сценарии.
- Реализованы и проверены weekly-лимиты free-тарифов:
  - `Free User`: 3 тренировки в неделю (group + regular);
  - `Free Coach`: 3 созданные групповые тренировки в неделю.
- Настроены мониторинг и алерты:
  - ошибки webhook;
  - рост `pending` платежей;
  - ошибки renew worker;
  - рассинхрон payment/subscription.

---

## 5) Рекомендуемые env-переменные

- `BILLING_WEBHOOK_SECRET` (уже используется для базовой проверки)
- `BILLING_TINKOFF_TERMINAL_KEY`
- `BILLING_TINKOFF_PASSWORD`
- `BILLING_TINKOFF_BASE_URL`
- `BILLING_TINKOFF_TIMEOUT`
- `BILLING_RENEWAL_ENABLED`
- `BILLING_RENEWAL_BATCH_SIZE`
- `BILLING_RENEWAL_INTERVAL`

---

## 6) Быстрый локальный e2e сценарий (текущая версия)

1. Открыть paywall и выбрать тариф.
2. Создается `payment` со статусом `pending`.
3. На экране статуса нажать «Подтвердить оплату (тест)».
4. Backend переводит payment в `paid`.
5. Создается `active` подписка в `user_subscriptions`.
6. `GET /me/billing/entitlements` отражает доступ платного тарифа.

Этот сценарий нужен для проверки продукта до подключения реального provider API.
