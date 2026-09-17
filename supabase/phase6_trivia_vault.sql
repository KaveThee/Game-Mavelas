-- Phase 6: Trivia Vault — host-selectable themed three-round packs.
-- Scores are deliberately simple: Easy 100, Medium 150, Hard 200.

insert into public.round_templates (code, title, game_mode, description, is_active)
values
  ('trivia_vault_kenya', 'Trivia Vault: Kenya & East Africa', 'trivia', 'Easy, medium and hard Kenya & East Africa questions.', true),
  ('trivia_vault_scitech', 'Trivia Vault: Science & Tech', 'trivia', 'An escalating science and technology challenge.', true),
  ('trivia_vault_mix', 'Trivia Vault: Mixed Challenge', 'trivia', 'A broad three-tier general-knowledge challenge.', true)
on conflict (code) do update
set title = excluded.title,
    description = excluded.description,
    is_active = excluded.is_active;

delete from public.round_template_steps
where template_id in (
  select id from public.round_templates
  where code in ('trivia_vault_kenya', 'trivia_vault_scitech', 'trivia_vault_mix')
);

insert into public.round_template_steps
  (template_id, position, category_id, difficulty_min, difficulty_max, question_count, seconds_per_question)
values
  ((select id from public.round_templates where code = 'trivia_vault_kenya'), 1, (select id from public.categories where code = 'kenya_geography'), 1, 1, 5, 20),
  ((select id from public.round_templates where code = 'trivia_vault_kenya'), 2, (select id from public.categories where code = 'kenya_geography'), 2, 2, 5, 15),
  ((select id from public.round_templates where code = 'trivia_vault_kenya'), 3, (select id from public.categories where code = 'kenya_geography'), 3, 3, 5, 12),

  ((select id from public.round_templates where code = 'trivia_vault_scitech'), 1, (select id from public.categories where code = 'science'), 2, 2, 5, 20),
  ((select id from public.round_templates where code = 'trivia_vault_scitech'), 2, (select id from public.categories where code = 'tech'), 2, 2, 5, 15),
  ((select id from public.round_templates where code = 'trivia_vault_scitech'), 3, (select id from public.categories where code = 'tech'), 3, 3, 5, 12),

  ((select id from public.round_templates where code = 'trivia_vault_mix'), 1, (select id from public.categories where code = 'trivia_archive'), 1, 1, 5, 20),
  ((select id from public.round_templates where code = 'trivia_vault_mix'), 2, (select id from public.categories where code = 'trivia_archive'), 2, 2, 5, 15),
  ((select id from public.round_templates where code = 'trivia_vault_mix'), 3, (select id from public.categories where code = 'trivia_archive'), 3, 3, 5, 12);

-- Keep a predictable shared-screen score scale for the new themed Vault packs.
update public.questions
set base_points = case
  when category_id = (select id from public.categories where code = 'kenya_geography') and difficulty = 1 then 100
  when category_id = (select id from public.categories where code = 'kenya_geography') and difficulty = 2 then 150
  when category_id = (select id from public.categories where code = 'kenya_geography') and difficulty = 3 then 200
  when category_id = (select id from public.categories where code = 'science') and difficulty = 2 then 100
  when category_id = (select id from public.categories where code = 'tech') and difficulty = 2 then 150
  when category_id = (select id from public.categories where code = 'tech') and difficulty = 3 then 200
  when category_id = (select id from public.categories where code = 'trivia_archive') and difficulty = 1 then 100
  when category_id = (select id from public.categories where code = 'trivia_archive') and difficulty = 2 then 150
  when category_id = (select id from public.categories where code = 'trivia_archive') and difficulty = 3 then 200
  else base_points
end
where game_mode = 'trivia'
  and status = 'approved'
  and (
    (category_id = (select id from public.categories where code = 'kenya_geography') and difficulty between 1 and 3)
    or (category_id = (select id from public.categories where code = 'science') and difficulty = 2)
    or (category_id = (select id from public.categories where code = 'tech') and difficulty between 2 and 3)
    or (category_id = (select id from public.categories where code = 'trivia_archive') and difficulty between 1 and 3)
  );
