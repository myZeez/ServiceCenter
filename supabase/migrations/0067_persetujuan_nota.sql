-- =====================================================================
--  Migrasi 0067 : nota yang sudah keluar perlu persetujuan super admin
--
--  PASANG SETELAH: 0065, akun super admin ada, dan aplikasi versi baru
--  terpasang. Aplikasi lama tetap aman: simpannya ditolak dengan pesan yang
--  jelas, tidak ada data yang rusak.
--
--  Nota Diambil dan Batal terkunci: unitnya sudah keluar dari toko, jadi
--  angkanya sudah masuk laporan. Selesai belum, unitnya masih di rak.
--
--  Yang tetap bebas pada nota terkunci:
--    * catatan (perbaikan, keterangan), untuk semua yang boleh mengubah nota;
--    * pelunasan nota yang belum lunas. Mencatat uang masuk tidak perlu izin,
--      mengoreksi pelunasan yang sudah tercatat perlu.
--
--  Admin mengubah sisanya lewat ajukan_perubahan_nota(); super admin
--  memutuskannya lewat putuskan_perubahan_nota(). Teknisi tidak mengajukan,
--  status nota terkunci bukan urusannya.
--
--  Impor melewati kunci: gunanya hanya migrasi dari aplikasi lama.
--
--  Aman dijalankan ulang.
-- =====================================================================

do $periksa$
begin
  if not exists (select 1 from public.profiles where role::text = 'super_admin' and aktif) then
    raise exception 'Belum ada super admin aktif. Tidak ada yang diubah.';
  end if;
end
$periksa$;

create table if not exists public.permintaan_ubah_nota (
  id               uuid primary key default gen_random_uuid(),
  service_order_id uuid not null references public.service_orders(id) on delete cascade,
  no_nota          text,
  perubahan        jsonb not null,
  sebelum          jsonb not null,
  alasan           text not null check (btrim(alasan) <> ''),
  status           text not null default 'menunggu'
                   check (status in ('menunggu', 'disetujui', 'ditolak', 'dibatalkan')),
  diajukan_oleh    uuid not null references public.profiles(id),
  diajukan_pada    timestamptz not null default now(),
  diputus_oleh     uuid references public.profiles(id),
  diputus_pada     timestamptz,
  catatan_putusan  text
);

-- Satu nota, satu permintaan berjalan. Dua permintaan atas kolom yang sama
-- saling menimpa, dan yang menyetujui tidak akan tahu.
create unique index if not exists permintaan_ubah_nota_satu_menunggu
  on public.permintaan_ubah_nota (service_order_id) where status = 'menunggu';

create index if not exists permintaan_ubah_nota_status
  on public.permintaan_ubah_nota (status, diajukan_pada desc);

-- Hanya kebijakan baca: semua penulisan lewat fungsi di bawah.
alter table public.permintaan_ubah_nota enable row level security;
revoke all on public.permintaan_ubah_nota from anon, authenticated;
grant select on public.permintaan_ubah_nota to authenticated;

drop policy if exists permintaan_baca on public.permintaan_ubah_nota;
create policy permintaan_baca on public.permintaan_ubah_nota
  for select to authenticated using (is_admin());

do $realtime$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'permintaan_ubah_nota'
  ) then
    alter publication supabase_realtime add table public.permintaan_ubah_nota;
  end if;
end
$realtime$;

create or replace function public.nota_belum_lunas(p_lunas date, p_cara text)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select p_lunas is null or p_cara is null or coalesce(
    (select m.piutang from metode_bayar m where m.kode = p_cara),
    false
  );
$fn$;

revoke all on function public.nota_belum_lunas(date, text) from public, anon, authenticated;

create or replace function public.kunci_nota_keluar()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
declare
  bebas text[] := array[
    'updated_at', 'operator_id', 'simpan_request_id', 'perbaikan', 'keterangan',
    -- Dijaga service_orders_guard_update dan fungsi taut klaim.
    'garansi', 'claim_id'
  ];
begin
  if old.status::text not in ('diambil', 'batal')
     or auth.uid() is null
     or is_super_admin()
     or coalesce(current_setting('app.sinkron_status', true), 'off') = 'on'
     or coalesce(current_setting('app.impor', true), 'off') = 'on'
  then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception 'Nota yang sudah keluar hanya bisa dihapus super admin.';
  end if;

  if nota_belum_lunas(old.tanggal_lunas, old.cara_bayar) then
    bebas := bebas || array['cara_bayar', 'tanggal_lunas', 'waktu_lunas'];
  end if;

  if (to_jsonb(new) - bebas) is distinct from (to_jsonb(old) - bebas) then
    raise exception 'Nota ini sudah keluar. Perubahannya perlu persetujuan super admin.';
  end if;

  return new;
end;
$fn$;

-- Berjalan sesudah trg_a_so_guard dan sebelum trg_so_touch: yang dibandingkan
-- harus perubahan dari pengirim, bukan hasil hitungan trigger lain.
drop trigger if exists trg_a_so_kunci on public.service_orders;
create trigger trg_a_so_kunci
  before update or delete on public.service_orders
  for each row execute function public.kunci_nota_keluar();

-- Menerima isi formulir nota apa adanya. Server yang menentukan bedanya,
-- supaya aplikasi tidak perlu menyalin aturan kunci.
--
-- Tanpa p_alasan, tidak ada yang tertulis selama ada kolom terkunci yang
-- berubah: hasilnya 'perlu_alasan' beserta perubahannya, untuk ditunjukkan ke
-- admin sebelum ia menulis alasan.
create or replace function public.ajukan_perubahan_nota(
  p_nota   uuid,
  p_data   jsonb,
  p_alasan text default null
)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $fn$
declare
  kolom_boleh constant text[] := array[
    'estimasi_selesai', 'customer_nama', 'customer_telp', 'customer_email',
    'customer_id', 'barang_nama', 'barang_type', 'barang_sn', 'kelengkapan',
    'keluhan', 'teknisi_id', 'perbaikan', 'status', 'cabang_tujuan',
    'tanggal_kirim', 'biaya_dikirim_cabang', 'biaya', 'cara_bayar',
    'tanggal_lunas', 'waktu_lunas', 'tanggal_diambil', 'waktu_diambil',
    'keterangan'
  ];
  v_nota    public.service_orders%rowtype;
  v_isi     public.service_orders%rowtype;
  v_lama    jsonb;
  v_baru    jsonb;
  v_kunci   jsonb := '{}'::jsonb;
  v_sebelum jsonb := '{}'::jsonb;
  v_bebas   jsonb := '{}'::jsonb;
  v_belum   boolean;
  v_alasan  text := nullif(btrim(p_alasan), '');
  v_id      uuid;
  k         text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Hanya admin yang boleh mengajukan perubahan nota.' using errcode = '42501';
  end if;
  if jsonb_typeof(p_data) is distinct from 'object' then
    raise exception 'Isi perubahan nota tidak terbaca.';
  end if;

  select * into v_nota from public.service_orders where id = p_nota for update;
  if not found then
    raise exception 'Nota servisnya tidak ditemukan.';
  end if;
  if v_nota.status::text not in ('diambil', 'batal') then
    raise exception 'Nota ini belum keluar, jadi tidak perlu persetujuan.';
  end if;

  v_belum := public.nota_belum_lunas(v_nota.tanggal_lunas, v_nota.cara_bayar);
  v_isi := jsonb_populate_record(v_nota, p_data);
  v_lama := to_jsonb(v_nota);
  v_baru := to_jsonb(v_isi);

  foreach k in array kolom_boleh loop
    continue when not p_data ? k;
    continue when v_lama->k is not distinct from v_baru->k;

    if k in ('perbaikan', 'keterangan')
       or (v_belum and k in ('cara_bayar', 'tanggal_lunas', 'waktu_lunas')) then
      v_bebas := v_bebas || jsonb_build_object(k, v_baru->k);
    else
      v_kunci := v_kunci || jsonb_build_object(k, v_baru->k);
      v_sebelum := v_sebelum || jsonb_build_object(k, v_lama->k);
    end if;
  end loop;

  if v_kunci <> '{}'::jsonb then
    if exists (
      select 1 from public.permintaan_ubah_nota
      where service_order_id = p_nota and status = 'menunggu'
    ) then
      raise exception 'Nota ini masih punya permintaan yang menunggu keputusan super admin.';
    end if;

    if v_alasan is null then
      return jsonb_build_object(
        'status', 'perlu_alasan',
        'perubahan', v_kunci,
        'sebelum', v_sebelum
      );
    end if;
  end if;

  if v_bebas <> '{}'::jsonb then
    v_isi := jsonb_populate_record(v_nota, v_bebas);
    update public.service_orders set
      perbaikan     = v_isi.perbaikan,
      keterangan    = v_isi.keterangan,
      cara_bayar    = v_isi.cara_bayar,
      tanggal_lunas = v_isi.tanggal_lunas,
      waktu_lunas   = v_isi.waktu_lunas
    where id = p_nota;
  end if;

  if v_kunci = '{}'::jsonb then
    return jsonb_build_object('status', 'tersimpan');
  end if;

  insert into public.permintaan_ubah_nota (
    service_order_id, no_nota, perubahan, sebelum, alasan, diajukan_oleh
  ) values (
    p_nota, v_nota.no_nota, v_kunci, v_sebelum, v_alasan, auth.uid()
  )
  returning id into v_id;

  return jsonb_build_object('status', 'diajukan', 'id', v_id);
end;
$fn$;

revoke all on function public.ajukan_perubahan_nota(uuid, jsonb, text) from public, anon;
grant execute on function public.ajukan_perubahan_nota(uuid, jsonb, text) to authenticated;

create or replace function public.putuskan_perubahan_nota(
  p_id      uuid,
  p_setuju  boolean,
  p_catatan text default null
)
returns text
language plpgsql security definer
set search_path = public, pg_temp
as $fn$
declare
  v_minta   public.permintaan_ubah_nota%rowtype;
  v_nota    public.service_orders%rowtype;
  v_isi     public.service_orders%rowtype;
  v_lama    jsonb;
  v_sebelum jsonb;
  k         text;
begin
  if auth.uid() is null or not public.is_super_admin() then
    raise exception 'Hanya super admin yang boleh memutuskan permintaan.' using errcode = '42501';
  end if;
  if p_setuju is null then
    raise exception 'Keputusannya belum dipilih.';
  end if;

  select * into v_minta from public.permintaan_ubah_nota where id = p_id for update;
  if not found then
    raise exception 'Permintaannya tidak ditemukan.';
  end if;
  if v_minta.status <> 'menunggu' then
    raise exception 'Permintaan ini sudah diputus.';
  end if;

  if p_setuju then
    select * into v_nota from public.service_orders
    where id = v_minta.service_order_id for update;

    -- Dibandingkan kolom per kolom: pelunasan yang masuk sesudah diajukan
    -- tidak perlu menggugurkan koreksi nama pelanggan.
    v_lama := to_jsonb(v_nota);
    v_sebelum := to_jsonb(jsonb_populate_record(v_nota, v_minta.sebelum));
    for k in select jsonb_object_keys(v_minta.perubahan) loop
      if v_lama->k is distinct from v_sebelum->k then
        raise exception 'Nota sudah berubah sejak diajukan (%). Tolak permintaan ini, lalu ajukan ulang.', k;
      end if;
    end loop;

    v_isi := jsonb_populate_record(v_nota, v_minta.perubahan);
    update public.service_orders set
      estimasi_selesai     = v_isi.estimasi_selesai,
      customer_nama        = v_isi.customer_nama,
      customer_telp        = v_isi.customer_telp,
      customer_email       = v_isi.customer_email,
      customer_id          = v_isi.customer_id,
      barang_nama          = v_isi.barang_nama,
      barang_type          = v_isi.barang_type,
      barang_sn            = v_isi.barang_sn,
      kelengkapan          = v_isi.kelengkapan,
      keluhan              = v_isi.keluhan,
      teknisi_id           = v_isi.teknisi_id,
      status               = v_isi.status,
      cabang_tujuan        = v_isi.cabang_tujuan,
      tanggal_kirim        = v_isi.tanggal_kirim,
      biaya_dikirim_cabang = v_isi.biaya_dikirim_cabang,
      biaya                = v_isi.biaya,
      cara_bayar           = v_isi.cara_bayar,
      tanggal_lunas        = v_isi.tanggal_lunas,
      waktu_lunas          = v_isi.waktu_lunas,
      tanggal_diambil      = v_isi.tanggal_diambil,
      waktu_diambil        = v_isi.waktu_diambil
    where id = v_nota.id;
  end if;

  update public.permintaan_ubah_nota set
    status          = case when p_setuju then 'disetujui' else 'ditolak' end,
    diputus_oleh    = auth.uid(),
    diputus_pada    = now(),
    catatan_putusan = nullif(btrim(p_catatan), '')
  where id = p_id;

  return v_minta.no_nota;
end;
$fn$;

revoke all on function public.putuskan_perubahan_nota(uuid, boolean, text) from public, anon;
grant execute on function public.putuskan_perubahan_nota(uuid, boolean, text) to authenticated;

create or replace function public.batalkan_permintaan_nota(p_id uuid)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $fn$
begin
  update public.permintaan_ubah_nota set
    status       = 'dibatalkan',
    diputus_oleh = auth.uid(),
    diputus_pada = now()
  where id = p_id and status = 'menunggu' and diajukan_oleh = auth.uid();

  if not found then
    raise exception 'Permintaan ini tidak bisa dibatalkan.';
  end if;
end;
$fn$;

revoke all on function public.batalkan_permintaan_nota(uuid) from public, anon;
grant execute on function public.batalkan_permintaan_nota(uuid) to authenticated;

-- Membatalkan garansi ikut membatalkan klaimnya, jadi tidak bisa ditampung
-- sebagai perubahan kolom nota.
create or replace function public.batalkan_garansi_nota(p_nota uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_nota public.service_orders%rowtype;
begin
  -- security definer melewati RLS: pembatalan ini hanya hak admin.
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Hanya admin yang boleh membatalkan status garansi.'
      using errcode = '42501';
  end if;

  select * into v_nota
  from public.service_orders
  where id = p_nota
  for update;

  if not found then
    raise exception 'Nota servisnya tidak ditemukan.';
  end if;

  -- Aman bila respons sebelumnya hilang lalu aplikasi mencoba lagi.
  if not v_nota.garansi and v_nota.claim_id is null then
    return v_nota.no_nota;
  end if;

  if v_nota.status::text in ('diambil', 'batal') and not public.is_super_admin() then
    raise exception 'Nota ini sudah keluar. Hanya super admin yang bisa membatalkan garansinya.';
  end if;

  if v_nota.claim_id is not null then
    update public.claims
    set
      status = 'batal',
      catatan = concat_ws(
        E'\n',
        nullif(btrim(catatan), ''),
        'Garansi pada nota ' || v_nota.no_nota ||
          ' dibatalkan oleh admin.'
      )
    where id = v_nota.claim_id;
  end if;

  -- Guard update service_orders hanya membuka dua kolom ini selama
  -- transaksi fungsi berlangsung.
  perform set_config('app.taut_klaim', 'on', true);
  update public.service_orders
  set garansi = false, claim_id = null
  where id = v_nota.id;
  perform set_config('app.taut_klaim', 'off', true);

  return v_nota.no_nota;
end;
$fn$;

-- Sama dengan 0064, ditambah pembuka kunci nota yang sudah keluar.
create or replace function public.terapkan_impor_servis(
  p_baru jsonb default '[]'::jsonb,
  p_ubah jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  r          record;
  u          record;
  v_now      timestamptz;
  v_status   text;
  k          text;
  n_baru     integer := 0;
  n_ubah     integer := 0;
  v_lewat    jsonb := '[]'::jsonb;
  kolom_boleh constant text[] := array[
    'status', 'garansi', 'teknisi_id', 'biaya', 'cara_bayar',
    'tanggal_lunas', 'tanggal_selesai', 'tanggal_diambil', 'perbaikan',
    'keluhan', 'customer_nama', 'customer_telp', 'barang_nama'
  ];
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Seorang admin aktif wajib login untuk impor.' using errcode = '42501';
  end if;
  if jsonb_typeof(p_baru) is distinct from 'array'
     or jsonb_typeof(p_ubah) is distinct from 'array' then
    raise exception 'Data impor harus berupa daftar.';
  end if;
  if jsonb_array_length(p_baru) + jsonb_array_length(p_ubah) = 0 then
    raise exception 'Tidak ada yang dipilih untuk diterapkan.';
  end if;
  if jsonb_array_length(p_baru) + jsonb_array_length(p_ubah) > 5000 then
    raise exception 'Terapkan paling banyak 5000 nota sekali jalan.';
  end if;

  -- Menahan penulisan nota lain selama transaksi singkat ini, supaya cek
  -- "sudah ada" dan "berubah sejak dicek" tidak didahului penyimpanan lain.
  lock table public.service_orders in share row exclusive mode;
  perform set_config('app.impor', 'on', true);

  -- -------------------------------------------------------------------
  --  Nota baru
  -- -------------------------------------------------------------------
  for r in select * from jsonb_to_recordset(p_baru) as x(
    no_nota text, tanggal_masuk date, customer_nama text, customer_telp text,
    barang_nama text, keluhan text, kelengkapan text, teknisi_id uuid,
    status text, garansi boolean, biaya numeric, cara_bayar text,
    tanggal_lunas date, tanggal_selesai date, tanggal_diambil date,
    perbaikan text
  ) loop
    if r.no_nota is null or r.no_nota !~ '^SVR-[0-9]{11}$'
       or r.tanggal_masuk is null
       or substring(r.no_nota from 5 for 6) <> to_char(r.tanggal_masuk, 'DDMMYY')
       or coalesce(btrim(r.customer_nama), '') = ''
       or coalesce(btrim(r.barang_nama), '') = ''
       or r.biaya is null or r.biaya < 0 or r.biaya > 9999999999.99
       or r.status is null or r.status not in ('masuk', 'diambil', 'batal')
       or r.garansi is null
       or (r.status in ('diambil', 'batal') and r.tanggal_diambil is null)
       or (r.status = 'masuk' and r.tanggal_diambil is not null)
       or r.tanggal_diambil < r.tanggal_masuk
       or (r.tanggal_lunas is not null and r.cara_bayar is null)
       or (r.cara_bayar is not null
           and not exists (select 1 from public.metode_bayar m where m.kode = r.cara_bayar))
       or (r.teknisi_id is not null
           and not exists (select 1 from public.profiles p where p.id = r.teknisi_id)) then
      raise exception 'Data nota baru tidak valid: %', r.no_nota;
    end if;

    if exists (select 1 from public.service_orders s
               where public.urut_no_nota(s.no_nota) = public.urut_no_nota(r.no_nota)) then
      v_lewat := v_lewat || jsonb_build_object('no_nota', r.no_nota,
                                               'alasan', 'nomor urutnya sudah dipakai');
      continue;
    end if;

    insert into public.service_orders (
      no_nota, tanggal_masuk, customer_nama, customer_telp, barang_nama,
      keluhan, kelengkapan, teknisi_id, status, garansi, biaya, cara_bayar,
      tanggal_lunas, tanggal_selesai, tanggal_diambil, perbaikan, created_by
    ) values (
      r.no_nota, r.tanggal_masuk::timestamp at time zone 'Asia/Jakarta',
      btrim(r.customer_nama), nullif(btrim(r.customer_telp), ''), btrim(r.barang_nama),
      nullif(btrim(r.keluhan), ''), nullif(btrim(r.kelengkapan), ''), r.teknisi_id,
      r.status::public.service_status, r.garansi, r.biaya, r.cara_bayar,
      r.tanggal_lunas, r.tanggal_selesai, r.tanggal_diambil,
      nullif(btrim(r.perbaikan), ''), auth.uid()
    );
    n_baru := n_baru + 1;
  end loop;

  -- -------------------------------------------------------------------
  --  Koreksi nota yang sudah ada
  -- -------------------------------------------------------------------
  for u in
    select (x->>'id')::uuid as id,
           (x->>'updated_at')::timestamptz as dilihat,
           x->'set' as s
    from jsonb_array_elements(p_ubah) x
  loop
    if u.id is null or u.dilihat is null
       or u.s is null or jsonb_typeof(u.s) <> 'object' or u.s = '{}'::jsonb then
      raise exception 'Koreksi impor tidak lengkap.';
    end if;
    for k in select jsonb_object_keys(u.s) loop
      if not k = any(kolom_boleh) then
        raise exception 'Kolom % tidak boleh diubah lewat impor.', k;
      end if;
    end loop;

    v_status := u.s->>'status';
    if (u.s ? 'status' and (v_status is null or v_status not in
          ('masuk', 'dikerjakan', 'tunggu_part', 'selesai', 'diambil', 'batal')))
       or (u.s ? 'garansi' and jsonb_typeof(u.s->'garansi') <> 'boolean')
       or (u.s ? 'biaya' and (jsonb_typeof(u.s->'biaya') <> 'number'
                              or (u.s->>'biaya')::numeric < 0))
       or (u.s ? 'customer_nama' and coalesce(btrim(u.s->>'customer_nama'), '') = '')
       or (u.s ? 'barang_nama' and coalesce(btrim(u.s->>'barang_nama'), '') = '')
       or (u.s ? 'cara_bayar' and u.s->>'cara_bayar' is not null
           and not exists (select 1 from public.metode_bayar m where m.kode = u.s->>'cara_bayar'))
       or (u.s ? 'teknisi_id' and u.s->>'teknisi_id' is not null
           and not exists (select 1 from public.profiles p where p.id = (u.s->>'teknisi_id')::uuid)) then
      raise exception 'Koreksi impor tidak valid untuk nota %.', u.id;
    end if;

    select updated_at into v_now from public.service_orders where id = u.id for update;
    if not found then
      v_lewat := v_lewat || jsonb_build_object('id', u.id, 'alasan', 'nota tidak ditemukan');
      continue;
    end if;
    if v_now is distinct from u.dilihat then
      v_lewat := v_lewat || jsonb_build_object(
        'id', u.id,
        'no_nota', (select no_nota from public.service_orders where id = u.id),
        'alasan', 'berubah sejak dicek; cek ulang');
      continue;
    end if;

    update public.service_orders set
      status          = case when u.s ? 'status' then v_status::public.service_status else status end,
      garansi         = case when u.s ? 'garansi' then (u.s->>'garansi')::boolean else garansi end,
      teknisi_id      = case when u.s ? 'teknisi_id' then (u.s->>'teknisi_id')::uuid else teknisi_id end,
      biaya           = case when u.s ? 'biaya' then (u.s->>'biaya')::numeric else biaya end,
      cara_bayar      = case when u.s ? 'cara_bayar' then u.s->>'cara_bayar' else cara_bayar end,
      -- Tanggal yang dipilih admin dipakai apa adanya. Saat lama yang
      -- tersisa akan dihitung ulang trigger menjadi hari lain, jadi ikut
      -- dikosongkan.
      tanggal_lunas   = case when u.s ? 'tanggal_lunas' then (u.s->>'tanggal_lunas')::date else tanggal_lunas end,
      waktu_lunas     = case when u.s ? 'tanggal_lunas' then null else waktu_lunas end,
      tanggal_selesai = case when u.s ? 'tanggal_selesai' then (u.s->>'tanggal_selesai')::date else tanggal_selesai end,
      tanggal_diambil = case when u.s ? 'tanggal_diambil' then (u.s->>'tanggal_diambil')::date else tanggal_diambil end,
      waktu_diambil   = case when u.s ? 'tanggal_diambil' then null else waktu_diambil end,
      perbaikan       = case when u.s ? 'perbaikan' then nullif(btrim(u.s->>'perbaikan'), '') else perbaikan end,
      keluhan         = case when u.s ? 'keluhan' then nullif(btrim(u.s->>'keluhan'), '') else keluhan end,
      customer_nama   = case when u.s ? 'customer_nama' then btrim(u.s->>'customer_nama') else customer_nama end,
      customer_telp   = case when u.s ? 'customer_telp' then nullif(btrim(u.s->>'customer_telp'), '') else customer_telp end,
      barang_nama     = case when u.s ? 'barang_nama' then btrim(u.s->>'barang_nama') else barang_nama end,
      -- Barang dari buku SVS sudah memuat tipenya; tipe lama tidak diulang.
      barang_type     = case when u.s ? 'barang_nama' then null else barang_type end
    where id = u.id;
    n_ubah := n_ubah + 1;
  end loop;

  perform set_config('app.impor', 'off', true);

  return jsonb_build_object('baru', n_baru, 'diubah', n_ubah, 'dilewati', v_lewat);
end
$fn$;

revoke all on function public.terapkan_impor_servis(jsonb, jsonb) from public, anon;
grant execute on function public.terapkan_impor_servis(jsonb, jsonb) to authenticated;
