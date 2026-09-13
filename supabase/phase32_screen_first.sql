-- Phase 3.2: Screen-first answers for Trivia Rush and Flag Frenzy.
-- The shared display receives A/B/C/D option wording. Phone controllers still
-- receive only option IDs, so they render big letter pads and no answer text.

create or replace function public.get_public_round_state(p_room_code text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'position', gr.position,
    'game_mode', q.game_mode,
    'duration_seconds', q.duration_seconds,
    'status', gr.status,
    'opens_at', gr.opens_at,
    'closes_at', gr.closes_at,
    'prompt', case
      when q.game_mode = 'who_am_i' then 'Ask the table yes-or-no questions and work out who you are.'
      when q.game_mode = 'guess_image' then 'Study the clue on your phone and make your guess.'
      else q.prompt
    end,
    'media', case
      when q.game_mode in ('who_am_i', 'guess_image') or m.id is null then null
      else jsonb_build_object('type', m.asset_type, 'url', m.public_url, 'alt', m.alt_text)
    end,
    'options', coalesce((
      select jsonb_agg(jsonb_build_object(
        'label', chr(64 + qo.position),
        'text', qo.option_text,
        'is_correct', case when gr.status = 'revealed' then qo.is_correct else null end
      ) order by qo.position)
      from public.question_options qo
      where qo.question_id = q.id
    ), '[]'::jsonb),
    'correct_option', case
      when gr.status = 'revealed' and q.game_mode not in ('who_am_i', 'guess_image') then (
        select qo.option_text from public.question_options qo
        where qo.question_id = q.id and qo.is_correct = true limit 1
      )
      else null
    end,
    'explanation', case
      when gr.status = 'revealed' and q.game_mode not in ('who_am_i', 'guess_image') then q.explanation
      else null
    end
  )
  from public.rooms r
  join public.game_rounds gr on gr.id = r.current_round_id
  join public.questions q on q.id = gr.question_id
  left join public.media_assets m on m.id = q.media_id
  where r.code = upper(trim(p_room_code))
    and r.status = 'playing'
  limit 1;
$$;

revoke all on function public.get_public_round_state(text) from public, anon;
grant execute on function public.get_public_round_state(text) to authenticated;
