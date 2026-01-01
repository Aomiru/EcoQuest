-- Add weekly points column to user_progress table
-- Run this in your Supabase SQL Editor

-- 1. Add weekly_points column
ALTER TABLE public.user_progress 
ADD COLUMN IF NOT EXISTS weekly_points INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS week_start_date TIMESTAMP WITH TIME ZONE DEFAULT date_trunc('week', NOW());

-- 2. Create a function to reset weekly points every week
CREATE OR REPLACE FUNCTION reset_weekly_points()
RETURNS void AS $$
BEGIN
  -- Reset all weekly_points to 0 and update week_start_date
  UPDATE public.user_progress
  SET 
    weekly_points = 0,
    week_start_date = date_trunc('week', NOW()),
    updated_at = NOW();
    
  RAISE NOTICE 'Weekly points reset completed for % users', 
    (SELECT COUNT(*) FROM public.user_progress);
END;
$$ LANGUAGE plpgsql;

-- 3. Create a cron job to reset weekly points every Monday at 00:00
-- Note: This requires pg_cron extension to be enabled in Supabase
-- You can enable it in: Database > Extensions > pg_cron

-- First, enable the extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the weekly reset (every Monday at midnight UTC)
SELECT cron.schedule(
  'reset-weekly-points',           -- job name
  '0 0 * * 1',                      -- cron schedule: every Monday at 00:00 UTC
  'SELECT reset_weekly_points();'   -- SQL to execute
);

-- 4. Manually trigger the reset for testing (optional)
-- SELECT reset_weekly_points();

-- 5. View scheduled cron jobs
SELECT * FROM cron.job;

-- 6. To remove the cron job (if needed):
-- SELECT cron.unschedule('reset-weekly-points');
