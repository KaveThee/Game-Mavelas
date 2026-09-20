-- The world flag pack already contains Uganda; keep a single answer identity.
update public.questions set status='retired',updated_at=now()
where status='approved' and slug='uganda_flag';
