-- Clue Heist: one guess per player per clue, not one guess per mystery.
alter table public.clue_heist_attempts
  drop constraint if exists clue_heist_attempts_round_id_player_id_key;
alter table public.clue_heist_attempts
  add constraint clue_heist_attempts_round_player_clue_key unique(round_id,player_id,clue_number);

create or replace function public.submit_clue_heist_guess(p_round_id uuid,p_guess text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_round record; v_state record; v_correct boolean; v_steal boolean; v_value smallint; v_award smallint;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if char_length(trim(coalesce(p_guess,'')))<2 then raise exception 'Enter a fuller guess'; end if;
  select gr.*,q.game_mode into v_round from public.game_rounds gr join public.questions q on q.id=gr.question_id where gr.id=p_round_id for update of gr;
  if not found or v_round.game_mode<>'guess_image' then raise exception 'This is not a Clue Heist round'; end if;
  select * into v_state from public.clue_heist_rounds where round_id=p_round_id for update;
  if v_round.status<>'open' or v_state.turn_phase='revealed' then raise exception 'This mystery is closed'; end if;
  if not exists(select 1 from public.room_players where room_id=v_round.room_id and user_id=v_user) then raise exception 'You are not in this room'; end if;
  v_steal:=v_state.turn_phase='steal';
  if not v_steal and v_round.active_player_id<>v_user then raise exception 'The spotlight player has priority'; end if;
  if v_steal and v_round.active_player_id=v_user then raise exception 'The spotlight player cannot steal their own mystery'; end if;
  if exists(select 1 from public.clue_heist_attempts where round_id=p_round_id and player_id=v_user and clue_number=v_state.clue_number) then
    raise exception 'You already guessed on this clue';
  end if;
  select exists(select 1 from public.clue_heist_aliases a where a.question_id=v_round.question_id and public.normalize_clue_answer(a.answer_text)=public.normalize_clue_answer(p_guess)) into v_correct;
  v_value:=105-(v_state.clue_number*5);
  v_award:=case when v_correct then case when v_steal then ceil(v_value/2.0)::smallint else v_value end else 0 end;
  insert into public.clue_heist_attempts(round_id,player_id,clue_number,guess,is_correct,is_steal)
  values(p_round_id,v_user,v_state.clue_number,trim(p_guess),v_correct,v_steal);
  if v_correct then
    update public.clue_heist_rounds set turn_phase='revealed',winner_id=v_user,awarded_points=v_award,updated_at=now() where round_id=p_round_id;
    update public.room_players set score=score+v_award where room_id=v_round.room_id and user_id=v_user;
    update public.game_rounds set status='revealed',closes_at=now() where id=p_round_id;
    update public.rooms set phase='revealed',state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=v_round.room_id;
  elsif not v_steal then
    update public.clue_heist_rounds set turn_phase='steal',updated_at=now() where round_id=p_round_id;
    update public.rooms set state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=v_round.room_id;
  end if;
  return jsonb_build_object('correct',v_correct,'steal',v_steal,'points_awarded',v_award);
end; $$;

create or replace function public.get_clue_heist_state(p_round_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_round record; v_state record; v_answer text; v_winner text; v_attempted boolean;
begin
  select gr.*,q.explanation,m.public_url,m.alt_text into v_round
  from public.game_rounds gr join public.questions q on q.id=gr.question_id
  left join public.clue_heist_mysteries hm on hm.question_id=q.id left join public.media_assets m on m.id=hm.answer_media_id
  where gr.id=p_round_id;
  if not found then raise exception 'Round not found'; end if;
  if v_user is not null and not exists(select 1 from public.room_players where room_id=v_round.room_id and user_id=v_user) then raise exception 'You are not in this room'; end if;
  select * into v_state from public.clue_heist_rounds where round_id=p_round_id;
  select answer_text into v_answer from public.clue_heist_aliases where question_id=v_round.question_id order by length(answer_text) desc limit 1;
  select nickname into v_winner from public.room_players where room_id=v_round.room_id and user_id=v_state.winner_id;
  select exists(select 1 from public.clue_heist_attempts where round_id=p_round_id and player_id=v_user and clue_number=v_state.clue_number) into v_attempted;
  return jsonb_build_object(
    'clue_number',v_state.clue_number,'current_value',105-v_state.clue_number*5,'turn_phase',v_state.turn_phase,
    'active_player_id',v_round.active_player_id,'is_spotlight',v_user=v_round.active_player_id,'has_attempted',coalesce(v_attempted,false),
    'can_guess',case when v_state.turn_phase='spotlight' then v_user=v_round.active_player_id and not coalesce(v_attempted,false)
      when v_state.turn_phase='steal' then v_user<>v_round.active_player_id and not coalesce(v_attempted,false) else false end,
    'clues',coalesce((select jsonb_agg(jsonb_build_object('position',c.position,'text',c.clue_text) order by c.position) from public.clue_heist_clues c where c.question_id=v_round.question_id and c.position<=v_state.clue_number),'[]'::jsonb),
    'answer',case when v_state.turn_phase='revealed' then v_answer else null end,
    'image',case when v_state.turn_phase='revealed' and v_round.public_url is not null then jsonb_build_object('url',v_round.public_url,'alt',v_round.alt_text) else null end,
    'explanation',case when v_state.turn_phase='revealed' then v_round.explanation else null end,
    'winner_name',v_winner,'awarded_points',v_state.awarded_points);
end; $$;

-- Who Am I remains secret during play but gets its proper image on the TV reveal.
create or replace function public.get_public_round_state(p_room_code text)
returns jsonb language sql security definer set search_path='' as $$
select jsonb_build_object(
  'position',gr.position,'game_mode',q.game_mode,'duration_seconds',q.duration_seconds,'status',gr.status,
  'opens_at',gr.opens_at,'closes_at',gr.closes_at,'active_player_name',active_player.nickname,
  'prompt',case when q.game_mode='who_am_i' then 'The active player is discovering a secret identity.' else q.prompt end,
  'media',case when m.id is null or (q.game_mode='who_am_i' and gr.status<>'revealed') then null
    else jsonb_build_object('type',m.asset_type,'url',m.public_url,'alt',m.alt_text) end,
  'options',case when q.game_mode='who_am_i' then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object('label',chr(64+coalesce(ro.position,qo.position)),'text',qo.option_text,
      'is_correct',case when gr.status='revealed' then qo.is_correct else null end) order by coalesce(ro.position,qo.position))
    from public.question_options qo left join public.round_option_orders ro on ro.round_id=gr.id and ro.option_id=qo.id
    where qo.question_id=q.id),'[]'::jsonb) end,
  'correct_option',case when gr.status='revealed' then (select qo.option_text from public.question_options qo where qo.question_id=q.id and qo.is_correct=true limit 1) else null end,
  'explanation',case when gr.status='revealed' then q.explanation else null end)
from public.rooms r join public.game_rounds gr on gr.id=r.current_round_id join public.questions q on q.id=gr.question_id
left join public.room_players active_player on active_player.room_id=r.id and active_player.user_id=gr.active_player_id
left join public.media_assets m on m.id=q.media_id
where r.code=upper(trim(p_room_code)) and r.status='playing' limit 1;
$$;

revoke all on function public.submit_clue_heist_guess(uuid,text),public.get_clue_heist_state(uuid) from public,anon;
grant execute on function public.submit_clue_heist_guess(uuid,text),public.get_clue_heist_state(uuid) to authenticated;
revoke all on function public.get_public_round_state(text) from public;
grant execute on function public.get_public_round_state(text) to anon,authenticated;
