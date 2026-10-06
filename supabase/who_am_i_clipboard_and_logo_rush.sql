-- Who Am I authenticity and interaction upgrade, plus Logo Rush.

-- Give the active guesser a full 90 seconds.
update public.questions
set duration_seconds = 90, updated_at = now()
where game_mode = 'who_am_i' and status = 'approved';

update public.round_template_steps
set seconds_per_question = 90
where template_id = (select id from public.round_templates where code = 'who_am_i_kenya');

-- Build a deep authentic portrait pool. Every image is cached locally, while its
-- source and licence remain traceable in the database and embedded SVG metadata.
insert into public.question_sources(source_key,title,source_url,licence,notes,checked_at)
values('who_am_i_commons','Who Am I authentic portraits','https://commons.wikimedia.org/','Mixed Wikimedia Commons licences','Verified portraits cached as self-contained local SVG files.',now())
on conflict(source_key) do update set title=excluded.title,source_url=excluded.source_url,licence=excluded.licence,notes=excluded.notes,checked_at=excluded.checked_at;

insert into public.content_packs(code,title,description,region,is_active)
values('famous_faces','Famous Faces','Recognisable Kenyan, African, and global public figures.','world',true)
on conflict(code) do update set title=excluded.title,description=excluded.description,region=excluded.region,is_active=true;

insert into public.categories(code,title,icon,sort_order,is_active)
values('who_am_i_icons','Famous Faces','users',30,true)
on conflict(code) do update set title=excluded.title,icon=excluded.icon,sort_order=excluded.sort_order,is_active=true;

insert into public.media_assets(asset_type,provider,asset_key,public_url,alt_text,attribution,licence,source_id,width,height)
select 'image','game_mavelas',v.asset_key,v.public_url,v.alt_text,v.attribution,v.licence,s.id,720,720
from (values
  ('lupita-nyongo', '/celebrities/lupita-nyongo.svg', 'Photograph of Lupita Nyong''o', 'PhilipRomano · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:LupitaNyongo-byPhilipRomano3.jpg'),
  ('eliud-kipchoge', '/celebrities/eliud-kipchoge.svg', 'Photograph of Eliud Kipchoge', 'Denis Barthel · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Berlin-Marathon_2015_Runners_1.jpg'),
  ('faith-kipyegon', '/celebrities/faith-kipyegon.svg', 'Photograph of Faith Kipyegon', 'Erik van Leeuwen, attribution: Erik van Leeuwen (bron: Wikipedia). · Wikimedia Commons', 'GFDL · https://commons.wikimedia.org/wiki/File:Faith_Kipyegon_London_2017_(cropped2).jpg'),
  ('wangari-maathai', '/celebrities/wangari-maathai.svg', 'Photograph of Wangari Maathai', 'Kingkongphoto &amp; www.celebrity-photos.com from Laurel Maryland, USA · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Wangari_Matthai_2001_(cropped).jpg'),
  ('ferdinand-omanyala', '/celebrities/ferdinand-omanyala.svg', 'Photograph of Ferdinand Omanyala', 'Erik van Leeuwen, attribution: Erik van Leeuwen (bron: Wikipedia). · Wikimedia Commons', 'GFDL · https://commons.wikimedia.org/wiki/File:Ferdinand_Omanyala_Budapest_2023.jpg'),
  ('david-rudisha', '/celebrities/david-rudisha.svg', 'Photograph of David Rudisha', 'Erik van Leeuwen · Wikimedia Commons', 'GFDL · https://commons.wikimedia.org/wiki/File:David_Rudisha_Daegu_2011.jpg'),
  ('mwai-kibaki', '/celebrities/mwai-kibaki.svg', 'Photograph of Mwai Kibaki', 'Foreign and Commonwealth Office · Wikimedia Commons', 'OGL v1.0 · https://commons.wikimedia.org/wiki/File:Mwai_Kibaki_(cropped).jpg'),
  ('dedan-kimathi', '/celebrities/dedan-kimathi.svg', 'Photograph of Dedan Kimathi', 'Murungaru at English Wikipedia · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Statue_of_Dedan_Kimathi_Nairobi,_Kenya.jpg'),
  ('joy-adamson', '/celebrities/joy-adamson.svg', 'Photograph of Joy Adamson', 'Beni7612 · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:JoyAdamson%C3%89sElza.jpg'),
  ('william-ruto', '/celebrities/william-ruto.svg', 'Photograph of William Ruto', 'Presidenza della Repubblica · Wikimedia Commons', 'Attribution · https://commons.wikimedia.org/wiki/File:William_Ruto_2023_(cropped).jpg'),
  ('raila-odinga', '/celebrities/raila-odinga.svg', 'Photograph of Raila Odinga', 'World Economic Forum from Cologny, Switzerland · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Raila_Amolo_Odinga_2009_(cropped).jpg'),
  ('uhuru-kenyatta', '/celebrities/uhuru-kenyatta.svg', 'Photograph of Uhuru Kenyatta', 'Office of the Prime Minister - Ethiopia · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:PMO_IMG_5262_(40547346173)_(cropped).jpg'),
  ('nyashinski', '/celebrities/nyashinski.svg', 'Photograph of Nyashinski', 'Safari jpk · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Nyashinski.jpg'),
  ('victor-wanyama', '/celebrities/victor-wanyama.svg', 'Photograph of Victor Wanyama', 'Glasgow Celtic · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Victor_Wanyama.jpg'),
  ('catherine-kamau', '/celebrities/catherine-kamau.svg', 'Photograph of Catherine Kamau', 'WachukaK · Wikimedia Commons', 'CC0 · https://commons.wikimedia.org/wiki/File:Caterine_Kamau_-_The_Kalasa_International_Award_2017.jpg'),
  ('nelson-mandela', '/celebrities/nelson-mandela.svg', 'Photograph of Nelson Mandela', 'Kingkongphoto &amp; www.celebrity-photos.com from Laurel · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Nelson_Mandela_1994.jpg'),
  ('trevor-noah', '/celebrities/trevor-noah.svg', 'Photograph of Trevor Noah', 'Web Summit Qatar · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Trevor_Noah_(53554114243)_(portrait_crop).jpg'),
  ('burna-boy', '/celebrities/burna-boy.svg', 'Photograph of Burna Boy', 'Nuță Lucian from Cluj-Napoca, Romania · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Untold_2024_-Burna_Boy_(53926047977)_(cropped).jpg'),
  ('diamond-platnumz', '/celebrities/diamond-platnumz.svg', 'Photograph of Diamond Platnumz', 'Peter Bennett / ZIFF · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Diamond_Platnumz.jpg'),
  ('mohamed-salah', '/celebrities/mohamed-salah.svg', 'Photograph of Mohamed Salah', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Mohamed_Salah_Argentina_v_Egypt_7_July_2026-163_(cropped).jpg'),
  ('didier-drogba', '/celebrities/didier-drogba.svg', 'Photograph of Didier Drogba', 'Y.Leclercq© · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Didier_Drogba_(2019)_(cropped).jpg'),
  ('davido', '/celebrities/davido.svg', 'Photograph of Davido', 'OLAMIPOSI DANIEL · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Davido_2024_(cropped).jpg'),
  ('cristiano-ronaldo', '/celebrities/cristiano-ronaldo.svg', 'Photograph of Cristiano Ronaldo', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Cristiano_Ronaldo_Croatia_v_Portugal_2_July_2026-075_(cropped).jpg'),
  ('lionel-messi', '/celebrities/lionel-messi.svg', 'Photograph of Lionel Messi', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Leo_Messi_Argentina_v_Egypt_7_July_2026-1.jpg'),
  ('barack-obama', '/celebrities/barack-obama.svg', 'Photograph of Barack Obama', 'Official White House Photo by Pete Souza · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:President_Barack_Obama.jpg'),
  ('jomo-kenyatta', '/celebrities/jomo-kenyatta.svg', 'Photograph of Jomo Kenyatta', 'Pridan Moshe · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Jomo_Kenyatta_(cropped)_in_June_15th,_1966.jpg'),
  ('daniel-arap-moi', '/celebrities/daniel-arap-moi.svg', 'Photograph of Daniel arap Moi', 'Croes, Rob C. / Anefo · Wikimedia Commons', 'CC BY-SA 3.0 nl · https://commons.wikimedia.org/wiki/File:Daniel_arap_Moi_1979b.jpg'),
  ('kalonzo-musyoka', '/celebrities/kalonzo-musyoka.svg', 'Photograph of Kalonzo Musyoka', 'Raidarmax · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Kalonzo_Musyoka1.jpg'),
  ('martha-karua', '/celebrities/martha-karua.svg', 'Photograph of Martha Karua', 'Tom Zed · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Martha_Karua.jpg'),
  ('charity-ngilu', '/celebrities/charity-ngilu.svg', 'Photograph of Charity Ngilu', 'World Water Week · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Hon._Charity_Kaluki_Ngilu_at_Opening_Session.jpg'),
  ('musalia-mudavadi', '/celebrities/musalia-mudavadi.svg', 'Photograph of Musalia Mudavadi', 'Jpmudavadi · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Musalia_Mudavadi.JPG'),
  ('patrick-njoroge', '/celebrities/patrick-njoroge.svg', 'Photograph of Patrick Njoroge', 'UN Trade and Development (UNCTAD) / William Albors · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Patrick_Njoroge,_Former_Governor_of_the_Central_Bank_of_Kenya_(cropped).jpg'),
  ('paul-tergat', '/celebrities/paul-tergat.svg', 'Photograph of Paul Tergat', 'Michael Gross · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:World_Food_Program_2.jpg'),
  ('catherine-ndereba', '/celebrities/catherine-ndereba.svg', 'Photograph of Catherine Ndereba', 'Eckhard Pecher ( Arcimboldo ) · Wikimedia Commons', 'CC BY 2.5 · https://commons.wikimedia.org/wiki/File:Osaka07_D9M_WMarathon_Ndereba_running.jpg'),
  ('vivian-cheruiyot', '/celebrities/vivian-cheruiyot.svg', 'Photograph of Vivian Cheruiyot', 'Agência Brasil Fotografias · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Vivian_Cheruiyot_Rio_2016.jpg'),
  ('brigid-kosgei', '/celebrities/brigid-kosgei.svg', 'Photograph of Brigid Kosgei', 'Paul Hudson from United Kingdom · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:London_Marathon_2018_(27765192508).jpg'),
  ('julius-yego', '/celebrities/julius-yego.svg', 'Photograph of Julius Yego', 'Erik van Leeuwen, attribution: Erik van Leeuwen (bron: Wikipedia). · Wikimedia Commons', 'GFDL · https://commons.wikimedia.org/wiki/File:Julius_Yego_Beijing_2015.jpg'),
  ('mcdonald-mariga', '/celebrities/mcdonald-mariga.svg', 'Photograph of McDonald Mariga', 'Yulia Novikova for Soccer.ru · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Mariga.jpg'),
  ('tecla-loroupe', '/celebrities/tecla-loroupe.svg', 'Photograph of Tegla Loroupe', 'Fernando Frazão/Agência Brasil · Wikimedia Commons', 'CC BY 3.0 br · https://commons.wikimedia.org/wiki/File:Tegla_Loroupe_Rio2016.jpg'),
  ('pamela-jelimo', '/celebrities/pamela-jelimo.svg', 'Photograph of Pamela Jelimo', 'Pamela_Jelimo_Bislett_Games_2008.jpg : Ragnar Singsaas derivative work: MachoCarioca ( talk ) · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Pamela_Jelimo_Bislett_Games_2008_cropped.jpg'),
  ('janeth-jepkosgei', '/celebrities/janeth-jepkosgei.svg', 'Photograph of Janeth Jepkosgei', 'Erik van Leeuwen · Wikimedia Commons', 'GFDL · https://commons.wikimedia.org/wiki/File:Janeth_Jepkosgei_2010_Memorial_Van_damme.jpg'),
  ('conseslus-kipruto', '/celebrities/conseslus-kipruto.svg', 'Photograph of Conseslus Kipruto', 'Citizen59 · Wikimedia Commons', 'CC BY 3.0 · https://commons.wikimedia.org/wiki/File:ConseslusKiprutoHeat3000mSteepleRio2016_edited.jpg'),
  ('larry-madowo', '/celebrities/larry-madowo.svg', 'Photograph of Larry Madowo', 'Raidarmax · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Larry_Madowo.JPG'),
  ('akothee', '/celebrities/akothee.svg', 'Photograph of Akothee', 'By Fay Ngina · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Esther_Akoth.jpg'),
  ('desmond-tutu', '/celebrities/desmond-tutu.svg', 'Photograph of Desmond Tutu', 'Benny Gool · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Archbishop-Tutu-medium.jpg'),
  ('kofi-annan', '/celebrities/kofi-annan.svg', 'Photograph of Kofi Annan', 'US Mission in Geneva · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Kofi_Annan_2012_(cropped).jpg'),
  ('kwame-nkrumah', '/celebrities/kwame-nkrumah.svg', 'Photograph of Kwame Nkrumah', 'USSR Post · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Kwame_Nkrumah_on_a_Soviet_stamp_(80th_anniversary_of_his_birth)_1989_CPA_6101.jpg'),
  ('julius-nyerere', '/celebrities/julius-nyerere.svg', 'Photograph of Julius Nyerere', 'Rob Mieremet / Anefo · Wikimedia Commons', 'CC0 · https://commons.wikimedia.org/wiki/File:President_Nyerere_van_Tanzania,_koppen,_Bestanddeelnr_928-2879_(cropped).jpg'),
  ('haile-selassie', '/celebrities/haile-selassie.svg', 'Photograph of Haile Selassie', 'unknown; according to [1] and [2] an official portrait of which b/w copies were distributed by the Ethiopian government · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Haile_Selassie_in_full_dress.jpg'),
  ('thomas-sankara', '/celebrities/thomas-sankara.svg', 'Photograph of Thomas Sankara', 'unknown, United States Central Intelligence Agency · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Photo_of_Thomas_Sankara_by_CIA.png'),
  ('patrice-lumumba', '/celebrities/patrice-lumumba.svg', 'Photograph of Patrice Lumumba', 'Harry Pot for Anefo ) · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:PatriceLumumba1960.jpg'),
  ('ellen-johnson-sirleaf', '/celebrities/ellen-johnson-sirleaf.svg', 'Photograph of Ellen Johnson Sirleaf', 'U.S. Institute of Peace · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:12_6_2022_Breaking_the_Barriers_of_Entry_for_Women_Leaders_in_Africa_(52577486307)_(Ellen_Johnson-Sirleaf).jpg'),
  ('paul-kagame', '/celebrities/paul-kagame.svg', 'Photograph of Paul Kagame', 'Hildenbrand /MSC · Wikimedia Commons', 'CC BY 3.0 de · https://commons.wikimedia.org/wiki/File:Paul_Kagame_MSC_2017.jpg'),
  ('samia-suluhu-hassan', '/celebrities/samia-suluhu-hassan.svg', 'Photograph of Samia Suluhu Hassan', 'Kremlin.ru · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:Samia_Suluhu_at_the_XXIX_St_Petersburg_International_Economic_Forum_-_2026_(cropped).jpg'),
  ('yoweri-museveni', '/celebrities/yoweri-museveni.svg', 'Photograph of Yoweri Museveni', 'U.S. Department of State · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Yoweri_Museveni_September_2015.jpg'),
  ('robert-mugabe', '/celebrities/robert-mugabe.svg', 'Photograph of Robert Mugabe', 'Press Service of the President of Russia · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:Robert_Mugabe_May_2015_(cropped_3x4).jpg'),
  ('cyril-ramaphosa', '/celebrities/cyril-ramaphosa.svg', 'Photograph of Cyril Ramaphosa', 'Ricardo Stuckert · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:21.11.2025_%E2%80%93_Presidente_da_Rep%C3%BAblica_da_%C3%81frica_do_Sul,_Cyril_Ramaphosa_(54938010569)_(cropped).jpg'),
  ('fela-kuti', '/celebrities/fela-kuti.svg', 'Photograph of Fela Kuti', 'His master’s voice record company. · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Fela_Kuti_record.jpg'),
  ('wizkid', '/celebrities/wizkid.svg', 'Photograph of Wizkid', 'TCD PHOTOGRAPHY/The TCD Concept Ltd · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Wizkid_at_Iyanya%27s_album_launch_concert,_2013_(cropped).jpg'),
  ('tiwa-savage', '/celebrities/tiwa-savage.svg', 'Photograph of Tiwa Savage', 'TCD Photography · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Tiwa_Savage%27s_studio_portrait.jpg'),
  ('tems', '/celebrities/tems.svg', 'Photograph of Tems', 'NdaniTV · Wikimedia Commons', 'CC BY 3.0 · https://commons.wikimedia.org/wiki/File:Tems_on_NdaniTV_Sessions_-cropped.png'),
  ('angelique-kidjo', '/celebrities/angelique-kidjo.svg', 'Photograph of Angélique Kidjo', 'Library of Congress Life · Wikimedia Commons', 'CC0 · https://commons.wikimedia.org/wiki/File:Ang%C3%A9lique_Kidjo_2023.jpg'),
  ('youssou-ndour', '/celebrities/youssou-ndour.svg', 'Photograph of Youssou N''Dour', 'Kotoviski photograph by Henryk Kotowski · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:YoussouNdour20090913.jpg'),
  ('alikiba', '/celebrities/alikiba.svg', 'Photograph of Ali Kiba', 'Suzanese · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Ali_Kiba_2017.jpg'),
  ('sadio-mane', '/celebrities/sadio-mane.svg', 'Photograph of Sadio Mané', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Sadio_Mane_France_v_Senegal_16_June_2026-450.jpg'),
  ('samuel-etoo', '/celebrities/samuel-etoo.svg', 'Photograph of Samuel Eto''o', 'BACHELOR45 · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Sammuel_Eto%27o_Fils_02.jpg'),
  ('riyad-mahrez', '/celebrities/riyad-mahrez.svg', 'Photograph of Riyad Mahrez', 'Jeanpierrekepseu · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Mahrez_2021.jpg'),
  ('caster-semenya', '/celebrities/caster-semenya.svg', 'Photograph of Caster Semenya', 'Yann Caradec from Paris, France · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Caster_Semenya_(42411013704)_(cropped).jpg'),
  ('wayde-van-niekerk', '/celebrities/wayde-van-niekerk.svg', 'Photograph of Wayde van Niekerk', 'Erik van Leeuwen · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Wayde_van_Niekerk_080817_London_2017ceopped.jpg'),
  ('francis-ngannou', '/celebrities/francis-ngannou.svg', 'Photograph of Francis Ngannou', 'X2o · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Francis_Ngannou_photo.jpg'),
  ('hakeem-olajuwon', '/celebrities/hakeem-olajuwon.svg', 'Photograph of Hakeem Olajuwon', 'U.S. Department of State · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Nigerian_President_Buhari_Stands_With_Secretary_Kerry,_U.S._Delegation_After_They_Attended_His_Inauguration_Ceremony_(cropped).jpg'),
  ('chimamanda-ngozi-adichie', '/celebrities/chimamanda-ngozi-adichie.svg', 'Photograph of Chimamanda Ngozi Adichie', 'fronteirasweb · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:2025-06-16_Chimamanda_Ngozi_Adichie_no_Fronteiras_do_Pensamento_2025_em_S%C3%A3o_Paulo,_013_(cropped).jpg'),
  ('wole-soyinka', '/celebrities/wole-soyinka.svg', 'Photograph of Wole Soyinka', 'Frankie Fouganthin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Wole_Soyinka_in_2018.jpg'),
  ('ngugi-wa-thiongo', '/celebrities/ngugi-wa-thiongo.svg', 'Photograph of Ngũgĩ wa Thiong''o', 'Library of Congress Life · Wikimedia Commons', 'CC0 · https://commons.wikimedia.org/wiki/File:Ng%C5%A9g%C4%A9_wa_Thiong%27o_2019_(48139052733).jpg'),
  ('miriam-makeba', '/celebrities/miriam-makeba.svg', 'Photograph of Miriam Makeba', 'Paul Weinberg · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Miriam_makeba_01.jpg'),
  ('oprah-winfrey', '/celebrities/oprah-winfrey.svg', 'Photograph of Oprah Winfrey', 'Maryland GovPics · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Pre_Inaugural_Reception_(52639556983)_(cropped).jpg'),
  ('beyonce', '/celebrities/beyonce.svg', 'Photograph of Beyoncé', 'Raph_PH · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Beyonc%C3%A9_-_Tottenham_Hotspur_Stadium_-_1st_June_2023_(10_of_118)_(52946364598)_(best_crop).jpg'),
  ('rihanna', '/celebrities/rihanna.svg', 'Photograph of Rihanna', 'U.S. Embassy Bridgetown · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Rihanna_visits_U.S._Embassy_in_Barbados_2024_(cropped).jpg'),
  ('taylor-swift', '/celebrities/taylor-swift.svg', 'Photograph of Taylor Swift', 'iHeartRadioCA · Wikimedia Commons', 'CC BY 3.0 · https://commons.wikimedia.org/wiki/File:Taylor_Swift_at_the_2023_MTV_Video_Music_Awards_(3).png'),
  ('michael-jackson', '/celebrities/michael-jackson.svg', 'Photograph of Michael Jackson', 'Matthew Rolston; Distributed by Epic Records · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Michael_Jackson_1983_(3x4_cropped)_(contrast).jpg'),
  ('dwayne-johnson', '/celebrities/dwayne-johnson.svg', 'Photograph of Dwayne Johnson', 'Harald Krichel · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Dwayne_Johnson-1809_(cropped).jpg'),
  ('will-smith', '/celebrities/will-smith.svg', 'Photograph of Will Smith', 'Gage Skidmore · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Will_Smith_by_Gage_Skidmore_2.jpg'),
  ('leonardo-dicaprio', '/celebrities/leonardo-dicaprio.svg', 'Photograph of Leonardo DiCaprio', 'Raph_PH · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:Leonardo_DiCaprio_-_BFI_Southbank_3_(crop).jpg'),
  ('tom-cruise', '/celebrities/tom-cruise.svg', 'Photograph of Tom Cruise', 'Kevin Paul · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:Tom_Cruise_at_53rd_Saturn_Awards_2026-01.jpg'),
  ('jackie-chan', '/celebrities/jackie-chan.svg', 'Photograph of Jackie Chan', 'Segolene Liger · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Jackie_Chan_-_2025_Locarno_Film_Festival.jpg'),
  ('shah-rukh-khan', '/celebrities/shah-rukh-khan.svg', 'Photograph of Shah Rukh Khan', 'Bollywood Hungama · Wikimedia Commons', 'CC BY 3.0 · https://commons.wikimedia.org/wiki/File:Shah_Rukh_Khan_graces_the_launch_of_the_new_Santro.jpg'),
  ('mrbeast', '/celebrities/mrbeast.svg', 'Photograph of MrBeast', 'Tyren Redd · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:MrBeast_in_2026_(cropped_4).png'),
  ('elon-musk', '/celebrities/elon-musk.svg', 'Photograph of Elon Musk', 'Gage Skidmore · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Elon_Musk_(54816836217)_(cropped_2)_(b).jpg'),
  ('bill-gates', '/celebrities/bill-gates.svg', 'Photograph of Bill Gates', 'Bogdan Hoyaux / European Union · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:Bill_Gates_at_the_European_Commission_-_2025_-_P067383-987995_(cropped).jpg'),
  ('steve-jobs', '/celebrities/steve-jobs.svg', 'Photograph of Steve Jobs', 'MetalGearLiquid , based on File:Steve_Jobs_Headshot_2010-CROP.jpg made by Matt Yohe · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Steve_Jobs_Headshot_2010-CROP2.jpg'),
  ('mark-zuckerberg', '/celebrities/mark-zuckerberg.svg', 'Photograph of Mark Zuckerberg', 'Anthony Quintano from Westminster, United States · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Mark_Zuckerberg_F8_2019_Keynote_(32830578717)_(cropped).jpg'),
  ('jeff-bezos', '/celebrities/jeff-bezos.svg', 'Photograph of Jeff Bezos', 'Seattle City Council from Seattle · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Jeff_Bezos_at_Amazon_Spheres_Grand_Opening_in_Seattle_-_2018_(39074799225)_(cropped).jpg'),
  ('queen-elizabeth-ii', '/celebrities/queen-elizabeth-ii.svg', 'Photograph of Elizabeth II', 'Original: Joel Rouse/ Ministry of Defence Derivative: nagualdesign · Wikimedia Commons', 'OGL 3 · https://commons.wikimedia.org/wiki/File:Queen_Elizabeth_II_in_March_2015.jpg'),
  ('king-charles-iii', '/celebrities/king-charles-iii.svg', 'Photograph of Charles III', 'White House · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:King_Charles_III_(July_2023).jpg'),
  ('princess-diana', '/celebrities/princess-diana.svg', 'Photograph of Princess Diana', 'John Mathew Smith &amp; www.celebrity-photos.com from Laurel Maryland, USA ( Archived link) · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Diana,_Princess_of_Wales_1997_(2)_(cropped).jpg'),
  ('muhammad-ali', '/celebrities/muhammad-ali.svg', 'Photograph of Muhammad Ali', 'Ira Rosenberg · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Muhammad_Ali_NYWTS.jpg'),
  ('usain-bolt', '/celebrities/usain-bolt.svg', 'Photograph of Usain Bolt', 'Fernando Frazão/Agência Brasil · Wikimedia Commons', 'CC BY 3.0 br · https://commons.wikimedia.org/wiki/File:Usain_Bolt_Rio_100m_final_2016k.jpg'),
  ('serena-williams', '/celebrities/serena-williams.svg', 'Photograph of Serena Williams', 'Edwin Martinez · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Serena_Williams_at_2013_US_Open.jpg'),
  ('lebron-james', '/celebrities/lebron-james.svg', 'Photograph of LeBron James', 'Erik Drost · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:LeBron_James_(51959977144)_(cropped2).jpg'),
  ('tiger-woods', '/celebrities/tiger-woods.svg', 'Photograph of Tiger Woods', 'The White House from Washington, DC · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Tiger_Woods_in_May_2019.jpg'),
  ('lewis-hamilton', '/celebrities/lewis-hamilton.svg', 'Photograph of Lewis Hamilton', 'Governo do Estado de São Paulo · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Lewis_Hamilton_2022_S%C3%A3o_Paulo_Grand_Prix_(52498120773)_(cropped).jpg'),
  ('kylian-mbappe', '/celebrities/kylian-mbappe.svg', 'Photograph of Kylian Mbappé', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Kylian_Mbappe_France_v_Senegal_16_June_2026-391_(cropped).jpg'),
  ('neymar', '/celebrities/neymar.svg', 'Photograph of Neymar', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Neymar_Junior_Brazil_V_Morocco_13_June_2026-40.jpg'),
  ('erling-haaland', '/celebrities/erling-haaland.svg', 'Photograph of Erling Haaland', 'Bryan Berlin · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Erling_Haaland_France_v_Norway_26_June_26-008.jpg'),
  ('pep-guardiola', '/celebrities/pep-guardiola.svg', 'Photograph of Pep Guardiola', 'Steffen Prößdorf · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Josep_Guardiola_2023-10-04_Fu%C3%9Fball,_M%C3%A4nner,_UEFA_Champions_League,_RB_Leipzig_-_Manchester_City_FC_1DX_2797_(cropped).jpg'),
  ('jose-mourinho', '/celebrities/jose-mourinho.svg', 'Photograph of José Mourinho', 'Zafer · Wikimedia Commons', 'CC BY 4.0 · https://commons.wikimedia.org/wiki/File:Jos%C3%A9_Mourinho_20250206_(1).jpg'),
  ('adele', '/celebrities/adele.svg', 'Photograph of Adele', 'Marc E. · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Adele_2016.jpg'),
  ('drake', '/celebrities/drake.svg', 'Photograph of Drake', 'The Come Up Show · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Drake_July_2016.jpg'),
  ('ed-sheeran', '/celebrities/ed-sheeran.svg', 'Photograph of Ed Sheeran', 'Harald Krichel · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:Ed_Sheeran-6886_(cropped).jpg'),
  ('justin-bieber', '/celebrities/justin-bieber.svg', 'Photograph of Justin Bieber', 'Lou Stejskal · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Justin_Bieber_in_2015.jpg'),
  ('kim-kardashian', '/celebrities/kim-kardashian.svg', 'Photograph of Kim Kardashian', 'The White House from Washington, DC · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:President_Trump_Meets_with_Sentencing_Commutation_Recipients_(49624188912)_(cropped).jpg'),
  ('greta-thunberg', '/celebrities/greta-thunberg.svg', 'Photograph of Greta Thunberg', 'Anders Hellberg · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Greta_Thunberg_4.jpg'),
  ('malala-yousafzai', '/celebrities/malala-yousafzai.svg', 'Photograph of Malala Yousafzai', 'DFID - UK Department for International Development · Wikimedia Commons', 'CC BY 2.0 · https://commons.wikimedia.org/wiki/File:Malala_Yousafzai_2015.jpg'),
  ('donald-trump', '/celebrities/donald-trump.svg', 'Photograph of Donald Trump', 'Daniel Torok · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Official_Presidential_Portrait_of_President_Donald_J._Trump_(2025).jpg'),
  ('pope-francis', '/celebrities/pope-francis.svg', 'Photograph of Pope Francis', 'Korea.net / Korean Culture and Information Service (Jeon Han) · Wikimedia Commons', 'CC BY-SA 2.0 · https://commons.wikimedia.org/wiki/File:Pope_Francis_Korea_Haemi_Castle_19.jpg')
) as v(asset_key,public_url,alt_text,attribution,licence)
join public.question_sources s on s.source_key='who_am_i_commons'
on conflict(provider,asset_key) do update set public_url=excluded.public_url,alt_text=excluded.alt_text,attribution=excluded.attribution,licence=excluded.licence,source_id=excluded.source_id,width=excluded.width,height=excluded.height;

insert into public.questions(slug,pack_id,category_id,game_mode,prompt,explanation,media_id,difficulty,duration_seconds,base_points,tags,status,source_id,fact_checked_at)
select v.question_slug,p.id,c.id,'who_am_i','Who Am I?',v.explanation,m.id,v.difficulty,90,200,array['who_am_i',v.region,v.field],'approved',s.id,now()
from (values
  ('lupita_nyongo_identity', 'lupita-nyongo', 'Lupita Nyong''o', 'Lupita Nyong''o is a widely recognised film figure associated with Kenya.', 2, 'kenya', 'film'),
  ('eliud_kipchoge_identity', 'eliud-kipchoge', 'Eliud Kipchoge', 'Eliud Kipchoge is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('faith_kipyegon_identity', 'faith-kipyegon', 'Faith Kipyegon', 'Faith Kipyegon is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('wangari_maathai', 'wangari-maathai', 'Wangari Maathai', 'Wangari Maathai is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('ferdinand_omanyala_identity', 'ferdinand-omanyala', 'Ferdinand Omanyala', 'Ferdinand Omanyala is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('david_rudisha_identity', 'david-rudisha', 'David Rudisha', 'David Rudisha is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('mwai_kibaki_identity', 'mwai-kibaki', 'Mwai Kibaki', 'Mwai Kibaki is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('dedan_kimathi_identity', 'dedan-kimathi', 'Dedan Kimathi', 'Dedan Kimathi is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('joy_adamson_identity', 'joy-adamson', 'Joy Adamson', 'Joy Adamson is a widely recognised conservation figure associated with Kenya.', 2, 'kenya', 'conservation'),
  ('william_ruto_identity', 'william-ruto', 'William Ruto', 'William Ruto is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('raila_odinga_identity', 'raila-odinga', 'Raila Odinga', 'Raila Odinga is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('uhuru_kenyatta_identity', 'uhuru-kenyatta', 'Uhuru Kenyatta', 'Uhuru Kenyatta is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('nyashinski_identity', 'nyashinski', 'Nyashinski', 'Nyashinski is a widely recognised music figure associated with Kenya.', 2, 'kenya', 'music'),
  ('victor_wanyama_identity', 'victor-wanyama', 'Victor Wanyama', 'Victor Wanyama is a widely recognised football figure associated with Kenya.', 2, 'kenya', 'football'),
  ('catherine_kamau_identity', 'catherine-kamau', 'Catherine Kamau', 'Catherine Kamau is a widely recognised film figure associated with Kenya.', 2, 'kenya', 'film'),
  ('nelson_mandela_identity', 'nelson-mandela', 'Nelson Mandela', 'Nelson Mandela is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('trevor_noah_identity', 'trevor-noah', 'Trevor Noah', 'Trevor Noah is a widely recognised comedy figure associated with Africa.', 2, 'africa', 'comedy'),
  ('burna_boy_identity', 'burna-boy', 'Burna Boy', 'Burna Boy is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('diamond_platnumz_identity', 'diamond-platnumz', 'Diamond Platnumz', 'Diamond Platnumz is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('mohamed_salah_identity', 'mohamed-salah', 'Mohamed Salah', 'Mohamed Salah is a widely recognised football figure associated with Africa.', 2, 'africa', 'football'),
  ('didier_drogba_identity', 'didier-drogba', 'Didier Drogba', 'Didier Drogba is a widely recognised football figure associated with Africa.', 2, 'africa', 'football'),
  ('davido_identity', 'davido', 'Davido', 'Davido is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('cristiano_ronaldo_identity', 'cristiano-ronaldo', 'Cristiano Ronaldo', 'Cristiano Ronaldo is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('lionel_messi_identity', 'lionel-messi', 'Lionel Messi', 'Lionel Messi is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('barack_obama_identity', 'barack-obama', 'Barack Obama', 'Barack Obama is a widely recognised leadership figure associated with Global.', 1, 'global', 'leadership'),
  ('jomo_kenyatta_identity', 'jomo-kenyatta', 'Jomo Kenyatta', 'Jomo Kenyatta is a widely recognised leadership figure associated with Kenya.', 1, 'kenya', 'leadership'),
  ('daniel_arap_moi_identity', 'daniel-arap-moi', 'Daniel arap Moi', 'Daniel arap Moi is a widely recognised leadership figure associated with Kenya.', 1, 'kenya', 'leadership'),
  ('kalonzo_musyoka_identity', 'kalonzo-musyoka', 'Kalonzo Musyoka', 'Kalonzo Musyoka is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('martha_karua_identity', 'martha-karua', 'Martha Karua', 'Martha Karua is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('charity_ngilu_identity', 'charity-ngilu', 'Charity Ngilu', 'Charity Ngilu is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('musalia_mudavadi_identity', 'musalia-mudavadi', 'Musalia Mudavadi', 'Musalia Mudavadi is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('patrick_njoroge_identity', 'patrick-njoroge', 'Patrick Njoroge', 'Patrick Njoroge is a widely recognised leadership figure associated with Kenya.', 3, 'kenya', 'leadership'),
  ('paul_tergat_identity', 'paul-tergat', 'Paul Tergat', 'Paul Tergat is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('catherine_ndereba_identity', 'catherine-ndereba', 'Catherine Ndereba', 'Catherine Ndereba is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('vivian_cheruiyot_identity', 'vivian-cheruiyot', 'Vivian Cheruiyot', 'Vivian Cheruiyot is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('brigid_kosgei_identity', 'brigid-kosgei', 'Brigid Kosgei', 'Brigid Kosgei is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('julius_yego_identity', 'julius-yego', 'Julius Yego', 'Julius Yego is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('mcdonald_mariga_identity', 'mcdonald-mariga', 'McDonald Mariga', 'McDonald Mariga is a widely recognised football figure associated with Kenya.', 2, 'kenya', 'football'),
  ('tecla_loroupe_identity', 'tecla-loroupe', 'Tegla Loroupe', 'Tegla Loroupe is a widely recognised athletics figure associated with Kenya.', 3, 'kenya', 'athletics'),
  ('pamela_jelimo_identity', 'pamela-jelimo', 'Pamela Jelimo', 'Pamela Jelimo is a widely recognised athletics figure associated with Kenya.', 3, 'kenya', 'athletics'),
  ('janeth_jepkosgei_identity', 'janeth-jepkosgei', 'Janeth Jepkosgei', 'Janeth Jepkosgei is a widely recognised athletics figure associated with Kenya.', 3, 'kenya', 'athletics'),
  ('conseslus_kipruto_identity', 'conseslus-kipruto', 'Conseslus Kipruto', 'Conseslus Kipruto is a widely recognised athletics figure associated with Kenya.', 3, 'kenya', 'athletics'),
  ('larry_madowo_identity', 'larry-madowo', 'Larry Madowo', 'Larry Madowo is a widely recognised media figure associated with Kenya.', 2, 'kenya', 'media'),
  ('akothee_identity', 'akothee', 'Akothee', 'Akothee is a widely recognised music figure associated with Kenya.', 2, 'kenya', 'music'),
  ('desmond_tutu_identity', 'desmond-tutu', 'Desmond Tutu', 'Desmond Tutu is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('kofi_annan_identity', 'kofi-annan', 'Kofi Annan', 'Kofi Annan is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('kwame_nkrumah_identity', 'kwame-nkrumah', 'Kwame Nkrumah', 'Kwame Nkrumah is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('julius_nyerere_identity', 'julius-nyerere', 'Julius Nyerere', 'Julius Nyerere is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('haile_selassie_identity', 'haile-selassie', 'Haile Selassie', 'Haile Selassie is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('thomas_sankara_identity', 'thomas-sankara', 'Thomas Sankara', 'Thomas Sankara is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('patrice_lumumba_identity', 'patrice-lumumba', 'Patrice Lumumba', 'Patrice Lumumba is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('ellen_johnson_sirleaf_identity', 'ellen-johnson-sirleaf', 'Ellen Johnson Sirleaf', 'Ellen Johnson Sirleaf is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('paul_kagame_identity', 'paul-kagame', 'Paul Kagame', 'Paul Kagame is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('samia_suluhu_hassan_identity', 'samia-suluhu-hassan', 'Samia Suluhu Hassan', 'Samia Suluhu Hassan is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('yoweri_museveni_identity', 'yoweri-museveni', 'Yoweri Museveni', 'Yoweri Museveni is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('robert_mugabe_identity', 'robert-mugabe', 'Robert Mugabe', 'Robert Mugabe is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('cyril_ramaphosa_identity', 'cyril-ramaphosa', 'Cyril Ramaphosa', 'Cyril Ramaphosa is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('fela_kuti_identity', 'fela-kuti', 'Fela Kuti', 'Fela Kuti is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('wizkid_identity', 'wizkid', 'Wizkid', 'Wizkid is a widely recognised music figure associated with Africa.', 1, 'africa', 'music'),
  ('tiwa_savage_identity', 'tiwa-savage', 'Tiwa Savage', 'Tiwa Savage is a widely recognised music figure associated with Africa.', 1, 'africa', 'music'),
  ('tems_identity', 'tems', 'Tems', 'Tems is a widely recognised music figure associated with Africa.', 1, 'africa', 'music'),
  ('angelique_kidjo_identity', 'angelique-kidjo', 'Angélique Kidjo', 'Angélique Kidjo is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('youssou_ndour_identity', 'youssou-ndour', 'Youssou N''Dour', 'Youssou N''Dour is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('alikiba_identity', 'alikiba', 'Ali Kiba', 'Ali Kiba is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('sadio_mane_identity', 'sadio-mane', 'Sadio Mané', 'Sadio Mané is a widely recognised football figure associated with Africa.', 1, 'africa', 'football'),
  ('samuel_etoo_identity', 'samuel-etoo', 'Samuel Eto''o', 'Samuel Eto''o is a widely recognised football figure associated with Africa.', 1, 'africa', 'football'),
  ('riyad_mahrez_identity', 'riyad-mahrez', 'Riyad Mahrez', 'Riyad Mahrez is a widely recognised football figure associated with Africa.', 2, 'africa', 'football'),
  ('caster_semenya_identity', 'caster-semenya', 'Caster Semenya', 'Caster Semenya is a widely recognised athletics figure associated with Africa.', 2, 'africa', 'athletics'),
  ('wayde_van_niekerk_identity', 'wayde-van-niekerk', 'Wayde van Niekerk', 'Wayde van Niekerk is a widely recognised athletics figure associated with Africa.', 2, 'africa', 'athletics'),
  ('francis_ngannou_identity', 'francis-ngannou', 'Francis Ngannou', 'Francis Ngannou is a widely recognised combat sports figure associated with Africa.', 2, 'africa', 'combat sports'),
  ('hakeem_olajuwon_identity', 'hakeem-olajuwon', 'Hakeem Olajuwon', 'Hakeem Olajuwon is a widely recognised basketball figure associated with Africa.', 2, 'africa', 'basketball'),
  ('chimamanda_ngozi_adichie_identity', 'chimamanda-ngozi-adichie', 'Chimamanda Ngozi Adichie', 'Chimamanda Ngozi Adichie is a widely recognised literature figure associated with Africa.', 2, 'africa', 'literature'),
  ('wole_soyinka_identity', 'wole-soyinka', 'Wole Soyinka', 'Wole Soyinka is a widely recognised literature figure associated with Africa.', 2, 'africa', 'literature'),
  ('ngugi_wa_thiongo_identity', 'ngugi-wa-thiongo', 'Ngũgĩ wa Thiong''o', 'Ngũgĩ wa Thiong''o is a widely recognised literature figure associated with Africa.', 1, 'africa', 'literature'),
  ('miriam_makeba_identity', 'miriam-makeba', 'Miriam Makeba', 'Miriam Makeba is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('oprah_winfrey_identity', 'oprah-winfrey', 'Oprah Winfrey', 'Oprah Winfrey is a widely recognised media figure associated with Global.', 1, 'global', 'media'),
  ('beyonce_identity', 'beyonce', 'Beyoncé', 'Beyoncé is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('rihanna_identity', 'rihanna', 'Rihanna', 'Rihanna is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('taylor_swift_identity', 'taylor-swift', 'Taylor Swift', 'Taylor Swift is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('michael_jackson_identity', 'michael-jackson', 'Michael Jackson', 'Michael Jackson is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('dwayne_johnson_identity', 'dwayne-johnson', 'Dwayne Johnson', 'Dwayne Johnson is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('will_smith_identity', 'will-smith', 'Will Smith', 'Will Smith is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('leonardo_dicaprio_identity', 'leonardo-dicaprio', 'Leonardo DiCaprio', 'Leonardo DiCaprio is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('tom_cruise_identity', 'tom-cruise', 'Tom Cruise', 'Tom Cruise is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('jackie_chan_identity', 'jackie-chan', 'Jackie Chan', 'Jackie Chan is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('shah_rukh_khan_identity', 'shah-rukh-khan', 'Shah Rukh Khan', 'Shah Rukh Khan is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('mrbeast_identity', 'mrbeast', 'MrBeast', 'MrBeast is a widely recognised digital media figure associated with Global.', 1, 'global', 'digital media'),
  ('elon_musk_identity', 'elon-musk', 'Elon Musk', 'Elon Musk is a widely recognised technology figure associated with Global.', 1, 'global', 'technology'),
  ('bill_gates_identity', 'bill-gates', 'Bill Gates', 'Bill Gates is a widely recognised technology figure associated with Global.', 1, 'global', 'technology'),
  ('steve_jobs_identity', 'steve-jobs', 'Steve Jobs', 'Steve Jobs is a widely recognised technology figure associated with Global.', 1, 'global', 'technology'),
  ('mark_zuckerberg_identity', 'mark-zuckerberg', 'Mark Zuckerberg', 'Mark Zuckerberg is a widely recognised technology figure associated with Global.', 1, 'global', 'technology'),
  ('jeff_bezos_identity', 'jeff-bezos', 'Jeff Bezos', 'Jeff Bezos is a widely recognised business figure associated with Global.', 1, 'global', 'business'),
  ('queen_elizabeth_ii_identity', 'queen-elizabeth-ii', 'Elizabeth II', 'Elizabeth II is a widely recognised royalty figure associated with Global.', 1, 'global', 'royalty'),
  ('king_charles_iii_identity', 'king-charles-iii', 'Charles III', 'Charles III is a widely recognised royalty figure associated with Global.', 1, 'global', 'royalty'),
  ('princess_diana_identity', 'princess-diana', 'Princess Diana', 'Princess Diana is a widely recognised royalty figure associated with Global.', 1, 'global', 'royalty'),
  ('muhammad_ali_identity', 'muhammad-ali', 'Muhammad Ali', 'Muhammad Ali is a widely recognised combat sports figure associated with Global.', 1, 'global', 'combat sports'),
  ('usain_bolt_identity', 'usain-bolt', 'Usain Bolt', 'Usain Bolt is a widely recognised athletics figure associated with Global.', 1, 'global', 'athletics'),
  ('serena_williams_identity', 'serena-williams', 'Serena Williams', 'Serena Williams is a widely recognised tennis figure associated with Global.', 1, 'global', 'tennis'),
  ('lebron_james_identity', 'lebron-james', 'LeBron James', 'LeBron James is a widely recognised basketball figure associated with Global.', 1, 'global', 'basketball'),
  ('tiger_woods_identity', 'tiger-woods', 'Tiger Woods', 'Tiger Woods is a widely recognised golf figure associated with Global.', 1, 'global', 'golf'),
  ('lewis_hamilton_identity', 'lewis-hamilton', 'Lewis Hamilton', 'Lewis Hamilton is a widely recognised motorsport figure associated with Global.', 1, 'global', 'motorsport'),
  ('kylian_mbappe_identity', 'kylian-mbappe', 'Kylian Mbappé', 'Kylian Mbappé is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('neymar_identity', 'neymar', 'Neymar', 'Neymar is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('erling_haaland_identity', 'erling-haaland', 'Erling Haaland', 'Erling Haaland is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('pep_guardiola_identity', 'pep-guardiola', 'Pep Guardiola', 'Pep Guardiola is a widely recognised football figure associated with Global.', 2, 'global', 'football'),
  ('jose_mourinho_identity', 'jose-mourinho', 'José Mourinho', 'José Mourinho is a widely recognised football figure associated with Global.', 2, 'global', 'football'),
  ('adele_identity', 'adele', 'Adele', 'Adele is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('drake_identity', 'drake', 'Drake', 'Drake is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('ed_sheeran_identity', 'ed-sheeran', 'Ed Sheeran', 'Ed Sheeran is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('justin_bieber_identity', 'justin-bieber', 'Justin Bieber', 'Justin Bieber is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('kim_kardashian_identity', 'kim-kardashian', 'Kim Kardashian', 'Kim Kardashian is a widely recognised television figure associated with Global.', 1, 'global', 'television'),
  ('greta_thunberg_identity', 'greta-thunberg', 'Greta Thunberg', 'Greta Thunberg is a widely recognised activism figure associated with Global.', 2, 'global', 'activism'),
  ('malala_yousafzai_identity', 'malala-yousafzai', 'Malala Yousafzai', 'Malala Yousafzai is a widely recognised activism figure associated with Global.', 1, 'global', 'activism'),
  ('donald_trump_identity', 'donald-trump', 'Donald Trump', 'Donald Trump is a widely recognised leadership figure associated with Global.', 1, 'global', 'leadership'),
  ('pope_francis_identity', 'pope-francis', 'Pope Francis', 'Pope Francis is a widely recognised religion figure associated with Global.', 1, 'global', 'religion')
) as v(question_slug,asset_key,identity_name,explanation,difficulty,region,field)
join public.content_packs p on p.code='famous_faces'
join public.categories c on c.code='who_am_i_icons'
join public.media_assets m on m.provider='game_mavelas' and m.asset_key=v.asset_key
join public.question_sources s on s.source_key='who_am_i_commons'
on conflict(slug) do update set pack_id=excluded.pack_id,category_id=excluded.category_id,game_mode=excluded.game_mode,prompt=excluded.prompt,explanation=excluded.explanation,media_id=excluded.media_id,difficulty=excluded.difficulty,duration_seconds=excluded.duration_seconds,base_points=excluded.base_points,tags=excluded.tags,status='approved',source_id=excluded.source_id,fact_checked_at=now(),updated_at=now();

update public.question_options qo
set option_text='__who_regen__'||qo.id::text,is_correct=false
from public.questions q
where qo.question_id=q.id and q.slug in (
  'lupita_nyongo_identity',
  'eliud_kipchoge_identity',
  'faith_kipyegon_identity',
  'wangari_maathai',
  'ferdinand_omanyala_identity',
  'david_rudisha_identity',
  'mwai_kibaki_identity',
  'dedan_kimathi_identity',
  'joy_adamson_identity',
  'william_ruto_identity',
  'raila_odinga_identity',
  'uhuru_kenyatta_identity',
  'nyashinski_identity',
  'victor_wanyama_identity',
  'catherine_kamau_identity',
  'nelson_mandela_identity',
  'trevor_noah_identity',
  'burna_boy_identity',
  'diamond_platnumz_identity',
  'mohamed_salah_identity',
  'didier_drogba_identity',
  'davido_identity',
  'cristiano_ronaldo_identity',
  'lionel_messi_identity',
  'barack_obama_identity',
  'jomo_kenyatta_identity',
  'daniel_arap_moi_identity',
  'kalonzo_musyoka_identity',
  'martha_karua_identity',
  'charity_ngilu_identity',
  'musalia_mudavadi_identity',
  'patrick_njoroge_identity',
  'paul_tergat_identity',
  'catherine_ndereba_identity',
  'vivian_cheruiyot_identity',
  'brigid_kosgei_identity',
  'julius_yego_identity',
  'mcdonald_mariga_identity',
  'tecla_loroupe_identity',
  'pamela_jelimo_identity',
  'janeth_jepkosgei_identity',
  'conseslus_kipruto_identity',
  'larry_madowo_identity',
  'akothee_identity',
  'desmond_tutu_identity',
  'kofi_annan_identity',
  'kwame_nkrumah_identity',
  'julius_nyerere_identity',
  'haile_selassie_identity',
  'thomas_sankara_identity',
  'patrice_lumumba_identity',
  'ellen_johnson_sirleaf_identity',
  'paul_kagame_identity',
  'samia_suluhu_hassan_identity',
  'yoweri_museveni_identity',
  'robert_mugabe_identity',
  'cyril_ramaphosa_identity',
  'fela_kuti_identity',
  'wizkid_identity',
  'tiwa_savage_identity',
  'tems_identity',
  'angelique_kidjo_identity',
  'youssou_ndour_identity',
  'alikiba_identity',
  'sadio_mane_identity',
  'samuel_etoo_identity',
  'riyad_mahrez_identity',
  'caster_semenya_identity',
  'wayde_van_niekerk_identity',
  'francis_ngannou_identity',
  'hakeem_olajuwon_identity',
  'chimamanda_ngozi_adichie_identity',
  'wole_soyinka_identity',
  'ngugi_wa_thiongo_identity',
  'miriam_makeba_identity',
  'oprah_winfrey_identity',
  'beyonce_identity',
  'rihanna_identity',
  'taylor_swift_identity',
  'michael_jackson_identity',
  'dwayne_johnson_identity',
  'will_smith_identity',
  'leonardo_dicaprio_identity',
  'tom_cruise_identity',
  'jackie_chan_identity',
  'shah_rukh_khan_identity',
  'mrbeast_identity',
  'elon_musk_identity',
  'bill_gates_identity',
  'steve_jobs_identity',
  'mark_zuckerberg_identity',
  'jeff_bezos_identity',
  'queen_elizabeth_ii_identity',
  'king_charles_iii_identity',
  'princess_diana_identity',
  'muhammad_ali_identity',
  'usain_bolt_identity',
  'serena_williams_identity',
  'lebron_james_identity',
  'tiger_woods_identity',
  'lewis_hamilton_identity',
  'kylian_mbappe_identity',
  'neymar_identity',
  'erling_haaland_identity',
  'pep_guardiola_identity',
  'jose_mourinho_identity',
  'adele_identity',
  'drake_identity',
  'ed_sheeran_identity',
  'justin_bieber_identity',
  'kim_kardashian_identity',
  'greta_thunberg_identity',
  'malala_yousafzai_identity',
  'donald_trump_identity',
  'pope_francis_identity'
);

insert into public.question_options(question_id,position,option_text,is_correct)
select q.id,1,v.identity_name,true
from (values
  ('lupita_nyongo_identity', 'lupita-nyongo', 'Lupita Nyong''o', 'Lupita Nyong''o is a widely recognised film figure associated with Kenya.', 2, 'kenya', 'film'),
  ('eliud_kipchoge_identity', 'eliud-kipchoge', 'Eliud Kipchoge', 'Eliud Kipchoge is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('faith_kipyegon_identity', 'faith-kipyegon', 'Faith Kipyegon', 'Faith Kipyegon is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('wangari_maathai', 'wangari-maathai', 'Wangari Maathai', 'Wangari Maathai is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('ferdinand_omanyala_identity', 'ferdinand-omanyala', 'Ferdinand Omanyala', 'Ferdinand Omanyala is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('david_rudisha_identity', 'david-rudisha', 'David Rudisha', 'David Rudisha is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('mwai_kibaki_identity', 'mwai-kibaki', 'Mwai Kibaki', 'Mwai Kibaki is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('dedan_kimathi_identity', 'dedan-kimathi', 'Dedan Kimathi', 'Dedan Kimathi is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('joy_adamson_identity', 'joy-adamson', 'Joy Adamson', 'Joy Adamson is a widely recognised conservation figure associated with Kenya.', 2, 'kenya', 'conservation'),
  ('william_ruto_identity', 'william-ruto', 'William Ruto', 'William Ruto is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('raila_odinga_identity', 'raila-odinga', 'Raila Odinga', 'Raila Odinga is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('uhuru_kenyatta_identity', 'uhuru-kenyatta', 'Uhuru Kenyatta', 'Uhuru Kenyatta is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('nyashinski_identity', 'nyashinski', 'Nyashinski', 'Nyashinski is a widely recognised music figure associated with Kenya.', 2, 'kenya', 'music'),
  ('victor_wanyama_identity', 'victor-wanyama', 'Victor Wanyama', 'Victor Wanyama is a widely recognised football figure associated with Kenya.', 2, 'kenya', 'football'),
  ('catherine_kamau_identity', 'catherine-kamau', 'Catherine Kamau', 'Catherine Kamau is a widely recognised film figure associated with Kenya.', 2, 'kenya', 'film'),
  ('nelson_mandela_identity', 'nelson-mandela', 'Nelson Mandela', 'Nelson Mandela is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('trevor_noah_identity', 'trevor-noah', 'Trevor Noah', 'Trevor Noah is a widely recognised comedy figure associated with Africa.', 2, 'africa', 'comedy'),
  ('burna_boy_identity', 'burna-boy', 'Burna Boy', 'Burna Boy is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('diamond_platnumz_identity', 'diamond-platnumz', 'Diamond Platnumz', 'Diamond Platnumz is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('mohamed_salah_identity', 'mohamed-salah', 'Mohamed Salah', 'Mohamed Salah is a widely recognised football figure associated with Africa.', 2, 'africa', 'football'),
  ('didier_drogba_identity', 'didier-drogba', 'Didier Drogba', 'Didier Drogba is a widely recognised football figure associated with Africa.', 2, 'africa', 'football'),
  ('davido_identity', 'davido', 'Davido', 'Davido is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('cristiano_ronaldo_identity', 'cristiano-ronaldo', 'Cristiano Ronaldo', 'Cristiano Ronaldo is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('lionel_messi_identity', 'lionel-messi', 'Lionel Messi', 'Lionel Messi is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('barack_obama_identity', 'barack-obama', 'Barack Obama', 'Barack Obama is a widely recognised leadership figure associated with Global.', 1, 'global', 'leadership'),
  ('jomo_kenyatta_identity', 'jomo-kenyatta', 'Jomo Kenyatta', 'Jomo Kenyatta is a widely recognised leadership figure associated with Kenya.', 1, 'kenya', 'leadership'),
  ('daniel_arap_moi_identity', 'daniel-arap-moi', 'Daniel arap Moi', 'Daniel arap Moi is a widely recognised leadership figure associated with Kenya.', 1, 'kenya', 'leadership'),
  ('kalonzo_musyoka_identity', 'kalonzo-musyoka', 'Kalonzo Musyoka', 'Kalonzo Musyoka is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('martha_karua_identity', 'martha-karua', 'Martha Karua', 'Martha Karua is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('charity_ngilu_identity', 'charity-ngilu', 'Charity Ngilu', 'Charity Ngilu is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('musalia_mudavadi_identity', 'musalia-mudavadi', 'Musalia Mudavadi', 'Musalia Mudavadi is a widely recognised leadership figure associated with Kenya.', 2, 'kenya', 'leadership'),
  ('patrick_njoroge_identity', 'patrick-njoroge', 'Patrick Njoroge', 'Patrick Njoroge is a widely recognised leadership figure associated with Kenya.', 3, 'kenya', 'leadership'),
  ('paul_tergat_identity', 'paul-tergat', 'Paul Tergat', 'Paul Tergat is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('catherine_ndereba_identity', 'catherine-ndereba', 'Catherine Ndereba', 'Catherine Ndereba is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('vivian_cheruiyot_identity', 'vivian-cheruiyot', 'Vivian Cheruiyot', 'Vivian Cheruiyot is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('brigid_kosgei_identity', 'brigid-kosgei', 'Brigid Kosgei', 'Brigid Kosgei is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('julius_yego_identity', 'julius-yego', 'Julius Yego', 'Julius Yego is a widely recognised athletics figure associated with Kenya.', 2, 'kenya', 'athletics'),
  ('mcdonald_mariga_identity', 'mcdonald-mariga', 'McDonald Mariga', 'McDonald Mariga is a widely recognised football figure associated with Kenya.', 2, 'kenya', 'football'),
  ('tecla_loroupe_identity', 'tecla-loroupe', 'Tegla Loroupe', 'Tegla Loroupe is a widely recognised athletics figure associated with Kenya.', 3, 'kenya', 'athletics'),
  ('pamela_jelimo_identity', 'pamela-jelimo', 'Pamela Jelimo', 'Pamela Jelimo is a widely recognised athletics figure associated with Kenya.', 3, 'kenya', 'athletics'),
  ('janeth_jepkosgei_identity', 'janeth-jepkosgei', 'Janeth Jepkosgei', 'Janeth Jepkosgei is a widely recognised athletics figure associated with Kenya.', 3, 'kenya', 'athletics'),
  ('conseslus_kipruto_identity', 'conseslus-kipruto', 'Conseslus Kipruto', 'Conseslus Kipruto is a widely recognised athletics figure associated with Kenya.', 3, 'kenya', 'athletics'),
  ('larry_madowo_identity', 'larry-madowo', 'Larry Madowo', 'Larry Madowo is a widely recognised media figure associated with Kenya.', 2, 'kenya', 'media'),
  ('akothee_identity', 'akothee', 'Akothee', 'Akothee is a widely recognised music figure associated with Kenya.', 2, 'kenya', 'music'),
  ('desmond_tutu_identity', 'desmond-tutu', 'Desmond Tutu', 'Desmond Tutu is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('kofi_annan_identity', 'kofi-annan', 'Kofi Annan', 'Kofi Annan is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('kwame_nkrumah_identity', 'kwame-nkrumah', 'Kwame Nkrumah', 'Kwame Nkrumah is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('julius_nyerere_identity', 'julius-nyerere', 'Julius Nyerere', 'Julius Nyerere is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('haile_selassie_identity', 'haile-selassie', 'Haile Selassie', 'Haile Selassie is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('thomas_sankara_identity', 'thomas-sankara', 'Thomas Sankara', 'Thomas Sankara is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('patrice_lumumba_identity', 'patrice-lumumba', 'Patrice Lumumba', 'Patrice Lumumba is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('ellen_johnson_sirleaf_identity', 'ellen-johnson-sirleaf', 'Ellen Johnson Sirleaf', 'Ellen Johnson Sirleaf is a widely recognised leadership figure associated with Africa.', 2, 'africa', 'leadership'),
  ('paul_kagame_identity', 'paul-kagame', 'Paul Kagame', 'Paul Kagame is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('samia_suluhu_hassan_identity', 'samia-suluhu-hassan', 'Samia Suluhu Hassan', 'Samia Suluhu Hassan is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('yoweri_museveni_identity', 'yoweri-museveni', 'Yoweri Museveni', 'Yoweri Museveni is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('robert_mugabe_identity', 'robert-mugabe', 'Robert Mugabe', 'Robert Mugabe is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('cyril_ramaphosa_identity', 'cyril-ramaphosa', 'Cyril Ramaphosa', 'Cyril Ramaphosa is a widely recognised leadership figure associated with Africa.', 1, 'africa', 'leadership'),
  ('fela_kuti_identity', 'fela-kuti', 'Fela Kuti', 'Fela Kuti is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('wizkid_identity', 'wizkid', 'Wizkid', 'Wizkid is a widely recognised music figure associated with Africa.', 1, 'africa', 'music'),
  ('tiwa_savage_identity', 'tiwa-savage', 'Tiwa Savage', 'Tiwa Savage is a widely recognised music figure associated with Africa.', 1, 'africa', 'music'),
  ('tems_identity', 'tems', 'Tems', 'Tems is a widely recognised music figure associated with Africa.', 1, 'africa', 'music'),
  ('angelique_kidjo_identity', 'angelique-kidjo', 'Angélique Kidjo', 'Angélique Kidjo is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('youssou_ndour_identity', 'youssou-ndour', 'Youssou N''Dour', 'Youssou N''Dour is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('alikiba_identity', 'alikiba', 'Ali Kiba', 'Ali Kiba is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('sadio_mane_identity', 'sadio-mane', 'Sadio Mané', 'Sadio Mané is a widely recognised football figure associated with Africa.', 1, 'africa', 'football'),
  ('samuel_etoo_identity', 'samuel-etoo', 'Samuel Eto''o', 'Samuel Eto''o is a widely recognised football figure associated with Africa.', 1, 'africa', 'football'),
  ('riyad_mahrez_identity', 'riyad-mahrez', 'Riyad Mahrez', 'Riyad Mahrez is a widely recognised football figure associated with Africa.', 2, 'africa', 'football'),
  ('caster_semenya_identity', 'caster-semenya', 'Caster Semenya', 'Caster Semenya is a widely recognised athletics figure associated with Africa.', 2, 'africa', 'athletics'),
  ('wayde_van_niekerk_identity', 'wayde-van-niekerk', 'Wayde van Niekerk', 'Wayde van Niekerk is a widely recognised athletics figure associated with Africa.', 2, 'africa', 'athletics'),
  ('francis_ngannou_identity', 'francis-ngannou', 'Francis Ngannou', 'Francis Ngannou is a widely recognised combat sports figure associated with Africa.', 2, 'africa', 'combat sports'),
  ('hakeem_olajuwon_identity', 'hakeem-olajuwon', 'Hakeem Olajuwon', 'Hakeem Olajuwon is a widely recognised basketball figure associated with Africa.', 2, 'africa', 'basketball'),
  ('chimamanda_ngozi_adichie_identity', 'chimamanda-ngozi-adichie', 'Chimamanda Ngozi Adichie', 'Chimamanda Ngozi Adichie is a widely recognised literature figure associated with Africa.', 2, 'africa', 'literature'),
  ('wole_soyinka_identity', 'wole-soyinka', 'Wole Soyinka', 'Wole Soyinka is a widely recognised literature figure associated with Africa.', 2, 'africa', 'literature'),
  ('ngugi_wa_thiongo_identity', 'ngugi-wa-thiongo', 'Ngũgĩ wa Thiong''o', 'Ngũgĩ wa Thiong''o is a widely recognised literature figure associated with Africa.', 1, 'africa', 'literature'),
  ('miriam_makeba_identity', 'miriam-makeba', 'Miriam Makeba', 'Miriam Makeba is a widely recognised music figure associated with Africa.', 2, 'africa', 'music'),
  ('oprah_winfrey_identity', 'oprah-winfrey', 'Oprah Winfrey', 'Oprah Winfrey is a widely recognised media figure associated with Global.', 1, 'global', 'media'),
  ('beyonce_identity', 'beyonce', 'Beyoncé', 'Beyoncé is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('rihanna_identity', 'rihanna', 'Rihanna', 'Rihanna is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('taylor_swift_identity', 'taylor-swift', 'Taylor Swift', 'Taylor Swift is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('michael_jackson_identity', 'michael-jackson', 'Michael Jackson', 'Michael Jackson is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('dwayne_johnson_identity', 'dwayne-johnson', 'Dwayne Johnson', 'Dwayne Johnson is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('will_smith_identity', 'will-smith', 'Will Smith', 'Will Smith is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('leonardo_dicaprio_identity', 'leonardo-dicaprio', 'Leonardo DiCaprio', 'Leonardo DiCaprio is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('tom_cruise_identity', 'tom-cruise', 'Tom Cruise', 'Tom Cruise is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('jackie_chan_identity', 'jackie-chan', 'Jackie Chan', 'Jackie Chan is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('shah_rukh_khan_identity', 'shah-rukh-khan', 'Shah Rukh Khan', 'Shah Rukh Khan is a widely recognised film figure associated with Global.', 1, 'global', 'film'),
  ('mrbeast_identity', 'mrbeast', 'MrBeast', 'MrBeast is a widely recognised digital media figure associated with Global.', 1, 'global', 'digital media'),
  ('elon_musk_identity', 'elon-musk', 'Elon Musk', 'Elon Musk is a widely recognised technology figure associated with Global.', 1, 'global', 'technology'),
  ('bill_gates_identity', 'bill-gates', 'Bill Gates', 'Bill Gates is a widely recognised technology figure associated with Global.', 1, 'global', 'technology'),
  ('steve_jobs_identity', 'steve-jobs', 'Steve Jobs', 'Steve Jobs is a widely recognised technology figure associated with Global.', 1, 'global', 'technology'),
  ('mark_zuckerberg_identity', 'mark-zuckerberg', 'Mark Zuckerberg', 'Mark Zuckerberg is a widely recognised technology figure associated with Global.', 1, 'global', 'technology'),
  ('jeff_bezos_identity', 'jeff-bezos', 'Jeff Bezos', 'Jeff Bezos is a widely recognised business figure associated with Global.', 1, 'global', 'business'),
  ('queen_elizabeth_ii_identity', 'queen-elizabeth-ii', 'Elizabeth II', 'Elizabeth II is a widely recognised royalty figure associated with Global.', 1, 'global', 'royalty'),
  ('king_charles_iii_identity', 'king-charles-iii', 'Charles III', 'Charles III is a widely recognised royalty figure associated with Global.', 1, 'global', 'royalty'),
  ('princess_diana_identity', 'princess-diana', 'Princess Diana', 'Princess Diana is a widely recognised royalty figure associated with Global.', 1, 'global', 'royalty'),
  ('muhammad_ali_identity', 'muhammad-ali', 'Muhammad Ali', 'Muhammad Ali is a widely recognised combat sports figure associated with Global.', 1, 'global', 'combat sports'),
  ('usain_bolt_identity', 'usain-bolt', 'Usain Bolt', 'Usain Bolt is a widely recognised athletics figure associated with Global.', 1, 'global', 'athletics'),
  ('serena_williams_identity', 'serena-williams', 'Serena Williams', 'Serena Williams is a widely recognised tennis figure associated with Global.', 1, 'global', 'tennis'),
  ('lebron_james_identity', 'lebron-james', 'LeBron James', 'LeBron James is a widely recognised basketball figure associated with Global.', 1, 'global', 'basketball'),
  ('tiger_woods_identity', 'tiger-woods', 'Tiger Woods', 'Tiger Woods is a widely recognised golf figure associated with Global.', 1, 'global', 'golf'),
  ('lewis_hamilton_identity', 'lewis-hamilton', 'Lewis Hamilton', 'Lewis Hamilton is a widely recognised motorsport figure associated with Global.', 1, 'global', 'motorsport'),
  ('kylian_mbappe_identity', 'kylian-mbappe', 'Kylian Mbappé', 'Kylian Mbappé is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('neymar_identity', 'neymar', 'Neymar', 'Neymar is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('erling_haaland_identity', 'erling-haaland', 'Erling Haaland', 'Erling Haaland is a widely recognised football figure associated with Global.', 1, 'global', 'football'),
  ('pep_guardiola_identity', 'pep-guardiola', 'Pep Guardiola', 'Pep Guardiola is a widely recognised football figure associated with Global.', 2, 'global', 'football'),
  ('jose_mourinho_identity', 'jose-mourinho', 'José Mourinho', 'José Mourinho is a widely recognised football figure associated with Global.', 2, 'global', 'football'),
  ('adele_identity', 'adele', 'Adele', 'Adele is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('drake_identity', 'drake', 'Drake', 'Drake is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('ed_sheeran_identity', 'ed-sheeran', 'Ed Sheeran', 'Ed Sheeran is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('justin_bieber_identity', 'justin-bieber', 'Justin Bieber', 'Justin Bieber is a widely recognised music figure associated with Global.', 1, 'global', 'music'),
  ('kim_kardashian_identity', 'kim-kardashian', 'Kim Kardashian', 'Kim Kardashian is a widely recognised television figure associated with Global.', 1, 'global', 'television'),
  ('greta_thunberg_identity', 'greta-thunberg', 'Greta Thunberg', 'Greta Thunberg is a widely recognised activism figure associated with Global.', 2, 'global', 'activism'),
  ('malala_yousafzai_identity', 'malala-yousafzai', 'Malala Yousafzai', 'Malala Yousafzai is a widely recognised activism figure associated with Global.', 1, 'global', 'activism'),
  ('donald_trump_identity', 'donald-trump', 'Donald Trump', 'Donald Trump is a widely recognised leadership figure associated with Global.', 1, 'global', 'leadership'),
  ('pope_francis_identity', 'pope-francis', 'Pope Francis', 'Pope Francis is a widely recognised religion figure associated with Global.', 1, 'global', 'religion')
) as v(question_slug,asset_key,identity_name,explanation,difficulty,region,field)
join public.questions q on q.slug=v.question_slug
on conflict(question_id,position) do update set option_text=excluded.option_text,is_correct=true;

-- Do not serve hand-drawn fallbacks when no verified portrait exists.
update public.questions q set status='retired',updated_at=now()
from public.media_assets m
where q.media_id=m.id and q.game_mode='who_am_i' and m.provider='game_mavelas'
  and m.asset_key in ('mekatilili-wa-menza', 'bien-aime-baraza', 'churchill-ndambuki', 'njugush', 'eric-omondi', 'amina-mohamed', 'jeff-koinange', 'elsa-majimbo');

delete from public.round_template_steps
where template_id=(select id from public.round_templates where code='who_am_i_kenya') and position>1;

update public.round_template_steps
set category_id=(select id from public.categories where code='who_am_i_icons'),difficulty_min=1,difficulty_max=5,question_count=10,seconds_per_question=90
where template_id=(select id from public.round_templates where code='who_am_i_kenya');

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
  ('google', '/logos/google.svg', 'Google logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/google.svg'),
  ('discord', '/logos/discord.svg', 'Discord logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/discord.svg'),
  ('cisco', '/logos/cisco.svg', 'Cisco logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/cisco_light.svg'),
  ('paypal', '/logos/paypal.svg', 'PayPal logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/paypal.svg'),
  ('youtube', '/logos/youtube.svg', 'YouTube logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/youtube.svg'),
  ('netflix', '/logos/netflix.svg', 'Netflix logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/netflix-icon.svg'),
  ('spotify', '/logos/spotify.svg', 'Spotify logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/spotify.svg'),
  ('nvidia', '/logos/nvidia.svg', 'NVIDIA logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/nvidia-icon-light.svg'),
  ('linkedin', '/logos/linkedin.svg', 'LinkedIn logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/linkedin.svg'),
  ('facebook', '/logos/facebook.svg', 'Facebook logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/facebook-icon.svg'),
  ('whatsapp', '/logos/whatsapp.svg', 'WhatsApp logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/whatsapp-icon.svg'),
  ('amazon-web-services', '/logos/amazon-web-services.svg', 'Amazon Web Services logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/aws_light.svg'),
  ('microsoft', '/logos/microsoft.svg', 'Microsoft logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft.svg'),
  ('microsoft-azure', '/logos/microsoft-azure.svg', 'Microsoft Azure logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/azure.svg'),
  ('telegram', '/logos/telegram.svg', 'Telegram logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/telegram.svg'),
  ('windows', '/logos/windows.svg', 'Windows logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/windows.svg'),
  ('chrome', '/logos/chrome.svg', 'Chrome logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/chrome.svg'),
  ('cloudflare', '/logos/cloudflare.svg', 'Cloudflare logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/cloudflare.svg'),
  ('apple', '/logos/apple.svg', 'Apple logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/apple.svg'),
  ('disney', '/logos/disney.svg', 'Disney+ logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/disneyplus.svg'),
  ('reddit', '/logos/reddit.svg', 'Reddit logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/reddit.svg'),
  ('canva', '/logos/canva.svg', 'Canva logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/canva.svg'),
  ('airbnb', '/logos/airbnb.svg', 'Airbnb logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/airbnb.svg'),
  ('safari', '/logos/safari.svg', 'Safari logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/safari.svg'),
  ('shopify', '/logos/shopify.svg', 'Shopify logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/shopify.svg'),
  ('firefox', '/logos/firefox.svg', 'Firefox logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/firefox.svg'),
  ('instagram', '/logos/instagram.svg', 'Instagram logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/instagram-icon.svg'),
  ('bitcoin', '/logos/bitcoin.svg', 'Bitcoin logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/btc.svg'),
  ('adobe', '/logos/adobe.svg', 'Adobe logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/adobe.svg'),
  ('ethereum', '/logos/ethereum.svg', 'Ethereum logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/eth.svg'),
  ('uber', '/logos/uber.svg', 'Uber logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/uber_light.svg'),
  ('github', '/logos/github.svg', 'GitHub logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/github_light.svg'),
  ('ebay', '/logos/ebay.svg', 'Ebay logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/ebay.svg'),
  ('pinterest', '/logos/pinterest.svg', 'Pinterest logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/pinterest.svg'),
  ('snapchat', '/logos/snapchat.svg', 'Snapchat logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/snapchat.svg'),
  ('tiktok', '/logos/tiktok.svg', 'TikTok logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/tiktok-icon-light.svg'),
  ('ibm', '/logos/ibm.svg', 'IBM logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/ibm.svg'),
  ('playstation', '/logos/playstation.svg', 'PlayStation logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/playstation.svg'),
  ('slack', '/logos/slack.svg', 'Slack logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/slack.svg'),
  ('xbox', '/logos/xbox.svg', 'Xbox logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/xbox.svg'),
  ('meta', '/logos/meta.svg', 'Meta logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/meta.svg'),
  ('prime-video', '/logos/prime-video.svg', 'Prime video logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/prime-video.svg'),
  ('google-play', '/logos/google-play.svg', 'Google Play logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/googleplay.svg'),
  ('app-store', '/logos/app-store.svg', 'App Store logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/appstore.svg'),
  ('zoom', '/logos/zoom.svg', 'Zoom logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/zoom.svg'),
  ('google-maps', '/logos/google-maps.svg', 'Google Maps logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/googleMaps.svg'),
  ('android', '/logos/android.svg', 'Android logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/android-icon.svg'),
  ('stripe', '/logos/stripe.svg', 'Stripe logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/stripe.svg'),
  ('notion', '/logos/notion.svg', 'Notion logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/notion.svg'),
  ('dropbox', '/logos/dropbox.svg', 'Dropbox logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/dropbox.svg'),
  ('twitch', '/logos/twitch.svg', 'Twitch logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/twitch.svg'),
  ('google-meet', '/logos/google-meet.svg', 'Google Meet logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/google-meet.svg'),
  ('google-sheets', '/logos/google-sheets.svg', 'Google Sheets logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/google-sheets.svg'),
  ('google-slides', '/logos/google-slides.svg', 'Google Slides logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/google-slides.svg'),
  ('x', '/logos/x.svg', 'X logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/x.svg'),
  ('binance', '/logos/binance.svg', 'Binance logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/binance.svg'),
  ('google-calendar', '/logos/google-calendar.svg', 'Google Calendar logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/google-calendar.svg'),
  ('gmail', '/logos/gmail.svg', 'Gmail logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/gmail.svg'),
  ('microsoft-teams', '/logos/microsoft-teams.svg', 'Microsoft Teams logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft-teams.svg'),
  ('google-drive', '/logos/google-drive.svg', 'Google Drive logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/drive.svg'),
  ('microsoft-excel', '/logos/microsoft-excel.svg', 'Microsoft Excel logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft-excel.svg'),
  ('messenger', '/logos/messenger.svg', 'Messenger logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/messenger.svg'),
  ('microsoft-powerpoint', '/logos/microsoft-powerpoint.svg', 'Microsoft PowerPoint logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft-powerpoint.svg'),
  ('threads', '/logos/threads.svg', 'Threads logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/threads.svg'),
  ('microsoft-word', '/logos/microsoft-word.svg', 'Microsoft Word logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft-word.svg'),
  ('apple-music', '/logos/apple-music.svg', 'Apple Music logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/apple-music-icon.svg'),
  ('bluesky', '/logos/bluesky.svg', 'Bluesky logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/bluesky.svg'),
  ('microsoft-onedrive', '/logos/microsoft-onedrive.svg', 'Microsoft OneDrive logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft-onedrive.svg'),
  ('microsoft-outlook', '/logos/microsoft-outlook.svg', 'Microsoft Outlook logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/microsoft-outlook.svg'),
  ('youtube-music', '/logos/youtube-music.svg', 'Youtube Music logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/youtube_music.svg'),
  ('figma', '/logos/figma.svg', 'Figma logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/figma.svg'),
  ('soundcloud', '/logos/soundcloud.svg', 'SoundCloud logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/soundcloud-logo.svg'),
  ('acrobat-reader', '/logos/acrobat-reader.svg', 'Acrobat Reader logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/acrobat-reader.svg'),
  ('hulu', '/logos/hulu.svg', 'Hulu logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/hulu.svg'),
  ('roblox', '/logos/roblox.svg', 'Roblox logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/roblox_light.svg'),
  ('brave-browser', '/logos/brave-browser.svg', 'Brave Browser logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/brave.svg'),
  ('opera', '/logos/opera.svg', 'Opera logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/opera.svg'),
  ('edge', '/logos/edge.svg', 'Edge logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/edge.svg'),
  ('steam', '/logos/steam.svg', 'Steam logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/steam.svg'),
  ('openai', '/logos/openai.svg', 'OpenAI logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/openai.svg'),
  ('gitlab', '/logos/gitlab.svg', 'GitLab logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/gitlab.svg'),
  ('trello', '/logos/trello.svg', 'Trello logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/trello.svg'),
  ('salesforce', '/logos/salesforce.svg', 'Salesforce logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/salesforce.svg'),
  ('asana', '/logos/asana.svg', 'Asana logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/asana-logo.svg'),
  ('docker', '/logos/docker.svg', 'Docker logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/docker.svg'),
  ('coursera', '/logos/coursera.svg', 'Coursera logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/coursera.svg'),
  ('wordpress', '/logos/wordpress.svg', 'WordPress logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/wordpress.svg'),
  ('udemy', '/logos/udemy.svg', 'Udemy logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/udemy.svg'),
  ('coinbase', '/logos/coinbase.svg', 'Coinbase logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/coinbase.svg'),
  ('google-classroom', '/logos/google-classroom.svg', 'Google Classroom logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/google-classroom.svg'),
  ('google-chat', '/logos/google-chat.svg', 'Google Chat logo', 'SVGL cached asset · Brand belongs to its owner', 'Brand trademark · https://svgl.app/library/google-chat.svg'),
  ('safaricom', '/logos/safaricom.svg', 'Safaricom logo', 'SeekLogo · Wikimedia Commons', 'CC0 · https://commons.wikimedia.org/wiki/File:Safaricom-logo-png_seeklogo-530479.svg'),
  ('m-pesa', '/logos/m-pesa.svg', 'M-PESA logo', 'Vodafone · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:M-PESA_LOGO-01.svg'),
  ('kenya-airways', '/logos/kenya-airways.svg', 'Kenya Airways logo', 'Kenya Airways · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Kenya_Airways_Logo.svg'),
  ('co-operative-bank', '/logos/co-operative-bank.svg', 'Co-operative Bank logo', 'Coopbank of Kenya · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Coopbanklogo.jpg'),
  ('jumia', '/logos/jumia.svg', 'Jumia logo', 'JumiaGroup · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:JumiaLogo_(14).png'),
  ('mtn', '/logos/mtn.svg', 'MTN logo', 'MTN · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:MTN_Logo.svg'),
  ('shoprite', '/logos/shoprite.svg', 'Shoprite logo', 'Martin a1999a · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Logo_-_Shoprite_-_SUPERMARCE.jpg'),
  ('dstv', '/logos/dstv.svg', 'DStv logo', 'Gadgenator · Wikimedia Commons', 'CC BY-SA 3.0 · https://commons.wikimedia.org/wiki/File:DStv_Logo_2012.png'),
  ('ethiopian-airlines', '/logos/ethiopian-airlines.svg', 'Ethiopian Airlines logo', 'Ethiopian Airlines · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Ethiopian_Airlines_Logo.svg'),
  ('ecobank', '/logos/ecobank.svg', 'Ecobank logo', 'Ecobank Transnational Incorporated · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Ecobank_Logo.svg'),
  ('absa', '/logos/absa.svg', 'Absa logo', 'Absa Group Limited · Wikimedia Commons', 'Public domain · https://commons.wikimedia.org/wiki/File:Absa_Logo.svg'),
  ('flutterwave', '/logos/flutterwave.svg', 'Flutterwave logo', 'Opelogbon · Wikimedia Commons', 'CC BY-SA 4.0 · https://commons.wikimedia.org/wiki/File:Flutterwave_Logo.png')
) as v(asset_key,public_url,alt_text,attribution,licence)
join public.question_sources s on s.source_key='logo_rush_assets'
on conflict(provider,asset_key) do update set public_url=excluded.public_url,alt_text=excluded.alt_text,attribution=excluded.attribution,licence=excluded.licence,source_id=excluded.source_id;

insert into public.questions(slug,pack_id,category_id,game_mode,prompt,explanation,media_id,difficulty,duration_seconds,base_points,tags,status,source_id,fact_checked_at)
select v.slug,p.id,c.id,'logo_quiz','Which brand owns this logo?',concat('This is the ',v.brand_name,' logo.'),m.id,v.difficulty,20,v.points,array['logo',v.region], 'approved',s.id,now()
from (values
  ('logo_google', 'google', 'Google', 1, 100, 'international'),
  ('logo_discord', 'discord', 'Discord', 1, 100, 'international'),
  ('logo_cisco', 'cisco', 'Cisco', 1, 100, 'international'),
  ('logo_paypal', 'paypal', 'PayPal', 1, 100, 'international'),
  ('logo_youtube', 'youtube', 'YouTube', 1, 100, 'international'),
  ('logo_netflix', 'netflix', 'Netflix', 1, 100, 'international'),
  ('logo_spotify', 'spotify', 'Spotify', 1, 100, 'international'),
  ('logo_nvidia', 'nvidia', 'NVIDIA', 1, 100, 'international'),
  ('logo_linkedin', 'linkedin', 'LinkedIn', 1, 100, 'international'),
  ('logo_facebook', 'facebook', 'Facebook', 1, 100, 'international'),
  ('logo_whatsapp', 'whatsapp', 'WhatsApp', 1, 100, 'international'),
  ('logo_amazon_web_services', 'amazon-web-services', 'Amazon Web Services', 1, 100, 'international'),
  ('logo_microsoft', 'microsoft', 'Microsoft', 1, 100, 'international'),
  ('logo_microsoft_azure', 'microsoft-azure', 'Microsoft Azure', 1, 100, 'international'),
  ('logo_telegram', 'telegram', 'Telegram', 1, 100, 'international'),
  ('logo_windows', 'windows', 'Windows', 1, 100, 'international'),
  ('logo_chrome', 'chrome', 'Chrome', 1, 100, 'international'),
  ('logo_cloudflare', 'cloudflare', 'Cloudflare', 1, 100, 'international'),
  ('logo_apple', 'apple', 'Apple', 1, 100, 'international'),
  ('logo_disney', 'disney', 'Disney+', 1, 100, 'international'),
  ('logo_reddit', 'reddit', 'Reddit', 1, 100, 'international'),
  ('logo_canva', 'canva', 'Canva', 1, 100, 'international'),
  ('logo_airbnb', 'airbnb', 'Airbnb', 1, 100, 'international'),
  ('logo_safari', 'safari', 'Safari', 1, 100, 'international'),
  ('logo_shopify', 'shopify', 'Shopify', 1, 100, 'international'),
  ('logo_firefox', 'firefox', 'Firefox', 1, 100, 'international'),
  ('logo_instagram', 'instagram', 'Instagram', 1, 100, 'international'),
  ('logo_bitcoin', 'bitcoin', 'Bitcoin', 1, 100, 'international'),
  ('logo_adobe', 'adobe', 'Adobe', 1, 100, 'international'),
  ('logo_ethereum', 'ethereum', 'Ethereum', 1, 100, 'international'),
  ('logo_uber', 'uber', 'Uber', 2, 150, 'international'),
  ('logo_github', 'github', 'GitHub', 2, 150, 'international'),
  ('logo_ebay', 'ebay', 'Ebay', 2, 150, 'international'),
  ('logo_pinterest', 'pinterest', 'Pinterest', 2, 150, 'international'),
  ('logo_snapchat', 'snapchat', 'Snapchat', 2, 150, 'international'),
  ('logo_tiktok', 'tiktok', 'TikTok', 2, 150, 'international'),
  ('logo_ibm', 'ibm', 'IBM', 2, 150, 'international'),
  ('logo_playstation', 'playstation', 'PlayStation', 2, 150, 'international'),
  ('logo_slack', 'slack', 'Slack', 2, 150, 'international'),
  ('logo_xbox', 'xbox', 'Xbox', 2, 150, 'international'),
  ('logo_meta', 'meta', 'Meta', 2, 150, 'international'),
  ('logo_prime_video', 'prime-video', 'Prime video', 2, 150, 'international'),
  ('logo_google_play', 'google-play', 'Google Play', 2, 150, 'international'),
  ('logo_app_store', 'app-store', 'App Store', 2, 150, 'international'),
  ('logo_zoom', 'zoom', 'Zoom', 2, 150, 'international'),
  ('logo_google_maps', 'google-maps', 'Google Maps', 2, 150, 'international'),
  ('logo_android', 'android', 'Android', 2, 150, 'international'),
  ('logo_stripe', 'stripe', 'Stripe', 2, 150, 'international'),
  ('logo_notion', 'notion', 'Notion', 2, 150, 'international'),
  ('logo_dropbox', 'dropbox', 'Dropbox', 2, 150, 'international'),
  ('logo_twitch', 'twitch', 'Twitch', 2, 150, 'international'),
  ('logo_google_meet', 'google-meet', 'Google Meet', 2, 150, 'international'),
  ('logo_google_sheets', 'google-sheets', 'Google Sheets', 2, 150, 'international'),
  ('logo_google_slides', 'google-slides', 'Google Slides', 2, 150, 'international'),
  ('logo_x', 'x', 'X', 2, 150, 'international'),
  ('logo_binance', 'binance', 'Binance', 2, 150, 'international'),
  ('logo_google_calendar', 'google-calendar', 'Google Calendar', 2, 150, 'international'),
  ('logo_gmail', 'gmail', 'Gmail', 2, 150, 'international'),
  ('logo_microsoft_teams', 'microsoft-teams', 'Microsoft Teams', 2, 150, 'international'),
  ('logo_google_drive', 'google-drive', 'Google Drive', 2, 150, 'international'),
  ('logo_microsoft_excel', 'microsoft-excel', 'Microsoft Excel', 2, 150, 'international'),
  ('logo_messenger', 'messenger', 'Messenger', 2, 150, 'international'),
  ('logo_microsoft_powerpoint', 'microsoft-powerpoint', 'Microsoft PowerPoint', 2, 150, 'international'),
  ('logo_threads', 'threads', 'Threads', 2, 150, 'international'),
  ('logo_microsoft_word', 'microsoft-word', 'Microsoft Word', 2, 150, 'international'),
  ('logo_apple_music', 'apple-music', 'Apple Music', 2, 150, 'international'),
  ('logo_bluesky', 'bluesky', 'Bluesky', 2, 150, 'international'),
  ('logo_microsoft_onedrive', 'microsoft-onedrive', 'Microsoft OneDrive', 2, 150, 'international'),
  ('logo_microsoft_outlook', 'microsoft-outlook', 'Microsoft Outlook', 2, 150, 'international'),
  ('logo_youtube_music', 'youtube-music', 'Youtube Music', 2, 150, 'international'),
  ('logo_figma', 'figma', 'Figma', 2, 150, 'international'),
  ('logo_soundcloud', 'soundcloud', 'SoundCloud', 2, 150, 'international'),
  ('logo_acrobat_reader', 'acrobat-reader', 'Acrobat Reader', 2, 150, 'international'),
  ('logo_hulu', 'hulu', 'Hulu', 2, 150, 'international'),
  ('logo_roblox', 'roblox', 'Roblox', 2, 150, 'international'),
  ('logo_brave_browser', 'brave-browser', 'Brave Browser', 2, 150, 'international'),
  ('logo_opera', 'opera', 'Opera', 2, 150, 'international'),
  ('logo_edge', 'edge', 'Edge', 2, 150, 'international'),
  ('logo_steam', 'steam', 'Steam', 2, 150, 'international'),
  ('logo_openai', 'openai', 'OpenAI', 2, 150, 'international'),
  ('logo_gitlab', 'gitlab', 'GitLab', 2, 150, 'international'),
  ('logo_trello', 'trello', 'Trello', 2, 150, 'international'),
  ('logo_salesforce', 'salesforce', 'Salesforce', 2, 150, 'international'),
  ('logo_asana', 'asana', 'Asana', 2, 150, 'international'),
  ('logo_docker', 'docker', 'Docker', 2, 150, 'international'),
  ('logo_coursera', 'coursera', 'Coursera', 2, 150, 'international'),
  ('logo_wordpress', 'wordpress', 'WordPress', 2, 150, 'international'),
  ('logo_udemy', 'udemy', 'Udemy', 2, 150, 'international'),
  ('logo_coinbase', 'coinbase', 'Coinbase', 2, 150, 'international'),
  ('logo_google_classroom', 'google-classroom', 'Google Classroom', 2, 150, 'international'),
  ('logo_google_chat', 'google-chat', 'Google Chat', 2, 150, 'international'),
  ('logo_safaricom', 'safaricom', 'Safaricom', 2, 150, 'kenya'),
  ('logo_m_pesa', 'm-pesa', 'M-PESA', 2, 150, 'kenya'),
  ('logo_kenya_airways', 'kenya-airways', 'Kenya Airways', 2, 150, 'kenya'),
  ('logo_co_operative_bank', 'co-operative-bank', 'Co-operative Bank', 2, 150, 'kenya'),
  ('logo_jumia', 'jumia', 'Jumia', 3, 200, 'africa'),
  ('logo_mtn', 'mtn', 'MTN', 3, 200, 'africa'),
  ('logo_shoprite', 'shoprite', 'Shoprite', 3, 200, 'africa'),
  ('logo_dstv', 'dstv', 'DStv', 3, 200, 'africa'),
  ('logo_ethiopian_airlines', 'ethiopian-airlines', 'Ethiopian Airlines', 3, 200, 'africa'),
  ('logo_ecobank', 'ecobank', 'Ecobank', 3, 200, 'africa'),
  ('logo_absa', 'absa', 'Absa', 3, 200, 'africa'),
  ('logo_flutterwave', 'flutterwave', 'Flutterwave', 3, 200, 'africa')
) as v(slug,asset_key,brand_name,difficulty,points,region)
join public.content_packs p on p.code='logo_rush'
join public.categories c on c.code='brand_logos'
join public.media_assets m on m.provider='game_mavelas_logos' and m.asset_key=v.asset_key
join public.question_sources s on s.source_key='logo_rush_assets'
on conflict(slug) do update set pack_id=excluded.pack_id,category_id=excluded.category_id,game_mode=excluded.game_mode,prompt=excluded.prompt,explanation=excluded.explanation,media_id=excluded.media_id,difficulty=excluded.difficulty,duration_seconds=excluded.duration_seconds,base_points=excluded.base_points,tags=excluded.tags,status='approved',source_id=excluded.source_id,fact_checked_at=now(),updated_at=now();

update public.question_options qo
set option_text='__logo_regen__'||qo.id::text,is_correct=false
from public.questions q
where qo.question_id=q.id and q.pack_id=(select id from public.content_packs where code='logo_rush');

insert into public.question_options(question_id,position,option_text,is_correct)
select q.id,v.position,v.option_text,v.is_correct
from (values
  ('logo_google', 1, 'Google', true),
  ('logo_google', 2, 'Discord', false),
  ('logo_google', 3, 'Microsoft', false),
  ('logo_google', 4, 'Safari', false),
  ('logo_discord', 1, 'Discord', true),
  ('logo_discord', 2, 'LinkedIn', false),
  ('logo_discord', 3, 'Disney+', false),
  ('logo_discord', 4, 'Uber', false),
  ('logo_cisco', 1, 'Cisco', true),
  ('logo_cisco', 2, 'Windows', false),
  ('logo_cisco', 3, 'Instagram', false),
  ('logo_cisco', 4, 'PlayStation', false),
  ('logo_paypal', 1, 'PayPal', true),
  ('logo_paypal', 2, 'Airbnb', false),
  ('logo_paypal', 3, 'Pinterest', false),
  ('logo_paypal', 4, 'Zoom', false),
  ('logo_youtube', 1, 'YouTube', true),
  ('logo_youtube', 2, 'Ethereum', false),
  ('logo_youtube', 3, 'Meta', false),
  ('logo_youtube', 4, 'Google Meet', false),
  ('logo_netflix', 1, 'Netflix', true),
  ('logo_netflix', 2, 'IBM', false),
  ('logo_netflix', 3, 'Stripe', false),
  ('logo_netflix', 4, 'Microsoft Teams', false),
  ('logo_spotify', 1, 'Spotify', true),
  ('logo_spotify', 2, 'App Store', false),
  ('logo_spotify', 3, 'X', false),
  ('logo_spotify', 4, 'Apple Music', false),
  ('logo_nvidia', 1, 'NVIDIA', true),
  ('logo_nvidia', 2, 'Twitch', false),
  ('logo_nvidia', 3, 'Messenger', false),
  ('logo_nvidia', 4, 'Acrobat Reader', false),
  ('logo_linkedin', 1, 'LinkedIn', true),
  ('logo_linkedin', 2, 'Gmail', false),
  ('logo_linkedin', 3, 'Microsoft Outlook', false),
  ('logo_linkedin', 4, 'OpenAI', false),
  ('logo_facebook', 1, 'Facebook', true),
  ('logo_facebook', 2, 'Microsoft Word', false),
  ('logo_facebook', 3, 'Brave Browser', false),
  ('logo_facebook', 4, 'WordPress', false),
  ('logo_whatsapp', 1, 'WhatsApp', true),
  ('logo_whatsapp', 2, 'SoundCloud', false),
  ('logo_whatsapp', 3, 'Salesforce', false),
  ('logo_whatsapp', 4, 'Cisco', false),
  ('logo_amazon_web_services', 1, 'Amazon Web Services', true),
  ('logo_amazon_web_services', 2, 'Steam', false),
  ('logo_amazon_web_services', 3, 'Google Classroom', false),
  ('logo_amazon_web_services', 4, 'Facebook', false),
  ('logo_microsoft', 1, 'Microsoft', true),
  ('logo_microsoft', 2, 'Coursera', false),
  ('logo_microsoft', 3, 'Netflix', false),
  ('logo_microsoft', 4, 'Cloudflare', false),
  ('logo_microsoft_azure', 1, 'Microsoft Azure', true),
  ('logo_microsoft_azure', 2, 'Discord', false),
  ('logo_microsoft_azure', 3, 'Microsoft', false),
  ('logo_microsoft_azure', 4, 'Shopify', false),
  ('logo_telegram', 1, 'Telegram', true),
  ('logo_telegram', 2, 'LinkedIn', false),
  ('logo_telegram', 3, 'Reddit', false),
  ('logo_telegram', 4, 'GitHub', false),
  ('logo_windows', 1, 'Windows', true),
  ('logo_windows', 2, 'Chrome', false),
  ('logo_windows', 3, 'Bitcoin', false),
  ('logo_windows', 4, 'Slack', false),
  ('logo_chrome', 1, 'Chrome', true),
  ('logo_chrome', 2, 'Safari', false),
  ('logo_chrome', 3, 'Snapchat', false),
  ('logo_chrome', 4, 'Google Maps', false),
  ('logo_cloudflare', 1, 'Cloudflare', true),
  ('logo_cloudflare', 2, 'Uber', false),
  ('logo_cloudflare', 3, 'Prime video', false),
  ('logo_cloudflare', 4, 'Google Sheets', false),
  ('logo_apple', 1, 'Apple', true),
  ('logo_apple', 2, 'PlayStation', false),
  ('logo_apple', 3, 'Notion', false),
  ('logo_apple', 4, 'Google Drive', false),
  ('logo_disney', 1, 'Disney+', true),
  ('logo_disney', 2, 'Zoom', false),
  ('logo_disney', 3, 'Binance', false),
  ('logo_disney', 4, 'Bluesky', false),
  ('logo_reddit', 1, 'Reddit', true),
  ('logo_reddit', 2, 'Google Meet', false),
  ('logo_reddit', 3, 'Microsoft PowerPoint', false),
  ('logo_reddit', 4, 'Hulu', false),
  ('logo_canva', 1, 'Canva', true),
  ('logo_canva', 2, 'Microsoft Teams', false),
  ('logo_canva', 3, 'Youtube Music', false),
  ('logo_canva', 4, 'GitLab', false),
  ('logo_airbnb', 1, 'Airbnb', true),
  ('logo_airbnb', 2, 'Apple Music', false),
  ('logo_airbnb', 3, 'Opera', false),
  ('logo_airbnb', 4, 'Udemy', false),
  ('logo_safari', 1, 'Safari', true),
  ('logo_safari', 2, 'Acrobat Reader', false),
  ('logo_safari', 3, 'Asana', false),
  ('logo_safari', 4, 'PayPal', false),
  ('logo_shopify', 1, 'Shopify', true),
  ('logo_shopify', 2, 'OpenAI', false),
  ('logo_shopify', 3, 'Google Chat', false),
  ('logo_shopify', 4, 'WhatsApp', false),
  ('logo_firefox', 1, 'Firefox', true),
  ('logo_firefox', 2, 'WordPress', false),
  ('logo_firefox', 3, 'Spotify', false),
  ('logo_firefox', 4, 'Cloudflare', false),
  ('logo_instagram', 1, 'Instagram', true),
  ('logo_instagram', 2, 'Cisco', false),
  ('logo_instagram', 3, 'Microsoft Azure', false),
  ('logo_instagram', 4, 'Shopify', false),
  ('logo_bitcoin', 1, 'Bitcoin', true),
  ('logo_bitcoin', 2, 'Facebook', false),
  ('logo_bitcoin', 3, 'Reddit', false),
  ('logo_bitcoin', 4, 'Ebay', false),
  ('logo_adobe', 1, 'Adobe', true),
  ('logo_adobe', 2, 'Chrome', false),
  ('logo_adobe', 3, 'Bitcoin', false),
  ('logo_adobe', 4, 'Xbox', false),
  ('logo_ethereum', 1, 'Ethereum', true),
  ('logo_ethereum', 2, 'Safari', false),
  ('logo_ethereum', 3, 'TikTok', false),
  ('logo_ethereum', 4, 'Android', false),
  ('logo_uber', 1, 'Uber', true),
  ('logo_uber', 2, 'GitHub', false),
  ('logo_uber', 3, 'Google Play', false),
  ('logo_uber', 4, 'Google Slides', false),
  ('logo_github', 1, 'GitHub', true),
  ('logo_github', 2, 'Slack', false),
  ('logo_github', 3, 'Dropbox', false),
  ('logo_github', 4, 'Microsoft Excel', false),
  ('logo_ebay', 1, 'Ebay', true),
  ('logo_ebay', 2, 'Google Maps', false),
  ('logo_ebay', 3, 'Google Calendar', false),
  ('logo_ebay', 4, 'Microsoft OneDrive', false),
  ('logo_pinterest', 1, 'Pinterest', true),
  ('logo_pinterest', 2, 'Google Sheets', false),
  ('logo_pinterest', 3, 'Threads', false),
  ('logo_pinterest', 4, 'Roblox', false),
  ('logo_snapchat', 1, 'Snapchat', true),
  ('logo_snapchat', 2, 'Google Drive', false),
  ('logo_snapchat', 3, 'Figma', false),
  ('logo_snapchat', 4, 'Trello', false),
  ('logo_tiktok', 1, 'TikTok', true),
  ('logo_tiktok', 2, 'Bluesky', false),
  ('logo_tiktok', 3, 'Edge', false),
  ('logo_tiktok', 4, 'Coinbase', false),
  ('logo_ibm', 1, 'IBM', true),
  ('logo_ibm', 2, 'Hulu', false),
  ('logo_ibm', 3, 'Docker', false),
  ('logo_ibm', 4, 'YouTube', false),
  ('logo_playstation', 1, 'PlayStation', true),
  ('logo_playstation', 2, 'GitLab', false),
  ('logo_playstation', 3, 'Google', false),
  ('logo_playstation', 4, 'Amazon Web Services', false),
  ('logo_slack', 1, 'Slack', true),
  ('logo_slack', 2, 'Udemy', false),
  ('logo_slack', 3, 'NVIDIA', false),
  ('logo_slack', 4, 'Apple', false),
  ('logo_xbox', 1, 'Xbox', true),
  ('logo_xbox', 2, 'PayPal', false),
  ('logo_xbox', 3, 'Telegram', false),
  ('logo_xbox', 4, 'Firefox', false),
  ('logo_meta', 1, 'Meta', true),
  ('logo_meta', 2, 'WhatsApp', false),
  ('logo_meta', 3, 'Canva', false),
  ('logo_meta', 4, 'Ebay', false),
  ('logo_prime_video', 1, 'Prime video', true),
  ('logo_prime_video', 2, 'Cloudflare', false),
  ('logo_prime_video', 3, 'Adobe', false),
  ('logo_prime_video', 4, 'Xbox', false),
  ('logo_google_play', 1, 'Google Play', true),
  ('logo_google_play', 2, 'Shopify', false),
  ('logo_google_play', 3, 'TikTok', false),
  ('logo_google_play', 4, 'Stripe', false),
  ('logo_app_store', 1, 'App Store', true),
  ('logo_app_store', 2, 'GitHub', false),
  ('logo_app_store', 3, 'Google Play', false),
  ('logo_app_store', 4, 'X', false),
  ('logo_zoom', 1, 'Zoom', true),
  ('logo_zoom', 2, 'Slack', false),
  ('logo_zoom', 3, 'Twitch', false),
  ('logo_zoom', 4, 'Messenger', false),
  ('logo_google_maps', 1, 'Google Maps', true),
  ('logo_google_maps', 2, 'Android', false),
  ('logo_google_maps', 3, 'Gmail', false),
  ('logo_google_maps', 4, 'Microsoft Outlook', false),
  ('logo_android', 1, 'Android', true),
  ('logo_android', 2, 'Google Slides', false),
  ('logo_android', 3, 'Microsoft Word', false),
  ('logo_android', 4, 'Brave Browser', false),
  ('logo_stripe', 1, 'Stripe', true),
  ('logo_stripe', 2, 'Microsoft Excel', false),
  ('logo_stripe', 3, 'SoundCloud', false),
  ('logo_stripe', 4, 'Salesforce', false),
  ('logo_notion', 1, 'Notion', true),
  ('logo_notion', 2, 'Microsoft OneDrive', false),
  ('logo_notion', 3, 'Steam', false),
  ('logo_notion', 4, 'Google Classroom', false),
  ('logo_dropbox', 1, 'Dropbox', true),
  ('logo_dropbox', 2, 'Roblox', false),
  ('logo_dropbox', 3, 'Coursera', false),
  ('logo_dropbox', 4, 'Netflix', false),
  ('logo_twitch', 1, 'Twitch', true),
  ('logo_twitch', 2, 'Trello', false),
  ('logo_twitch', 3, 'Discord', false),
  ('logo_twitch', 4, 'Microsoft', false),
  ('logo_google_meet', 1, 'Google Meet', true),
  ('logo_google_meet', 2, 'Coinbase', false),
  ('logo_google_meet', 3, 'LinkedIn', false),
  ('logo_google_meet', 4, 'Disney+', false),
  ('logo_google_sheets', 1, 'Google Sheets', true),
  ('logo_google_sheets', 2, 'YouTube', false),
  ('logo_google_sheets', 3, 'Windows', false),
  ('logo_google_sheets', 4, 'Instagram', false),
  ('logo_google_slides', 1, 'Google Slides', true),
  ('logo_google_slides', 2, 'Amazon Web Services', false),
  ('logo_google_slides', 3, 'Airbnb', false),
  ('logo_google_slides', 4, 'Pinterest', false),
  ('logo_x', 1, 'X', true),
  ('logo_x', 2, 'Apple', false),
  ('logo_x', 3, 'Ethereum', false),
  ('logo_x', 4, 'Meta', false),
  ('logo_binance', 1, 'Binance', true),
  ('logo_binance', 2, 'Firefox', false),
  ('logo_binance', 3, 'IBM', false),
  ('logo_binance', 4, 'Stripe', false),
  ('logo_google_calendar', 1, 'Google Calendar', true),
  ('logo_google_calendar', 2, 'Ebay', false),
  ('logo_google_calendar', 3, 'App Store', false),
  ('logo_google_calendar', 4, 'X', false),
  ('logo_gmail', 1, 'Gmail', true),
  ('logo_gmail', 2, 'Xbox', false),
  ('logo_gmail', 3, 'Twitch', false),
  ('logo_gmail', 4, 'Microsoft PowerPoint', false),
  ('logo_microsoft_teams', 1, 'Microsoft Teams', true),
  ('logo_microsoft_teams', 2, 'Android', false),
  ('logo_microsoft_teams', 3, 'Gmail', false),
  ('logo_microsoft_teams', 4, 'Youtube Music', false),
  ('logo_google_drive', 1, 'Google Drive', true),
  ('logo_google_drive', 2, 'Google Slides', false),
  ('logo_google_drive', 3, 'Apple Music', false),
  ('logo_google_drive', 4, 'Opera', false),
  ('logo_microsoft_excel', 1, 'Microsoft Excel', true),
  ('logo_microsoft_excel', 2, 'Messenger', false),
  ('logo_microsoft_excel', 3, 'Acrobat Reader', false),
  ('logo_microsoft_excel', 4, 'Asana', false),
  ('logo_messenger', 1, 'Messenger', true),
  ('logo_messenger', 2, 'Microsoft Outlook', false),
  ('logo_messenger', 3, 'OpenAI', false),
  ('logo_messenger', 4, 'Google Chat', false),
  ('logo_microsoft_powerpoint', 1, 'Microsoft PowerPoint', true),
  ('logo_microsoft_powerpoint', 2, 'Brave Browser', false),
  ('logo_microsoft_powerpoint', 3, 'WordPress', false),
  ('logo_microsoft_powerpoint', 4, 'Spotify', false),
  ('logo_threads', 1, 'Threads', true),
  ('logo_threads', 2, 'Salesforce', false),
  ('logo_threads', 3, 'Cisco', false),
  ('logo_threads', 4, 'Microsoft Azure', false),
  ('logo_microsoft_word', 1, 'Microsoft Word', true),
  ('logo_microsoft_word', 2, 'Google Classroom', false),
  ('logo_microsoft_word', 3, 'Facebook', false),
  ('logo_microsoft_word', 4, 'Reddit', false),
  ('logo_apple_music', 1, 'Apple Music', true),
  ('logo_apple_music', 2, 'Netflix', false),
  ('logo_apple_music', 3, 'Chrome', false),
  ('logo_apple_music', 4, 'Bitcoin', false),
  ('logo_bluesky', 1, 'Bluesky', true),
  ('logo_bluesky', 2, 'Microsoft', false),
  ('logo_bluesky', 3, 'Safari', false),
  ('logo_bluesky', 4, 'Snapchat', false),
  ('logo_microsoft_onedrive', 1, 'Microsoft OneDrive', true),
  ('logo_microsoft_onedrive', 2, 'Disney+', false),
  ('logo_microsoft_onedrive', 3, 'Uber', false),
  ('logo_microsoft_onedrive', 4, 'Prime video', false),
  ('logo_microsoft_outlook', 1, 'Microsoft Outlook', true),
  ('logo_microsoft_outlook', 2, 'Instagram', false),
  ('logo_microsoft_outlook', 3, 'PlayStation', false),
  ('logo_microsoft_outlook', 4, 'Notion', false),
  ('logo_youtube_music', 1, 'Youtube Music', true),
  ('logo_youtube_music', 2, 'Pinterest', false),
  ('logo_youtube_music', 3, 'Zoom', false),
  ('logo_youtube_music', 4, 'Binance', false),
  ('logo_figma', 1, 'Figma', true),
  ('logo_figma', 2, 'Meta', false),
  ('logo_figma', 3, 'Google Meet', false),
  ('logo_figma', 4, 'Microsoft PowerPoint', false),
  ('logo_soundcloud', 1, 'SoundCloud', true),
  ('logo_soundcloud', 2, 'Stripe', false),
  ('logo_soundcloud', 3, 'Microsoft Teams', false),
  ('logo_soundcloud', 4, 'Youtube Music', false),
  ('logo_acrobat_reader', 1, 'Acrobat Reader', true),
  ('logo_acrobat_reader', 2, 'X', false),
  ('logo_acrobat_reader', 3, 'Apple Music', false),
  ('logo_acrobat_reader', 4, 'Edge', false),
  ('logo_hulu', 1, 'Hulu', true),
  ('logo_hulu', 2, 'Messenger', false),
  ('logo_hulu', 3, 'Acrobat Reader', false),
  ('logo_hulu', 4, 'Docker', false),
  ('logo_roblox', 1, 'Roblox', true),
  ('logo_roblox', 2, 'Microsoft Outlook', false),
  ('logo_roblox', 3, 'GitLab', false),
  ('logo_roblox', 4, 'Google', false),
  ('logo_brave_browser', 1, 'Brave Browser', true),
  ('logo_brave_browser', 2, 'Opera', false),
  ('logo_brave_browser', 3, 'Udemy', false),
  ('logo_brave_browser', 4, 'NVIDIA', false),
  ('logo_opera', 1, 'Opera', true),
  ('logo_opera', 2, 'Asana', false),
  ('logo_opera', 3, 'PayPal', false),
  ('logo_opera', 4, 'Telegram', false),
  ('logo_edge', 1, 'Edge', true),
  ('logo_edge', 2, 'Google Chat', false),
  ('logo_edge', 3, 'WhatsApp', false),
  ('logo_edge', 4, 'Canva', false),
  ('logo_steam', 1, 'Steam', true),
  ('logo_steam', 2, 'Spotify', false),
  ('logo_steam', 3, 'Cloudflare', false),
  ('logo_steam', 4, 'Adobe', false),
  ('logo_openai', 1, 'OpenAI', true),
  ('logo_openai', 2, 'Microsoft Azure', false),
  ('logo_openai', 3, 'Shopify', false),
  ('logo_openai', 4, 'TikTok', false),
  ('logo_gitlab', 1, 'GitLab', true),
  ('logo_gitlab', 2, 'Reddit', false),
  ('logo_gitlab', 3, 'GitHub', false),
  ('logo_gitlab', 4, 'Google Play', false),
  ('logo_trello', 1, 'Trello', true),
  ('logo_trello', 2, 'Bitcoin', false),
  ('logo_trello', 3, 'Slack', false),
  ('logo_trello', 4, 'Dropbox', false),
  ('logo_salesforce', 1, 'Salesforce', true),
  ('logo_salesforce', 2, 'Snapchat', false),
  ('logo_salesforce', 3, 'Google Maps', false),
  ('logo_salesforce', 4, 'Google Calendar', false),
  ('logo_asana', 1, 'Asana', true),
  ('logo_asana', 2, 'Prime video', false),
  ('logo_asana', 3, 'Google Sheets', false),
  ('logo_asana', 4, 'Threads', false),
  ('logo_docker', 1, 'Docker', true),
  ('logo_docker', 2, 'Notion', false),
  ('logo_docker', 3, 'Google Drive', false),
  ('logo_docker', 4, 'Figma', false),
  ('logo_coursera', 1, 'Coursera', true),
  ('logo_coursera', 2, 'Binance', false),
  ('logo_coursera', 3, 'Bluesky', false),
  ('logo_coursera', 4, 'Edge', false),
  ('logo_wordpress', 1, 'WordPress', true),
  ('logo_wordpress', 2, 'Microsoft PowerPoint', false),
  ('logo_wordpress', 3, 'Hulu', false),
  ('logo_wordpress', 4, 'Docker', false),
  ('logo_udemy', 1, 'Udemy', true),
  ('logo_udemy', 2, 'Youtube Music', false),
  ('logo_udemy', 3, 'GitLab', false),
  ('logo_udemy', 4, 'Discord', false),
  ('logo_coinbase', 1, 'Coinbase', true),
  ('logo_coinbase', 2, 'Opera', false),
  ('logo_coinbase', 3, 'Udemy', false),
  ('logo_coinbase', 4, 'LinkedIn', false),
  ('logo_google_classroom', 1, 'Google Classroom', true),
  ('logo_google_classroom', 2, 'Asana', false),
  ('logo_google_classroom', 3, 'YouTube', false),
  ('logo_google_classroom', 4, 'Windows', false),
  ('logo_google_chat', 1, 'Google Chat', true),
  ('logo_google_chat', 2, 'Google', false),
  ('logo_google_chat', 3, 'Amazon Web Services', false),
  ('logo_google_chat', 4, 'Airbnb', false),
  ('logo_safaricom', 1, 'Safaricom', true),
  ('logo_safaricom', 2, 'Kenya Airways', false),
  ('logo_safaricom', 3, 'M-PESA', false),
  ('logo_safaricom', 4, 'Co-operative Bank', false),
  ('logo_m_pesa', 1, 'M-PESA', true),
  ('logo_m_pesa', 2, 'Co-operative Bank', false),
  ('logo_m_pesa', 3, 'Kenya Airways', false),
  ('logo_m_pesa', 4, 'Safaricom', false),
  ('logo_kenya_airways', 1, 'Kenya Airways', true),
  ('logo_kenya_airways', 2, 'Safaricom', false),
  ('logo_kenya_airways', 3, 'Co-operative Bank', false),
  ('logo_kenya_airways', 4, 'M-PESA', false),
  ('logo_co_operative_bank', 1, 'Co-operative Bank', true),
  ('logo_co_operative_bank', 2, 'M-PESA', false),
  ('logo_co_operative_bank', 3, 'Safaricom', false),
  ('logo_co_operative_bank', 4, 'Kenya Airways', false),
  ('logo_jumia', 1, 'Jumia', true),
  ('logo_jumia', 2, 'MTN', false),
  ('logo_jumia', 3, 'Ecobank', false),
  ('logo_jumia', 4, 'Shoprite', false),
  ('logo_mtn', 1, 'MTN', true),
  ('logo_mtn', 2, 'Jumia', false),
  ('logo_mtn', 3, 'Ecobank', false),
  ('logo_mtn', 4, 'Shoprite', false),
  ('logo_shoprite', 1, 'Shoprite', true),
  ('logo_shoprite', 2, 'Jumia', false),
  ('logo_shoprite', 3, 'Ecobank', false),
  ('logo_shoprite', 4, 'MTN', false),
  ('logo_dstv', 1, 'DStv', true),
  ('logo_dstv', 2, 'Jumia', false),
  ('logo_dstv', 3, 'Ecobank', false),
  ('logo_dstv', 4, 'MTN', false),
  ('logo_ethiopian_airlines', 1, 'Ethiopian Airlines', true),
  ('logo_ethiopian_airlines', 2, 'Jumia', false),
  ('logo_ethiopian_airlines', 3, 'Ecobank', false),
  ('logo_ethiopian_airlines', 4, 'MTN', false),
  ('logo_ecobank', 1, 'Ecobank', true),
  ('logo_ecobank', 2, 'Jumia', false),
  ('logo_ecobank', 3, 'Ethiopian Airlines', false),
  ('logo_ecobank', 4, 'MTN', false),
  ('logo_absa', 1, 'Absa', true),
  ('logo_absa', 2, 'Jumia', false),
  ('logo_absa', 3, 'Ethiopian Airlines', false),
  ('logo_absa', 4, 'MTN', false),
  ('logo_flutterwave', 1, 'Flutterwave', true),
  ('logo_flutterwave', 2, 'Jumia', false),
  ('logo_flutterwave', 3, 'Ethiopian Airlines', false),
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
