-- Scores are applied only at reveal so correctness stays secret until the celebration.
create or replace function public.submit_game_answer(p_round_id uuid,p_option_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_round public.game_rounds%rowtype;v_correct boolean;v_points integer:=0;v_player_count integer;v_answer_count integer;
begin
 if v_user is null then raise exception 'Sign in before answering'; end if; select * into v_round from public.game_rounds where id=p_round_id for update;if not found then raise exception 'Round not found';end if;if v_round.status<>'open' then raise exception 'This round is not currently accepting answers';end if;if v_round.closes_at is not null and now()>(v_round.closes_at+interval '2 seconds') then raise exception 'Time is up for this question';end if;
 if not exists(select 1 from public.room_players rp where rp.room_id=v_round.room_id and rp.user_id=v_user and rp.role='player') then raise exception 'Only player controllers can answer this round';end if;
 if exists(select 1 from public.player_answers where round_id=p_round_id and player_id=v_user) then raise exception 'You have already locked in your answer for this round';end if;
 select qo.is_correct into v_correct from public.question_options qo where qo.id=p_option_id and qo.question_id=v_round.question_id;if v_correct is null then raise exception 'Selected option is invalid for this question';end if;
 select case when v_correct then coalesce(q.base_points,100) else 0 end into v_points from public.questions q where q.id=v_round.question_id;
 insert into public.player_answers(round_id,room_id,player_id,selected_option_id,is_correct,points_awarded,answered_at) values(v_round.id,v_round.room_id,v_user,p_option_id,v_correct,v_points,now());
 select count(*) into v_player_count from public.room_players where room_id=v_round.room_id and role='player'; select count(*) into v_answer_count from public.player_answers pa join public.room_players rp on rp.room_id=pa.room_id and rp.user_id=pa.player_id where pa.round_id=v_round.id and rp.role='player';
 if v_player_count>0 and v_answer_count>=v_player_count then update public.game_rounds set closes_at=now() where id=v_round.id;update public.rooms set phase='all_answered',round_ends_at=now(),state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=v_round.room_id and phase='playing';else update public.rooms set state_version=state_version+1,updated_at=now() where id=v_round.room_id;end if;return jsonb_build_object('accepted',true,'has_answered',true);
end; $$;
create or replace function public.host_reveal_round(p_room_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_round_id uuid;
begin
 if v_user is null then raise exception 'Sign in required';end if;if not exists(select 1 from public.rooms r where r.id=p_room_id and r.host_id=v_user and r.status='playing') then raise exception 'Only the room host can reveal this round';end if;
 select id into v_round_id from public.game_rounds where room_id=p_room_id and status='open' order by position limit 1 for update;if v_round_id is null then raise exception 'There is no open round to reveal';end if;
 update public.game_rounds set status='revealed',closes_at=coalesce(closes_at,now()) where id=v_round_id;
 update public.room_players rp set score=rp.score+pa.points_awarded from public.player_answers pa where pa.round_id=v_round_id and pa.player_id=rp.user_id and pa.room_id=rp.room_id and pa.is_correct;
 update public.rooms set phase='revealed',state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=p_room_id;return jsonb_build_object('revealed',true,'round_id',v_round_id);
end; $$;
revoke all on function public.host_reveal_round(uuid) from public,anon;grant execute on function public.host_reveal_round(uuid) to authenticated;