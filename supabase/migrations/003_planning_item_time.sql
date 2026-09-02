-- Chunk 4: optional planning item time.
-- Additive and idempotent; scheduled_date remains date-only.

alter table public.trip_planning_items
  add column if not exists scheduled_time time;
