create schema if not exists private;
create table if not exists private.question_play_history(question_id uuid primary key references public.questions(id) on delete cascade,last_played_at timestamptz not null default now(),times_played integer not null default 1 check(times_played>0));
create index if not exists question_play_history_last_played_idx on private.question_play_history(last_played_at);

create or replace function public.submit_game_answer(p_round_id uuid,p_option_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_round public.game_rounds%rowtype;v_correct boolean;v_points integer:=0;v_player_count integer;v_answer_count integer;
begin
 if v_user is null then raise exception 'Sign in before answering'; end if;
 select * into v_round from public.game_rounds where id=p_round_id for update;
 if not found then raise exception 'Round not found'; end if;
 if v_round.status<>'open' then raise exception 'This round is not currently accepting answers'; end if;
 if v_round.closes_at is not null and now()>(v_round.closes_at+interval '2 seconds') then raise exception 'Time is up for this question'; end if;
 if not exists(select 1 from public.room_players rp where rp.room_id=v_round.room_id and rp.user_id=v_user and rp.role='player') then raise exception 'Only player controllers can answer this round'; end if;
 if exists(select 1 from public.player_answers where round_id=p_round_id and player_id=v_user) then raise exception 'You have already locked in your answer for this round'; end if;
 select qo.is_correct into v_correct from public.question_options qo where qo.id=p_option_id and qo.question_id=v_round.question_id;
 if v_correct is null then raise exception 'Selected option is invalid for this question'; end if;
 select case when v_correct then coalesce(q.base_points,100) else 0 end into v_points from public.questions q where q.id=v_round.question_id;
 insert into public.player_answers(round_id,room_id,player_id,selected_option_id,is_correct,points_awarded,answered_at) values(v_round.id,v_round.room_id,v_user,p_option_id,v_correct,v_points,now());
 select count(*) into v_player_count from public.room_players where room_id=v_round.room_id and role='player';
 select count(*) into v_answer_count from public.player_answers pa join public.room_players rp on rp.room_id=pa.room_id and rp.user_id=pa.player_id where pa.round_id=v_round.id and rp.role='player';
 if v_player_count>0 and v_answer_count>=v_player_count then
   update public.game_rounds set closes_at=now() where id=v_round.id;
   update public.rooms set phase='all_answered',round_ends_at=now(),state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=v_round.room_id and phase='playing';
 else update public.rooms set state_version=state_version+1,updated_at=now() where id=v_round.room_id; end if;
 return jsonb_build_object('accepted',true,'has_answered',true);
end; $$;

create or replace function public.start_game(p_room_id uuid,p_template_code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_template public.round_templates%rowtype;v_step public.round_template_steps%rowtype;v_question public.questions%rowtype;v_position smallint:=0;v_total integer:=0;v_first_round_id uuid:=null;v_first_duration smallint:=20;v_first_closes_at timestamptz:=null;
begin
 if v_user is null then raise exception 'Sign in before starting a game'; end if;
 if not exists(select 1 from public.rooms r where r.id=p_room_id and r.host_id=v_user and r.status in('lobby','results')) then raise exception 'Only the room host can start this lobby'; end if;
 select * into v_template from public.round_templates where code=p_template_code;if not found then raise exception 'Game template not found: %',p_template_code;end if;
 delete from public.player_answers where room_id=p_room_id; delete from public.game_rounds where room_id=p_room_id; update public.room_players set score=0 where room_id=p_room_id;
 for v_step in select * from public.round_template_steps where template_id=v_template.id order by position loop
  for v_question in select q.* from public.questions q left join private.question_play_history h on h.question_id=q.id where q.status='approved' and q.game_mode=v_template.game_mode and q.difficulty between v_step.difficulty_min and v_step.difficulty_max and (v_step.category_id is null or q.category_id=v_step.category_id) and not exists(select 1 from public.game_rounds gr where gr.room_id=p_room_id and gr.question_id=q.id) order by h.last_played_at nulls first,random() limit v_step.question_count loop
   v_position:=v_position+1;
   if v_position=1 then v_first_duration:=coalesce(v_question.duration_seconds,v_step.seconds_per_question,20);v_first_closes_at:=now()+(v_first_duration||' seconds')::interval;insert into public.game_rounds(room_id,template_id,question_id,position,status,opens_at,closes_at) values(p_room_id,v_template.id,v_question.id,v_position,'open',now(),v_first_closes_at)returning id into v_first_round_id;
   else insert into public.game_rounds(room_id,template_id,question_id,position,status,opens_at,closes_at) values(p_room_id,v_template.id,v_question.id,v_position,'pending',null,null);end if;
   insert into private.question_play_history(question_id,last_played_at,times_played) values(v_question.id,now(),1) on conflict(question_id) do update set last_played_at=excluded.last_played_at,times_played=private.question_play_history.times_played+1;v_total:=v_total+1;
  end loop;
 end loop;
 if v_total=0 then raise exception 'No approved questions match template %',p_template_code;end if;
 update public.rooms set selected_game=v_template.game_mode,game_title=v_template.title,status='playing',phase='playing',current_round_id=v_first_round_id,round_ends_at=v_first_closes_at,state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=p_room_id;
 return jsonb_build_object('room_id',p_room_id,'round_count',v_total,'game_mode',v_template.game_mode,'first_round_id',v_first_round_id,'closes_at',v_first_closes_at);
end; $$;

create or replace function public.get_public_room_state(p_room_code text) returns jsonb language sql security definer set search_path='' as $$
select jsonb_build_object('room_code',r.code,'status',r.status,'phase',coalesce(r.phase,r.status),'game_mode',r.selected_game,'game_title',r.game_title,'state_version',r.state_version,'round_ends_at',r.round_ends_at,'last_transition_at',r.last_transition_at,'total_players',(select count(*) from public.room_players rp where rp.room_id=r.id and rp.role='player'),'answered_count',(select count(*) from public.player_answers pa join public.room_players rp on rp.room_id=pa.room_id and rp.user_id=pa.player_id where pa.round_id=r.current_round_id and rp.role='player'),'players',coalesce((select jsonb_agg(jsonb_build_object('name',rp.nickname,'score',rp.score,'seat',rp.seat_no,'role',rp.role,'has_answered',exists(select 1 from public.player_answers pa where pa.round_id=r.current_round_id and pa.player_id=rp.user_id),'is_correct',case when exists(select 1 from public.game_rounds gr where gr.id=r.current_round_id and gr.status='revealed') then coalesce((select pa.is_correct from public.player_answers pa where pa.round_id=r.current_round_id and pa.player_id=rp.user_id),false) else null end,'points_awarded',case when exists(select 1 from public.game_rounds gr where gr.id=r.current_round_id and gr.status='revealed') then coalesce((select pa.points_awarded from public.player_answers pa where pa.round_id=r.current_round_id and pa.player_id=rp.user_id),0) else null end) order by rp.score desc,rp.joined_at asc) from public.room_players rp where rp.room_id=r.id and rp.role<>'spectator'),'[]'::jsonb)) from public.rooms r where r.code=upper(trim(p_room_code)); $$;
revoke all on function public.submit_game_answer(uuid,uuid),public.start_game(uuid,text) from public,anon; grant execute on function public.submit_game_answer(uuid,uuid),public.start_game(uuid,text) to authenticated;
revoke all on function public.get_public_room_state(text) from public;grant execute on function public.get_public_room_state(text) to anon,authenticated;