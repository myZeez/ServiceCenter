-- =====================================================================
--  Migrasi 0006 : identitas toko untuk kepala dan kaki nota
--
--  Dipisah dari pengaturan lain karena isinya dipakai saat mencetak, dan
--  ketentuan toko adalah kalimat yang sesekali berubah -- mengubahnya
--  tidak boleh menuntut membangun ulang aplikasi.
--
--  Aman dijalankan ulang.
-- =====================================================================

create table if not exists store_settings (
  id            smallint primary key default 1 check (id = 1),
  nama          text not null default 'CELLCOM PLK',
  alamat        text,
  telepon       text,

  -- Dicetak di kaki nota. Baris baru dipertahankan apa adanya.
  ketentuan     text,

  updated_at    timestamptz not null default now(),
  updated_by    uuid references profiles(id)
);

insert into store_settings (id) values (1) on conflict (id) do nothing;

alter table store_settings enable row level security;

-- Semua pengguna aktif boleh membacanya: nota bisa dicetak siapa pun yang
-- bertugas. Hanya admin yang boleh mengubahnya.
drop policy if exists toko_baca on store_settings;
create policy toko_baca on store_settings for select to authenticated
  using (is_active_user());

drop policy if exists toko_ubah on store_settings;
create policy toko_ubah on store_settings for all to authenticated
  using (is_admin()) with check (is_admin());
