-- Bayu hanya memantau data klaim garansi. Email disimpan oleh Supabase Auth,
-- sedangkan role aplikasi tinggal di public.profiles, jadi keduanya dipasangkan
-- melalui UUID pengguna agar akun dengan nama mirip tidak ikut berubah.
do $$
declare
  jumlah_auth integer;
  jumlah_target integer;
  id_bayu uuid;
begin
  select count(*)
    into jumlah_auth
    from auth.users u
   where lower(u.email) = 'bayu@cellcom.pky';

  select count(*)
    into jumlah_target
    from public.profiles p
    join auth.users u on u.id = p.id
   where lower(u.email) = 'bayu@cellcom.pky';

  if jumlah_auth <> 1 then
    raise exception
      'Role Bayu tidak diubah: ditemukan % akun Auth untuk bayu@cellcom.pky.',
      jumlah_auth;
  end if;

  select id
    into id_bayu
    from auth.users
   where lower(email) = 'bayu@cellcom.pky';

  -- Akun dibuat manual lewat Dashboard tidak otomatis mempunyai profil.
  -- Bila profilnya sudah ada cukup ubah role; bila belum, buat satu profil
  -- yang langsung aktif agar pengguna dapat login ke aplikasi.
  if jumlah_target = 0 then
    insert into public.profiles (id, nama, role, aktif)
    values (id_bayu, 'Bayu', 'admin_sc'::public.user_role, true);
  else
    update public.profiles
       set role = 'admin_sc'::public.user_role,
           aktif = true
     where id = id_bayu;
  end if;
end
$$;
