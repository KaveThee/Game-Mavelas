-- Per-round choice order, answer submission recovery, and 3-second auto reveal.

create table if not exists public.round_option_orders (
  round_id uuid not null references public.game_rounds(id) on delete cascade,
  option_id uuid not null references public.question_options(id) on delete cascade,
  position smallint not null check(position between 1 and 6),
  primary key(round_id,option_id), unique(round_id,position)
);
alter table public.round_option_orders enable row level security;
create index if not exists round_option_orders_round_idx on public.round_option_orders(round_id,position);

CREATE OR REPLACE FUNCTION public.auto_reveal_round(p_room_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user uuid:=auth.uid();v_round_id uuid;
begin
 if v_user is null or not exists(select 1 from public.room_players where room_id=p_room_id and user_id=v_user) then raise exception 'You are not in this room';end if;
 if exists(select 1 from public.rooms where id=p_room_id and phase='revealed') then return jsonb_build_object('revealed',true,'already_revealed',true);end if;
 if not exists(select 1 from public.rooms where id=p_room_id and status='playing' and phase='all_answered' and last_transition_at<=now()-interval '3 seconds') then raise exception 'Reveal is not ready';end if;
 select id into v_round_id from public.game_rounds where room_id=p_room_id and status='open' order by position limit 1 for update;if v_round_id is null then raise exception 'Round is no longer open';end if;
 update public.game_rounds set status='revealed',closes_at=coalesce(closes_at,now()) where id=v_round_id;
 update public.room_players rp set score=rp.score+pa.points_awarded from public.player_answers pa where pa.round_id=v_round_id and pa.player_id=rp.user_id and pa.room_id=rp.room_id and pa.is_correct;
 update public.rooms set phase='revealed',state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=p_room_id;
 return jsonb_build_object('revealed',true,'round_id',v_round_id);
end; $function$


CREATE OR REPLACE FUNCTION public.get_player_game_state(p_room_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user uuid:=auth.uid();v_room record;v_round record;v_question record;v_answer record;v_host_name text;v_active_name text;v_secret text;v_score integer:=0;v_total integer:=0;v_answered integer:=0;v_correct_id uuid;v_result jsonb;
begin
 if v_user is null then raise exception 'Sign in required';end if;select * into v_room from public.rooms where id=p_room_id;if not found then raise exception 'Room not found';end if;if not exists(select 1 from public.room_players where room_id=p_room_id and user_id=v_user) then raise exception 'You are not a player in this room';end if;
 select score into v_score from public.room_players where room_id=p_room_id and user_id=v_user;select nickname into v_host_name from public.room_players where room_id=p_room_id and user_id=v_room.host_id;select count(*) into v_total from public.game_rounds where room_id=p_room_id;select gr.* into v_round from public.game_rounds gr where gr.room_id=p_room_id and gr.status in('open','revealed') order by gr.position limit 1;
 if v_round.id is not null then select q.*,m.asset_type media_type,m.public_url media_url,m.alt_text media_alt into v_question from public.questions q left join public.media_assets m on m.id=q.media_id where q.id=v_round.question_id;select * into v_answer from public.player_answers where round_id=v_round.id and player_id=v_user;select count(*) into v_answered from public.player_answers where round_id=v_round.id;select nickname into v_active_name from public.room_players where room_id=p_room_id and user_id=v_round.active_player_id;select option_text,id into v_secret,v_correct_id from public.question_options where question_id=v_question.id and is_correct=true limit 1;end if;
 v_result:=jsonb_build_object('room_id',v_room.id,'room_code',v_room.code,'status',v_room.status,'phase',coalesce(v_room.phase,v_room.status),'is_host',v_room.host_id=v_user,'host_name',coalesce(v_host_name,'Host'),'selected_game',v_room.selected_game,'state_version',v_room.state_version,'my_score',coalesce(v_score,0),'total_players',(select count(*) from public.room_players where room_id=p_room_id),'answered_count',v_answered,'current_question',case when v_round.id is null then null else jsonb_build_object('round_id',v_round.id,'position',v_round.position,'total_rounds',v_total,'prompt',case when v_question.game_mode='who_am_i' then case when v_round.active_player_id=v_user then 'You are the guesser. Ask the table yes-or-no questions.' else 'Help the guesser with fair yes-or-no clues.' end else v_question.prompt end,'game_mode',v_question.game_mode,'duration_seconds',v_question.duration_seconds,'opens_at',v_round.opens_at,'closes_at',v_round.closes_at,'active_player_name',v_active_name,'is_active_player',v_round.active_player_id=v_user,'secret_identity',case when v_question.game_mode='who_am_i' and v_round.active_player_id<>v_user then v_secret else null end,'media',case when v_question.media_url is null then null when v_question.game_mode='who_am_i' and v_round.active_player_id=v_user and v_round.status<>'revealed' then null else jsonb_build_object('type',v_question.media_type,'url',v_question.media_url,'alt',v_question.media_alt) end,'options',case when v_question.game_mode='who_am_i' then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('id',qo.id,'text',qo.option_text) order by coalesce(ro.position,qo.position)) from public.question_options qo left join public.round_option_orders ro on ro.round_id=v_round.id and ro.option_id=qo.id where qo.question_id=v_question.id),'[]'::jsonb) end) end,'my_answer',jsonb_build_object('has_answered',v_answer.id is not null,'selected_option_id',v_answer.selected_option_id,'is_revealed',coalesce(v_round.status='revealed',false),'is_correct',case when v_round.status='revealed' then v_answer.is_correct else null end,'points_awarded',case when v_round.status='revealed' then v_answer.points_awarded else null end,'correct_option_id',case when v_round.status='revealed' and v_question.game_mode<>'who_am_i' then v_correct_id else null end,'explanation',case when v_round.status='revealed' then v_question.explanation else null end),'leaderboard',coalesce((select jsonb_agg(jsonb_build_object('name',rp.nickname,'score',rp.score,'is_me',rp.user_id=v_user,'is_host',rp.user_id=v_room.host_id) order by rp.score desc,rp.joined_at asc) from public.room_players rp where rp.room_id=p_room_id),'[]'::jsonb));return v_result;
end; $function$


CREATE OR REPLACE FUNCTION public.get_public_round_state(p_room_code text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
select jsonb_build_object('position',gr.position,'game_mode',q.game_mode,'duration_seconds',q.duration_seconds,'status',gr.status,'opens_at',gr.opens_at,'closes_at',gr.closes_at,'active_player_name',active_player.nickname,'prompt',case when q.game_mode='who_am_i' then 'The active player is discovering a secret identity.' else q.prompt end,'media',case when q.game_mode='who_am_i' or m.id is null then null else jsonb_build_object('type',m.asset_type,'url',m.public_url,'alt',m.alt_text) end,'options',case when q.game_mode='who_am_i' then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('label',chr(64+coalesce(ro.position,qo.position)),'text',qo.option_text,'is_correct',case when gr.status='revealed' then qo.is_correct else null end) order by coalesce(ro.position,qo.position)) from public.question_options qo left join public.round_option_orders ro on ro.round_id=gr.id and ro.option_id=qo.id where qo.question_id=q.id),'[]'::jsonb) end,'correct_option',case when gr.status='revealed' then (select qo.option_text from public.question_options qo where qo.question_id=q.id and qo.is_correct=true limit 1) else null end,'explanation',case when gr.status='revealed' then q.explanation else null end) from public.rooms r join public.game_rounds gr on gr.id=r.current_round_id join public.questions q on q.id=gr.question_id left join public.room_players active_player on active_player.room_id=r.id and active_player.user_id=gr.active_player_id left join public.media_assets m on m.id=q.media_id where r.code=upper(trim(p_room_code)) and r.status='playing' limit 1; $function$


CREATE OR REPLACE FUNCTION public.start_game(p_room_id uuid, p_template_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user uuid:=auth.uid();v_template public.round_templates%rowtype;v_step public.round_template_steps%rowtype;v_question public.questions%rowtype;v_position smallint:=0;v_total integer:=0;v_first_round_id uuid:=null;v_round_id uuid;v_first_duration smallint:=20;v_first_closes_at timestamptz:=null;
begin
 if v_user is null then raise exception 'Sign in before starting a game';end if;
 if not exists(select 1 from public.rooms r where r.id=p_room_id and r.host_id=v_user and r.status in('lobby','results')) then raise exception 'Only the room host can start this lobby';end if;
 select * into v_template from public.round_templates where code=p_template_code;if not found then raise exception 'Game template not found: %',p_template_code;end if;
 delete from public.player_answers where room_id=p_room_id;delete from public.game_rounds where room_id=p_room_id;update public.room_players set score=0 where room_id=p_room_id;
 for v_step in select * from public.round_template_steps where template_id=v_template.id order by position loop
  for v_question in select q.* from public.questions q left join private.question_play_history h on h.question_id=q.id where q.status='approved' and q.game_mode=v_template.game_mode and q.difficulty between v_step.difficulty_min and v_step.difficulty_max and (v_step.category_id is null or q.category_id=v_step.category_id) and not exists(select 1 from public.game_rounds gr where gr.room_id=p_room_id and gr.question_id=q.id) order by h.last_played_at nulls first,random() limit v_step.question_count loop
   v_position:=v_position+1;
   if v_position=1 then v_first_duration:=coalesce(v_question.duration_seconds,v_step.seconds_per_question,20);v_first_closes_at:=now()+(v_first_duration||' seconds')::interval;insert into public.game_rounds(room_id,template_id,question_id,position,status,opens_at,closes_at) values(p_room_id,v_template.id,v_question.id,v_position,'open',now(),v_first_closes_at)returning id into v_round_id;v_first_round_id:=v_round_id;
   else insert into public.game_rounds(room_id,template_id,question_id,position,status,opens_at,closes_at) values(p_room_id,v_template.id,v_question.id,v_position,'pending',null,null)returning id into v_round_id;end if;
   insert into public.round_option_orders(round_id,option_id,position)
   select v_round_id,qo.id,row_number() over(order by md5(qo.id::text||v_round_id::text))::smallint from public.question_options qo where qo.question_id=v_question.id;
   insert into private.question_play_history(question_id,last_played_at,times_played) values(v_question.id,now(),1) on conflict(question_id) do update set last_played_at=excluded.last_played_at,times_played=private.question_play_history.times_played+1;v_total:=v_total+1;
  end loop;
 end loop;
 if v_total=0 then raise exception 'No approved questions match template %',p_template_code;end if;
 update public.rooms set selected_game=v_template.game_mode,game_title=v_template.title,status='playing',phase='playing',current_round_id=v_first_round_id,round_ends_at=v_first_closes_at,state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=p_room_id;
 return jsonb_build_object('room_id',p_room_id,'round_count',v_total,'game_mode',v_template.game_mode,'first_round_id',v_first_round_id,'closes_at',v_first_closes_at);
end; $function$


CREATE OR REPLACE FUNCTION public.submit_game_answer(p_round_id uuid, p_option_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user uuid:=auth.uid();v_round public.game_rounds%rowtype;v_correct boolean;v_points integer:=0;v_player_count integer;v_answer_count integer;
begin
 if v_user is null then raise exception 'Sign in before answering';end if;select * into v_round from public.game_rounds where id=p_round_id for update;if not found then raise exception 'Round not found';end if;if v_round.status<>'open' then raise exception 'This round is not currently accepting answers';end if;if v_round.closes_at is not null and now()>(v_round.closes_at+interval '2 seconds') then raise exception 'Time is up for this question';end if;
 if not exists(select 1 from public.room_players rp where rp.room_id=v_round.room_id and rp.user_id=v_user and rp.role in('player','host')) then raise exception 'You are not in this room';end if;
 if exists(select 1 from public.player_answers where round_id=p_round_id and player_id=v_user) then raise exception 'You have already locked in your answer for this round';end if;
 select qo.is_correct into v_correct from public.question_options qo where qo.id=p_option_id and qo.question_id=v_round.question_id;if v_correct is null then raise exception 'Selected option is invalid for this question';end if;
 select case when v_correct then coalesce(q.base_points,100) else 0 end into v_points from public.questions q where q.id=v_round.question_id;
 insert into public.player_answers(round_id,room_id,player_id,selected_option_id,is_correct,points_awarded,answered_at) values(v_round.id,v_round.room_id,v_user,p_option_id,v_correct,v_points,now());
 select count(*) into v_player_count from public.room_players where room_id=v_round.room_id and role='player';select count(*) into v_answer_count from public.player_answers pa join public.room_players rp on rp.room_id=pa.room_id and rp.user_id=pa.player_id where pa.round_id=v_round.id and rp.role='player';
 if v_player_count>0 and v_answer_count>=v_player_count then update public.game_rounds set closes_at=now() where id=v_round.id;update public.rooms set phase='all_answered',round_ends_at=now(),state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=v_round.room_id and phase='playing';else update public.rooms set state_version=state_version+1,updated_at=now() where id=v_round.room_id;end if;
 return jsonb_build_object('accepted',true,'has_answered',true);
end; $function$


revoke all on function public.auto_reveal_round(uuid) from public,anon;
grant execute on function public.auto_reveal_round(uuid) to authenticated;