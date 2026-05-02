ALTER TABLE billing_payments
  ADD COLUMN IF NOT EXISTS plan_code VARCHAR(40) REFERENCES billing_plans(code),
  ADD COLUMN IF NOT EXISTS checkout_url TEXT;

CREATE INDEX IF NOT EXISTS idx_billing_payments_plan_code
  ON billing_payments(plan_code);
