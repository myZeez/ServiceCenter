-- =====================================================================
--  Migrasi 0002 : pengguna nonaktif benar-benar kehilangan akses
--
--  Di migrasi 0001, semua pengguna yang berhasil login boleh membaca dan
--  menambah klaim. Akibatnya menonaktifkan seseorang hanya menyembunyikan
--  namanya dari daftar teknisi -- akunnya masih bisa dipakai.
--
--  Setelah migrasi ini, akun nonaktif masih bisa login tetapi tidak
--  melihat data apa pun dan tidak bisa menulis.
-- =====================================================================

create or replace function is_active_user()
returns boolean
language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from profiles where id = auth.uid() and aktif
  );
$fn$;


-- ---------------------------------------------------------------------
-- claims
-- ---------------------------------------------------------------------
drop policy if exists claims_select on claims;
create policy claims_select on claims
  for select to authenticated using (is_active_user());

drop policy if exists claims_insert on claims;
create policy claims_insert on claims
  for insert to authenticated with check (is_active_user());

drop policy if exists claims_update on claims;
create policy claims_update on claims
  for update to authenticated
  using (is_active_user()) with check (is_active_user());


-- ---------------------------------------------------------------------
-- claim_parts
-- ---------------------------------------------------------------------
drop policy if exists cp_select on claim_parts;
create policy cp_select on claim_parts
  for select to authenticated using (is_active_user());

drop policy if exists cp_insert on claim_parts;
create policy cp_insert on claim_parts
  for insert to authenticated with check (is_active_user());


-- ---------------------------------------------------------------------
-- audit & master data
-- ---------------------------------------------------------------------
drop policy if exists audit_select on claim_audit;
create policy audit_select on claim_audit
  for select to authenticated using (is_active_user());

drop policy if exists brands_select on brands;
create policy brands_select on brands
  for select to authenticated using (is_active_user());

drop policy if exists parts_select on part_types;
create policy parts_select on part_types
  for select to authenticated using (is_active_user());

-- Daftar profil tetap terbaca oleh semua yang aktif, karena aplikasi
-- perlu menerjemahkan teknisi_id menjadi nama.
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles
  for select to authenticated using (is_active_user());


-- ---------------------------------------------------------------------
-- Jaga agar sistem tidak pernah kehilangan admin terakhir.
-- Tanpa ini, satu klik keliru bisa mengunci semua orang dari pengelolaan.
-- ---------------------------------------------------------------------
create or replace function profiles_guard_last_admin()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  sisa_admin int;
begin
  if old.role = 'admin' and old.aktif
     and (new.role <> 'admin' or not new.aktif) then

    select count(*) into sisa_admin
    from profiles
    where role = 'admin' and aktif and id <> old.id;

    if sisa_admin = 0 then
      raise exception 'Tidak bisa menonaktifkan admin terakhir.';
    end if;
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_profiles_last_admin on profiles;
create trigger trg_profiles_last_admin
  before update on profiles
  for each row execute function profiles_guard_last_admin();
