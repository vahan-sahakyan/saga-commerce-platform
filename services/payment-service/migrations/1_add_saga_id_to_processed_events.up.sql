-- Add saga_id column to processed_events for event correlation
ALTER TABLE processed_events ADD COLUMN saga_id VARCHAR;
CREATE INDEX IF NOT EXISTS idx_processed_events_saga_id ON processed_events(saga_id);