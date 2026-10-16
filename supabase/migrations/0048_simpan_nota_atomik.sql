-- =====================================================================
-- Migrasi 0048: satu transaksi untuk membuat nota baru
--
-- Sebelumnya aplikasi menyimpan pelanggan, klaim, nota, dan tanya harga
-- lewat beberapa HTTP request. Selain terasa lambat, jaringan yang putus
-- di tengah dapat meninggalkan data setengah jadi. Fungsi ini membuatnya
-- sebagai satu transaksi Postgres dan memakai request id agar retry aman.
-- =====================================================================

alter table public.service_orders
  add column if not exists simpan_request_id uuid;

create unique index if not exists service_orders_simpan_request_unik
  on public.service_orders (simpan_request_id)
  where simpan_request_id is not null;

create or replace function public.simpan_nota_baru(
  p_request_id uuid,
  p_nota jsonb,
  p_pelanggan jsonb default null,
  p_klaim jsonb default null,
  p_part jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_user uuid := auth.uid();
  v_customer uuid;
  v_claim uuid;
  v_nota public.service_orders%rowtype;
begin
  if v_user is null then
    raise exception 'Sesi masuk tidak ditemukan.' using errcode = '42501';
  end if;
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat membuat nota.' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'Request id wajib diisi.' using errcode = '22023';
  end if;
  if coalesce(nullif(btrim(p_nota ->> 'customer_nama'), ''), '') = ''
     or coalesce(nullif(btrim(p_nota ->> 'barang_nama'), ''), '') = '' then
    raise exception 'Nama pelanggan dan barang wajib diisi.' using errcode = '22023';
  end if;

  -- Retry setelah respons jaringan hilang harus mengembalikan nota yang
  -- sama, bukan menerbitkan nomor nota berikutnya.
  select * into v_nota
  from public.service_orders
  where simpan_request_id = p_request_id;
  if found then
    if v_nota.created_by <> v_user then
      raise exception 'Request simpan ini bukan milik sesi Anda.' using errcode = '42501';
    end if;
    return jsonb_build_object('nota', to_jsonb(v_nota));
  end if;

  if p_pelanggan is not null then
    insert into public.customers (nama, telp, created_by)
    values (
      nullif(btrim(p_pelanggan ->> 'nama'), ''),
      nullif(btrim(p_pelanggan ->> 'telp'), ''),
      v_user
    )
    returning id into v_customer;
  else
    v_customer := nullif(p_nota ->> 'customer_id', '')::uuid;
  end if;

  if p_klaim is not null then
    v_claim := (p_klaim ->> 'id')::uuid;
    if v_claim is null or (p_klaim ->> 'brand_id') is null then
      raise exception 'Data klaim belum lengkap.' using errcode = '22023';
    end if;

    insert into public.claims (
      id, tanggal, brand_id, jenis, nama_pelanggan, telp, email, sn,
      teknisi_id, keluhan, status, catatan, created_by
    ) values (
      v_claim,
      coalesce((p_klaim ->> 'tanggal')::timestamptz, now()),
      (p_klaim ->> 'brand_id')::smallint,
      coalesce(nullif(p_klaim ->> 'jenis', ''), 'brand'),
      nullif(btrim(p_klaim ->> 'nama_pelanggan'), ''),
      nullif(btrim(p_klaim ->> 'telp'), ''),
      nullif(btrim(p_klaim ->> 'email'), ''),
      nullif(btrim(p_klaim ->> 'sn'), ''),
      nullif(p_klaim ->> 'teknisi_id', '')::uuid,
      nullif(btrim(p_klaim ->> 'keluhan'), ''),
      coalesce(nullif(p_klaim ->> 'status', ''), 'open'),
      nullif(btrim(p_klaim ->> 'catatan'), ''),
      v_user
    );
  else
    v_claim := nullif(p_nota ->> 'claim_id', '')::uuid;
  end if;

  insert into public.service_orders (
    simpan_request_id, estimasi_selesai,
    customer_nama, customer_telp, customer_email, customer_id, operator_id,
    barang_nama, barang_type, barang_sn, kelengkapan, keluhan, teknisi_id,
    perbaikan, garansi, claim_id, status, cabang_tujuan, tanggal_kirim,
    biaya_dikirim_cabang, biaya, cara_bayar, tanggal_lunas, waktu_lunas,
    tanggal_diambil, waktu_diambil, keterangan, created_by
  ) values (
    p_request_id, nullif(p_nota ->> 'estimasi_selesai', '')::date,
    nullif(btrim(p_nota ->> 'customer_nama'), ''),
    nullif(btrim(p_nota ->> 'customer_telp'), ''),
    nullif(btrim(p_nota ->> 'customer_email'), ''), v_customer, v_user,
    nullif(btrim(p_nota ->> 'barang_nama'), ''),
    nullif(btrim(p_nota ->> 'barang_type'), ''),
    nullif(btrim(p_nota ->> 'barang_sn'), ''),
    nullif(btrim(p_nota ->> 'kelengkapan'), ''),
    nullif(btrim(p_nota ->> 'keluhan'), ''),
    nullif(p_nota ->> 'teknisi_id', '')::uuid,
    nullif(btrim(p_nota ->> 'perbaikan'), ''),
    coalesce((p_nota ->> 'garansi')::boolean, false), v_claim,
    coalesce(nullif(p_nota ->> 'status', ''), 'masuk')::public.service_status,
    nullif(btrim(p_nota ->> 'cabang_tujuan'), ''),
    nullif(p_nota ->> 'tanggal_kirim', '')::date,
    (p_nota ->> 'biaya_dikirim_cabang')::boolean,
    coalesce((p_nota ->> 'biaya')::numeric, 0),
    nullif(p_nota ->> 'cara_bayar', ''),
    nullif(p_nota ->> 'tanggal_lunas', '')::date,
    nullif(p_nota ->> 'waktu_lunas', '')::timestamptz,
    nullif(p_nota ->> 'tanggal_diambil', '')::date,
    nullif(p_nota ->> 'waktu_diambil', '')::timestamptz,
    nullif(btrim(p_nota ->> 'keterangan'), ''), v_user
  ) returning * into v_nota;

  if p_part is not null then
    insert into public.part_orders (
      id, customer_nama, customer_telp, customer_id, barang_type, barang_sn,
      part_req, keterangan, teknisi_id, service_order_id, created_by
    ) values (
      (p_part ->> 'id')::uuid,
      nullif(btrim(p_part ->> 'customer_nama'), ''),
      nullif(btrim(p_part ->> 'customer_telp'), ''), v_customer,
      nullif(btrim(p_part ->> 'barang_type'), ''),
      nullif(btrim(p_part ->> 'barang_sn'), ''),
      nullif(btrim(p_part ->> 'part_req'), ''),
      nullif(btrim(p_part ->> 'keterangan'), ''),
      nullif(p_part ->> 'teknisi_id', '')::uuid, v_nota.id, v_user
    );
  end if;

  return jsonb_build_object('nota', to_jsonb(v_nota));
end;
$fn$;

revoke all on function public.simpan_nota_baru(uuid, jsonb, jsonb, jsonb, jsonb) from public;
grant execute on function public.simpan_nota_baru(uuid, jsonb, jsonb, jsonb, jsonb) to authenticated;

comment on function public.simpan_nota_baru(uuid, jsonb, jsonb, jsonb, jsonb) is
  'Membuat nota baru beserta pelanggan, klaim, dan tanya harga dalam satu transaksi idempoten.';
