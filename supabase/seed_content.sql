-- Initial editorial pack. Safe to run repeatedly.

insert into public.content_packs (code, title, description, region) values
  ('kenya_core', 'Kenya Core', 'Kenyan culture, geography and everyday brilliance.', 'kenya'),
  ('east_africa', 'East Africa', 'Countries, nature and culture across East Africa.', 'east_africa'),
  ('africa', 'Africa', 'Continental history, places, people and sport.', 'africa'),
  ('world_mix', 'World Mix', 'Well-checked global party trivia.', 'world'),
  ('school_smart', 'School Smart', 'Science, maths, animals and geography.', 'world')
on conflict (code) do update set title = excluded.title, description = excluded.description, region = excluded.region;

insert into public.categories (code, title, icon, sort_order) values
  ('animals', 'Animals', 'paw-print', 10),
  ('geography', 'Geography', 'map', 20),
  ('science', 'Science', 'flask-conical', 30),
  ('entertainment', 'Entertainment', 'film', 40),
  ('tech', 'Technology', 'cpu', 50),
  ('math', 'Math', 'calculator', 60),
  ('sports', 'Sports', 'trophy', 70),
  ('history', 'History', 'landmark', 80),
  ('kenyan_culture', 'Kenyan Culture', 'heart-handshake', 90),
  ('flags', 'Flags', 'flag', 100)
on conflict (code) do update set title = excluded.title, icon = excluded.icon, sort_order = excluded.sort_order;

insert into public.question_sources (source_key, title, source_url, licence, notes, checked_at) values
  ('editorial', 'Game Mavelas Editorial', null, 'Original editorial work', 'Questions reviewed for clarity and age suitability.', now()),
  ('flagcdn', 'FlagCDN', 'https://flagcdn.com/', 'See provider terms', 'Country flag delivery using ISO 3166-1 alpha-2 codes.', now()),
  ('wikidata', 'Wikidata', 'https://www.wikidata.org/', 'CC0', 'Structured fact checking source.', now())
on conflict (source_key) do update set checked_at = excluded.checked_at;

insert into public.media_assets (asset_type, provider, asset_key, public_url, alt_text, attribution, licence, source_id) values
  ('flag', 'flagcdn', 'ke', 'https://flagcdn.com/ke.svg', 'Flag of Kenya', 'FlagCDN / Wikimedia Commons', 'See provider terms', (select id from public.question_sources where source_key = 'flagcdn')),
  ('flag', 'flagcdn', 'ug', 'https://flagcdn.com/ug.svg', 'Flag of Uganda', 'FlagCDN / Wikimedia Commons', 'See provider terms', (select id from public.question_sources where source_key = 'flagcdn')),
  ('flag', 'flagcdn', 'tz', 'https://flagcdn.com/tz.svg', 'Flag of Tanzania', 'FlagCDN / Wikimedia Commons', 'See provider terms', (select id from public.question_sources where source_key = 'flagcdn')),
  ('flag', 'flagcdn', 'rw', 'https://flagcdn.com/rw.svg', 'Flag of Rwanda', 'FlagCDN / Wikimedia Commons', 'See provider terms', (select id from public.question_sources where source_key = 'flagcdn')),
  ('flag', 'flagcdn', 'za', 'https://flagcdn.com/za.svg', 'Flag of South Africa', 'FlagCDN / Wikimedia Commons', 'See provider terms', (select id from public.question_sources where source_key = 'flagcdn'))
on conflict (provider, asset_key) do update set public_url = excluded.public_url, alt_text = excluded.alt_text;

insert into public.round_templates (code, title, game_mode, description) values
  ('trivia_rush_classic', 'Trivia Rush: Classic', 'trivia', 'A three-phase sprint from warm-up to finale.'),
  ('flag_frenzy_africa', 'Flag Frenzy: Africa', 'flag_frenzy', 'Recognise African flags under time pressure.'),
  ('smart_mix', 'Smart Mix', 'trivia', 'Science, geography, animals and maths in one round.')
on conflict (code) do update set title = excluded.title, description = excluded.description;

insert into public.round_template_steps (template_id, position, category_id, difficulty_min, difficulty_max, question_count, seconds_per_question) values
  ((select id from public.round_templates where code = 'trivia_rush_classic'), 1, null, 1, 2, 5, 20),
  ((select id from public.round_templates where code = 'trivia_rush_classic'), 2, null, 2, 3, 5, 15),
  ((select id from public.round_templates where code = 'trivia_rush_classic'), 3, null, 3, 5, 5, 10),
  ((select id from public.round_templates where code = 'flag_frenzy_africa'), 1, (select id from public.categories where code = 'flags'), 1, 4, 10, 12),
  ((select id from public.round_templates where code = 'smart_mix'), 1, null, 1, 3, 12, 18)
on conflict (template_id, position) do update set question_count = excluded.question_count, seconds_per_question = excluded.seconds_per_question;

insert into public.questions (slug, pack_id, category_id, game_mode, prompt, explanation, media_id, difficulty, duration_seconds, base_points, tags, status, source_id, fact_checked_at)
select v.slug, p.id, c.id, v.game_mode, v.prompt, v.explanation, m.id, v.difficulty, v.duration, v.points, v.tags, 'approved', s.id, now()
from (values
  ('kenya_capital', 'kenya_core', 'geography', 'trivia', 'What is the capital city of Kenya?', 'Nairobi is Kenya''s capital and largest city.', null, 1, 20, 100, array['kenya','capital']),
  ('equator_kenya', 'kenya_core', 'geography', 'trivia', 'Which imaginary line passes through Kenya?', 'The Equator crosses Kenya and divides Earth into northern and southern hemispheres.', null, 2, 20, 150, array['kenya','equator']),
  ('wangari_maathai', 'kenya_core', 'who_am_i', 'I was the first African woman to receive the Nobel Peace Prize and founded the Green Belt Movement. Who am I?', 'Wangari Maathai received the Nobel Peace Prize in 2004.', null, 3, 20, 200, array['kenya','women','environment']),
  ('east_africa_mountain', 'east_africa', 'geography', 'trivia', 'What is the highest mountain in Africa?', 'Mount Kilimanjaro, in Tanzania, is Africa''s highest mountain.', null, 2, 20, 150, array['africa','mountain']),
  ('kenya_flag', 'kenya_core', 'flags', 'flag_frenzy', 'Which country does this flag belong to?', 'The shield and crossed spears are distinctive features of Kenya''s flag.', 'ke', 1, 12, 100, array['flag','kenya']),
  ('uganda_flag', 'east_africa', 'flags', 'flag_frenzy', 'Which East African country does this flag belong to?', 'Uganda''s flag features a grey crowned crane.', 'ug', 2, 12, 150, array['flag','east_africa']),
  ('tanzania_flag', 'east_africa', 'flags', 'flag_frenzy', 'Which country does this flag belong to?', 'Tanzania''s flag has a black diagonal band edged in yellow.', 'tz', 2, 12, 150, array['flag','east_africa']),
  ('water_formula', 'school_smart', 'science', 'trivia', 'What is the chemical formula for water?', 'Water is made from two hydrogen atoms and one oxygen atom.', null, 1, 18, 100, array['science','chemistry']),
  ('largest_planet', 'school_smart', 'science', 'trivia', 'Which is the largest planet in our solar system?', 'Jupiter is the largest planet in the solar system.', null, 2, 18, 150, array['space','science']),
  ('red_planet', 'school_smart', 'science', 'trivia', 'Which planet is known as the Red Planet?', 'Mars appears reddish because of iron oxide on its surface.', null, 1, 18, 100, array['space','science']),
  ('cheetah_speed', 'africa', 'animals', 'trivia', 'Which animal is the fastest land animal?', 'The cheetah is famous for its short, extremely fast sprints.', null, 1, 18, 100, array['animals','africa']),
  ('hexagon_sides', 'school_smart', 'math', 'trivia', 'How many sides does a hexagon have?', 'A hexagon is a polygon with six sides.', null, 1, 18, 100, array['math','shapes']),
  ('multiply_12_8', 'school_smart', 'math', 'trivia', 'What is 12 × 8?', 'Twelve multiplied by eight equals ninety-six.', null, 1, 15, 100, array['math','mental_math']),
  ('cpu_meaning', 'world_mix', 'tech', 'trivia', 'In computing, what does CPU stand for?', 'CPU means Central Processing Unit.', null, 2, 18, 150, array['technology','computers']),
  ('olympic_rings', 'world_mix', 'sports', 'trivia', 'How many rings are on the Olympic symbol?', 'The Olympic symbol has five interlocking rings.', null, 1, 18, 100, array['sports','olympics']),
  ('continents_count', 'world_mix', 'geography', 'trivia', 'How many continents are commonly taught in the seven-continent model?', 'The common school model identifies seven continents.', null, 1, 18, 100, array['geography','world'])
) as v(slug, pack_code, category_code, game_mode, prompt, explanation, media_key, difficulty, duration, points, tags)
join public.content_packs p on p.code = v.pack_code
join public.categories c on c.code = v.category_code
join public.question_sources s on s.source_key = 'editorial'
left join public.media_assets m on m.provider = 'flagcdn' and m.asset_key = v.media_key
on conflict (slug) do update set
  prompt = excluded.prompt, explanation = excluded.explanation, media_id = excluded.media_id,
  difficulty = excluded.difficulty, duration_seconds = excluded.duration_seconds,
  base_points = excluded.base_points, tags = excluded.tags, status = excluded.status,
  fact_checked_at = excluded.fact_checked_at, updated_at = now();

insert into public.question_options (question_id, position, option_text, is_correct)
select q.id, v.position, v.option_text, v.is_correct
from (values
  ('kenya_capital', 1, 'Nairobi', true), ('kenya_capital', 2, 'Mombasa', false), ('kenya_capital', 3, 'Kisumu', false), ('kenya_capital', 4, 'Nakuru', false),
  ('equator_kenya', 1, 'The Equator', true), ('equator_kenya', 2, 'The Tropic of Cancer', false), ('equator_kenya', 3, 'The Prime Meridian', false), ('equator_kenya', 4, 'The Arctic Circle', false),
  ('wangari_maathai', 1, 'Wangari Maathai', true), ('wangari_maathai', 2, 'Mekatilili wa Menza', false), ('wangari_maathai', 3, 'Lupita Nyong''o', false), ('wangari_maathai', 4, 'Joy Adamson', false),
  ('east_africa_mountain', 1, 'Mount Kilimanjaro', true), ('east_africa_mountain', 2, 'Mount Kenya', false), ('east_africa_mountain', 3, 'Mount Elgon', false), ('east_africa_mountain', 4, 'Mount Meru', false),
  ('kenya_flag', 1, 'Kenya', true), ('kenya_flag', 2, 'Uganda', false), ('kenya_flag', 3, 'South Sudan', false), ('kenya_flag', 4, 'Malawi', false),
  ('uganda_flag', 1, 'Uganda', true), ('uganda_flag', 2, 'Rwanda', false), ('uganda_flag', 3, 'Kenya', false), ('uganda_flag', 4, 'Ghana', false),
  ('tanzania_flag', 1, 'Tanzania', true), ('tanzania_flag', 2, 'South Africa', false), ('tanzania_flag', 3, 'Zambia', false), ('tanzania_flag', 4, 'Gabon', false),
  ('water_formula', 1, 'H₂O', true), ('water_formula', 2, 'CO₂', false), ('water_formula', 3, 'O₂', false), ('water_formula', 4, 'NaCl', false),
  ('largest_planet', 1, 'Jupiter', true), ('largest_planet', 2, 'Earth', false), ('largest_planet', 3, 'Saturn', false), ('largest_planet', 4, 'Mars', false),
  ('red_planet', 1, 'Mars', true), ('red_planet', 2, 'Venus', false), ('red_planet', 3, 'Mercury', false), ('red_planet', 4, 'Jupiter', false),
  ('cheetah_speed', 1, 'Cheetah', true), ('cheetah_speed', 2, 'Lion', false), ('cheetah_speed', 3, 'Ostrich', false), ('cheetah_speed', 4, 'Leopard', false),
  ('hexagon_sides', 1, '6', true), ('hexagon_sides', 2, '5', false), ('hexagon_sides', 3, '7', false), ('hexagon_sides', 4, '8', false),
  ('multiply_12_8', 1, '96', true), ('multiply_12_8', 2, '86', false), ('multiply_12_8', 3, '108', false), ('multiply_12_8', 4, '92', false),
  ('cpu_meaning', 1, 'Central Processing Unit', true), ('cpu_meaning', 2, 'Computer Power Utility', false), ('cpu_meaning', 3, 'Central Program User', false), ('cpu_meaning', 4, 'Control Processing Upload', false),
  ('olympic_rings', 1, '5', true), ('olympic_rings', 2, '4', false), ('olympic_rings', 3, '6', false), ('olympic_rings', 4, '7', false),
  ('continents_count', 1, '7', true), ('continents_count', 2, '5', false), ('continents_count', 3, '6', false), ('continents_count', 4, '8', false)
) as v(question_slug, position, option_text, is_correct)
join public.questions q on q.slug = v.question_slug
on conflict (question_id, position) do update set option_text = excluded.option_text, is_correct = excluded.is_correct;
