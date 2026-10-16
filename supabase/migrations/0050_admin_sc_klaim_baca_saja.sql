-- =====================================================================
-- Migrasi 0050 : role Admin SC (pemantau klaim garansi)
--
-- Admin SC hanya membaca data yang dibutuhkan halaman Klaim. Ia tidak
-- dapat membuat/mengubah klaim, membuat nota, atau membuka data servis.
-- =====================================================================

alter type public.user_role add value if not exists 'admin_sc';

create or replace function public.is_admin_sc()
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role::text = 'admin_sc'
      and aktif
  );
$fn$;

comment on function public.is_admin_sc() is
  'Benar bila pengguna aktif hanya bertugas memantau klaim garansi.';

-- Klaim dan data pendukungnya tetap dapat dibaca. Tulis ditutup, termasuk
-- insert part baru yang sebelumnya terbuka untuk teknisi.
drop policy if exists claims_insert on public.claims;
create policy claims_insert on public.claims for insert to authenticated
  with check (public.is_active_user() and not public.is_admin_sc());

drop policy if exists claims_update on public.claims;
create policy claims_update on public.claims for update to authenticated
  using (public.is_active_user() and not public.is_admin_sc())
  with check (public.is_active_user() and not public.is_admin_sc());

drop policy if exists cp_insert on public.claim_parts;
create policy cp_insert on public.claim_parts for insert to authenticated
  with check (public.is_active_user() and not public.is_admin_sc());

-- Tutup seluruh jalur data servis yang sebelumnya dibaca semua teknisi.
drop policy if exists so_baca on public.service_orders;
create policy so_baca on public.service_orders for select to authenticated
  using (public.is_active_user() and not public.is_admin_sc());

drop policy if exists so_teknisi_ubah on public.service_orders;
create policy so_teknisi_ubah on public.service_orders for update to authenticated
  using (public.is_active_user() and not public.is_admin_sc())
  with check (public.is_active_user() and not public.is_admin_sc());

drop policy if exists po_baca on public.part_orders;
create policy po_baca on public.part_orders for select to authenticated
  using (public.is_active_user() and not public.is_admin_sc());

drop policy if exists po_ubah on public.part_orders;
create policy po_ubah on public.part_orders for update to authenticated
  using (public.is_active_user() and not public.is_admin_sc())
  with check (public.is_active_user() and not public.is_admin_sc());

drop policy if exists mb_baca on public.metode_bayar;
create policy mb_baca on public.metode_bayar for select to authenticated
  using (public.is_active_user() and not public.is_admin_sc());

-- Fungsi security definer ini melewati RLS, jadi perannya diperiksa sendiri.
create or replace function public.tautkan_nota_ke_klaim(p_nota uuid, p_klaim uuid)
returns text
language plpgsql volatile security definer
set search_path = public
as $fn$
declare
  nota record;
begin
  if not public.is_active_user() or public.is_admin_sc() then
    raise exception 'Akun ini tidak berhak mengubah klaim atau nota.'
      using errcode = '42501';
  end if;

  select id, no_nota, claim_id into nota
  from public.service_orders where id = p_nota;

  if not found then
    raise exception 'Nota servisnya tidak ditemukan.';
  end if;

  if not exists (select 1 from public.claims where id = p_klaim) then
    raise exception 'Klaim garansinya tidak ditemukan.';
  end if;

  if nota.claim_id is not null and nota.claim_id <> p_klaim then
    raise exception 'Nota % sudah tertaut ke klaim garansi lain.', nota.no_nota;
  end if;

  perform set_config('app.taut_klaim', 'on', true);
  update public.service_orders
  set garansi = true, claim_id = p_klaim
  where id = p_nota;
  perform set_config('app.taut_klaim', 'off', true);

  return nota.no_nota;
end;
$fn$;
