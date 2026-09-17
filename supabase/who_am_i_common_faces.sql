-- Expand Who Am I with widely recognizable Kenyan, African, and global faces.

insert into public.content_packs (code, title, description, region)
values ('famous_faces', 'Famous Faces', 'Widely recognizable Kenyan, African, and global public figures.', 'world')
on conflict (code) do update set title = excluded.title, description = excluded.description, is_active = true;

insert into public.categories (code, title, icon, sort_order)
values ('who_am_i_icons', 'Famous Faces', 'users', 30)
on conflict (code) do update set title = excluded.title, icon = excluded.icon, is_active = true;

insert into public.media_assets (asset_type, provider, asset_key, public_url, alt_text, attribution, licence, width, height)
select 'image', 'game_mavelas', v.slug, '/celebrities/' || v.slug || '.svg',
  'Stylized portrait of ' || v.name, 'Original Game Mavelas vector artwork', 'Project asset', 512, 512
from (values
  ('william-ruto', 'William Ruto'), ('raila-odinga', 'Raila Odinga'),
  ('uhuru-kenyatta', 'Uhuru Kenyatta'), ('bien-aime-baraza', 'Bien-Aimé Baraza'),
  ('nyashinski', 'Nyashinski'), ('churchill-ndambuki', 'Churchill Ndambuki'),
  ('victor-wanyama', 'Victor Wanyama'), ('njugush', 'Njugush'),
  ('eric-omondi', 'Eric Omondi'), ('catherine-kamau', 'Catherine Kamau'),
  ('nelson-mandela', 'Nelson Mandela'), ('trevor-noah', 'Trevor Noah'),
  ('burna-boy', 'Burna Boy'), ('diamond-platnumz', 'Diamond Platnumz'),
  ('mohamed-salah', 'Mohamed Salah'), ('didier-drogba', 'Didier Drogba'),
  ('davido', 'Davido'), ('cristiano-ronaldo', 'Cristiano Ronaldo'),
  ('lionel-messi', 'Lionel Messi'), ('barack-obama', 'Barack Obama')
) as v(slug, name)
on conflict (provider, asset_key) do update set
  public_url = excluded.public_url, alt_text = excluded.alt_text,
  attribution = excluded.attribution, licence = excluded.licence,
  width = excluded.width, height = excluded.height;

insert into public.questions
  (slug, pack_id, category_id, game_mode, prompt, explanation, media_id, difficulty,
   duration_seconds, base_points, tags, status, source_id, fact_checked_at)
select replace(v.asset_slug, '-', '_') || '_identity', p.id, c.id, 'who_am_i', 'Who Am I?',
  v.explanation, m.id, v.difficulty, 45, 200, v.tags, 'approved', s.id, now()
from (values
  ('william-ruto', 'William Ruto', 'A Kenyan politician who became Kenya''s fifth President in 2022.', 1, array['kenya','leadership']),
  ('raila-odinga', 'Raila Odinga', 'A prominent Kenyan political leader and former Prime Minister.', 1, array['kenya','leadership']),
  ('uhuru-kenyatta', 'Uhuru Kenyatta', 'Kenya''s fourth President, serving from 2013 to 2022.', 1, array['kenya','leadership']),
  ('bien-aime-baraza', 'Bien-Aimé Baraza', 'A Kenyan singer and songwriter best known as a member of Sauti Sol.', 2, array['kenya','music']),
  ('nyashinski', 'Nyashinski', 'A Kenyan rapper and singer who first became famous with the group Kleptomaniax.', 2, array['kenya','music']),
  ('churchill-ndambuki', 'Churchill Ndambuki', 'A Kenyan comedian and broadcaster associated with Churchill Show.', 1, array['kenya','comedy']),
  ('victor-wanyama', 'Victor Wanyama', 'A Kenyan footballer who captained the national team and played in the English Premier League.', 2, array['kenya','football']),
  ('njugush', 'Njugush', 'A Kenyan comedian and digital creator known for relatable comedy.', 2, array['kenya','comedy']),
  ('eric-omondi', 'Eric Omondi', 'A Kenyan comedian and entertainer who rose to fame through Churchill Live.', 2, array['kenya','comedy']),
  ('catherine-kamau', 'Catherine Kamau', 'A Kenyan actor popularly known as Kate Actress.', 2, array['kenya','film']),
  ('nelson-mandela', 'Nelson Mandela', 'The anti-apartheid leader who became South Africa''s first Black President.', 1, array['africa','leadership']),
  ('trevor-noah', 'Trevor Noah', 'A South African comedian and former host of The Daily Show.', 1, array['africa','comedy']),
  ('burna-boy', 'Burna Boy', 'A Nigerian singer and Grammy-winning Afrobeats star.', 1, array['africa','music']),
  ('diamond-platnumz', 'Diamond Platnumz', 'A Tanzanian singer and major Bongo Flava star.', 1, array['africa','music']),
  ('mohamed-salah', 'Mohamed Salah', 'An Egyptian footballer famous for playing for Liverpool.', 1, array['africa','football']),
  ('didier-drogba', 'Didier Drogba', 'An Ivorian football legend strongly associated with Chelsea.', 1, array['africa','football']),
  ('davido', 'Davido', 'A Nigerian Afrobeats singer known internationally for numerous hit songs.', 1, array['africa','music']),
  ('cristiano-ronaldo', 'Cristiano Ronaldo', 'A Portuguese footballer and one of the most famous athletes in the world.', 1, array['global','football']),
  ('lionel-messi', 'Lionel Messi', 'An Argentine footballer who captained his country to the 2022 World Cup title.', 1, array['global','football']),
  ('barack-obama', 'Barack Obama', 'The 44th President of the United States, whose father was Kenyan.', 1, array['global','leadership'])
) as v(asset_slug, identity_name, explanation, difficulty, tags)
join public.content_packs p on p.code = 'famous_faces'
join public.categories c on c.code = 'who_am_i_icons'
join public.question_sources s on s.source_key = 'editorial'
join public.media_assets m on m.provider = 'game_mavelas' and m.asset_key = v.asset_slug
on conflict (slug) do update set
  pack_id = excluded.pack_id, category_id = excluded.category_id, explanation = excluded.explanation,
  media_id = excluded.media_id, difficulty = excluded.difficulty, tags = excluded.tags,
  status = excluded.status, fact_checked_at = excluded.fact_checked_at, updated_at = now();

insert into public.question_options (question_id, position, option_text, is_correct)
select q.id, 1, v.identity_name, true
from (values
  ('william_ruto_identity', 'William Ruto'), ('raila_odinga_identity', 'Raila Odinga'),
  ('uhuru_kenyatta_identity', 'Uhuru Kenyatta'), ('bien_aime_baraza_identity', 'Bien-Aimé Baraza'),
  ('nyashinski_identity', 'Nyashinski'), ('churchill_ndambuki_identity', 'Churchill Ndambuki'),
  ('victor_wanyama_identity', 'Victor Wanyama'), ('njugush_identity', 'Njugush'),
  ('eric_omondi_identity', 'Eric Omondi'), ('catherine_kamau_identity', 'Catherine Kamau'),
  ('nelson_mandela_identity', 'Nelson Mandela'), ('trevor_noah_identity', 'Trevor Noah'),
  ('burna_boy_identity', 'Burna Boy'), ('diamond_platnumz_identity', 'Diamond Platnumz'),
  ('mohamed_salah_identity', 'Mohamed Salah'), ('didier_drogba_identity', 'Didier Drogba'),
  ('davido_identity', 'Davido'), ('cristiano_ronaldo_identity', 'Cristiano Ronaldo'),
  ('lionel_messi_identity', 'Lionel Messi'), ('barack_obama_identity', 'Barack Obama')
) as v(question_slug, identity_name)
join public.questions q on q.slug = v.question_slug
on conflict (question_id, position) do update set option_text = excluded.option_text, is_correct = true;

-- Move the original ten into the same playable pool, then draw ten random faces per game.
update public.questions
set category_id = (select id from public.categories where code = 'who_am_i_icons'), updated_at = now()
where game_mode = 'who_am_i';

update public.round_template_steps
set category_id = (select id from public.categories where code = 'who_am_i_icons'),
    difficulty_min = 1, difficulty_max = 5, question_count = 10, seconds_per_question = 45
where template_id = (select id from public.round_templates where code = 'who_am_i_kenya');
