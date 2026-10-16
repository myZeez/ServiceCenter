-- =====================================================================
-- Migrasi 0040: waktu pengambilan dapat dikoreksi manual
--
-- 0039 mencatat waktu saat status pertama kali menjadi `diambil`. Saat
-- admin kemudian membetulkan waktu tersebut, tanggal laporan juga harus
-- dihitung ulang dengan tutup_jam yang sedang berlaku.
-- =====================================================================

begin;

create or replace function public.sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  if (new.status = 'diambil' or (new.status = 'batal' and new.biaya > 0))
     and new.cara_bayar is not null
     and new.tanggal_lunas is null
     and not coalesce(
       (select m.piutang from metode_bayar m where m.kode = new.cara_bayar),
       false
     )
  then
    new.waktu_lunas := coalesce(new.waktu_lunas, now());
    new.tanggal_lunas := hari_laporan(new.waktu_lunas);
  end if;

  if new.tanggal_lunas is null then
    new.waktu_lunas := null;
  end if;

  if old.status::text in ('selesai', 'diambil', 'batal')
     and new.status::text in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  if old.status = 'diambil' and new.status <> 'diambil' then
    new.tanggal_diambil := null;
    new.waktu_diambil := null;
  end if;

  -- Selain transisi status, penggantian waktu manual harus memindahkan
  -- tanggal laporan juga. Kalau waktunya kosong saat baru Diambil, server
  -- tetap memberi waktu sekarang agar catatan tidak menggantung.
  if new.status = 'diambil' and (
       old.status is distinct from 'diambil'
       or new.waktu_diambil is distinct from old.waktu_diambil
     )
  then
    new.waktu_diambil := coalesce(new.waktu_diambil, now());
    new.tanggal_diambil := hari_laporan(new.waktu_diambil);
  end if;

  if new.status in ('selesai', 'diambil', 'batal')
     and new.tanggal_selesai is null
  then
    new.tanggal_selesai := hari_laporan();
  end if;

  return new;
end;
$fn$;

commit;
