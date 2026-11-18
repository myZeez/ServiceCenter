-- =====================================================================
--  Migrasi 0065 : role super admin, tahap penambahan
--
--  Admin dipecah menjadi dua: admin (meja depan) dan super admin
--  (pengelola). Berkas ini hanya MENAMBAH, tidak mengubah perilaku siapa
--  pun selama belum ada akun super admin, jadi aman dipasang lebih dulu.
--  Pembatasan admin ada di 0066, dan baru dipasang setelah akun super admin
--  ada dan aplikasi versi baru terpasang: kalau dibalik, tidak ada yang bisa
--  mengelola pengguna.
--
--  is_admin() sengaja mencakup keduanya. Dipakai puluhan kebijakan dan
--  fungsi untuk arti "pengelola nota": super admin tidak boleh kehilangan
--  hak yang dipunyai admin. Yang khusus super admin memakai is_super_admin().
--
--  role::text dipakai, bukan literal enum: nilai enum baru tidak boleh
--  dipakai dalam transaksi yang menambahkannya.
--
--  Sekalian menutup celah: tiga view rekap bisa dibaca peran anon, tanpa
--  login, dan view biasa berjalan dengan hak pemiliknya sehingga melewati
--  RLS. Kunci anon tertanam di setiap APK.
--
--  Aman dijalankan ulang.
-- =====================================================================

alter type public.user_role add value if not exists 'super_admin';

create or replace function public.is_super_admin()
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role::text = 'super_admin' and aktif
  );
$fn$;

revoke all on function public.is_super_admin() from public, anon;
grant execute on function public.is_super_admin() to authenticated;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role::text in ('admin', 'super_admin') and aktif
  );
$fn$;

-- Harus selalu tersisa satu pengelola aktif. Selama belum ada super admin,
-- admin terakhirlah pengelolanya; sesudah itu super admin terakhir.
create or replace function public.profiles_guard_last_admin()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
declare
  lama       text := old.role::text;
  baru       text := new.role::text;
  sisa_super int;
  sisa_admin int;
begin
  if not old.aktif or lama not in ('admin', 'super_admin') then
    return new;
  end if;
  if new.aktif and baru = lama then
    return new;
  end if;

  select count(*) filter (where role::text = 'super_admin'),
         count(*) filter (where role::text = 'admin')
    into sisa_super, sisa_admin
  from profiles
  where aktif and id <> old.id;

  if lama = 'super_admin' then
    if sisa_super = 0 then
      raise exception 'Tidak bisa menurunkan atau menonaktifkan super admin terakhir.';
    end if;
  elsif sisa_super = 0 and sisa_admin = 0
        and not (new.aktif and baru = 'super_admin') then
    raise exception 'Tidak bisa menonaktifkan admin terakhir.';
  end if;

  return new;
end;
$fn$;

-- View rekap mengikuti hak pembacanya, dan tertutup bagi yang belum login.
alter view public.v_rekap_brand_kuartal set (security_invoker = true);
alter view public.v_rekap_teknisi_brand set (security_invoker = true);
alter view public.v_riwayat_pindah_teknisi set (security_invoker = true);

revoke all on public.v_rekap_brand_kuartal from public, anon;
revoke all on public.v_rekap_teknisi_brand from public, anon;
revoke all on public.v_riwayat_pindah_teknisi from public, anon;
