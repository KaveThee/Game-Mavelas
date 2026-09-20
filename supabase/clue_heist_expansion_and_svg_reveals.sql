-- Expand Clue Heist to three full five-mystery rotations and replace the
-- generic cartoon portraits with dedicated editorial SVG reveal posters.

create temporary table clue_heist_seed(
  slug text primary key, answer text, asset_slug text, category_code text,
  explanation text, difficulty smallint, aliases text, clues text
) on commit drop;

insert into clue_heist_seed values
('clue_heist_faith_kipyegon','Faith Kipyegon','faith-kipyegon','sports','Faith Kipyegon is a Kenyan middle-distance runner and multiple Olympic 1500-metre champion.',2,'Faith Kipyegon|Kipyegon',
'I built my career around running a few laps, not a marathon.|I grew up in Kenya''s Rift Valley.|I first competed internationally as a teenager.|Cross-country running was part of my early career.|My signature race rewards speed and tactics.|I have won major titles on three continents.|I became a mother and returned to elite competition.|I have repeatedly broken world records.|I race in middle-distance athletics.|One of my events is the mile.|My best-known event is 1500 metres.|I have won World Championship gold medals.|I have won Olympic gold more than once.|I represent Kenya.|My finishing kick is one of my trademarks.|My first name begins with F.|My surname begins with K.|My first name is Faith.|My surname is Kipyegon.|I am Faith Kipyegon.'),
('clue_heist_ferdinand_omanyala','Ferdinand Omanyala','ferdinand-omanyala','sports','Ferdinand Omanyala is a Kenyan sprinter known for record-setting performances in the 100 metres.',2,'Ferdinand Omanyala|Omanyala',
'My main event is over almost as soon as it starts.|I changed sporting direction while at university.|Explosive acceleration matters more than endurance in my event.|I compete in a straight lane.|My sport measures hundredths of a second.|I have represented an East African nation better known for distance running.|I became a Commonwealth champion.|My breakthrough helped reshape perceptions of Kenyan sprinting.|I race outdoors and indoors.|I have competed in the 60 metres.|My signature event is the 100 metres.|I have held the African 100-metre record.|I represent Kenya.|I am nicknamed Africa''s fastest man.|My first name has nine letters.|My surname begins with O.|My first name is Ferdinand.|My surname contains “manya”.|My surname is Omanyala.|I am Ferdinand Omanyala.'),
('clue_heist_david_rudisha','David Rudisha','david-rudisha','sports','David Rudisha is a Kenyan Olympic 800-metre champion whose London 2012 final produced a world record.',3,'David Rudisha|Rudisha',
'My greatest race lasted less than two minutes.|I come from a family with an Olympic athletics connection.|I attended St Patrick''s High School in Iten.|Brother Colm O''Connell coached me.|My event demands both speed and endurance.|I usually complete two laps of an outdoor track.|I won major global titles for Kenya.|I was known for controlling races from the front.|One of my finest performances came in London.|That race was an Olympic final in 2012.|Every finisher in that final ran exceptionally fast.|I won Olympic gold twice.|I set a world record of 1:40.91.|My signature event is the 800 metres.|I am Kenyan.|My first name is David.|My surname begins with R.|My surname contains “disha”.|My surname is Rudisha.|I am David Rudisha.'),
('clue_heist_nelson_mandela','Nelson Mandela','nelson-mandela','kenyan_culture','Nelson Mandela was an anti-apartheid leader who spent 27 years imprisoned and became South Africa''s first Black president.',2,'Nelson Mandela|Mandela|Madiba',
'I trained as a lawyer.|I was born into a Thembu royal family.|My political struggle opposed a system of racial segregation.|I helped establish a youth league within a liberation movement.|A famous trial shaped my life.|I delivered a speech about an ideal worth dying for.|I spent many years on an island prison.|My prisoner number became globally recognised.|I spent 27 years in prison.|I was released in 1990.|I shared a Nobel Peace Prize.|I became president in 1994.|I was South Africa''s first Black president.|People often call me Madiba.|My life is closely linked with the fight against apartheid.|My first name begins with N.|My first name is Nelson.|My surname begins with M.|My surname is Mandela.|I am Nelson Mandela.'),
('clue_heist_trevor_noah','Trevor Noah','trevor-noah','entertainment','Trevor Noah is a South African comedian, author and former host of The Daily Show.',2,'Trevor Noah|Trevor|Noah',
'My childhood crossed boundaries created by law.|I grew up in Johannesburg.|I speak several languages.|Radio and television came before my biggest international job.|Stand-up comedy took me around the world.|I wrote a memoir about my childhood.|That memoir''s title describes my birth as illegal under apartheid.|I moved from South African entertainment to American television.|I became known for political satire.|I succeeded Jon Stewart.|I hosted an American late-night programme.|That programme was The Daily Show.|I am South African.|My memoir is Born a Crime.|I am a comedian and author.|My first name begins with T.|My first name is Trevor.|My surname begins with N.|My surname is Noah.|I am Trevor Noah.'),
('clue_heist_burna_boy','Burna Boy','burna-boy','entertainment','Burna Boy is a Nigerian singer and Grammy-winning global Afrobeats star.',2,'Burna Boy|Damini Ogulu|Damini Ebunoluwa Ogulu',
'My stage name is not the name on my birth certificate.|Music runs in my family.|I was born in Port Harcourt.|My sound blends African styles with dancehall and reggae influences.|I call my style Afro-fusion.|I released an album titled Outside.|One of my albums is named African Giant.|I have performed at major festivals around the world.|I collaborated on the song Location with Dave.|I have received a Grammy Award.|The winning album was Twice as Tall.|I am Nigerian.|I am associated with Afrobeats.|My given first name is Damini.|My family name is Ogulu.|My stage name contains a word connected with fire.|The second word of my stage name is Boy.|The first word is Burna.|My stage name is Burna Boy.|I am Burna Boy.'),
('clue_heist_mohamed_salah','Mohamed Salah','mohamed-salah','sports','Mohamed Salah is an Egyptian footballer who became a Premier League and Champions League star.',2,'Mohamed Salah|Mo Salah|Salah',
'I began my senior career in North Africa.|A move to Switzerland helped launch my European career.|I am known for speed and left-footed finishing.|I have played club football in England and Italy.|I represented clubs in Florence and Rome.|I became a major star on Merseyside.|I have won the UEFA Champions League.|I have won the English Premier League.|I play mainly as a forward.|I have won the Premier League Golden Boot.|I represent Egypt.|I am nicknamed the Egyptian King.|Fans often shorten my first name to Mo.|I am strongly associated with Liverpool.|I commonly wear number 11.|My first name begins with M.|My first name is Mohamed.|My surname begins with S.|My surname is Salah.|I am Mohamed Salah.'),
('clue_heist_didier_drogba','Didier Drogba','didier-drogba','sports','Didier Drogba is an Ivorian football legend celebrated for his leadership and success with Chelsea.',3,'Didier Drogba|Drogba',
'I was born in West Africa and spent part of my childhood in France.|I developed relatively late as an elite footballer.|Power and strength were hallmarks of my game.|I played for Marseille before moving to England.|I became famous in west London.|I was a centre-forward.|I won multiple English league titles.|I scored in major cup finals.|A 2012 final became one of my defining nights.|I scored both a late equaliser and the winning penalty that night.|That trophy was the UEFA Champions League.|I became a legend at Chelsea.|I captained my national team.|I represent Côte d''Ivoire.|I am known as an Ivorian football icon.|My first name begins with D.|My first name is Didier.|My surname begins with D.|My surname is Drogba.|I am Didier Drogba.'),
('clue_heist_barack_obama','Barack Obama','barack-obama','kenyan_culture','Barack Obama was the 44th President of the United States and has family roots in Kenya.',2,'Barack Obama|Obama|Barack Hussein Obama',
'I worked as a community organiser before entering national politics.|I taught constitutional law.|My birthplace is an island in the Pacific.|My father was born in Kenya.|I served in a state senate.|A convention speech in 2004 raised my national profile.|I later served as a United States senator.|My campaign became associated with the word Hope.|I won a presidential election in 2008.|I won a second term in 2012.|I received the Nobel Peace Prize.|I was the first African American U.S. president.|I served immediately before Donald Trump''s first term.|I was the 44th U.S. president.|My wife is Michelle.|My first name begins with B.|My first name is Barack.|My surname begins with O.|My surname is Obama.|I am Barack Obama.'),
('clue_heist_mekatilili_wa_menza','Mekatilili wa Menza','mekatilili-wa-menza','kenyan_culture','Mekatilili wa Menza was a Giriama leader remembered for resisting British colonial rule on Kenya''s coast.',3,'Mekatilili wa Menza|Mekatilili|Mnyazi wa Menza',
'I am remembered for resistance rather than elected office.|My story is rooted on the East African coast.|I belonged to the Giriama community.|I challenged colonial demands for labour and taxation.|Public speaking helped me mobilise people.|A traditional dance became part of my organising.|That dance is called kifudu.|I worked alongside Wanje wa Mwadorikola.|Colonial authorities arrested me.|I was deported far from my homeland.|I escaped and returned to continue resisting.|My activism intensified around 1913.|I opposed British colonial rule.|I am a Kenyan historical heroine.|My birth name is also remembered as Mnyazi wa Menza.|My best-known name begins with M.|The middle words are “wa”.|My final name is Menza.|I am Mekatilili wa Menza.|My identity is Mekatilili wa Menza.');

insert into public.media_assets(asset_type,provider,asset_key,public_url,alt_text,attribution,licence,width,height)
select 'image','game_mavelas_clue_heist',v.asset_slug,'/clue-heist/'||v.asset_slug||'.svg',
  'Editorial vector reveal poster for '||v.answer,'Original Game Mavelas vector artwork','Project asset',1200,900
from (values
 ('cristiano-ronaldo','Cristiano Ronaldo'),('lionel-messi','Lionel Messi'),('lupita-nyongo','Lupita Nyong''o'),
 ('eliud-kipchoge','Eliud Kipchoge'),('wangari-maathai','Wangari Maathai'),
 ('faith-kipyegon','Faith Kipyegon'),('ferdinand-omanyala','Ferdinand Omanyala'),('david-rudisha','David Rudisha'),
 ('nelson-mandela','Nelson Mandela'),('trevor-noah','Trevor Noah'),('burna-boy','Burna Boy'),
 ('mohamed-salah','Mohamed Salah'),('didier-drogba','Didier Drogba'),('barack-obama','Barack Obama'),
 ('mekatilili-wa-menza','Mekatilili wa Menza')
) v(asset_slug,answer)
on conflict(provider,asset_key) do update set public_url=excluded.public_url,alt_text=excluded.alt_text,
  attribution=excluded.attribution,licence=excluded.licence,width=excluded.width,height=excluded.height;

insert into public.questions(slug,pack_id,category_id,game_mode,prompt,explanation,difficulty,duration_seconds,base_points,tags,status,source_id,fact_checked_at)
select s.slug,p.id,c.id,'guess_image','Mystery image',s.explanation,s.difficulty,120,100,
  array['clue_heist',s.category_code],'approved',src.id,now()
from clue_heist_seed s
join public.content_packs p on p.code='kenya_core'
join public.categories c on c.code=s.category_code
join public.question_sources src on src.source_key='editorial'
on conflict(slug) do update set explanation=excluded.explanation,difficulty=excluded.difficulty,
  duration_seconds=120,base_points=100,tags=excluded.tags,status='approved',fact_checked_at=now(),updated_at=now();

insert into public.clue_heist_mysteries(question_id,answer_media_id)
select q.id,m.id from public.questions q
join public.media_assets m on m.provider='game_mavelas_clue_heist'
 and m.asset_key=replace(replace(q.slug,'clue_heist_',''),'_','-')
where q.slug like 'clue_heist_%'
on conflict(question_id) do update set answer_media_id=excluded.answer_media_id;

insert into public.clue_heist_aliases(question_id,answer_text)
select q.id,a.answer_text from clue_heist_seed s join public.questions q on q.slug=s.slug
cross join lateral unnest(string_to_array(s.aliases,'|')) a(answer_text)
on conflict do nothing;

insert into public.clue_heist_clues(question_id,position,clue_text)
select q.id,c.ordinality::smallint,c.clue_text
from clue_heist_seed s join public.questions q on q.slug=s.slug
cross join lateral unnest(string_to_array(s.clues,'|')) with ordinality c(clue_text,ordinality)
on conflict(question_id,position) do update set clue_text=excluded.clue_text;
