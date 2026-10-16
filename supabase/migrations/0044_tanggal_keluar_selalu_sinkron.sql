-- Tanggal Nota Keluar selalu berasal dari waktu unit benar-benar keluar.
--
-- Sebelumnya trigger hanya berjalan pada UPDATE. Nota yang langsung dibuat
-- dengan status Diambil/Batal dapat menyimpan waktu_diambil tanpa
-- tanggal_diambil, sehingga hilang dari laporan Nota Keluar.

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

  if tg_op = 'UPDATE'
     and old.status in ('selesai', 'diambil', 'batal')
     and new.status in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  -- Satu sumber kebenaran Nota Keluar: kapan unit benar-benar keluar.
  -- Berlaku saat INSERT maupun UPDATE, jadi tanggal tidak dapat tertinggal.
  if new.status in ('diambil', 'batal') then
    new.waktu_diambil := coalesce(new.waktu_diambil, now());
    new.tanggal_diambil := hari_laporan(new.waktu_diambil);
  elsif tg_op = 'UPDATE' and old.status in ('diambil', 'batal') then
    new.tanggal_diambil := null;
    new.waktu_diambil := null;
  end if;

  if new.status in ('selesai', 'diambil', 'batal')
     and new.tanggal_selesai is null
  then
    new.tanggal_selesai := hari_laporan();
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_so_touch on public.service_orders;
create trigger trg_so_touch
before insert or update on public.service_orders
for each row execute function public.sentuh_service_order();

-- Lengkapi arsip yang waktu keluarnya sudah tercatat tetapi tanggal laporan
-- keluarnya belum ada. Waktu riil diprioritaskan; tanggal selesai hanya
-- cadangan untuk arsip lama tanpa cap waktu.
update public.service_orders
set tanggal_diambil = hari_laporan(
  coalesce(
    waktu_diambil,
    tanggal_selesai::timestamp at time zone 'Asia/Jakarta',
    updated_at
  )
)
where status in ('diambil', 'batal')
  and tanggal_diambil is null;

commit;
