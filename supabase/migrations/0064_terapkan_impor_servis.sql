-- =====================================================================
--  Migrasi 0064 : menerapkan hasil CEK DATA impor
--
--  Impor 0060 hanya menambah nota yang belum ada dan menyamakan teknisi.
--  Nota yang sudah ada tetapi tertinggal (sudah diambil di aplikasi lama,
--  masih "masuk" di sini) dihitung "sesuai" dan dibiarkan. Sekarang
--  aplikasi membandingkan file dengan database lebih dulu, menunjukkan
--  kolom mana yang berbeda, dan admin mencentang yang mau dikoreksi.
--  Fungsi ini menerapkan yang dicentang saja.
--
--  Yang dijaga di sini, bukan di aplikasi:
--    * hanya admin yang login;
--    * hanya kolom dalam daftar yang boleh diubah lewat impor;
--    * nota yang berubah sejak dicek dilewati, bukan ditimpa -- hasil
--      cek yang sudah basi tidak boleh menimpa pekerjaan orang lain;
--    * nota baru yang nomor urutnya sudah dipakai dilewati;
--    * cara bayar harus terdaftar.
--  Semuanya satu transaksi: data yang tidak valid membatalkan semuanya.
--
--  Aman dijalankan ulang.
-- =====================================================================

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

  return jsonb_build_object('baru', n_baru, 'diubah', n_ubah, 'dilewati', v_lewat);
end
$fn$;

revoke all on function public.terapkan_impor_servis(jsonb, jsonb) from public, anon;
grant execute on function public.terapkan_impor_servis(jsonb, jsonb) to authenticated;
