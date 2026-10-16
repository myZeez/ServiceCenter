-- Nota yang dikirim ke cabang dapat memiliki biaya jasa. Nilainya adalah
-- piutang terhadap cabang: ikut omzet, tetapi bukan uang kas yang diterima.
-- Tanggal lunas dipakai sebagai tanggal buku saat dikirim sesuai kebijakan
-- operasional, sehingga pembeda kas/piutang harus memakai cara_bayar.

begin;

create or replace function public.sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  -- Kirim cabang berbiaya selalu menjadi piutang. Tanggal buku mengikuti
  -- tanggal kirim, sedangkan waktu pelunasan dikosongkan karena uang belum
  -- diterima dari cabang.
  if new.status = 'dikirim_cabang' and new.biaya > 0 then
    new.cara_bayar := 'piutang';
    new.tanggal_lunas := new.tanggal_kirim;
    new.waktu_lunas := null;
  elsif new.waktu_lunas is not null
     and new.cara_bayar is not null
     and not coalesce(
       (select m.piutang from metode_bayar m where m.kode = new.cara_bayar),
       false
     )
  then
    new.tanggal_lunas := hari_laporan(new.waktu_lunas);
  elsif new.tanggal_lunas is null then
    new.waktu_lunas := null;
  end if;

  if tg_op = 'UPDATE'
     and old.status in ('selesai', 'diambil', 'batal')
     and new.status in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  if new.status in ('diambil', 'batal') then
    if new.waktu_diambil is not null then
      new.tanggal_diambil := hari_laporan(new.waktu_diambil);
    end if;
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

-- Selaraskan arsip cabang berbiaya. Hanya baris yang memiliki tanggal
-- kirim disentuh; arsip tanpa tanggal tetap dibiarkan untuk audit manual.
update public.service_orders
set cara_bayar = 'piutang',
    tanggal_lunas = tanggal_kirim,
    waktu_lunas = null,
    biaya_dikirim_cabang = true
where status = 'dikirim_cabang'
  and biaya > 0
  and tanggal_kirim is not null
  and (
    cara_bayar is distinct from 'piutang'
    or tanggal_lunas is distinct from tanggal_kirim
    or waktu_lunas is not null
    or biaya_dikirim_cabang is distinct from true
  );

do $$
declare
  belum_sinkron integer;
begin
  select count(*) into belum_sinkron
  from public.service_orders
  where status = 'dikirim_cabang'
    and biaya > 0
    and tanggal_kirim is not null
    and (
      cara_bayar is distinct from 'piutang'
      or tanggal_lunas is distinct from tanggal_kirim
      or waktu_lunas is not null
      or biaya_dikirim_cabang is distinct from true
    );
  if belum_sinkron <> 0 then
    raise exception 'Sinkronisasi piutang cabang gagal: % nota belum sesuai.', belum_sinkron;
  end if;
end $$;

commit;
