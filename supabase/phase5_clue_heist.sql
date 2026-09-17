-- Phase 5: Clue Heist
-- 20 progressive clues, 100-to-5 scoring, rotating spotlight player, and half-value steals.

alter table public.game_rounds add column if not exists active_player_id uuid;

create table if not exists public.clue_heist_clues (
  question_id uuid not null references public.questions(id) on delete cascade,
  position smallint not null check (position between 1 and 20),
  clue_text text not null check (char_length(clue_text) between 3 and 300),
  primary key (question_id, position)
);

create table if not exists public.clue_heist_aliases (
  question_id uuid not null references public.questions(id) on delete cascade,
  answer_text text not null,
  primary key (question_id, answer_text)
);

create table if not exists public.clue_heist_mysteries (
  question_id uuid primary key references public.questions(id) on delete cascade,
  answer_media_id uuid not null references public.media_assets(id) on delete restrict
);

create table if not exists public.clue_heist_rounds (
  round_id uuid primary key references public.game_rounds(id) on delete cascade,
  clue_number smallint not null default 1 check (clue_number between 1 and 20),
  turn_phase text not null default 'spotlight' check (turn_phase in ('spotlight', 'steal', 'revealed')),
  winner_id uuid,
  awarded_points smallint not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.clue_heist_attempts (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.game_rounds(id) on delete cascade,
  player_id uuid not null,
  clue_number smallint not null,
  guess text not null,
  is_correct boolean not null,
  is_steal boolean not null,
  created_at timestamptz not null default now(),
  unique (round_id, player_id)
);

alter table public.clue_heist_clues enable row level security;
alter table public.clue_heist_aliases enable row level security;
alter table public.clue_heist_mysteries enable row level security;
alter table public.clue_heist_rounds enable row level security;
alter table public.clue_heist_attempts enable row level security;
revoke all on public.clue_heist_clues, public.clue_heist_aliases, public.clue_heist_mysteries,
  public.clue_heist_rounds, public.clue_heist_attempts from anon, authenticated;

insert into public.round_templates (code, title, game_mode, description, is_active)
values ('clue_heist_classic', 'Clue Heist', 'guess_image', 'Guess the hidden image with fewer clues, or steal for half points.', true)
on conflict (code) do update set title = excluded.title, description = excluded.description, is_active = true;

insert into public.round_template_steps (template_id, position, difficulty_min, difficulty_max, question_count, seconds_per_question)
select id, 1, 1, 5, 5, 120 from public.round_templates where code = 'clue_heist_classic'
on conflict (template_id, position) do update set question_count = 5, seconds_per_question = 120;

insert into public.questions
  (slug, pack_id, category_id, game_mode, prompt, explanation, media_id, difficulty, duration_seconds, base_points, tags, status, source_id, fact_checked_at)
select v.slug, p.id, c.id, 'guess_image', 'Mystery image', v.explanation, m.id, v.difficulty, 120, 100,
  array['clue_heist', v.category_code], 'approved', s.id, now()
from (values
  ('clue_heist_cristiano_ronaldo', 'Cristiano Ronaldo', 'sports', 'cristiano-ronaldo', 'Cristiano Ronaldo is a Portuguese footballer and one of the most prolific goalscorers in football history.', 1),
  ('clue_heist_lionel_messi', 'Lionel Messi', 'sports', 'lionel-messi', 'Lionel Messi is an Argentine footballer, World Cup winner and multiple Ballon d''Or recipient.', 1),
  ('clue_heist_lupita_nyongo', 'Lupita Nyong''o', 'entertainment', 'lupita-nyongo', 'Lupita Nyong''o is a Kenyan-Mexican actor and Academy Award winner.', 2),
  ('clue_heist_eliud_kipchoge', 'Eliud Kipchoge', 'sports', 'eliud-kipchoge', 'Eliud Kipchoge is a Kenyan Olympic marathon champion and distance-running icon.', 2),
  ('clue_heist_wangari_maathai', 'Wangari Maathai', 'kenyan_culture', 'wangari-maathai', 'Wangari Maathai founded the Green Belt Movement and became the first African woman to receive the Nobel Peace Prize.', 2)
) as v(slug, answer, category_code, asset_key, explanation, difficulty)
join public.content_packs p on p.code = 'kenya_core'
join public.categories c on c.code = v.category_code
join public.media_assets m on m.provider = 'game_mavelas' and m.asset_key = v.asset_key
join public.question_sources s on s.source_key = 'editorial'
on conflict (slug) do update set explanation = excluded.explanation, media_id = excluded.media_id,
  difficulty = excluded.difficulty, duration_seconds = 120, base_points = 100,
  tags = excluded.tags, status = 'approved', fact_checked_at = now(), updated_at = now();

-- Keep answer images outside the generic question payload so players cannot inspect
-- a hidden image before the mystery is revealed.
insert into public.clue_heist_mysteries(question_id,answer_media_id)
select id,media_id from public.questions where 'clue_heist'=any(tags) and media_id is not null
on conflict(question_id) do update set answer_media_id=excluded.answer_media_id;
update public.questions set media_id=null where 'clue_heist'=any(tags);

insert into public.clue_heist_aliases (question_id, answer_text)
select q.id, v.answer from (values
  ('clue_heist_cristiano_ronaldo','Cristiano Ronaldo'),('clue_heist_cristiano_ronaldo','Ronaldo'),('clue_heist_cristiano_ronaldo','CR7'),
  ('clue_heist_lionel_messi','Lionel Messi'),('clue_heist_lionel_messi','Messi'),('clue_heist_lionel_messi','Leo Messi'),
  ('clue_heist_lupita_nyongo','Lupita Nyongo'),('clue_heist_lupita_nyongo','Lupita Nyong''o'),('clue_heist_lupita_nyongo','Lupita'),
  ('clue_heist_eliud_kipchoge','Eliud Kipchoge'),('clue_heist_eliud_kipchoge','Kipchoge'),
  ('clue_heist_wangari_maathai','Wangari Maathai'),('clue_heist_wangari_maathai','Wangari')
) v(slug,answer) join public.questions q on q.slug=v.slug
on conflict do nothing;

insert into public.clue_heist_clues (question_id, position, clue_text)
select q.id, v.position, v.clue from (values
('clue_heist_cristiano_ronaldo',1,'I grew up on a European island.'),('clue_heist_cristiano_ronaldo',2,'My career has taken me through England, Spain and Italy.'),('clue_heist_cristiano_ronaldo',3,'I became famous for explosive speed and jumping ability.'),('clue_heist_cristiano_ronaldo',4,'I have captained my national team.'),('clue_heist_cristiano_ronaldo',5,'I have won major European club trophies.'),('clue_heist_cristiano_ronaldo',6,'I have played in more than five World Cup tournaments.'),('clue_heist_cristiano_ronaldo',7,'I once played for Sporting CP.'),('clue_heist_cristiano_ronaldo',8,'Sir Alex Ferguson helped launch my global career.'),('clue_heist_cristiano_ronaldo',9,'I became a superstar at Real Madrid.'),('clue_heist_cristiano_ronaldo',10,'I later played for Juventus.'),('clue_heist_cristiano_ronaldo',11,'I represent Portugal.'),('clue_heist_cristiano_ronaldo',12,'I am famous for the number 7.'),('clue_heist_cristiano_ronaldo',13,'My goal celebration is shouted around the world.'),('clue_heist_cristiano_ronaldo',14,'I have won the Ballon d''Or multiple times.'),('clue_heist_cristiano_ronaldo',15,'I am one of football''s highest-ever scorers.'),('clue_heist_cristiano_ronaldo',16,'My initials are used as a global brand.'),('clue_heist_cristiano_ronaldo',17,'Fans call me CR7.'),('clue_heist_cristiano_ronaldo',18,'My first name is Cristiano.'),('clue_heist_cristiano_ronaldo',19,'My surname is Ronaldo.'),('clue_heist_cristiano_ronaldo',20,'I am Cristiano Ronaldo.'),
('clue_heist_lionel_messi',1,'I left my home country as a young teenager to pursue my dream.'),('clue_heist_lionel_messi',2,'A medical treatment was important early in my life.'),('clue_heist_lionel_messi',3,'Most of my club legacy was built in one Spanish city.'),('clue_heist_lionel_messi',4,'I am known more for close control than physical size.'),('clue_heist_lionel_messi',5,'I have captained my national team.'),('clue_heist_lionel_messi',6,'I scored hundreds of goals for Barcelona.'),('clue_heist_lionel_messi',7,'I later played club football in Paris.'),('clue_heist_lionel_messi',8,'I moved to Major League Soccer.'),('clue_heist_lionel_messi',9,'I won an Olympic gold medal.'),('clue_heist_lionel_messi',10,'I won the Copa América with my country.'),('clue_heist_lionel_messi',11,'I finally lifted the World Cup in 2022.'),('clue_heist_lionel_messi',12,'I represent Argentina.'),('clue_heist_lionel_messi',13,'I am left-footed.'),('clue_heist_lionel_messi',14,'I have worn number 10 for much of my career.'),('clue_heist_lionel_messi',15,'I have won more Ballon d''Or awards than anyone else.'),('clue_heist_lionel_messi',16,'My first name is Lionel.'),('clue_heist_lionel_messi',17,'Some fans call me Leo.'),('clue_heist_lionel_messi',18,'My surname begins with M.'),('clue_heist_lionel_messi',19,'My surname is Messi.'),('clue_heist_lionel_messi',20,'I am Lionel Messi.'),
('clue_heist_lupita_nyongo',1,'I was born in Mexico and raised in East Africa.'),('clue_heist_lupita_nyongo',2,'Storytelling runs in my family.'),('clue_heist_lupita_nyongo',3,'I studied film before becoming globally famous.'),('clue_heist_lupita_nyongo',4,'One of my early jobs was behind the camera.'),('clue_heist_lupita_nyongo',5,'My breakthrough film was a historical drama.'),('clue_heist_lupita_nyongo',6,'I won a major acting award for my first feature-film role.'),('clue_heist_lupita_nyongo',7,'I have appeared in a famous space saga.'),('clue_heist_lupita_nyongo',8,'I played a warrior in an African superhero kingdom.'),('clue_heist_lupita_nyongo',9,'I have also starred in a horror film where I played two roles.'),('clue_heist_lupita_nyongo',10,'I wrote a children''s book called Sulwe.'),('clue_heist_lupita_nyongo',11,'I am closely associated with Kenya.'),('clue_heist_lupita_nyongo',12,'I appeared in Black Panther.'),('clue_heist_lupita_nyongo',13,'My character in Black Panther is Nakia.'),('clue_heist_lupita_nyongo',14,'I won an Academy Award.'),('clue_heist_lupita_nyongo',15,'My surname contains an apostrophe.'),('clue_heist_lupita_nyongo',16,'My first name begins with L.'),('clue_heist_lupita_nyongo',17,'My first name is Lupita.'),('clue_heist_lupita_nyongo',18,'My surname begins with Ny.'),('clue_heist_lupita_nyongo',19,'My surname is Nyong''o.'),('clue_heist_lupita_nyongo',20,'I am Lupita Nyong''o.'),
('clue_heist_eliud_kipchoge',1,'My greatest achievements require patience over a very long distance.'),('clue_heist_eliud_kipchoge',2,'I began my international career on the track.'),('clue_heist_eliud_kipchoge',3,'I defeated celebrated champions while still very young.'),('clue_heist_eliud_kipchoge',4,'Discipline and simple living are central to my public image.'),('clue_heist_eliud_kipchoge',5,'I train in Kaptagat.'),('clue_heist_eliud_kipchoge',6,'I switched from track competition to road racing.'),('clue_heist_eliud_kipchoge',7,'I have won major city marathons repeatedly.'),('clue_heist_eliud_kipchoge',8,'I have won Olympic gold medals.'),('clue_heist_eliud_kipchoge',9,'My sport is athletics.'),('clue_heist_eliud_kipchoge',10,'My signature event covers 42.195 kilometres.'),('clue_heist_eliud_kipchoge',11,'I am Kenyan.'),('clue_heist_eliud_kipchoge',12,'I became a global symbol of marathon excellence.'),('clue_heist_eliud_kipchoge',13,'I took part in the INEOS 1:59 Challenge.'),('clue_heist_eliud_kipchoge',14,'I became the first person to run a marathon distance in under two hours in a special event.'),('clue_heist_eliud_kipchoge',15,'My philosophy says no human is limited.'),('clue_heist_eliud_kipchoge',16,'My surname begins with K.'),('clue_heist_eliud_kipchoge',17,'My first name is Eliud.'),('clue_heist_eliud_kipchoge',18,'My surname contains “choge”.'),('clue_heist_eliud_kipchoge',19,'My surname is Kipchoge.'),('clue_heist_eliud_kipchoge',20,'I am Eliud Kipchoge.'),
('clue_heist_wangari_maathai',1,'I connected environmental care with democracy and human rights.'),('clue_heist_wangari_maathai',2,'My most famous work began with communities and seedlings.'),('clue_heist_wangari_maathai',3,'I studied biological sciences.'),('clue_heist_wangari_maathai',4,'I earned a doctorate at a time when few women from my region had done so.'),('clue_heist_wangari_maathai',5,'I taught at the University of Nairobi.'),('clue_heist_wangari_maathai',6,'I challenged powerful political interests.'),('clue_heist_wangari_maathai',7,'I was detained and attacked for my activism.'),('clue_heist_wangari_maathai',8,'I served as a Member of Parliament.'),('clue_heist_wangari_maathai',9,'I also served as an assistant minister.'),('clue_heist_wangari_maathai',10,'I founded a movement focused on planting trees.'),('clue_heist_wangari_maathai',11,'That organisation is called the Green Belt Movement.'),('clue_heist_wangari_maathai',12,'I was Kenyan.'),('clue_heist_wangari_maathai',13,'I became the first African woman to receive a particular global prize.'),('clue_heist_wangari_maathai',14,'That prize was the Nobel Peace Prize.'),('clue_heist_wangari_maathai',15,'I received it in 2004.'),('clue_heist_wangari_maathai',16,'My first name begins with W.'),('clue_heist_wangari_maathai',17,'My first name is Wangari.'),('clue_heist_wangari_maathai',18,'My surname begins with M.'),('clue_heist_wangari_maathai',19,'My surname is Maathai.'),('clue_heist_wangari_maathai',20,'I am Wangari Maathai.')
) v(slug,position,clue) join public.questions q on q.slug=v.slug
on conflict (question_id,position) do update set clue_text=excluded.clue_text;

create or replace function public.setup_clue_heist_round()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_count integer;
begin
  if exists(select 1 from public.questions q where q.id=new.question_id and q.game_mode='guess_image') then
    select count(*) into v_count from public.room_players where room_id=new.room_id;
    if v_count=0 then raise exception 'Clue Heist needs at least one player'; end if;
    if new.active_player_id is null then
      select user_id into new.active_player_id from public.room_players where room_id=new.room_id order by joined_at,user_id offset ((new.position-1)%v_count) limit 1;
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists setup_clue_heist_round_before on public.game_rounds;
create trigger setup_clue_heist_round_before before insert on public.game_rounds
for each row execute function public.setup_clue_heist_round();

create or replace function public.initialize_clue_heist_round()
returns trigger language plpgsql security definer set search_path=''
as $$ begin
  if exists(select 1 from public.questions q where q.id=new.question_id and q.game_mode='guess_image') then
    insert into public.clue_heist_rounds(round_id) values(new.id) on conflict do nothing;
  end if; return new;
end; $$;
drop trigger if exists initialize_clue_heist_round_after on public.game_rounds;
create trigger initialize_clue_heist_round_after after insert on public.game_rounds
for each row execute function public.initialize_clue_heist_round();

create or replace function public.normalize_clue_answer(p_text text)
returns text language sql immutable set search_path=''
as $$ select regexp_replace(lower(trim(coalesce(p_text,''))), '[^a-z0-9]+','','g') $$;

create or replace function public.submit_clue_heist_guess(p_round_id uuid,p_guess text)
returns jsonb language plpgsql security definer set search_path=''
as $$
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
  if exists(select 1 from public.clue_heist_attempts where round_id=p_round_id and player_id=v_user) then raise exception 'You already guessed this mystery'; end if;
  select exists(select 1 from public.clue_heist_aliases a where a.question_id=v_round.question_id and public.normalize_clue_answer(a.answer_text)=public.normalize_clue_answer(p_guess)) into v_correct;
  v_value:=105-(v_state.clue_number*5); v_award:=case when v_correct then case when v_steal then ceil(v_value/2.0)::smallint else v_value end else 0 end;
  insert into public.clue_heist_attempts(round_id,player_id,clue_number,guess,is_correct,is_steal) values(p_round_id,v_user,v_state.clue_number,trim(p_guess),v_correct,v_steal);
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

create or replace function public.advance_clue_heist_clue(p_round_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_round record; v_state record;
begin
  select gr.*,r.host_id into v_round from public.game_rounds gr join public.rooms r on r.id=gr.room_id where gr.id=p_round_id for update of gr;
  if not found then raise exception 'Round not found'; end if;
  if v_user<>v_round.host_id and v_user<>v_round.active_player_id then raise exception 'Only the host or spotlight player can request another clue'; end if;
  select * into v_state from public.clue_heist_rounds where round_id=p_round_id for update;
  if v_state.turn_phase='revealed' then raise exception 'This mystery is already revealed'; end if;
  if v_state.clue_number>=20 then
    update public.clue_heist_rounds set turn_phase='revealed',updated_at=now() where round_id=p_round_id;
    update public.game_rounds set status='revealed',closes_at=now() where id=p_round_id;
    update public.rooms set phase='revealed',state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=v_round.room_id;
    return jsonb_build_object('revealed',true,'clue_number',20,'value',5);
  end if;
  update public.clue_heist_rounds set clue_number=clue_number+1,turn_phase='spotlight',updated_at=now() where round_id=p_round_id;
  update public.rooms set state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=v_round.room_id;
  return jsonb_build_object('revealed',false,'clue_number',v_state.clue_number+1,'value',100-(v_state.clue_number*5));
end; $$;

create or replace function public.get_clue_heist_state(p_round_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_round record; v_state record; v_answer text; v_image jsonb; v_winner text; v_attempted boolean;
begin
  select gr.*,q.explanation,m.public_url,m.alt_text into v_round from public.game_rounds gr join public.questions q on q.id=gr.question_id left join public.clue_heist_mysteries hm on hm.question_id=q.id left join public.media_assets m on m.id=hm.answer_media_id where gr.id=p_round_id;
  if not found then raise exception 'Round not found'; end if;
  if v_user is not null and not exists(select 1 from public.room_players where room_id=v_round.room_id and user_id=v_user) then raise exception 'You are not in this room'; end if;
  select * into v_state from public.clue_heist_rounds where round_id=p_round_id;
  select answer_text into v_answer from public.clue_heist_aliases where question_id=v_round.question_id order by length(answer_text) desc limit 1;
  select nickname into v_winner from public.room_players where room_id=v_round.room_id and user_id=v_state.winner_id;
  select exists(select 1 from public.clue_heist_attempts where round_id=p_round_id and player_id=v_user) into v_attempted;
  return jsonb_build_object('clue_number',v_state.clue_number,'current_value',105-v_state.clue_number*5,'turn_phase',v_state.turn_phase,
    'active_player_id',v_round.active_player_id,'is_spotlight',v_user=v_round.active_player_id,'has_attempted',coalesce(v_attempted,false),
    'can_guess',case when v_state.turn_phase='spotlight' then v_user=v_round.active_player_id when v_state.turn_phase='steal' then v_user<>v_round.active_player_id and not coalesce(v_attempted,false) else false end,
    'clues',coalesce((select jsonb_agg(jsonb_build_object('position',c.position,'text',c.clue_text) order by c.position) from public.clue_heist_clues c where c.question_id=v_round.question_id and c.position<=v_state.clue_number),'[]'::jsonb),
    'answer',case when v_state.turn_phase='revealed' then v_answer else null end,
    'image',case when v_state.turn_phase='revealed' and v_round.public_url is not null then jsonb_build_object('url',v_round.public_url,'alt',v_round.alt_text) else null end,
    'explanation',case when v_state.turn_phase='revealed' then v_round.explanation else null end,'winner_name',v_winner,'awarded_points',v_state.awarded_points);
end; $$;

create or replace function public.reveal_clue_heist_answer(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_round_id uuid;
begin
  select gr.id into v_round_id from public.rooms r join public.game_rounds gr on gr.id=r.current_round_id
  join public.questions q on q.id=gr.question_id
  where r.id=p_room_id and r.host_id=v_user and r.status='playing' and q.game_mode='guess_image';
  if v_round_id is null then raise exception 'Only the host can reveal this Clue Heist mystery'; end if;
  update public.clue_heist_rounds set turn_phase='revealed',updated_at=now() where round_id=v_round_id;
  update public.game_rounds set status='revealed',closes_at=now() where id=v_round_id;
  update public.rooms set phase='revealed',state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=p_room_id;
  return jsonb_build_object('revealed',true,'round_id',v_round_id);
end; $$;

revoke all on function public.submit_clue_heist_guess(uuid,text), public.advance_clue_heist_clue(uuid), public.get_clue_heist_state(uuid), public.reveal_clue_heist_answer(uuid) from public,anon;
grant execute on function public.submit_clue_heist_guess(uuid,text), public.advance_clue_heist_clue(uuid), public.get_clue_heist_state(uuid), public.reveal_clue_heist_answer(uuid) to authenticated;
revoke all on function public.setup_clue_heist_round(), public.initialize_clue_heist_round() from public,anon,authenticated;

create index if not exists clue_heist_mysteries_media_idx on public.clue_heist_mysteries(answer_media_id);
create index if not exists clue_heist_attempts_round_idx on public.clue_heist_attempts(round_id,created_at);

create or replace function public.get_public_clue_heist_state(p_room_code text)
returns jsonb language sql security definer set search_path=''
as $$
  select jsonb_build_object(
    'clue_number',chs.clue_number,'current_value',105-chs.clue_number*5,'turn_phase',chs.turn_phase,
    'clues',coalesce((select jsonb_agg(jsonb_build_object('position',c.position,'text',c.clue_text) order by c.position) from public.clue_heist_clues c where c.question_id=gr.question_id and c.position<=chs.clue_number),'[]'::jsonb),
    'answer',case when chs.turn_phase='revealed' then (select answer_text from public.clue_heist_aliases where question_id=gr.question_id order by length(answer_text) desc limit 1) else null end,
    'image',case when chs.turn_phase='revealed' and m.public_url is not null then jsonb_build_object('url',m.public_url,'alt',m.alt_text) else null end,
    'explanation',case when chs.turn_phase='revealed' then q.explanation else null end,
    'winner_name',winner.nickname,'awarded_points',chs.awarded_points)
  from public.rooms r join public.game_rounds gr on gr.id=r.current_round_id
  join public.questions q on q.id=gr.question_id join public.clue_heist_rounds chs on chs.round_id=gr.id
  left join public.clue_heist_mysteries hm on hm.question_id=q.id
  left join public.media_assets m on m.id=hm.answer_media_id
  left join public.room_players winner on winner.room_id=r.id and winner.user_id=chs.winner_id
  where r.code=upper(trim(p_room_code)) and r.status='playing' and q.game_mode='guess_image' limit 1;
$$;

revoke all on function public.get_public_clue_heist_state(text) from public;
grant execute on function public.get_public_clue_heist_state(text) to anon,authenticated;
