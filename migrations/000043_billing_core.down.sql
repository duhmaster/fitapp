DROP INDEX IF EXISTS idx_billing_refunds_payment;
DROP TABLE IF EXISTS billing_refunds;

DROP TABLE IF EXISTS billing_provider_events;

DROP INDEX IF EXISTS idx_billing_payments_user_created;
DROP TABLE IF EXISTS billing_payments;

DROP INDEX IF EXISTS idx_payment_methods_user;
DROP TABLE IF EXISTS payment_methods;

DROP INDEX IF EXISTS idx_user_subscriptions_renew;
DROP INDEX IF EXISTS idx_user_subscriptions_user_status;
DROP TABLE IF EXISTS user_subscriptions;

DROP TABLE IF EXISTS billing_plans;
