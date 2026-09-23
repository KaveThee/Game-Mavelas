import { readFile, writeFile } from "node:fs/promises";

const celebrityManifest = JSON.parse(await readFile("public/celebrities/manifest.json", "utf8"));
const logoManifest = JSON.parse(await readFile("public/logos/manifest.json", "utf8"));
const sql = (value = "") => `'${String(value).replaceAll("'", "''")}'`;
const sqlSlug = (value) => value.replaceAll("-", "_");

const celebrityRows = celebrityManifest
  .filter((person) => person.provider === "Wikimedia Commons")
  .map((person) => `  (${sql(person.slug)}, ${sql(person.alt)}, ${sql(`${person.author} · Wikimedia Commons`)}, ${sql(`${person.license} · ${person.source}`)})`)
  .join(",\n");

const logoRows = logoManifest.map((logo) => {
  const attribution = logo.provider === "SVGL" ? "SVGL cached asset · Brand belongs to its owner" : `${logo.author} · Wikimedia Commons`;
  const licence = logo.provider === "SVGL" ? `Brand trademark · ${logo.assetSource}` : `${logo.license} · ${logo.source}`;
  return `  (${sql(logo.slug)}, ${sql(logo.src)}, ${sql(`${logo.name} logo`)}, ${sql(attribution)}, ${sql(licence)})`;
}).join(",\n");

const questions = logoManifest.map((logo, index) => {
  const difficulty = logo.region === "Africa" ? 3 : logo.region === "Kenya" ? 2 : index < 30 ? 1 : 2;
  const points = difficulty === 1 ? 100 : difficulty === 2 ? 150 : 200;
  return `  (${sql(`logo_${sqlSlug(logo.slug)}`)}, ${sql(logo.slug)}, ${sql(logo.name)}, ${difficulty}, ${points}, ${sql(logo.region.toLowerCase())})`;
});

const options = [];
for (let index = 0; index < logoManifest.length; index += 1) {
  const logo = logoManifest[index];
  const regionalPool = logoManifest.filter((item) => item.region === logo.region && item.slug !== logo.slug);
  const pool = regionalPool.length >= 3 ? regionalPool : logoManifest.filter((item) => item.slug !== logo.slug);
  const offset = (index * 7) % pool.length;
  const distractors = [0, 1, 2].map((step) => pool[(offset + step * 11) % pool.length]);
  const choices = [logo, ...distractors];
  choices.forEach((choice, position) => {
    options.push(`  (${sql(`logo_${sqlSlug(logo.slug)}`)}, ${position + 1}, ${sql(choice.name)}, ${position === 0})`);
  });
}

const migration = `-- Who Am I authenticity and interaction upgrade, plus Logo Rush.

-- Give the active guesser a full 90 seconds.
update public.questions
set duration_seconds = 90, updated_at = now()
where game_mode = 'who_am_i' and status = 'approved';

update public.round_template_steps
set seconds_per_question = 90
where template_id = (select id from public.round_templates where code = 'who_am_i_kenya');

-- Keep source and licence information aligned with the authentic local SVG portraits.
update public.media_assets m
set alt_text = v.alt_text,
    attribution = v.attribution,
    licence = v.licence
from (values
${celebrityRows}
) as v(asset_key, alt_text, attribution, licence)
where m.provider = 'game_mavelas' and m.asset_key = v.asset_key;

-- Opponents can send short clues; the RPCs keep the hidden identity and table private.
create table if not exists public.who_am_i_clues (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.game_rounds(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  player_id uuid not null,
  clue_text text not null check (char_length(clue_text) between 2 and 48),
  created_at timestamptz not null default now()
);

create index if not exists who_am_i_clues_round_created_idx
  on public.who_am_i_clues(round_id, created_at);
create index if not exists who_am_i_clues_player_round_idx
  on public.who_am_i_clues(player_id, round_id);
create index if not exists who_am_i_clues_room_idx
  on public.who_am_i_clues(room_id);
alter table public.who_am_i_clues enable row level security;
revoke all on table public.who_am_i_clues from public, anon, authenticated;

create or replace function public.submit_who_am_i_clue(p_round_id uuid, p_clue text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_round record;
  v_clue text := regexp_replace(btrim(coalesce(p_clue, '')), '\\s+', ' ', 'g');
  v_id uuid;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if char_length(v_clue) not between 2 and 48 then raise exception 'Clues must be 2 to 48 characters'; end if;

  select gr.*, q.game_mode into v_round
  from public.game_rounds gr join public.questions q on q.id=gr.question_id
  where gr.id=p_round_id;
  if not found or v_round.game_mode <> 'who_am_i' then raise exception 'This is not a Who Am I round'; end if;
  if v_round.status <> 'open' or (v_round.closes_at is not null and now() > v_round.closes_at) then raise exception 'This round is closed'; end if;
  if not exists (select 1 from public.room_players where room_id=v_round.room_id and user_id=v_user) then raise exception 'You are not in this room'; end if;
  if v_round.active_player_id=v_user then raise exception 'The guesser uses the private clipboard'; end if;
  if (select count(*) from public.who_am_i_clues where round_id=p_round_id and player_id=v_user) >= 8 then raise exception 'You have shared enough clues this round'; end if;

  insert into public.who_am_i_clues(round_id,room_id,player_id,clue_text)
  values(p_round_id,v_round.room_id,v_user,v_clue)
  returning id into v_id;

  update public.rooms set state_version=state_version+1,updated_at=now() where id=v_round.room_id;
  return jsonb_build_object('id',v_id,'clue',v_clue);
end;
$$;

create or replace function public.get_who_am_i_round_clues(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room_id uuid;
  v_result jsonb;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  select room_id into v_room_id from public.game_rounds where id=p_round_id;
  if v_room_id is null or not exists (select 1 from public.room_players where room_id=v_room_id and user_id=v_user) then
    raise exception 'You are not in this room';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'text',c.clue_text,'is_mine',c.player_id=v_user,'sender',rp.nickname
  ) order by c.created_at), '[]'::jsonb)
  into v_result
  from public.who_am_i_clues c
  join public.room_players rp on rp.room_id=c.room_id and rp.user_id=c.player_id
  where c.round_id=p_round_id;
  return v_result;
end;
$$;

revoke all on function public.submit_who_am_i_clue(uuid,text) from public,anon;
revoke all on function public.get_who_am_i_round_clues(uuid) from public,anon;
grant execute on function public.submit_who_am_i_clue(uuid,text) to authenticated;
grant execute on function public.get_who_am_i_round_clues(uuid) to authenticated;

-- Logo Rush content and templates. All assets are cached locally; no API call occurs during play.
alter table public.round_templates drop constraint if exists round_templates_game_mode_check;
alter table public.round_templates add constraint round_templates_game_mode_check
  check (game_mode = any (array['trivia','flag_frenzy','who_am_i','guess_image','logo_quiz']));
alter table public.questions drop constraint if exists questions_game_mode_check;
alter table public.questions add constraint questions_game_mode_check
  check (game_mode = any (array['trivia','flag_frenzy','who_am_i','guess_image','logo_quiz']));
alter table public.media_assets drop constraint if exists media_assets_asset_type_check;
alter table public.media_assets add constraint media_assets_asset_type_check
  check (asset_type = any (array['flag','image','audio','logo']));

insert into public.question_sources(source_key,title,source_url,licence,notes,checked_at)
values('logo_rush_assets','Logo Rush verified assets','https://svgl.app/docs/api','Mixed brand/trademark and source licences','SVGL plus reviewed Wikimedia Commons Kenyan and African brand assets.',now())
on conflict(source_key) do update set title=excluded.title,source_url=excluded.source_url,licence=excluded.licence,notes=excluded.notes,checked_at=excluded.checked_at;

insert into public.content_packs(code,title,description,region,is_active)
values('logo_rush','Logo Rush','Recognisable international, African, and Kenyan brand logos.','world',true)
on conflict(code) do update set title=excluded.title,description=excluded.description,region=excluded.region,is_active=true;

insert into public.categories(code,title,icon,sort_order,is_active)
values('brand_logos','Brand Logos','badge',60,true)
on conflict(code) do update set title=excluded.title,icon=excluded.icon,sort_order=excluded.sort_order,is_active=true;

insert into public.round_templates(code,title,game_mode,description,is_active)
values('logo_rush_world','Logo Rush','logo_quiz','Twenty shuffled international, African, and Kenyan logos.',true)
on conflict(code) do update set title=excluded.title,game_mode=excluded.game_mode,description=excluded.description,is_active=true;

delete from public.round_template_steps
where template_id=(select id from public.round_templates where code='logo_rush_world');
insert into public.round_template_steps(template_id,position,category_id,difficulty_min,difficulty_max,question_count,seconds_per_question)
select rt.id,s.position,c.id,s.difficulty,s.difficulty,s.question_count,20
from public.round_templates rt
join public.categories c on c.code='brand_logos'
cross join (values (1::smallint,1::smallint,7::smallint),(2::smallint,2::smallint,7::smallint),(3::smallint,3::smallint,6::smallint)) s(position,difficulty,question_count)
where rt.code='logo_rush_world';

insert into public.media_assets(asset_type,provider,asset_key,public_url,alt_text,attribution,licence,source_id,width,height)
select 'logo','game_mavelas_logos',v.asset_key,v.public_url,v.alt_text,v.attribution,v.licence,s.id,720,480
from (values
${logoRows}
) as v(asset_key,public_url,alt_text,attribution,licence)
join public.question_sources s on s.source_key='logo_rush_assets'
on conflict(provider,asset_key) do update set public_url=excluded.public_url,alt_text=excluded.alt_text,attribution=excluded.attribution,licence=excluded.licence,source_id=excluded.source_id;

insert into public.questions(slug,pack_id,category_id,game_mode,prompt,explanation,media_id,difficulty,duration_seconds,base_points,tags,status,source_id,fact_checked_at)
select v.slug,p.id,c.id,'logo_quiz','Which brand owns this logo?',concat('This is the ',v.brand_name,' logo.'),m.id,v.difficulty,20,v.points,array['logo',v.region], 'approved',s.id,now()
from (values
${questions.join(",\n")}
) as v(slug,asset_key,brand_name,difficulty,points,region)
join public.content_packs p on p.code='logo_rush'
join public.categories c on c.code='brand_logos'
join public.media_assets m on m.provider='game_mavelas_logos' and m.asset_key=v.asset_key
join public.question_sources s on s.source_key='logo_rush_assets'
on conflict(slug) do update set pack_id=excluded.pack_id,category_id=excluded.category_id,game_mode=excluded.game_mode,prompt=excluded.prompt,explanation=excluded.explanation,media_id=excluded.media_id,difficulty=excluded.difficulty,duration_seconds=excluded.duration_seconds,base_points=excluded.base_points,tags=excluded.tags,status='approved',source_id=excluded.source_id,fact_checked_at=now(),updated_at=now();

insert into public.question_options(question_id,position,option_text,is_correct)
select q.id,v.position,v.option_text,v.is_correct
from (values
${options.join(",\n")}
) as v(question_slug,position,option_text,is_correct)
join public.questions q on q.slug=v.question_slug
on conflict(question_id,position) do update set option_text=excluded.option_text,is_correct=excluded.is_correct;

create or replace function public.create_game_room(p_nickname text,p_selected_game text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=(select auth.uid());v_nickname text:=btrim(p_nickname);v_game text:=lower(btrim(p_selected_game));
  v_code text;v_room public.rooms%rowtype;v_attempt smallint:=0;
begin
  if v_user is null then raise exception 'Sign in before creating a room';end if;
  if char_length(v_nickname) not between 2 and 24 then raise exception 'Nickname must be between 2 and 24 characters';end if;
  if v_game not in ('trivia','trivia-kenya','trivia-scitech','trivia-mix','flags','flag_frenzy','who','who_am_i','image','guess_image','logos','logo_quiz') then raise exception 'Unsupported game selection';end if;
  loop
    v_attempt:=v_attempt+1;v_code:=upper(substr(md5(random()::text||clock_timestamp()::text||v_user::text),1,6));
    begin
      insert into public.rooms(code,host_id,selected_game,status,phase) values(v_code,v_user,v_game,'lobby','lobby') returning * into v_room;
      exit;
    exception when unique_violation then if v_attempt>=10 then raise exception 'Could not allocate a unique room code';end if;end;
  end loop;
  insert into public.room_players(room_id,user_id,nickname,role) values(v_room.id,v_user,v_nickname,'host');
  return jsonb_build_object('id',v_room.id,'code',v_room.code,'status',v_room.status,'host_id',v_room.host_id,'selected_game',v_room.selected_game);
end;$$;

create or replace function public.select_room_game(p_room_id uuid,p_selected_game text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_game text:=lower(btrim(p_selected_game));
begin
  if v_user is null then raise exception 'Sign in required';end if;
  if v_game not in ('trivia-kenya','trivia-scitech','trivia-mix','flags','who','image','logos') then raise exception 'Unsupported game selection';end if;
  update public.rooms set selected_game=v_game,phase='lobby',state_version=state_version+1,last_transition_at=now(),updated_at=now()
  where id=p_room_id and host_id=v_user and status in ('lobby','results');
  if not found then raise exception 'Only the room host can select a game';end if;
  return jsonb_build_object('room_id',p_room_id,'selected_game',v_game);
end;$$;

create or replace function public.host_replay_game(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_template_code text;v_selection text;v_result jsonb;
begin
  if v_user is null then raise exception 'Sign in required';end if;
  if not exists(select 1 from public.rooms r where r.id=p_room_id and r.host_id=v_user and r.status='results') then raise exception 'Only the room host can replay a finished game';end if;
  select rt.code into v_template_code from public.game_rounds gr join public.round_templates rt on rt.id=gr.template_id where gr.room_id=p_room_id order by gr.position limit 1;
  if v_template_code is null then raise exception 'Previous game could not be found';end if;
  v_selection:=case v_template_code when 'trivia_vault_kenya' then 'trivia-kenya' when 'trivia_vault_scitech' then 'trivia-scitech' when 'trivia_vault_mix' then 'trivia-mix' when 'flag_frenzy_africa' then 'flags' when 'who_am_i_kenya' then 'who' when 'clue_heist_classic' then 'image' when 'logo_rush_world' then 'logos' else null end;
  v_result:=public.start_game(p_room_id,v_template_code);
  if v_selection is not null then update public.rooms set selected_game=v_selection,updated_at=now() where id=p_room_id;end if;
  return v_result||jsonb_build_object('replayed',true,'template_code',v_template_code,'selected_game',v_selection);
end;$$;

create or replace function public.host_return_to_lobby(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_template_code text;v_selection text;
begin
  if v_user is null then raise exception 'Sign in required';end if;
  if not exists(select 1 from public.rooms r where r.id=p_room_id and r.host_id=v_user and r.status='results') then raise exception 'Only the room host can return this game to the lobby';end if;
  select rt.code into v_template_code from public.game_rounds gr join public.round_templates rt on rt.id=gr.template_id where gr.room_id=p_room_id order by gr.position limit 1;
  v_selection:=case v_template_code when 'trivia_vault_kenya' then 'trivia-kenya' when 'trivia_vault_scitech' then 'trivia-scitech' when 'trivia_vault_mix' then 'trivia-mix' when 'flag_frenzy_africa' then 'flags' when 'who_am_i_kenya' then 'who' when 'clue_heist_classic' then 'image' when 'logo_rush_world' then 'logos' else 'trivia-kenya' end;
  update public.game_rounds set status='closed',closes_at=coalesce(closes_at,now()) where room_id=p_room_id and status in ('pending','open','revealed');
  update public.room_players set score=0 where room_id=p_room_id;
  update public.rooms set status='lobby',phase='lobby',selected_game=v_selection,game_title=null,current_round_id=null,round_ends_at=null,state_version=state_version+1,last_transition_at=now(),updated_at=now() where id=p_room_id;
  return jsonb_build_object('returned_to_lobby',true,'selected_game',v_selection);
end;$$;

revoke all on function public.create_game_room(text,text),public.select_room_game(uuid,text),public.host_replay_game(uuid),public.host_return_to_lobby(uuid) from public,anon;
grant execute on function public.create_game_room(text,text),public.select_room_game(uuid,text),public.host_replay_game(uuid),public.host_return_to_lobby(uuid) to authenticated;
`;

await writeFile("supabase/who_am_i_clipboard_and_logo_rush.sql", migration);
process.stdout.write(`Generated migration with ${logoManifest.length} logos and ${options.length} answer options.\n`);
