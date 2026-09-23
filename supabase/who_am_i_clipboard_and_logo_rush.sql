-- Who Am I authenticity and interaction upgrade, plus Logo Rush.

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
  ('lupita-nyongo', 'Photograph of Lupita Nyong''o', 'PhilipRomano · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:LupitaNyongo-byPhilipRomano3.jpg'),
  ('eliud-kipchoge', 'Photograph of Eliud Kipchoge', 'Denis Barthel · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Berlin-Marathon_2015_Runners_1.jpg'),
  ('faith-kipyegon', 'Photograph of Faith Kipyegon', 'Erik van Leeuwen, attribution: Erik van Leeuwen (bron: Wikipedia). · Wikimedia Commons', 'GFDL · https://commons.wikimedia.org/wiki/File:Faith_Kipyegon_London_2017_(cropped2).jpg'),
  ('wangari-maathai', 'Photograph of Wangari Maathai', 'Kingkongphoto &amp; www.celebrity-photos.com from Laurel Maryland, USA · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Wangari_Matthai_2001_(cropped).jpg'),
  ('ferdinand-omanyala', 'Photograph of Ferdinand Omanyala', 'Erik van Leeuwen, attribution: Erik van Leeuwen (bron: Wikipedia). · Wikimedia Commons', 'GFDL · https://commons.wikimedia.org/wiki/File:Ferdinand_Omanyala_Budapest_2023.jpg'),
  ('david-rudisha', 'Photograph of David Rudisha', 'Erik van Leeuwen · Wikimedia Commons', 'GFDL · https://commons.wikimedia.org/wiki/File:David_Rudisha_Daegu_2011.jpg'),
  ('mwai-kibaki', 'Photograph of Mwai Kibaki', 'Foreign and Commonwealth Office · Wikimedia Commons', 'OGL v1.0 · https://commons.wikimedia.org/wiki/File:Mwai_Kibaki_(cropped).jpg'),
  ('dedan-kimathi', 'Photograph of Dedan Kimathi', 'Murungaru at English Wikipedia · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Statue_of_Dedan_Kimathi_Nairobi,_Kenya.jpg'),
  ('joy-adamson', 'Photograph of Joy Adamson', 'Beni7612 · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:JoyAdamson%C3%89sElza.jpg'),
  ('william-ruto', 'Photograph of William Ruto', 'Presidenza della Repubblica · Wikimedia Commons', 'Attribution · https://commons.wikimedia.org/wiki/File:William_Ruto_2023_(cropped).jpg'),
  ('raila-odinga', 'Photograph of Raila Odinga', 'World Economic Forum from Cologny, Switzerland · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Raila_Amolo_Odinga_2009_(cropped).jpg'),
  ('uhuru-kenyatta', 'Photograph of Uhuru Kenyatta', 'Office of the Prime Minister - Ethiopia · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:PMO_IMG_5262_(40547346173)_(cropped).jpg'),
  ('nyashinski', 'Photograph of Nyashinski', 'Safari jpk · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Nyashinski.jpg'),
  ('victor-wanyama', 'Photograph of Victor Wanyama', 'Glasgow Celtic · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Victor_Wanyama.jpg'),
  ('catherine-kamau', 'Photograph of Catherine Kamau', 'WachukaK · Wikimedia Commons', 'CC0 · https://commons.wikimedia.org/wiki/File:Caterine_Kamau_-_The_Kalasa_International_Award_2017.jpg'),
  ('nelson-mandela', 'Photograph of Nelson Mandela', 'Kingkongphoto &amp; www.celebrity-photos.com from Laurel · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Nelson_Mandela_1994.jpg'),
  ('trevor-noah', 'Photograph of Trevor Noah', 'Web Summit Qatar · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Trevor_Noah_(53554114243)_(portrait_crop).jpg'),
  ('burna-boy', 'Photograph of Burna Boy', 'Nuță Lucian from Cluj-Napoca, Romania · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Untold_2024_-Burna_Boy_(53926047977)_(cropped).jpg'),
  ('diamond-platnumz', 'Photograph of Diamond Platnumz', 'Peter Bennett / ZIFF · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Diamond_Platnumz.jpg'),
  ('mohamed-salah', 'Photograph of Mohamed Salah', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Mohamed_Salah_Argentina_v_Egypt_7_July_2026-163_(cropped).jpg'),
  ('didier-drogba', 'Photograph of Didier Drogba', 'Y.Leclercq© · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Didier_Drogba_(2019)_(cropped).jpg'),
  ('davido', 'Photograph of Davido', 'OLAMIPOSI DANIEL · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Davido_2024_(cropped).jpg'),
  ('cristiano-ronaldo', 'Photograph of Cristiano Ronaldo', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Cristiano_Ronaldo_Croatia_v_Portugal_2_July_2026-075_(cropped).jpg'),
  ('lionel-messi', 'Photograph of Lionel Messi', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Leo_Messi_Argentina_v_Egypt_7_July_2026-1.jpg'),
  ('barack-obama', 'Photograph of Barack Obama', 'Official White House Photo by Pete Souza · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:President_Barack_Obama.jpg')
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
  v_clue text := regexp_replace(btrim(coalesce(p_clue, '')), '\s+', ' ', 'g');
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
  ('linkedin', '/logos/linkedin.svg', 'LinkedIn logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/linkedin.svg'),
  ('paypal', '/logos/paypal.svg', 'PayPal logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/paypal.svg'),
  ('netflix', '/logos/netflix.svg', 'Netflix logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/netflix-icon.svg'),
  ('youtube', '/logos/youtube.svg', 'YouTube logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/youtube.svg'),
  ('google', '/logos/google.svg', 'Google logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/google.svg'),
  ('nvidia', '/logos/nvidia.svg', 'NVIDIA logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/nvidia-icon-light.svg'),
  ('discord', '/logos/discord.svg', 'Discord logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/discord.svg'),
  ('facebook', '/logos/facebook.svg', 'Facebook logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/facebook-icon.svg'),
  ('cisco', '/logos/cisco.svg', 'Cisco logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/cisco_light.svg'),
  ('spotify', '/logos/spotify.svg', 'Spotify logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/spotify.svg'),
  ('telegram', '/logos/telegram.svg', 'Telegram logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/telegram.svg'),
  ('microsoft', '/logos/microsoft.svg', 'Microsoft logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft.svg'),
  ('windows', '/logos/windows.svg', 'Windows logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/windows.svg'),
  ('microsoft-azure', '/logos/microsoft-azure.svg', 'Microsoft Azure logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/azure.svg'),
  ('cloudflare', '/logos/cloudflare.svg', 'Cloudflare logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/cloudflare.svg'),
  ('chrome', '/logos/chrome.svg', 'Chrome logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/chrome.svg'),
  ('amazon-web-services', '/logos/amazon-web-services.svg', 'Amazon Web Services logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/aws_light.svg'),
  ('apple', '/logos/apple.svg', 'Apple logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/apple.svg'),
  ('whatsapp', '/logos/whatsapp.svg', 'WhatsApp logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/whatsapp-icon.svg'),
  ('disney', '/logos/disney.svg', 'Disney+ logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/disneyplus.svg'),
  ('shopify', '/logos/shopify.svg', 'Shopify logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/shopify.svg'),
  ('canva', '/logos/canva.svg', 'Canva logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/canva.svg'),
  ('airbnb', '/logos/airbnb.svg', 'Airbnb logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/airbnb.svg'),
  ('safari', '/logos/safari.svg', 'Safari logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/safari.svg'),
  ('firefox', '/logos/firefox.svg', 'Firefox logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/firefox.svg'),
  ('instagram', '/logos/instagram.svg', 'Instagram logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/instagram-icon.svg'),
  ('reddit', '/logos/reddit.svg', 'Reddit logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/reddit.svg'),
  ('bitcoin', '/logos/bitcoin.svg', 'Bitcoin logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/btc.svg'),
  ('adobe', '/logos/adobe.svg', 'Adobe logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/adobe.svg'),
  ('ethereum', '/logos/ethereum.svg', 'Ethereum logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/eth.svg'),
  ('uber', '/logos/uber.svg', 'Uber logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/uber_light.svg'),
  ('github', '/logos/github.svg', 'GitHub logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/github_light.svg'),
  ('slack', '/logos/slack.svg', 'Slack logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/slack.svg'),
  ('ibm', '/logos/ibm.svg', 'IBM logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/ibm.svg'),
  ('ebay', '/logos/ebay.svg', 'Ebay logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/ebay.svg'),
  ('tiktok', '/logos/tiktok.svg', 'TikTok logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/tiktok-icon-light.svg'),
  ('snapchat', '/logos/snapchat.svg', 'Snapchat logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/snapchat.svg'),
  ('xbox', '/logos/xbox.svg', 'Xbox logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/xbox.svg'),
  ('pinterest', '/logos/pinterest.svg', 'Pinterest logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/pinterest.svg'),
  ('playstation', '/logos/playstation.svg', 'PlayStation logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/playstation.svg'),
  ('meta', '/logos/meta.svg', 'Meta logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/meta.svg'),
  ('app-store', '/logos/app-store.svg', 'App Store logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/appstore.svg'),
  ('stripe', '/logos/stripe.svg', 'Stripe logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/stripe.svg'),
  ('dropbox', '/logos/dropbox.svg', 'Dropbox logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/dropbox.svg'),
  ('notion', '/logos/notion.svg', 'Notion logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/notion.svg'),
  ('google-play', '/logos/google-play.svg', 'Google Play logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/googleplay.svg'),
  ('zoom', '/logos/zoom.svg', 'Zoom logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/zoom.svg'),
  ('android', '/logos/android.svg', 'Android logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/android-icon.svg'),
  ('google-maps', '/logos/google-maps.svg', 'Google Maps logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/googleMaps.svg'),
  ('prime-video', '/logos/prime-video.svg', 'Prime video logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/prime-video.svg'),
  ('x', '/logos/x.svg', 'X logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/x.svg'),
  ('microsoft-teams', '/logos/microsoft-teams.svg', 'Microsoft Teams logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft-teams.svg'),
  ('google-drive', '/logos/google-drive.svg', 'Google Drive logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/drive.svg'),
  ('binance', '/logos/binance.svg', 'Binance logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/binance.svg'),
  ('twitch', '/logos/twitch.svg', 'Twitch logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/twitch.svg'),
  ('m-pesa', '/logos/m-pesa.svg', 'M-PESA logo', 'Vodafone · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:M-PESA_LOGO-01.svg'),
  ('safaricom', '/logos/safaricom.svg', 'Safaricom logo', 'SeekLogo · Wikimedia Commons', 'CC0 · https://commons.wikimedia.org/wiki/File:Safaricom-logo-png_seeklogo-530479.svg'),
  ('kenya-airways', '/logos/kenya-airways.svg', 'Kenya Airways logo', 'Kenya Airways · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Kenya_Airways_Logo.svg'),
  ('co-operative-bank', '/logos/co-operative-bank.svg', 'Co-operative Bank logo', 'Coopbank of Kenya · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Coopbanklogo.jpg'),
  ('jumia', '/logos/jumia.svg', 'Jumia logo', 'JumiaGroup · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:JumiaLogo_(14).png'),
  ('mtn', '/logos/mtn.svg', 'MTN logo', 'MTN · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:MTN_Logo.svg'),
  ('dstv', '/logos/dstv.svg', 'DStv logo', 'Gadgenator · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:DStv_Logo_2012.png'),
  ('shoprite', '/logos/shoprite.svg', 'Shoprite logo', 'Martin a1999a · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Logo_-_Shoprite_-_SUPERMARCE.jpg'),
  ('ecobank', '/logos/ecobank.svg', 'Ecobank logo', 'Ecobank Transnational Incorporated · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Ecobank_Logo.svg'),
  ('ethiopian-airlines', '/logos/ethiopian-airlines.svg', 'Ethiopian Airlines logo', 'Ethiopian Airlines · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Ethiopian_Airlines_Logo.svg'),
  ('absa', '/logos/absa.svg', 'Absa logo', 'Absa Group Limited · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Absa_Logo.svg'),
  ('flutterwave', '/logos/flutterwave.svg', 'Flutterwave logo', 'Opelogbon · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Flutterwave_Logo.png')
) as v(asset_key,public_url,alt_text,attribution,licence)
join public.question_sources s on s.source_key='logo_rush_assets'
on conflict(provider,asset_key) do update set public_url=excluded.public_url,alt_text=excluded.alt_text,attribution=excluded.attribution,licence=excluded.licence,source_id=excluded.source_id;

insert into public.questions(slug,pack_id,category_id,game_mode,prompt,explanation,media_id,difficulty,duration_seconds,base_points,tags,status,source_id,fact_checked_at)
select v.slug,p.id,c.id,'logo_quiz','Which brand owns this logo?',concat('This is the ',v.brand_name,' logo.'),m.id,v.difficulty,20,v.points,array['logo',v.region], 'approved',s.id,now()
from (values
  ('logo_linkedin', 'linkedin', 'LinkedIn', 1, 100, 'international'),
  ('logo_paypal', 'paypal', 'PayPal', 1, 100, 'international'),
  ('logo_netflix', 'netflix', 'Netflix', 1, 100, 'international'),
  ('logo_youtube', 'youtube', 'YouTube', 1, 100, 'international'),
  ('logo_google', 'google', 'Google', 1, 100, 'international'),
  ('logo_nvidia', 'nvidia', 'NVIDIA', 1, 100, 'international'),
  ('logo_discord', 'discord', 'Discord', 1, 100, 'international'),
  ('logo_facebook', 'facebook', 'Facebook', 1, 100, 'international'),
  ('logo_cisco', 'cisco', 'Cisco', 1, 100, 'international'),
  ('logo_spotify', 'spotify', 'Spotify', 1, 100, 'international'),
  ('logo_telegram', 'telegram', 'Telegram', 1, 100, 'international'),
  ('logo_microsoft', 'microsoft', 'Microsoft', 1, 100, 'international'),
  ('logo_windows', 'windows', 'Windows', 1, 100, 'international'),
  ('logo_microsoft_azure', 'microsoft-azure', 'Microsoft Azure', 1, 100, 'international'),
  ('logo_cloudflare', 'cloudflare', 'Cloudflare', 1, 100, 'international'),
  ('logo_chrome', 'chrome', 'Chrome', 1, 100, 'international'),
  ('logo_amazon_web_services', 'amazon-web-services', 'Amazon Web Services', 1, 100, 'international'),
  ('logo_apple', 'apple', 'Apple', 1, 100, 'international'),
  ('logo_whatsapp', 'whatsapp', 'WhatsApp', 1, 100, 'international'),
  ('logo_disney', 'disney', 'Disney+', 1, 100, 'international'),
  ('logo_shopify', 'shopify', 'Shopify', 1, 100, 'international'),
  ('logo_canva', 'canva', 'Canva', 1, 100, 'international'),
  ('logo_airbnb', 'airbnb', 'Airbnb', 1, 100, 'international'),
  ('logo_safari', 'safari', 'Safari', 1, 100, 'international'),
  ('logo_firefox', 'firefox', 'Firefox', 1, 100, 'international'),
  ('logo_instagram', 'instagram', 'Instagram', 1, 100, 'international'),
  ('logo_reddit', 'reddit', 'Reddit', 1, 100, 'international'),
  ('logo_bitcoin', 'bitcoin', 'Bitcoin', 1, 100, 'international'),
  ('logo_adobe', 'adobe', 'Adobe', 1, 100, 'international'),
  ('logo_ethereum', 'ethereum', 'Ethereum', 1, 100, 'international'),
  ('logo_uber', 'uber', 'Uber', 2, 150, 'international'),
  ('logo_github', 'github', 'GitHub', 2, 150, 'international'),
  ('logo_slack', 'slack', 'Slack', 2, 150, 'international'),
  ('logo_ibm', 'ibm', 'IBM', 2, 150, 'international'),
  ('logo_ebay', 'ebay', 'Ebay', 2, 150, 'international'),
  ('logo_tiktok', 'tiktok', 'TikTok', 2, 150, 'international'),
  ('logo_snapchat', 'snapchat', 'Snapchat', 2, 150, 'international'),
  ('logo_xbox', 'xbox', 'Xbox', 2, 150, 'international'),
  ('logo_pinterest', 'pinterest', 'Pinterest', 2, 150, 'international'),
  ('logo_playstation', 'playstation', 'PlayStation', 2, 150, 'international'),
  ('logo_meta', 'meta', 'Meta', 2, 150, 'international'),
  ('logo_app_store', 'app-store', 'App Store', 2, 150, 'international'),
  ('logo_stripe', 'stripe', 'Stripe', 2, 150, 'international'),
  ('logo_dropbox', 'dropbox', 'Dropbox', 2, 150, 'international'),
  ('logo_notion', 'notion', 'Notion', 2, 150, 'international'),
  ('logo_google_play', 'google-play', 'Google Play', 2, 150, 'international'),
  ('logo_zoom', 'zoom', 'Zoom', 2, 150, 'international'),
  ('logo_android', 'android', 'Android', 2, 150, 'international'),
  ('logo_google_maps', 'google-maps', 'Google Maps', 2, 150, 'international'),
  ('logo_prime_video', 'prime-video', 'Prime video', 2, 150, 'international'),
  ('logo_x', 'x', 'X', 2, 150, 'international'),
  ('logo_microsoft_teams', 'microsoft-teams', 'Microsoft Teams', 2, 150, 'international'),
  ('logo_google_drive', 'google-drive', 'Google Drive', 2, 150, 'international'),
  ('logo_binance', 'binance', 'Binance', 2, 150, 'international'),
  ('logo_twitch', 'twitch', 'Twitch', 2, 150, 'international'),
  ('logo_m_pesa', 'm-pesa', 'M-PESA', 2, 150, 'kenya'),
  ('logo_safaricom', 'safaricom', 'Safaricom', 2, 150, 'kenya'),
  ('logo_kenya_airways', 'kenya-airways', 'Kenya Airways', 2, 150, 'kenya'),
  ('logo_co_operative_bank', 'co-operative-bank', 'Co-operative Bank', 2, 150, 'kenya'),
  ('logo_jumia', 'jumia', 'Jumia', 3, 200, 'africa'),
  ('logo_mtn', 'mtn', 'MTN', 3, 200, 'africa'),
  ('logo_dstv', 'dstv', 'DStv', 3, 200, 'africa'),
  ('logo_shoprite', 'shoprite', 'Shoprite', 3, 200, 'africa'),
  ('logo_ecobank', 'ecobank', 'Ecobank', 3, 200, 'africa'),
  ('logo_ethiopian_airlines', 'ethiopian-airlines', 'Ethiopian Airlines', 3, 200, 'africa'),
  ('logo_absa', 'absa', 'Absa', 3, 200, 'africa'),
  ('logo_flutterwave', 'flutterwave', 'Flutterwave', 3, 200, 'africa')
) as v(slug,asset_key,brand_name,difficulty,points,region)
join public.content_packs p on p.code='logo_rush'
join public.categories c on c.code='brand_logos'
join public.media_assets m on m.provider='game_mavelas_logos' and m.asset_key=v.asset_key
join public.question_sources s on s.source_key='logo_rush_assets'
on conflict(slug) do update set pack_id=excluded.pack_id,category_id=excluded.category_id,game_mode=excluded.game_mode,prompt=excluded.prompt,explanation=excluded.explanation,media_id=excluded.media_id,difficulty=excluded.difficulty,duration_seconds=excluded.duration_seconds,base_points=excluded.base_points,tags=excluded.tags,status='approved',source_id=excluded.source_id,fact_checked_at=now(),updated_at=now();

insert into public.question_options(question_id,position,option_text,is_correct)
select q.id,v.position,v.option_text,v.is_correct
from (values
  ('logo_linkedin', 1, 'LinkedIn', true),
  ('logo_linkedin', 2, 'PayPal', false),
  ('logo_linkedin', 3, 'Windows', false),
  ('logo_linkedin', 4, 'Safari', false),
  ('logo_paypal', 1, 'PayPal', true),
  ('logo_paypal', 2, 'Cisco', false),
  ('logo_paypal', 3, 'Disney+', false),
  ('logo_paypal', 4, 'Uber', false),
  ('logo_netflix', 1, 'Netflix', true),
  ('logo_netflix', 2, 'Chrome', false),
  ('logo_netflix', 3, 'Reddit', false),
  ('logo_netflix', 4, 'Xbox', false),
  ('logo_youtube', 1, 'YouTube', true),
  ('logo_youtube', 2, 'Airbnb', false),
  ('logo_youtube', 3, 'IBM', false),
  ('logo_youtube', 4, 'Notion', false),
  ('logo_google', 1, 'Google', true),
  ('logo_google', 2, 'Ethereum', false),
  ('logo_google', 3, 'Meta', false),
  ('logo_google', 4, 'Microsoft Teams', false),
  ('logo_nvidia', 1, 'NVIDIA', true),
  ('logo_nvidia', 2, 'Snapchat', false),
  ('logo_nvidia', 3, 'Android', false),
  ('logo_nvidia', 4, 'YouTube', false),
  ('logo_discord', 1, 'Discord', true),
  ('logo_discord', 2, 'Dropbox', false),
  ('logo_discord', 3, 'Twitch', false),
  ('logo_discord', 4, 'Microsoft', false),
  ('logo_facebook', 1, 'Facebook', true),
  ('logo_facebook', 2, 'X', false),
  ('logo_facebook', 3, 'Discord', false),
  ('logo_facebook', 4, 'WhatsApp', false),
  ('logo_cisco', 1, 'Cisco', true),
  ('logo_cisco', 2, 'Netflix', false),
  ('logo_cisco', 3, 'Cloudflare', false),
  ('logo_cisco', 4, 'Instagram', false),
  ('logo_spotify', 1, 'Spotify', true),
  ('logo_spotify', 2, 'Telegram', false),
  ('logo_spotify', 3, 'Canva', false),
  ('logo_spotify', 4, 'Slack', false),
  ('logo_telegram', 1, 'Telegram', true),
  ('logo_telegram', 2, 'Apple', false),
  ('logo_telegram', 3, 'Adobe', false),
  ('logo_telegram', 4, 'PlayStation', false),
  ('logo_microsoft', 1, 'Microsoft', true),
  ('logo_microsoft', 2, 'Firefox', false),
  ('logo_microsoft', 3, 'TikTok', false),
  ('logo_microsoft', 4, 'Zoom', false),
  ('logo_windows', 1, 'Windows', true),
  ('logo_windows', 2, 'GitHub', false),
  ('logo_windows', 3, 'Stripe', false),
  ('logo_windows', 4, 'Binance', false),
  ('logo_microsoft_azure', 1, 'Microsoft Azure', true),
  ('logo_microsoft_azure', 2, 'Pinterest', false),
  ('logo_microsoft_azure', 3, 'Prime video', false),
  ('logo_microsoft_azure', 4, 'NVIDIA', false),
  ('logo_cloudflare', 1, 'Cloudflare', true),
  ('logo_cloudflare', 2, 'Google Play', false),
  ('logo_cloudflare', 3, 'PayPal', false),
  ('logo_cloudflare', 4, 'Windows', false),
  ('logo_chrome', 1, 'Chrome', true),
  ('logo_chrome', 2, 'Google Drive', false),
  ('logo_chrome', 3, 'Cisco', false),
  ('logo_chrome', 4, 'Shopify', false),
  ('logo_amazon_web_services', 1, 'Amazon Web Services', true),
  ('logo_amazon_web_services', 2, 'Google', false),
  ('logo_amazon_web_services', 3, 'Chrome', false),
  ('logo_amazon_web_services', 4, 'Bitcoin', false),
  ('logo_apple', 1, 'Apple', true),
  ('logo_apple', 2, 'Microsoft', false),
  ('logo_apple', 3, 'Safari', false),
  ('logo_apple', 4, 'Ebay', false),
  ('logo_whatsapp', 1, 'WhatsApp', true),
  ('logo_whatsapp', 2, 'Disney+', false),
  ('logo_whatsapp', 3, 'Uber', false),
  ('logo_whatsapp', 4, 'App Store', false),
  ('logo_disney', 1, 'Disney+', true),
  ('logo_disney', 2, 'Reddit', false),
  ('logo_disney', 3, 'Xbox', false),
  ('logo_disney', 4, 'Google Maps', false),
  ('logo_shopify', 1, 'Shopify', true),
  ('logo_shopify', 2, 'IBM', false),
  ('logo_shopify', 3, 'Notion', false),
  ('logo_shopify', 4, 'LinkedIn', false),
  ('logo_canva', 1, 'Canva', true),
  ('logo_canva', 2, 'Meta', false),
  ('logo_canva', 3, 'Microsoft Teams', false),
  ('logo_canva', 4, 'Facebook', false),
  ('logo_airbnb', 1, 'Airbnb', true),
  ('logo_airbnb', 2, 'Android', false),
  ('logo_airbnb', 3, 'YouTube', false),
  ('logo_airbnb', 4, 'Cloudflare', false),
  ('logo_safari', 1, 'Safari', true),
  ('logo_safari', 2, 'Twitch', false),
  ('logo_safari', 3, 'Telegram', false),
  ('logo_safari', 4, 'Canva', false),
  ('logo_firefox', 1, 'Firefox', true),
  ('logo_firefox', 2, 'Discord', false),
  ('logo_firefox', 3, 'Apple', false),
  ('logo_firefox', 4, 'Ethereum', false),
  ('logo_instagram', 1, 'Instagram', true),
  ('logo_instagram', 2, 'Microsoft Azure', false),
  ('logo_instagram', 3, 'Firefox', false),
  ('logo_instagram', 4, 'Snapchat', false),
  ('logo_reddit', 1, 'Reddit', true),
  ('logo_reddit', 2, 'Shopify', false),
  ('logo_reddit', 3, 'Slack', false),
  ('logo_reddit', 4, 'Dropbox', false),
  ('logo_bitcoin', 1, 'Bitcoin', true),
  ('logo_bitcoin', 2, 'Adobe', false),
  ('logo_bitcoin', 3, 'PlayStation', false),
  ('logo_bitcoin', 4, 'X', false),
  ('logo_adobe', 1, 'Adobe', true),
  ('logo_adobe', 2, 'TikTok', false),
  ('logo_adobe', 3, 'Zoom', false),
  ('logo_adobe', 4, 'Netflix', false),
  ('logo_ethereum', 1, 'Ethereum', true),
  ('logo_ethereum', 2, 'Stripe', false),
  ('logo_ethereum', 3, 'Binance', false),
  ('logo_ethereum', 4, 'Spotify', false),
  ('logo_uber', 1, 'Uber', true),
  ('logo_uber', 2, 'Prime video', false),
  ('logo_uber', 3, 'NVIDIA', false),
  ('logo_uber', 4, 'Amazon Web Services', false),
  ('logo_github', 1, 'GitHub', true),
  ('logo_github', 2, 'PayPal', false),
  ('logo_github', 3, 'Windows', false),
  ('logo_github', 4, 'Safari', false),
  ('logo_slack', 1, 'Slack', true),
  ('logo_slack', 2, 'Cisco', false),
  ('logo_slack', 3, 'Disney+', false),
  ('logo_slack', 4, 'Uber', false),
  ('logo_ibm', 1, 'IBM', true),
  ('logo_ibm', 2, 'Chrome', false),
  ('logo_ibm', 3, 'Reddit', false),
  ('logo_ibm', 4, 'Pinterest', false),
  ('logo_ebay', 1, 'Ebay', true),
  ('logo_ebay', 2, 'Airbnb', false),
  ('logo_ebay', 3, 'IBM', false),
  ('logo_ebay', 4, 'Google Play', false),
  ('logo_tiktok', 1, 'TikTok', true),
  ('logo_tiktok', 2, 'Ethereum', false),
  ('logo_tiktok', 3, 'App Store', false),
  ('logo_tiktok', 4, 'Google Drive', false),
  ('logo_snapchat', 1, 'Snapchat', true),
  ('logo_snapchat', 2, 'Xbox', false),
  ('logo_snapchat', 3, 'Google Maps', false),
  ('logo_snapchat', 4, 'Google', false),
  ('logo_xbox', 1, 'Xbox', true),
  ('logo_xbox', 2, 'Notion', false),
  ('logo_xbox', 3, 'LinkedIn', false),
  ('logo_xbox', 4, 'Microsoft', false),
  ('logo_pinterest', 1, 'Pinterest', true),
  ('logo_pinterest', 2, 'Microsoft Teams', false),
  ('logo_pinterest', 3, 'Facebook', false),
  ('logo_pinterest', 4, 'WhatsApp', false),
  ('logo_playstation', 1, 'PlayStation', true),
  ('logo_playstation', 2, 'YouTube', false),
  ('logo_playstation', 3, 'Cloudflare', false),
  ('logo_playstation', 4, 'Instagram', false),
  ('logo_meta', 1, 'Meta', true),
  ('logo_meta', 2, 'Telegram', false),
  ('logo_meta', 3, 'Canva', false),
  ('logo_meta', 4, 'Slack', false),
  ('logo_app_store', 1, 'App Store', true),
  ('logo_app_store', 2, 'Apple', false),
  ('logo_app_store', 3, 'Adobe', false),
  ('logo_app_store', 4, 'PlayStation', false),
  ('logo_stripe', 1, 'Stripe', true),
  ('logo_stripe', 2, 'Firefox', false),
  ('logo_stripe', 3, 'TikTok', false),
  ('logo_stripe', 4, 'Android', false),
  ('logo_dropbox', 1, 'Dropbox', true),
  ('logo_dropbox', 2, 'GitHub', false),
  ('logo_dropbox', 3, 'Stripe', false),
  ('logo_dropbox', 4, 'Twitch', false),
  ('logo_notion', 1, 'Notion', true),
  ('logo_notion', 2, 'Pinterest', false),
  ('logo_notion', 3, 'X', false),
  ('logo_notion', 4, 'Discord', false),
  ('logo_google_play', 1, 'Google Play', true),
  ('logo_google_play', 2, 'Zoom', false),
  ('logo_google_play', 3, 'Netflix', false),
  ('logo_google_play', 4, 'Microsoft Azure', false),
  ('logo_zoom', 1, 'Zoom', true),
  ('logo_zoom', 2, 'Binance', false),
  ('logo_zoom', 3, 'Spotify', false),
  ('logo_zoom', 4, 'Shopify', false),
  ('logo_android', 1, 'Android', true),
  ('logo_android', 2, 'NVIDIA', false),
  ('logo_android', 3, 'Amazon Web Services', false),
  ('logo_android', 4, 'Bitcoin', false),
  ('logo_google_maps', 1, 'Google Maps', true),
  ('logo_google_maps', 2, 'Windows', false),
  ('logo_google_maps', 3, 'Safari', false),
  ('logo_google_maps', 4, 'Ebay', false),
  ('logo_prime_video', 1, 'Prime video', true),
  ('logo_prime_video', 2, 'Disney+', false),
  ('logo_prime_video', 3, 'Uber', false),
  ('logo_prime_video', 4, 'App Store', false),
  ('logo_x', 1, 'X', true),
  ('logo_x', 2, 'Reddit', false),
  ('logo_x', 3, 'Xbox', false),
  ('logo_x', 4, 'Google Maps', false),
  ('logo_microsoft_teams', 1, 'Microsoft Teams', true),
  ('logo_microsoft_teams', 2, 'IBM', false),
  ('logo_microsoft_teams', 3, 'Notion', false),
  ('logo_microsoft_teams', 4, 'PayPal', false),
  ('logo_google_drive', 1, 'Google Drive', true),
  ('logo_google_drive', 2, 'Meta', false),
  ('logo_google_drive', 3, 'Microsoft Teams', false),
  ('logo_google_drive', 4, 'Cisco', false),
  ('logo_binance', 1, 'Binance', true),
  ('logo_binance', 2, 'Android', false),
  ('logo_binance', 3, 'Google', false),
  ('logo_binance', 4, 'Chrome', false),
  ('logo_twitch', 1, 'Twitch', true),
  ('logo_twitch', 2, 'LinkedIn', false),
  ('logo_twitch', 3, 'Microsoft', false),
  ('logo_twitch', 4, 'Airbnb', false),
  ('logo_m_pesa', 1, 'M-PESA', true),
  ('logo_m_pesa', 2, 'Kenya Airways', false),
  ('logo_m_pesa', 3, 'Safaricom', false),
  ('logo_m_pesa', 4, 'Co-operative Bank', false),
  ('logo_safaricom', 1, 'Safaricom', true),
  ('logo_safaricom', 2, 'Co-operative Bank', false),
  ('logo_safaricom', 3, 'Kenya Airways', false),
  ('logo_safaricom', 4, 'M-PESA', false),
  ('logo_kenya_airways', 1, 'Kenya Airways', true),
  ('logo_kenya_airways', 2, 'M-PESA', false),
  ('logo_kenya_airways', 3, 'Co-operative Bank', false),
  ('logo_kenya_airways', 4, 'Safaricom', false),
  ('logo_co_operative_bank', 1, 'Co-operative Bank', true),
  ('logo_co_operative_bank', 2, 'Safaricom', false),
  ('logo_co_operative_bank', 3, 'M-PESA', false),
  ('logo_co_operative_bank', 4, 'Kenya Airways', false),
  ('logo_jumia', 1, 'Jumia', true),
  ('logo_jumia', 2, 'MTN', false),
  ('logo_jumia', 3, 'Ethiopian Airlines', false),
  ('logo_jumia', 4, 'DStv', false),
  ('logo_mtn', 1, 'MTN', true),
  ('logo_mtn', 2, 'Jumia', false),
  ('logo_mtn', 3, 'Ethiopian Airlines', false),
  ('logo_mtn', 4, 'DStv', false),
  ('logo_dstv', 1, 'DStv', true),
  ('logo_dstv', 2, 'Jumia', false),
  ('logo_dstv', 3, 'Ethiopian Airlines', false),
  ('logo_dstv', 4, 'MTN', false),
  ('logo_shoprite', 1, 'Shoprite', true),
  ('logo_shoprite', 2, 'Jumia', false),
  ('logo_shoprite', 3, 'Ethiopian Airlines', false),
  ('logo_shoprite', 4, 'MTN', false),
  ('logo_ecobank', 1, 'Ecobank', true),
  ('logo_ecobank', 2, 'Jumia', false),
  ('logo_ecobank', 3, 'Ethiopian Airlines', false),
  ('logo_ecobank', 4, 'MTN', false),
  ('logo_ethiopian_airlines', 1, 'Ethiopian Airlines', true),
  ('logo_ethiopian_airlines', 2, 'Jumia', false),
  ('logo_ethiopian_airlines', 3, 'Ecobank', false),
  ('logo_ethiopian_airlines', 4, 'MTN', false),
  ('logo_absa', 1, 'Absa', true),
  ('logo_absa', 2, 'Jumia', false),
  ('logo_absa', 3, 'Ecobank', false),
  ('logo_absa', 4, 'MTN', false),
  ('logo_flutterwave', 1, 'Flutterwave', true),
  ('logo_flutterwave', 2, 'Jumia', false),
  ('logo_flutterwave', 3, 'Ecobank', false),
  ('logo_flutterwave', 4, 'MTN', false)
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
