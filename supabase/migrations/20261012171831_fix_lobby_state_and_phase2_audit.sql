-- Phase 2 production audit: make lobby state readable before a round exists.
--
-- Generic PL/pgSQL records have no tuple shape until a query assigns them.
-- The previous function read v_round.id in a fresh lobby, raising SQLSTATE
-- 55000 and leaving new host controllers stuck on the home screen. Typed
-- row variables have a known shape and safely expose null fields in a lobby.

create or replace function public.get_player_game_state(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_room public.rooms%rowtype;
  v_round public.game_rounds%rowtype;
  v_question public.questions%rowtype;
  v_answer public.player_answers%rowtype;
  v_host_name text;
  v_active_name text;
  v_secret text;
  v_media_type text;
  v_media_url text;
  v_media_alt text;
  v_score integer := 0;
  v_total integer := 0;
  v_answered integer := 0;
  v_correct_id uuid;
  v_result jsonb;
begin
  if v_user is null then
    raise exception 'Sign in required';
  end if;

  select * into v_room from public.rooms where id = p_room_id;
  if not found then
    raise exception 'Room not found';
  end if;

  if not exists (
    select 1 from public.room_players
    where room_id = p_room_id and user_id = v_user
  ) then
    raise exception 'You are not a player in this room';
  end if;

  select score into v_score
  from public.room_players
  where room_id = p_room_id and user_id = v_user;

  select nickname into v_host_name
  from public.room_players
  where room_id = p_room_id and user_id = v_room.host_id;

  select count(*) into v_total
  from public.game_rounds
  where room_id = p_room_id;

  select gr.* into v_round
  from public.game_rounds gr
  where gr.room_id = p_room_id and gr.status in ('open', 'revealed')
  order by gr.position
  limit 1;

  if v_round.id is not null then
    select q.* into v_question
    from public.questions q
    where q.id = v_round.question_id;

    select m.asset_type, m.public_url, m.alt_text
    into v_media_type, v_media_url, v_media_alt
    from public.media_assets m
    where m.id = v_question.media_id;

    select * into v_answer
    from public.player_answers
    where round_id = v_round.id and player_id = v_user;

    select count(*) into v_answered
    from public.player_answers
    where round_id = v_round.id;

    select nickname into v_active_name
    from public.room_players
    where room_id = p_room_id and user_id = v_round.active_player_id;

    select option_text, id into v_secret, v_correct_id
    from public.question_options
    where question_id = v_question.id and is_correct = true
    limit 1;
  end if;

  v_result := jsonb_build_object(
    'room_id', v_room.id,
    'room_code', v_room.code,
    'status', v_room.status,
    'phase', coalesce(v_room.phase, v_room.status),
    'is_host', v_room.host_id = v_user,
    'host_name', coalesce(v_host_name, 'Host'),
    'selected_game', v_room.selected_game,
    'state_version', v_room.state_version,
    'my_score', coalesce(v_score, 0),
    'total_players', (
      select count(*) from public.room_players where room_id = p_room_id
    ),
    'answered_count', v_answered,
    'current_question', case when v_round.id is null then null else jsonb_build_object(
      'round_id', v_round.id,
      'position', v_round.position,
      'total_rounds', v_total,
      'prompt', case when v_question.game_mode = 'who_am_i' then
        case when v_round.active_player_id = v_user
          then 'You are the guesser. Ask the table yes-or-no questions.'
          else 'Help the guesser with fair yes-or-no clues.'
        end
      else v_question.prompt end,
      'game_mode', v_question.game_mode,
      'duration_seconds', v_question.duration_seconds,
      'opens_at', v_round.opens_at,
      'closes_at', v_round.closes_at,
      'active_player_name', v_active_name,
      'is_active_player', v_round.active_player_id = v_user,
      'secret_identity', case
        when v_question.game_mode = 'who_am_i' and v_round.active_player_id <> v_user then v_secret
        else null
      end,
      'media', case
        when v_media_url is null then null
        when v_question.game_mode = 'who_am_i'
          and v_round.active_player_id = v_user
          and v_round.status <> 'revealed' then null
        else jsonb_build_object('type', v_media_type, 'url', v_media_url, 'alt', v_media_alt)
      end,
      'options', case when v_question.game_mode = 'who_am_i' then '[]'::jsonb else coalesce((
        select jsonb_agg(
          jsonb_build_object('id', qo.id, 'text', qo.option_text)
          order by coalesce(ro.position, qo.position)
        )
        from public.question_options qo
        left join public.round_option_orders ro
          on ro.round_id = v_round.id and ro.option_id = qo.id
        where qo.question_id = v_question.id
      ), '[]'::jsonb) end
    ) end,
    'my_answer', jsonb_build_object(
      'has_answered', v_answer.id is not null,
      'selected_option_id', v_answer.selected_option_id,
      'is_revealed', coalesce(v_round.status = 'revealed', false),
      'is_correct', case when v_round.status = 'revealed' then v_answer.is_correct else null end,
      'points_awarded', case when v_round.status = 'revealed' then v_answer.points_awarded else null end,
      'correct_option_id', case
        when v_round.status = 'revealed' and v_question.game_mode <> 'who_am_i' then v_correct_id
        else null
      end,
      'explanation', case when v_round.status = 'revealed' then v_question.explanation else null end
    ),
    'leaderboard', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', rp.nickname,
          'score', rp.score,
          'is_me', rp.user_id = v_user,
          'is_host', rp.user_id = v_room.host_id
        )
        order by rp.score desc, rp.joined_at asc
      )
      from public.room_players rp
      where rp.room_id = p_room_id
    ), '[]'::jsonb)
  );

  return v_result;
end;
$$;

revoke all on function public.get_player_game_state(uuid) from public, anon;
grant execute on function public.get_player_game_state(uuid) to authenticated;
