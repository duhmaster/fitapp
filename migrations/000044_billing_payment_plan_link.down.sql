DROP INDEX IF EXISTS idx_billing_payments_plan_code;

ALTER TABLE billing_payments
  DROP COLUMN IF EXISTS checkout_url,
  DROP COLUMN IF EXISTS plan_code;
