-- EcoQuest Supabase Database Schema
-- Run these SQL commands in your Supabase SQL Editor

-- 1. Create users table
CREATE TABLE IF NOT EXISTS public.users (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    email TEXT,
    age TEXT,
    gender TEXT,
    hobby TEXT,
    favorite_animal TEXT,
    profile_image TEXT,
    is_connected_to_google BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create user_progress table
CREATE TABLE IF NOT EXISTS public.user_progress (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    exp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    points INTEGER DEFAULT 0,
    weekly_points INTEGER DEFAULT 0,
    week_start_date TIMESTAMP WITH TIME ZONE DEFAULT date_trunc('week', NOW()),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create journals table
CREATE TABLE IF NOT EXISTS public.journals (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    entry_id TEXT NOT NULL,
    image_path TEXT,
    capture_date TEXT,
    identified_species JSONB,
    confidence NUMERIC,
    location TEXT,
    notes TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    type TEXT,
    category TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, entry_id)
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journals ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS Policies for users table
CREATE POLICY "Users can view all users data for leaderboard"
    ON public.users FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own data"
    ON public.users FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own data"
    ON public.users FOR UPDATE
    USING (auth.uid() = user_id);

-- 6. Create RLS Policies for user_progress table
CREATE POLICY "Users can view all progress for leaderboard"
    ON public.user_progress FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own progress"
    ON public.user_progress FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own progress"
    ON public.user_progress FOR UPDATE
    USING (auth.uid() = user_id);

-- 7. Create RLS Policies for journals table
CREATE POLICY "Users can view their own journals"
    ON public.journals FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own journals"
    ON public.journals FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own journals"
    ON public.journals FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own journals"
    ON public.journals FOR DELETE
    USING (auth.uid() = user_id);

-- 8. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_user_id ON public.users(user_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_user_id ON public.user_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_journals_user_id ON public.journals(user_id);
CREATE INDEX IF NOT EXISTS idx_journals_entry_id ON public.journals(entry_id);

-- 9. Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 10. Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_progress_updated_at BEFORE UPDATE ON public.user_progress
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
