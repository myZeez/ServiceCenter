-- =====================================================================
--  Migrasi 0003 : fee brand dan pembagian hasil
--
--  Inilah perhitungan yang selama ini tersebar di beberapa file Excel.
--  Dipindahkan ke database supaya rumusnya satu, tercatat, dan tidak bisa
--  kesenggol tanpa jejak.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. FEE PER BRAND
--
--    Memakai tanggal berlaku, bukan satu kolom fee di tabel brands.
--    Alasannya: fee akan berubah. Kalau fee lama ditimpa, rekap kuartal
--    yang sudah lewat ikut berubah angkanya -- dan bagi hasil yang sudah
--    terlanjur dibayarkan tidak lagi cocok dengan laporannya.
-- ---------------------------------------------------------------------
create table brand_fees (
  id           bigint generated always as identity primary key,
  brand_id     smallint      not null references brands(id) on delete cascade,
  fee          numeric(12,2) not null check (fee >= 0),
  berlaku_dari date          not null,
  catatan      text,
  created_at   timestamptz   not null default now(),

  unique (brand_id, berlaku_dari)
);

create index on brand_fees (brand_id, berlaku_dari desc);


-- ---------------------------------------------------------------------
-- 2. ATURAN PEMBAGIAN
--
--    Satu baris saja. Kunci id = 1 memastikan tidak ada aturan kedua yang
--    diam-diam ikut terpakai.
-- ---------------------------------------------------------------------
create table revenue_settings (
  id             smallint     primary key default 1 check (id = 1),
  persen_toko    numeric(5,2) not null default 30,
  persen_admin   numeric(5,2) not null default 10,
  persen_teknisi numeric(5,2) not null default 60,

  -- per_unit : jatah teknisi dibagi menurut nilai yang dihasilkan
  -- rata     : dibagi sama besar antar teknisi yang bekerja di periode itu
  -- manual   : memakai persentase tetap di tabel technician_shares
  metode_teknisi text not null default 'per_unit'
    check (metode_teknisi in ('per_unit', 'rata', 'manual')),

  updated_at timestamptz not null default now(),
  updated_by uuid references profiles(id),

  -- Menjaga agar totalnya tidak pernah meleset dari 100%.
  constraint total_100
    check (persen_toko + persen_admin + persen_teknisi = 100)
);

insert into revenue_settings (id) values (1);

-- Persentase tetap per teknisi. Hanya dipakai saat metode 'manual'.
create table technician_shares (
  profile_id uuid         primary key references profiles(id) on delete cascade,
  persen     numeric(5,2) not null check (persen >= 0 and persen <= 100),
  updated_at timestamptz  not null default now()
);


-- ---------------------------------------------------------------------
-- 3. NILAI TIAP KLAIM
--
--    Hanya klaim berstatus 'close' yang dihitung: fee dibayarkan brand
--    setelah perbaikan selesai, bukan saat unit masih di meja.
-- ---------------------------------------------------------------------
create view v_nilai_klaim as
select
  c.id,
  c.tanggal,
  c.brand_id,
  c.teknisi_id,
  c.no_perbaikan,
  c.sn,
  coalesce(
    (select f.fee
     from brand_fees f
     where f.brand_id = c.brand_id
       and f.berlaku_dari <= c.tanggal::date
     order by f.berlaku_dari desc
     limit 1),
    0
  ) as nilai
from claims c
where c.status = 'close';

-- View ini memuat nilai rupiah tiap klaim, jadi tidak boleh dibaca
-- langsung oleh siapa pun. Aksesnya hanya lewat fungsi di bawah, yang
-- memeriksa peran pemanggilnya lebih dulu.
revoke all on v_nilai_klaim from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. PERHITUNGAN PERIODE
--
--    Semua fungsi memeriksa peran sendiri. security definer membuatnya
--    bisa membaca view di atas, jadi penjaga itu wajib ada di dalam --
--    bukan hanya mengandalkan siapa yang boleh memanggil.
-- ---------------------------------------------------------------------

create or replace function ringkasan_pendapatan(p_dari date, p_sampai date)
returns table (
  total_unit     bigint,
  total_nilai    numeric,
  unit_tanpa_fee bigint,
  bagian_toko    numeric,
  bagian_admin   numeric,
  bagian_teknisi numeric
)
language plpgsql stable security definer set search_path = public as $fn$
declare
  s        revenue_settings%rowtype;
  v_unit   bigint;
  v_nilai  numeric;
  v_kosong bigint;
begin
  if not is_admin() then
    raise exception 'Hanya admin yang dapat melihat perhitungan pendapatan.';
  end if;

  select * into s from revenue_settings where id = 1;

  select count(*), coalesce(sum(nilai), 0), count(*) filter (where nilai = 0)
    into v_unit, v_nilai, v_kosong
  from v_nilai_klaim
  where tanggal::date between p_dari and p_sampai;

  return query select
    v_unit,
    v_nilai,
    -- Klaim yang brand-nya belum punya fee. Diangkat terpisah supaya
    -- tidak diam-diam ikut terhitung sebagai nol.
    v_kosong,
    round(v_nilai * s.persen_toko / 100, 2),
    round(v_nilai * s.persen_admin / 100, 2),
    round(v_nilai * s.persen_teknisi / 100, 2);
end;
$fn$;


create or replace function pendapatan_teknisi(p_dari date, p_sampai date)
returns table (
  teknisi_id uuid,
  nama       text,
  unit       bigint,
  nilai      numeric,
  porsi      numeric,
  pendapatan numeric
)
language plpgsql stable security definer set search_path = public as $fn$
declare
  s            revenue_settings%rowtype;
  v_nilai_all  numeric;
  v_jatah      numeric;
  v_jumlah     integer;
begin
  if not is_admin() then
    raise exception 'Hanya admin yang dapat melihat perhitungan pendapatan.';
  end if;

  select * into s from revenue_settings where id = 1;

  -- Jatah teknisi dihitung dari SELURUH nilai periode, termasuk klaim yang
  -- teknisinya kosong. Kalau tidak, klaim tanpa teknisi akan menaikkan
  -- porsi orang lain tanpa alasan.
  select coalesce(sum(nilai), 0) into v_nilai_all
  from v_nilai_klaim
  where tanggal::date between p_dari and p_sampai;

  v_jatah := round(v_nilai_all * s.persen_teknisi / 100, 2);

  select count(distinct t.teknisi_id) into v_jumlah
  from v_nilai_klaim t
  where t.tanggal::date between p_dari and p_sampai
    and t.teknisi_id is not null;

  return query
  with per_teknisi as (
    select k.teknisi_id as tid, count(*)::bigint as jml, sum(k.nilai) as val
    from v_nilai_klaim k
    where k.tanggal::date between p_dari and p_sampai
      and k.teknisi_id is not null
    group by k.teknisi_id
  ),
  dihitung as (
    select
      t.tid,
      t.jml,
      t.val,
      case s.metode_teknisi
        when 'per_unit' then
          case when v_nilai_all = 0 then 0 else t.val / v_nilai_all end
        when 'rata' then
          1.0 / greatest(v_jumlah, 1)
        else
          coalesce((select sh.persen from technician_shares sh
                    where sh.profile_id = t.tid), 0) / 100
      end as rasio
    from per_teknisi t
  )
  select
    d.tid,
    p.nama,
    d.jml,
    d.val,
    -- Porsi disimpan sebagai persen agar laporan bisa menunjukkan dasar
    -- hitungannya, bukan hanya rupiah akhirnya.
    round(d.rasio * 100, 2),
    round(v_jatah * d.rasio, 2)
  from dihitung d
  join profiles p on p.id = d.tid
  order by round(v_jatah * d.rasio, 2) desc;
end;
$fn$;


create or replace function pendapatan_brand(p_dari date, p_sampai date)
returns table (
  brand      text,
  unit       bigint,
  nilai      numeric,
  fee_satuan numeric
)
language plpgsql stable security definer set search_path = public as $fn$
begin
  if not is_admin() then
    raise exception 'Hanya admin yang dapat melihat perhitungan pendapatan.';
  end if;

  return query
  select
    b.nama,
    count(*)::bigint,
    sum(k.nilai),
    -- Fee bisa berubah di tengah periode; yang ditampilkan rata-rata
    -- efektifnya, supaya angkanya tetap bisa dijelaskan.
    case when count(*) = 0 then 0 else round(sum(k.nilai) / count(*), 2) end
  from v_nilai_klaim k
  join brands b on b.id = k.brand_id
  where k.tanggal::date between p_dari and p_sampai
  group by b.nama
  order by sum(k.nilai) desc;
end;
$fn$;


-- ---------------------------------------------------------------------
-- 5. AKSES TABEL
--
--    Angka fee dan aturan pembagian hanya untuk admin. Teknisi tidak
--    melihat fee brand maupun perolehan rekannya.
-- ---------------------------------------------------------------------
alter table brand_fees        enable row level security;
alter table revenue_settings  enable row level security;
alter table technician_shares enable row level security;

create policy fees_admin on brand_fees for all to authenticated
  using (is_admin()) with check (is_admin());

create policy settings_admin on revenue_settings for all to authenticated
  using (is_admin()) with check (is_admin());

create policy shares_admin on technician_shares for all to authenticated
  using (is_admin()) with check (is_admin());
