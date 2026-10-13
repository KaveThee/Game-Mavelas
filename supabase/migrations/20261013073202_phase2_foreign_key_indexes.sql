-- Cover foreign keys used by content selection and Phase 2 game state.

create index if not exists media_assets_source_id_idx
  on public.media_assets (source_id);
create index if not exists questions_category_id_idx
  on public.questions (category_id);
create index if not exists questions_media_id_idx
  on public.questions (media_id);
create index if not exists questions_source_id_idx
  on public.questions (source_id);
create index if not exists room_player_private_state_round_id_idx
  on public.room_player_private_state (round_id);
create index if not exists round_template_steps_category_id_idx
  on public.round_template_steps (category_id);
create index if not exists score_ledger_round_id_idx
  on public.score_ledger (round_id);
