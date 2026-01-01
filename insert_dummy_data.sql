-- Dummy Data for EcoQuest Leaderboard
-- IMPORTANT: This creates dummy users WITHOUT requiring auth.users entries
-- Run this in your Supabase SQL Editor

-- Step 1: Temporarily disable RLS to insert dummy data
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.journals DISABLE ROW LEVEL SECURITY;

-- Step 2: Remove foreign key constraint temporarily (we'll add it back)
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_user_id_fkey;
ALTER TABLE public.user_progress DROP CONSTRAINT IF EXISTS user_progress_user_id_fkey;
ALTER TABLE public.journals DROP CONSTRAINT IF EXISTS journals_user_id_fkey;

-- Step 3: Insert dummy users directly
DO $$
DECLARE
  dummy_user_id UUID;
  dummy_names TEXT[] := ARRAY[
    'Ahmad Danial', 'Nurul Aisyah', 'Muhammad Arif', 'Siti Fatimah',
    'Faiz Abdullah', 'Nur Amira', 'Harith Iskandar', 'Aina Sofea',
    'Fikri Hakim', 'Alya Damia', 'Irfan Hakimi', 'Sara Adriana',
    'Zafran Iqbal', 'Hannah Farhana', 'Aiman Rusydi', 'Nabilah Husna',
    'Danish Haziq', 'Qistina Balqis', 'Haikal Syafiq', 'Natasha Elyna',
    'Luqman Hakim', 'Insyirah Zahra', 'Rayyan Farhan', 'Maisarah Nadhirah',
    'Zharif Zikri', 'Aleeya Maryam', 'Afiq Adib', 'Sofia Husna',
    'Izzat Haiqal', 'Eryna Batrisyia', 'Hariz Akmal', 'Myra Safiya',
    'Syazwan Imran', 'Adriana Sofea', 'Zikri Faris', 'Fatiha Izzati',
    'Hazim Qayyum', 'Balqis Irdina', 'Syahmi Aiman', 'Damia Humaira',
    'Aryan Hakim', 'Aina Medina', 'Haqeem Razin', 'Syakira Damia',
    'Uzair Harith', 'Alisha Naura', 'Ahnaf Mikail', 'Iris Aisyah',
    'Mirza Hakim', 'Zara Aleesya'
  ];
  dummy_points INTEGER[] := ARRAY[
    15000, 14500, 14000, 13500, 13000, 12500, 12000, 11500, 11000, 10500,
    10000, 9500, 9000, 8500, 8000, 7500, 7000, 6500, 6000, 5500,
    5000, 4500, 4000, 3500, 3000, 2500, 2000, 1500, 1000, 900,
    800, 700, 600, 500, 400, 350, 300, 250, 200, 150,
    140, 130, 120, 110, 100, 90, 80, 70, 60, 50
  ];
  dummy_weekly_points INTEGER[] := ARRAY[
    850, 920, 780, 1050, 650, 890, 720, 980, 550, 810,
    690, 1020, 580, 750, 880, 620, 940, 570, 830, 710,
    990, 540, 870, 660, 800, 520, 910, 640, 770, 480,
    850, 600, 730, 460, 890, 590, 710, 440, 820, 560,
    680, 420, 780, 530, 650, 400, 740, 510, 620, 380
  ];
  dummy_genders TEXT[] := ARRAY['Male', 'Female'];
  dummy_hobbies TEXT[] := ARRAY['Fotografi', 'Mendaki', 'Memerhati Burung', 'Perkhemahan', 'Berjalan di Hutan', 'Kajian Hidupan Liar'];
  dummy_animals TEXT[] := ARRAY['Harimau', 'Gajah', 'Orang Utan', 'Tapir', 'Beruang Madu', 'Penyu', 'Buaya', 'Rusa', 'Monyet', 'Burung Enggang'];
  i INTEGER;
BEGIN
  -- Loop through and create 50 dummy users
  FOR i IN 1..50 LOOP
    -- Generate a unique UUID for each dummy user
    dummy_user_id := gen_random_uuid();
    
    -- Insert into public.users table
    INSERT INTO public.users (user_id, name, email, age, gender, hobby, favorite_animal, profile_image, is_connected_to_google)
    VALUES (
      dummy_user_id,
      dummy_names[i],
      'dummy' || i || '@ecoquest.test',
      (18 + (i % 40))::TEXT,
      dummy_genders[(i % 2) + 1],
      dummy_hobbies[(i % 6) + 1],
      dummy_animals[(i % 10) + 1],
      NULL,
      false
    );
    
    -- Insert into user_progress table with both all-time and weekly points
    INSERT INTO public.user_progress (user_id, exp, level, points, weekly_points)
    VALUES (
      dummy_user_id,
      dummy_points[i],
      CASE 
        WHEN dummy_points[i] >= 10000 THEN 10 + (dummy_points[i] - 10000) / 1000
        WHEN dummy_points[i] >= 5000 THEN 5 + (dummy_points[i] - 5000) / 1000
        WHEN dummy_points[i] >= 1000 THEN 1 + (dummy_points[i] - 1000) / 500
        ELSE 1
      END,
      dummy_points[i],
      dummy_weekly_points[i]
    );
    
  END LOOP;
  
  RAISE NOTICE 'Created 50 dummy users with progress data!';
END $$;

-- Step 4: Re-add the foreign key constraints (but NOT requiring auth.users)
-- Skip re-adding the FK to auth.users for dummy data

-- Step 5: Re-enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journals ENABLE ROW LEVEL SECURITY;

-- Verify the data was created
SELECT 'Total users:' as info, COUNT(*)::TEXT as count FROM public.users;
SELECT 'Total progress records:' as info, COUNT(*)::TEXT as count FROM public.user_progress;

-- Show top 10 all-time leaderboard
SELECT 
  ROW_NUMBER() OVER (ORDER BY up.points DESC) as rank,
  u.name,
  up.level,
  up.points as all_time_points,
  up.weekly_points
FROM public.user_progress up
JOIN public.users u ON u.user_id = up.user_id
ORDER BY up.points DESC
LIMIT 10;

-- Show top 10 weekly leaderboard
SELECT 
  ROW_NUMBER() OVER (ORDER BY up.weekly_points DESC) as rank,
  u.name,
  up.level,
  up.weekly_points,
  up.points as all_time_points
FROM public.user_progress up
JOIN public.users u ON u.user_id = up.user_id
ORDER BY up.weekly_points DESC
LIMIT 10;
