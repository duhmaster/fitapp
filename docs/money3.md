# Money Plan v3: Billing Blueprint (Web/iOS/Android + SBP Tinkoff)

Документ фиксирует целевую модель монетизации и технический план внедрения с учетом:

- платформ: `web`, `ios`, `android`;
- платежей через `СБП Тинькофф`;
- автопродления;
- возвратов;
- free-режима с ограничениями и платной подписки.

---

## 1) Ключевое продуктовое решение по платформам

Из-за правил App Store для цифровых услуг рекомендована гибридная схема:

- `Web`: СБП Тинькофф (основной канал).
- `Android`: СБП Тинькофф (основной канал).
- `iOS`: In-App Purchase (StoreKit subscriptions) как основной канал для цифрового контента.

Backend выступает единой точкой истины по правам доступа (`entitlements`) и объединяет статусы подписок из разных провайдеров.

---

## 2) Тарифы и entitlements

## Тарифы

- `free_user`
- `premium_user`
- `free_coach`
- `coach_pro`

## Базовые ограничения free

- User: ограниченная аналитика (например, 14 дней), базовые цели.
- Coach: лимит активных клиентов (например, 5).

## Платные преимущества

- Снятие лимитов по аналитике/истории/целям.
- Расширенные coach-инструменты, безлимит клиентов.
- Отключение рекламы.

---

## 3) Юридический и фискальный контур (ИП)

Рекомендованный операционный стек для ИП:

- Эквайринг/СБП: `Тинькофф`.
- Онлайн-касса: `CloudKassir` (альтернатива: `АТОЛ Онлайн`).
- ОФД: `Платформа ОФД` (альтернатива: `Такском`).

Обязательные требования:

- 54-ФЗ чеки на продажу и возврат;
- хранение фискальных реквизитов;
- синхронизация статусов платежа и фискализации.

---

## 4) SQL-схема (MVP+)

```sql
-- 1) Каталог планов
CREATE TABLE billing_plans (
  code            VARCHAR(40) PRIMARY KEY, -- free_user, premium_user, free_coach, coach_pro
  title           TEXT NOT NULL,
  billing_period  VARCHAR(20) NOT NULL,    -- month|year
  price_minor     BIGINT NOT NULL,         -- в копейках
  currency        CHAR(3) NOT NULL DEFAULT 'RUB',
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2) Подписки пользователя
CREATE TABLE user_subscriptions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_code             VARCHAR(40) NOT NULL REFERENCES billing_plans(code),
  provider              VARCHAR(20) NOT NULL, -- tinkoff|apple
  provider_subscription_id TEXT,
  status                VARCHAR(20) NOT NULL, -- trial|active|grace|past_due|canceled|expired
  auto_renew            BOOLEAN NOT NULL DEFAULT TRUE,
  trial_started_at      TIMESTAMPTZ,
  trial_ends_at         TIMESTAMPTZ,
  current_period_start  TIMESTAMPTZ NOT NULL,
  current_period_end    TIMESTAMPTZ NOT NULL,
  grace_until           TIMESTAMPTZ,
  canceled_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_user_subscriptions_user_status ON user_subscriptions(user_id, status);
CREATE INDEX idx_user_subscriptions_renew ON user_subscriptions(provider, auto_renew, current_period_end);

-- 3) Платежные методы (токены провайдера, без PAN)
CREATE TABLE payment_methods (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider              VARCHAR(20) NOT NULL, -- tinkoff|apple
  provider_customer_id  TEXT,
  provider_method_id    TEXT,
  is_default            BOOLEAN NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_payment_methods_user ON payment_methods(user_id);

-- 4) Платежи
CREATE TABLE billing_payments (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subscription_id       UUID REFERENCES user_subscriptions(id) ON DELETE SET NULL,
  provider              VARCHAR(20) NOT NULL, -- tinkoff|apple
  provider_payment_id   TEXT NOT NULL,
  order_id              TEXT NOT NULL,
  amount_minor          BIGINT NOT NULL,
  currency              CHAR(3) NOT NULL DEFAULT 'RUB',
  status                VARCHAR(20) NOT NULL, -- created|pending|paid|failed|canceled|refunded|partial_refunded
  failure_code          TEXT,
  failure_message       TEXT,
  paid_at               TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(provider, provider_payment_id),
  UNIQUE(order_id)
);
CREATE INDEX idx_billing_payments_user_created ON billing_payments(user_id, created_at DESC);

-- 5) Сырые webhook/event записи (аудит и идемпотентность)
CREATE TABLE billing_provider_events (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider              VARCHAR(20) NOT NULL, -- tinkoff|apple
  provider_event_id     TEXT,
  event_type            TEXT NOT NULL,
  payload               JSONB NOT NULL,
  signature_valid       BOOLEAN NOT NULL DEFAULT FALSE,
  processed_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(provider, provider_event_id)
);

-- 6) Возвраты
CREATE TABLE billing_refunds (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id            UUID NOT NULL REFERENCES billing_payments(id) ON DELETE CASCADE,
  provider              VARCHAR(20) NOT NULL,
  provider_refund_id    TEXT,
  amount_minor          BIGINT NOT NULL,
  status                VARCHAR(20) NOT NULL, -- created|succeeded|failed
  reason                TEXT,
  created_by            UUID, -- admin user
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_billing_refunds_payment ON billing_refunds(payment_id);
```

---

## 5) State machine подписки

Базовые состояния:

- `trial` -> `active` -> `grace` -> `expired`
- `active` -> `past_due` -> (`active` | `grace`)
- `active|trial` -> `canceled` (auto_renew = false, доступ до конца периода)

## Переходы

1. `create_subscription`:
   - если trial доступен: `trial`;
   - иначе сразу `active` после успешной оплаты.
2. `renew_success`: продление `current_period_end`, статус `active`.
3. `renew_failed`: `past_due` и запуск retry-политики.
4. `retry_exhausted`: переход в `grace` (если включен grace).
5. `grace_expired`: `expired` и отзыв premium/pro entitlement.
6. `cancel_requested`: `auto_renew=false`, статус может оставаться `active` до конца периода.
7. `refund_full`: отзыв доступа немедленно или по правилам оферты.

---

## 6) Backend API (MVP)

## Пользовательские методы

- `GET /api/v1/billing/plans`
- `GET /api/v1/me/billing/entitlements`
- `POST /api/v1/me/billing/checkout`  
  body: `{ plan_code, platform, return_url, cancel_url }`
- `GET /api/v1/me/billing/payments/:payment_id`
- `GET /api/v1/me/billing/subscription`
- `POST /api/v1/me/billing/cancel-auto-renew`

## Webhook методы

- `POST /api/v1/billing/webhooks/tinkoff`
- `POST /api/v1/billing/webhooks/apple`

## Админ методы

- `GET /api/v1/admin/billing/payments`
- `GET /api/v1/admin/billing/subscriptions`
- `POST /api/v1/admin/billing/refunds`
- `POST /api/v1/admin/billing/subscriptions/:id/force-status`

---

## 7) Платформенные флоу оплаты

## Web/Android (СБП Тинькофф)

1. Клиент вызывает `POST /me/billing/checkout`.
2. Backend создает платеж в Тинькофф и возвращает `payment_id + sbp_url/qr_payload`.
3. Клиент открывает СБП/показывает QR.
4. Клиент опрашивает `GET /payments/:id/status` + backend получает webhook.
5. При `paid` backend активирует/продлевает подписку и entitlement.

## iOS (StoreKit)

1. Покупка в StoreKit.
2. Клиент отправляет transaction/receipt на backend.
3. Backend валидирует у Apple и обновляет подписку.
4. Server Notifications от Apple синхронизируют renew/cancel/refund.

---

## 8) Автопродление и retry

Рекомендуемая политика:

- до 3 попыток списания после неудачи (`+1 день`, `+3 дня`, `+7 дней`);
- при неудаче: `past_due`, затем `grace` (3-7 дней);
- после `grace`: `expired`.

Технически:

- cron/worker `subscription_renewal_worker`;
- таблица задач или outbox для retry;
- idempotency-key на каждую попытку.

---

## 9) Возвраты (обязательный контур)

Поддержать:

- `full refund`;
- `partial refund` (если провайдер/бизнес-процесс допускает).

Правила:

- возврат инициируется из админки;
- результат фиксируется в `billing_refunds`;
- при полном возврате entitlement снимается по политике;
- обязательно пробивается чек возврата через онлайн-кассу.

---

## 10) Entitlement-guard матрица (минимум)

- `premium_analytics_full_history` -> `premium_user`
- `premium_goals_extended` -> `premium_user`
- `coach_clients_unlimited` -> `coach_pro`
- `coach_advanced_reports` -> `coach_pro`
- `ads_disabled` -> `premium_user|coach_pro`

Все проверки критичных функций выполняются на backend.

---

## 11) Реклама и safe-zones

Для `free_user` / `free_coach`:

- показывать нативную рекламу только в безопасных зонах (лента/контент);
- frequency cap: до 3 показов в сутки.

Запрет показа:

- активная тренировка;
- логирование подходов;
- завершение и экран итогов тренировки;
- редактирование плана клиента.

---

## 12) Roadmap внедрения (по спринтам)

## Спринт 1

- Billing schema + repository/usecase.
- Entitlement service + guards.
- API plans/subscription/entitlements (без реальных оплат).

## Спринт 2

- Интеграция Тинькофф СБП (checkout + webhook + status).
- Включение автопродления и retry worker.
- Paywall UI web/android.

## Спринт 3

- iOS StoreKit server validation + Apple webhook.
- Единая сводка подписки в `/me/billing/subscription`.
- Ограничения free и unlock paid в продукте.

## Спринт 4

- Возвраты (admin flow + чек возврата).
- Фискализация (онлайн-касса + ОФД).
- Мониторинг, дашборды и алерты.

---

## 13) KPI и эксплуатационные метрики

- `paywall_view -> checkout_start -> paid_success` воронка;
- trial conversion и trial->paid;
- renewal success rate;
- refund rate;
- churn monthly;
- webhook failure rate;
- доля расхождений payment vs subscription;
- retention D30 после включения paywall/ads.

---

## 14) Риски и меры

- Риск App Store compliance -> использовать IAP для iOS.
- Дубли webhook -> строгая идемпотентность событий.
- Потеря webhook -> fallback polling + reconcile job.
- Несвоевременная фискализация -> async retry + alerting.
- Ложные entitlement -> только server-authoritative access checks.

