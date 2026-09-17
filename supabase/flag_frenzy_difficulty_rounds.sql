-- Escalating Flag Frenzy rounds: 3 easy, 4 medium, 3 hard.
-- Difficulty controls the flag pool, timer, and points awarded.

update public.round_templates
set title = 'Flag Frenzy: World Tour',
    description = 'Ten world-flag rounds that progress from easy to medium to hard.',
    is_active = true
where code = 'flag_frenzy_africa';

delete from public.round_template_steps
where template_id = (
  select id from public.round_templates where code = 'flag_frenzy_africa'
);

insert into public.round_template_steps (
  template_id,
  position,
  category_id,
  difficulty_min,
  difficulty_max,
  question_count,
  seconds_per_question
)
select
  rt.id,
  step.position,
  null,
  step.difficulty_min,
  step.difficulty_max,
  step.question_count,
  step.seconds_per_question
from public.round_templates rt
cross join (
  values
    (1::smallint, 1::smallint, 1::smallint, 3::smallint, 15::smallint),
    (2::smallint, 2::smallint, 2::smallint, 4::smallint, 12::smallint),
    (3::smallint, 3::smallint, 3::smallint, 3::smallint, 10::smallint)
) as step(position, difficulty_min, difficulty_max, question_count, seconds_per_question)
where rt.code = 'flag_frenzy_africa';

update public.questions
set duration_seconds = case difficulty
      when 1 then 15
      when 2 then 12
      when 3 then 10
      else duration_seconds
    end,
    base_points = case difficulty
      when 1 then 100
      when 2 then 200
      when 3 then 300
      else base_points
    end,
    updated_at = now()
where game_mode = 'flag_frenzy'
  and status = 'approved'
  and difficulty in (1, 2, 3);
