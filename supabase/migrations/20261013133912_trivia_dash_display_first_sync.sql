-- Give the shared display a deterministic four-second head start on every
-- Trivia Dash question without changing the 25-second answer duration.
--
-- Keep the proven gameplay implementations private, then wrap their three
-- public entry points. Because each wrapper and its implementation run in one
-- transaction, clients can only observe the final scheduled timestamps.

alter function public.start_trivia_dash(uuid) set schema private;
alter function private.start_trivia_dash(uuid) rename to start_trivia_dash_immediate;
revoke all on function private.start_trivia_dash_immediate(uuid) from public, anon, authenticated;

create function public.start_trivia_dash(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_round_id uuid;
  v_opens_at timestamptz;
  v_closes_at timestamptz;
begin
  v_result := private.start_trivia_dash_immediate(p_room_id);
  v_round_id := (v_result ->> 'first_round_id')::uuid;
  v_opens_at := clock_timestamp() + interval '4 seconds';
  v_closes_at := v_opens_at + interval '25 seconds';

  update public.game_rounds
  set opens_at = v_opens_at,
      closes_at = v_closes_at
  where id = v_round_id
    and room_id = p_room_id
    and status = 'open';

  if not found then
    raise exception 'Trivia Dash could not prepare the first display-first answer window';
  end if;

  update public.rooms
  set round_ends_at = v_closes_at,
      state = coalesce(state, '{}'::jsonb) || jsonb_build_object(
        'display_lead_seconds', 4,
        'answer_unlocks_at', v_opens_at
      ),
      updated_at = now()
  where id = p_room_id
    and current_round_id = v_round_id
    and status = 'playing';

  return (v_result - 'closes_at') || jsonb_build_object(
    'opens_at', v_opens_at,
    'closes_at', v_closes_at,
    'display_lead_seconds', 4
  );
end;
$$;

revoke all on function public.start_trivia_dash(uuid) from public, anon;
grant execute on function public.start_trivia_dash(uuid) to authenticated;

alter function public.advance_trivia_dash_round(uuid) set schema private;
alter function private.advance_trivia_dash_round(uuid) rename to advance_trivia_dash_round_immediate;
revoke all on function private.advance_trivia_dash_round_immediate(uuid) from public, anon, authenticated;

create function public.advance_trivia_dash_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_round_id uuid;
  v_opens_at timestamptz;
  v_closes_at timestamptz;
begin
  v_result := private.advance_trivia_dash_round_immediate(p_room_id);

  if coalesce((v_result ->> 'finished')::boolean, false) then
    return v_result;
  end if;

  v_round_id := (v_result ->> 'round_id')::uuid;
  v_opens_at := clock_timestamp() + interval '4 seconds';
  v_closes_at := v_opens_at + interval '25 seconds';

  update public.game_rounds
  set opens_at = v_opens_at,
      closes_at = v_closes_at
  where id = v_round_id
    and room_id = p_room_id
    and status = 'open';

  if not found then
    raise exception 'Trivia Dash could not prepare the next display-first answer window';
  end if;

  update public.rooms
  set round_ends_at = v_closes_at,
      state = coalesce(state, '{}'::jsonb) || jsonb_build_object(
        'display_lead_seconds', 4,
        'answer_unlocks_at', v_opens_at
      ),
      updated_at = now()
  where id = p_room_id
    and current_round_id = v_round_id
    and status = 'playing';

  return (v_result - 'closes_at') || jsonb_build_object(
    'opens_at', v_opens_at,
    'closes_at', v_closes_at,
    'display_lead_seconds', 4
  );
end;
$$;

revoke all on function public.advance_trivia_dash_round(uuid) from public, anon;
grant execute on function public.advance_trivia_dash_round(uuid) to authenticated;

alter function public.submit_trivia_dash_answer(uuid, uuid) set schema private;
alter function private.submit_trivia_dash_answer(uuid, uuid) rename to submit_trivia_dash_answer_unlocked;
revoke all on function private.submit_trivia_dash_answer_unlocked(uuid, uuid) from public, anon, authenticated;

create function public.submit_trivia_dash_answer(
  p_round_id uuid,
  p_option_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_opens_at timestamptz;
begin
  select round.opens_at
  into v_opens_at
  from public.game_rounds round
  where round.id = p_round_id
  for update;

  if not found then
    raise exception 'Round not found';
  end if;

  if v_opens_at is not null and clock_timestamp() < v_opens_at then
    raise exception 'Answer pads are still locked while the question appears on the shared display';
  end if;

  return private.submit_trivia_dash_answer_unlocked(p_round_id, p_option_id);
end;
$$;

revoke all on function public.submit_trivia_dash_answer(uuid, uuid) from public, anon;
grant execute on function public.submit_trivia_dash_answer(uuid, uuid) to authenticated;
