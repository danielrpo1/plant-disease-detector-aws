-- Ejecutar una vez en RDS PostgreSQL (Etapa 4)
CREATE TABLE IF NOT EXISTS predictions (
  id SERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  s3_key VARCHAR(512) NOT NULL,
  predicted_class VARCHAR(128) NOT NULL,
  confidence REAL NOT NULL,
  display_name VARCHAR(256),
  top3 JSONB
);

CREATE INDEX IF NOT EXISTS idx_predictions_created_at ON predictions (created_at DESC);
