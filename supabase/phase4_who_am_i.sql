-- Phase 4: turn-based Who Am I?
-- Run this once in the Supabase SQL editor after deploying the accompanying app update.

alter table public.game_rounds
  add column if not exists active_player_id uuid;

create index if not exists game_rounds_active_player_idx
  on public.game_rounds (room_id, active_player_id)
  where active_player_id is not null;

create or replace function public.assign_who_am_i_player()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if new.active_player_id is not null then return new; end if;

  if exists (select 1 from public.questions q where q.id = new.question_id and q.game_mode = 'who_am_i') then
    select count(*) into v_count from public.room_players where room_id = new.room_id;
    if v_count = 0 then raise exception 'Who Am I needs at least one player'; end if;

    select rp.user_id into new.active_player_id
    from public.room_players rp
    where rp.room_id = new.room_id
    order by rp.joined_at, rp.user_id
    offset ((new.position - 1) % v_count)
    limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists assign_who_am_i_player_before_round on public.game_rounds;
create trigger assign_who_am_i_player_before_round
before insert on public.game_rounds
for each row execute function public.assign_who_am_i_player();

insert into public.media_assets (asset_type, provider, asset_key, public_url, alt_text, attribution, licence, width, height)
select 'image', 'game_mavelas', v.asset_key, v.public_url, v.alt_text, 'Original Game Mavelas vector artwork', 'Project asset', 512, 512
from (values
  ('wangari-maathai', '/celebrities/wangari-maathai.svg', 'Stylized portrait of Wangari Maathai'),
  ('eliud-kipchoge', '/celebrities/eliud-kipchoge.svg', 'Stylized portrait of Eliud Kipchoge'),
  ('lupita-nyongo', '/celebrities/lupita-nyongo.svg', 'Stylized portrait of Lupita Nyong''o'),
  ('faith-kipyegon', '/celebrities/faith-kipyegon.svg', 'Stylized portrait of Faith Kipyegon'),
  ('david-rudisha', '/celebrities/david-rudisha.svg', 'Stylized portrait of David Rudisha'),
  ('mekatilili-wa-menza', '/celebrities/mekatilili-wa-menza.svg', 'Stylized portrait of Mekatilili wa Menza'),
  ('dedan-kimathi', '/celebrities/dedan-kimathi.svg', 'Stylized portrait of Dedan Kimathi'),
  ('ferdinand-omanyala', '/celebrities/ferdinand-omanyala.svg', 'Stylized portrait of Ferdinand Omanyala'),
  ('joy-adamson', '/celebrities/joy-adamson.svg', 'Stylized portrait of Joy Adamson'),
  ('mwai-kibaki', '/celebrities/mwai-kibaki.svg', 'Stylized portrait of Mwai Kibaki')
) as v(asset_key, public_url, alt_text)
on conflict (provider, asset_key) do update set
  public_url = excluded.public_url, alt_text = excluded.alt_text,
  attribution = excluded.attribution, licence = excluded.licence,
  width = excluded.width, height = excluded.height;

insert into public.questions (slug, pack_id, category_id, game_mode, prompt, explanation, difficulty, duration_seconds, base_points, tags, status, source_id, fact_checked_at)
select v.slug, p.id, c.id, 'who_am_i', 'Who Am I?', v.explanation, v.difficulty, 45, 200, array['kenya','icons','who_am_i'], 'approved', s.id, now()
from (values
  ('eliud_kipchoge_identity', 'Eliud Kipchoge', 'A Kenyan distance runner and Olympic marathon champion, known for being the first person to run a marathon in under two hours in a special event.', 2),
  ('lupita_nyongo_identity', 'Lupita Nyong''o', 'A Kenyan-Mexican actor who won an Academy Award for her role in 12 Years a Slave.', 2),
  ('faith_kipyegon_identity', 'Faith Kipyegon', 'A Kenyan middle- and long-distance runner, multiple Olympic champion and world-record holder.', 2),
  ('david_rudisha_identity', 'David Rudisha', 'A Kenyan 800-metre runner and Olympic champion who holds the men''s world record in the event.', 3),
  ('mekatilili_wa_menza_identity', 'Mekatilili wa Menza', 'A Giriama leader remembered for resisting British colonial rule at the Kenyan coast.', 4),
  ('dedan_kimathi_identity', 'Dedan Kimathi', 'A leading figure of the Mau Mau uprising during Kenya''s struggle for independence.', 3),
  ('ferdinand_omanyala_identity', 'Ferdinand Omanyala', 'A Kenyan sprinter known for holding the African men''s 100-metre record.', 3),
  ('joy_adamson_identity', 'Joy Adamson', 'A conservationist and author associated with Elsa the lioness and Born Free.', 4),
  ('mwai_kibaki_identity', 'Mwai Kibaki', 'Kenya''s third President, serving from 2002 to 2013.', 3)
) as v(slug, identity_name, explanation, difficulty)
join public.content_packs p on p.code = 'kenya_core'
join public.categories c on c.code = 'kenyan_culture'
join public.question_sources s on s.source_key = 'editorial'
on conflict (slug) do update set
  explanation = excluded.explanation, difficulty = excluded.difficulty,
  duration_seconds = excluded.duration_seconds, base_points = excluded.base_points,
  status = excluded.status, fact_checked_at = excluded.fact_checked_at, updated_at = now();

insert into public.question_options (question_id, position, option_text, is_correct)
select q.id, v.position, v.option_text, v.is_correct
from (values
  ('eliud_kipchoge_identity', 1, 'Eliud Kipchoge', true), ('eliud_kipchoge_identity', 2, 'David Rudisha', false), ('eliud_kipchoge_identity', 3, 'Ferdinand Omanyala', false), ('eliud_kipchoge_identity', 4, 'Victor Wanyama', false),
  ('lupita_nyongo_identity', 1, 'Lupita Nyong''o', true), ('lupita_nyongo_identity', 2, 'Brenda Wanga', false), ('lupita_nyongo_identity', 3, 'Wangari Maathai', false), ('lupita_nyongo_identity', 4, 'Joy Adamson', false),
  ('faith_kipyegon_identity', 1, 'Faith Kipyegon', true), ('faith_kipyegon_identity', 2, 'Hellen Obiri', false), ('faith_kipyegon_identity', 3, 'Lupita Nyong''o', false), ('faith_kipyegon_identity', 4, 'Tegla Loroupe', false),
  ('david_rudisha_identity', 1, 'David Rudisha', true), ('david_rudisha_identity', 2, 'Eliud Kipchoge', false), ('david_rudisha_identity', 3, 'Ferdinand Omanyala', false), ('david_rudisha_identity', 4, 'Kipchoge Keino', false),
  ('mekatilili_wa_menza_identity', 1, 'Mekatilili wa Menza', true), ('mekatilili_wa_menza_identity', 2, 'Wangari Maathai', false), ('mekatilili_wa_menza_identity', 3, 'Joy Adamson', false), ('mekatilili_wa_menza_identity', 4, 'Martha Karua', false),
  ('dedan_kimathi_identity', 1, 'Dedan Kimathi', true), ('dedan_kimathi_identity', 2, 'Jomo Kenyatta', false), ('dedan_kimathi_identity', 3, 'Mwai Kibaki', false), ('dedan_kimathi_identity', 4, 'Tom Mboya', false),
  ('ferdinand_omanyala_identity', 1, 'Ferdinand Omanyala', true), ('ferdinand_omanyala_identity', 2, 'David Rudisha', false), ('ferdinand_omanyala_identity', 3, 'Eliud Kipchoge', false), ('ferdinand_omanyala_identity', 4, 'Victor Wanyama', false),
  ('joy_adamson_identity', 1, 'Joy Adamson', true), ('joy_adamson_identity', 2, 'Dian Fossey', false), ('joy_adamson_identity', 3, 'Wangari Maathai', false), ('joy_adamson_identity', 4, 'Mekatilili wa Menza', false),
  ('mwai_kibaki_identity', 1, 'Mwai Kibaki', true), ('mwai_kibaki_identity', 2, 'Jomo Kenyatta', false), ('mwai_kibaki_identity', 3, 'Daniel arap Moi', false), ('mwai_kibaki_identity', 4, 'Uhuru Kenyatta', false)
) as v(question_slug, position, option_text, is_correct)
join public.questions q on q.slug = v.question_slug
on conflict (question_id, position) do update set option_text = excluded.option_text, is_correct = excluded.is_correct;

update public.questions q
set media_id = m.id, updated_at = now()
from public.media_assets m
where m.provider = 'game_mavelas'
  and m.asset_key = case q.slug
    when 'wangari_maathai' then 'wangari-maathai'
    when 'eliud_kipchoge_identity' then 'eliud-kipchoge'
    when 'lupita_nyongo_identity' then 'lupita-nyongo'
    when 'faith_kipyegon_identity' then 'faith-kipyegon'
    when 'david_rudisha_identity' then 'david-rudisha'
    when 'mekatilili_wa_menza_identity' then 'mekatilili-wa-menza'
    when 'dedan_kimathi_identity' then 'dedan-kimathi'
    when 'ferdinand_omanyala_identity' then 'ferdinand-omanyala'
    when 'joy_adamson_identity' then 'joy-adamson'
    when 'mwai_kibaki_identity' then 'mwai-kibaki'
  end;

update public.round_template_steps
set question_count = 10, seconds_per_question = 45
where template_id = (select id from public.round_templates where code = 'who_am_i_kenya')
  and position = 1;

create or replace function public.submit_who_am_i_guess(p_round_id uuid, p_guess text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_round record;
  v_correct_text text;
  v_is_correct boolean;
  v_points integer := 0;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if char_length(trim(coalesce(p_guess, ''))) < 2 then raise exception 'Enter a fuller guess'; end if;

  select gr.*, q.game_mode, q.base_points into v_round
  from public.game_rounds gr join public.questions q on q.id = gr.question_id
  where gr.id = p_round_id;
  if not found or v_round.game_mode <> 'who_am_i' then raise exception 'This is not a Who Am I round'; end if;
  if v_round.status <> 'open' then raise exception 'This round is closed'; end if;
  if v_round.active_player_id <> v_user then raise exception 'Only the active player can submit this guess'; end if;
  if exists (select 1 from public.player_answers where round_id = p_round_id and player_id = v_user) then raise exception 'Your final guess is already locked in'; end if;

  select option_text into v_correct_text from public.question_options
  where question_id = v_round.question_id and is_correct = true limit 1;
  v_is_correct := regexp_replace(lower(trim(p_guess)), '[^a-z0-9]+', '', 'g') = regexp_replace(lower(v_correct_text), '[^a-z0-9]+', '', 'g');
  if v_is_correct then v_points := v_round.base_points; end if;

  insert into public.player_answers (round_id, room_id, player_id, free_text_answer, is_correct, points_awarded)
  values (p_round_id, v_round.room_id, v_user, trim(p_guess), v_is_correct, v_points);

  if v_is_correct then
    update public.room_players set score = score + v_points
    where room_id = v_round.room_id and user_id = v_user;
    update public.game_rounds set status = 'revealed', closes_at = now() where id = p_round_id;
    update public.rooms set phase = 'revealed', state_version = state_version + 1, last_transition_at = now(), updated_at = now()
    where id = v_round.room_id;
  end if;

  return jsonb_build_object('correct', v_is_correct, 'points_awarded', v_points);
end;
$$;

revoke all on function public.submit_who_am_i_guess(uuid, text) from public, anon;
grant execute on function public.submit_who_am_i_guess(uuid, text) to authenticated;

-- Keep the identity private from the active player, and never expose it to the public TV RPC.
create or replace function public.get_player_game_state(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid(); v_room record; v_round record; v_question record; v_answer record;
  v_host_name text; v_active_name text; v_secret text; v_score integer := 0; v_total integer := 0; v_answered integer := 0;
  v_correct_id uuid; v_result jsonb;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  select * into v_room from public.rooms where id = p_room_id;
  if not found then raise exception 'Room not found'; end if;
  if not exists (select 1 from public.room_players where room_id = p_room_id and user_id = v_user) then
    raise exception 'You are not a player in this room';
  end if;
  select score into v_score from public.room_players where room_id = p_room_id and user_id = v_user;
  select nickname into v_host_name from public.room_players where room_id = p_room_id and user_id = v_room.host_id;
  select count(*) into v_total from public.game_rounds where room_id = p_room_id;
  select gr.* into v_round from public.game_rounds gr
  where gr.room_id = p_room_id and gr.status in ('open', 'revealed') order by gr.position limit 1;

  if v_round.id is not null then
    select q.*, m.asset_type as media_type, m.public_url as media_url, m.alt_text as media_alt into v_question
    from public.questions q left join public.media_assets m on m.id = q.media_id where q.id = v_round.question_id;
    select * into v_answer from public.player_answers where round_id = v_round.id and player_id = v_user;
    select count(*) into v_answered from public.player_answers where round_id = v_round.id;
    select nickname into v_active_name from public.room_players where room_id = p_room_id and user_id = v_round.active_player_id;
    select option_text, id into v_secret, v_correct_id from public.question_options
    where question_id = v_question.id and is_correct = true limit 1;
  end if;

  v_result := jsonb_build_object(
    'room_id', v_room.id, 'room_code', v_room.code, 'status', v_room.status,
    'phase', coalesce(v_room.phase, v_room.status), 'is_host', v_room.host_id = v_user,
    'host_name', coalesce(v_host_name, 'Host'), 'selected_game', v_room.selected_game,
    'state_version', v_room.state_version, 'my_score', coalesce(v_score, 0),
    'total_players', (select count(*) from public.room_players where room_id = p_room_id),
    'answered_count', v_answered,
    'current_question', case when v_round.id is null then null else jsonb_build_object(
      'round_id', v_round.id, 'position', v_round.position, 'total_rounds', v_total,
      'prompt', case when v_question.game_mode = 'who_am_i' then
          case when v_round.active_player_id = v_user then 'You are the guesser. Ask the table yes-or-no questions.' else 'Help the guesser with fair yes-or-no clues.' end
        else v_question.prompt end,
      'game_mode', v_question.game_mode, 'duration_seconds', v_question.duration_seconds,
      'opens_at', v_round.opens_at, 'closes_at', v_round.closes_at,
      'active_player_name', v_active_name, 'is_active_player', v_round.active_player_id = v_user,
      'secret_identity', case when v_question.game_mode = 'who_am_i' and v_round.active_player_id <> v_user then v_secret else null end,
      'media', case
        when v_question.media_url is null then null
        when v_question.game_mode = 'who_am_i' and v_round.active_player_id = v_user and v_round.status <> 'revealed' then null
        else jsonb_build_object('type', v_question.media_type, 'url', v_question.media_url, 'alt', v_question.media_alt)
      end,
      'options', case when v_question.game_mode = 'who_am_i' then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('id', qo.id, 'text', qo.option_text) order by qo.position) from public.question_options qo where qo.question_id = v_question.id), '[]'::jsonb) end
    ) end,
    'my_answer', jsonb_build_object(
      'has_answered', v_answer.id is not null, 'selected_option_id', v_answer.selected_option_id,
      'is_revealed', coalesce(v_round.status = 'revealed', false),
      'is_correct', case when v_round.status = 'revealed' then v_answer.is_correct else null end,
      'points_awarded', case when v_round.status = 'revealed' then v_answer.points_awarded else null end,
      'correct_option_id', case when v_round.status = 'revealed' and v_question.game_mode <> 'who_am_i' then v_correct_id else null end,
      'explanation', case when v_round.status = 'revealed' then v_question.explanation else null end
    ),
    'leaderboard', coalesce((select jsonb_agg(jsonb_build_object('name', rp.nickname, 'score', rp.score, 'is_me', rp.user_id = v_user, 'is_host', rp.user_id = v_room.host_id) order by rp.score desc, rp.joined_at asc) from public.room_players rp where rp.room_id = p_room_id), '[]'::jsonb)
  );
  return v_result;
end;
$$;

create or replace function public.get_public_round_state(p_room_code text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'position', gr.position, 'game_mode', q.game_mode, 'duration_seconds', q.duration_seconds,
    'status', gr.status, 'opens_at', gr.opens_at, 'closes_at', gr.closes_at,
    'active_player_name', active_player.nickname,
    'prompt', case when q.game_mode = 'who_am_i' then 'The active player is discovering a secret identity.' else q.prompt end,
    'media', case when q.game_mode = 'who_am_i' or m.id is null then null else jsonb_build_object('type', m.asset_type, 'url', m.public_url, 'alt', m.alt_text) end,
    'options', case when q.game_mode = 'who_am_i' then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('label', chr(64 + qo.position), 'text', qo.option_text, 'is_correct', case when gr.status = 'revealed' then qo.is_correct else null end) order by qo.position) from public.question_options qo where qo.question_id = q.id), '[]'::jsonb) end,
    'correct_option', case when gr.status = 'revealed' then (select qo.option_text from public.question_options qo where qo.question_id = q.id and qo.is_correct = true limit 1) else null end,
    'explanation', case when gr.status = 'revealed' then q.explanation else null end
  )
  from public.rooms r
  join public.game_rounds gr on gr.id = r.current_round_id
  join public.questions q on q.id = gr.question_id
  left join public.room_players active_player on active_player.room_id = r.id and active_player.user_id = gr.active_player_id
  left join public.media_assets m on m.id = q.media_id
  where r.code = upper(trim(p_room_code)) and r.status = 'playing'
  limit 1;
$$;

revoke all on function public.get_player_game_state(uuid) from public, anon;
grant execute on function public.get_player_game_state(uuid) to authenticated;
revoke all on function public.get_public_round_state(text) from public;
grant execute on function public.get_public_round_state(text) to anon, authenticated;
