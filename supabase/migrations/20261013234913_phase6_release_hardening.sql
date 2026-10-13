-- Phase 6 release hardening: keep shuffled option order RPC-only and make the
-- host room policy evaluate the caller identity once per statement.

revoke all on table public.round_option_orders from public, anon, authenticated;

drop policy if exists "host updates room" on public.rooms;

create policy "host updates room"
on public.rooms
for update
to authenticated
using ((select auth.uid()) = host_id)
with check ((select auth.uid()) = host_id);
