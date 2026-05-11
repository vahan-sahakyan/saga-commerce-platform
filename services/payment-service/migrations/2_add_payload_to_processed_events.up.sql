-- Add payload column to processed_events for event payload storage
ALTER TABLE processed_events ADD COLUMN payload TEXT;