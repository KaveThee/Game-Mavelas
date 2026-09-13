-- Phase 3.1: Explicit Three-Surface Architecture Migration
-- Functions accepting room code, host verification, and server authority.

create or replace function public.get_host_game_state(p_room_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room record;
  v_round record;
  v_question record;
  v_total_players integer := 0;
  v_answered_count integer := 0;
  v_total_rounds integer := 0;
  v_is_host boolean;
begin
  if v_user is null then
    return jsonb_build_object('is_host', false, 'error', 'Sign in required');
  end if;

  select * into v_room from public.rooms
  where code = upper(trim(p_room_code));
  if not found then
    return jsonb_build_object('is_host', false, 'error', 'Room not found');
  end if;

  v_is_host := (v_room.host_id = v_user);
  if not v_is_host then
    return jsonb_build_object(
      'is_host', false,
      'room_code', v_room.code,
      'status', v_room.status,
      'error', 'Unauthorized: caller is not the room host'
    );
  end if;

  select count(*) into v_total_players from public.room_players
  where room_id = v_room.id;

  select count(*) into v_total_rounds from public.game_rounds
  where room_id = v_room.id;

  select gr.* into v_round from public.game_rounds gr
  where gr.room_id = v_room.id and gr.status in ('open', 'revealed')
  order by gr.position limit 1;

  if v_round.id is not null then
    select q.*, m.asset_type as media_type, m.public_url as media_url, m.alt_text as media_alt
    into v_question
    from public.questions q
    left join public.media_assets m on m.id = q.media_id
    where q.id = v_round.question_id;

    select count(*) into v_answered_count from public.player_answers
    where round_id = v_round.id;
  end if;

  return jsonb_build_object(
    'is_host', true,
    'room_id', v_room.id,
    'room_code', v_room.code,
    'status', v_room.status,
    'phase', coalesce(v_room.phase, v_room.status),
    'selected_game', v_room.selected_game,
    'game_title', v_room.game_title,
    'state_version', v_room.state_version,
    'round_ends_at', v_room.round_ends_at,
    'total_players', v_total_players,
    'answered_count', v_answered_count,
    'current_round', case when v_round.id is null then null else jsonb_build_object(
      'round_id', v_round.id,
      'position', v_round.position,
      'total_rounds', v_total_rounds,
      'prompt', v_question.prompt,
      'game_mode', v_question.game_mode,
      'duration_seconds', v_question.duration_seconds,
      'opens_at', v_round.opens_at,
      'closes_at', v_round.closes_at,
      'status', v_round.status,
      'explanation', case when v_round.status = 'revealed' then v_question.explanation else null end,
      'correct_option', case when v_round.status = 'revealed' then (
        select qo.option_text from public.question_options qo
        where qo.question_id = v_question.id and qo.is_correct = true limit 1
      ) else null end,
      'media', case when v_question.media_url is null then null else jsonb_build_object(
        'type', v_question.media_type,
        'url', v_question.media_url,
        'alt', v_question.media_alt
      ) end,
      'options', coalesce((
        select jsonb_agg(jsonb_build_object('id', qo.id, 'text', qo.option_text) order by qo.position)
        from public.question_options qo where qo.question_id = v_question.id
      ), '[]'::jsonb)
    ) end,
    'players', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', rp.nickname,
        'score', rp.score,
        'role', rp.role,
        'has_answered', exists(
          select 1 from public.player_answers pa
          where pa.round_id = v_round.id and pa.player_id = rp.user_id
        )
      ) order by rp.score desc, rp.joined_at asc)
      from public.room_players rp
      where rp.room_id = v_room.id
    ), '[]'::jsonb)
  );
end;
$$;

-- Overload host actions to accept room code for clean routing
create or replace function public.host_start_game(p_room_code text, p_template_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
begin
  select id into v_room_id from public.rooms
  where code = upper(trim(p_room_code));
  if not found then raise exception 'Room not found: %', p_room_code; end if;

  return public.start_game(v_room_id, p_template_code);
end;
$$;

create or replace function public.host_reveal_round(p_room_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
begin
  select id into v_room_id from public.rooms
  where code = upper(trim(p_room_code));
  if not found then raise exception 'Room not found: %', p_room_code; end if;

  return public.host_reveal_round(v_room_id);
end;
$$;

create or replace function public.host_advance_round(p_room_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
begin
  select id into v_room_id from public.rooms
  where code = upper(trim(p_room_code));
  if not found then raise exception 'Room not found: %', p_room_code; end if;

  return public.host_advance_round(v_room_id);
end;
$$;

create or replace function public.host_end_game(p_room_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
begin
  select id into v_room_id from public.rooms
  where code = upper(trim(p_room_code));
  if not found then raise exception 'Room not found: %', p_room_code; end if;

  return public.host_end_game(v_room_id);
end;
$$;

-- Overload get_player_game_state to accept room code
create or replace function public.get_player_game_state(p_room_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
begin
  select id into v_room_id from public.rooms
  where code = upper(trim(p_room_code));
  if not found then raise exception 'Room not found: %', p_room_code; end if;

  return public.get_player_game_state(v_room_id);
end;
$$;

-- Grants
grant execute on function public.get_host_game_state(text) to authenticated;
grant execute on function public.host_start_game(text, text) to authenticated;
grant execute on function public.host_reveal_round(text) to authenticated;
grant execute on function public.host_advance_round(text) to authenticated;
grant execute on function public.host_end_game(text) to authenticated;
grant execute on function public.get_player_game_state(text) to authenticated;
