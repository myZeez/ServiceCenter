-- =====================================================================
--  Migrasi 0072 : role gudang
--
--  Tim gudang memegang pembelian part dan memeriksa laporan pemesanan yang
--  dikirim ke pusat. Yang boleh dilakukan gudang:
--
--    * membaca semua pesanan part beserta modalnya (HPP);
--    * mengisi data pembelian: HPP, tanggal order, No PO, dan asal part,
--      serta catatan;
--    * tidak boleh menyentuh harga jual, DP, tahap, nota, atau up toko.
--
--  Gudang tidak membaca nota servis maupun klaim. Data itu berisi nama dan
--  nomor telepon pelanggan serta uang yang tidak ada hubungannya dengan
--  pembelian part.
--
--  role::text dipakai, bukan literal enum: nilai enum baru tidak boleh
--  dipakai dalam transaksi yang menambahkannya.
--
--  Menambah saja bagi yang sudah ada: tidak ada akun gudang sampai
--  super admin membuatnya. Aman dijalankan ulang.
-- =====================================================================

alter type public.user_role add value if not exists 'gudang';

create or replace function public.is_gudang()
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role::text = 'gudang' and aktif
  );
$fn$;

revoke all on function public.is_gudang() from public, anon;
grant execute on function public.is_gudang() to authenticated;

-- ---------------------------------------------------------------------
--  Gudang tidak membaca atau mengubah nota servis dan klaim.
-- ---------------------------------------------------------------------
drop policy if exists so_baca on public.service_orders;
create policy so_baca on public.service_orders
  for select to authenticated
  using (is_active_user() and not is_admin_sc() and not is_gudang());

drop policy if exists so_teknisi_ubah on public.service_orders;
create policy so_teknisi_ubah on public.service_orders
  for update to authenticated
  using (is_active_user() and not is_admin_sc() and not is_gudang())
  with check (is_active_user() and not is_admin_sc() and not is_gudang());

drop policy if exists claims_select on public.claims;
create policy claims_select on public.claims
  for select to authenticated
  using (is_active_user() and not is_gudang());

drop policy if exists claims_insert on public.claims;
create policy claims_insert on public.claims
  for insert to authenticated
  with check (is_active_user() and not is_admin_sc() and not is_gudang());

drop policy if exists claims_update on public.claims;
create policy claims_update on public.claims
  for update to authenticated
  using (is_active_user() and not is_admin_sc() and not is_gudang())
  with check (is_active_user() and not is_admin_sc() and not is_gudang());

drop policy if exists cp_select on public.claim_parts;
create policy cp_select on public.claim_parts
  for select to authenticated
  using (is_active_user() and not is_gudang());

drop policy if exists cp_insert on public.claim_parts;
create policy cp_insert on public.claim_parts
  for insert to authenticated
  with check (is_active_user() and not is_admin_sc() and not is_gudang());

drop policy if exists audit_select on public.claim_audit;
create policy audit_select on public.claim_audit
  for select to authenticated
  using (is_active_user() and not is_gudang());

create or replace function public.tautkan_nota_ke_klaim(p_nota uuid, p_klaim uuid)
returns text
language plpgsql security definer
set search_path = public
as $fn$
declare
  nota record;
begin
  if not public.is_active_user() or public.is_admin_sc() or public.is_gudang() then
    raise exception 'Akun ini tidak berhak mengubah klaim atau nota.'
      using errcode = '42501';
  end if;

  select id, no_nota, claim_id into nota
  from public.service_orders where id = p_nota;

  if not found then
    raise exception 'Nota servisnya tidak ditemukan.';
  end if;

  if not exists (select 1 from public.claims where id = p_klaim) then
    raise exception 'Klaim garansinya tidak ditemukan.';
  end if;

  if nota.claim_id is not null and nota.claim_id <> p_klaim then
    raise exception 'Nota % sudah tertaut ke klaim garansi lain.', nota.no_nota;
  end if;

  perform set_config('app.taut_klaim', 'on', true);
  update public.service_orders
  set garansi = true, claim_id = p_klaim
  where id = p_nota;
  perform set_config('app.taut_klaim', 'off', true);

  return nota.no_nota;
end;
$fn$;

-- ---------------------------------------------------------------------
--  Modal part: gudang membaca dan mengisi HPP, tetapi bukan up toko.
-- ---------------------------------------------------------------------
drop policy if exists pc_gudang_baca on public.part_order_costs;
create policy pc_gudang_baca on public.part_order_costs
  for select to authenticated using (is_gudang());

drop policy if exists pc_gudang_tambah on public.part_order_costs;
create policy pc_gudang_tambah on public.part_order_costs
  for insert to authenticated with check (is_gudang());

drop policy if exists pc_gudang_ubah on public.part_order_costs;
create policy pc_gudang_ubah on public.part_order_costs
  for update to authenticated using (is_gudang()) with check (is_gudang());

create or replace function public.part_cost_guard_gudang()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
begin
  if is_gudang() and not is_admin() then
    if (tg_op = 'INSERT' and new.up_persen is not null)
       or (tg_op = 'UPDATE' and new.up_persen is distinct from old.up_persen) then
      raise exception 'Up toko diatur admin. Gudang hanya mengisi HPP.';
    end if;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_a_pc_gudang on public.part_order_costs;
create trigger trg_a_pc_gudang
  before insert or update on public.part_order_costs
  for each row execute function public.part_cost_guard_gudang();

-- ---------------------------------------------------------------------
--  Pesanan part: gudang hanya mengisi data pembelian.
-- ---------------------------------------------------------------------
create or replace function public.part_orders_guard_update()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
begin
  if ubah_kolom_bebas() then
    return new;
  end if;

  if is_gudang() then
    if (new.id, new.tanggal, new.customer_nama, new.customer_telp,
        new.customer_id, new.barang_type, new.barang_sn, new.part_req,
        new.teknisi_id, new.tahap, new.harga, new.dp, new.cara_bayar,
        new.tanggal_dp, new.tanggal_selesai, new.service_order_id,
        new.created_by)
       is distinct from
       (old.id, old.tanggal, old.customer_nama, old.customer_telp,
        old.customer_id, old.barang_type, old.barang_sn, old.part_req,
        old.teknisi_id, old.tahap, old.harga, old.dp, old.cara_bayar,
        old.tanggal_dp, old.tanggal_selesai, old.service_order_id,
        old.created_by)
    then
      raise exception 'Gudang hanya boleh mengisi tanggal order, No PO, '
                      'asal part, dan catatan. Harga, DP, dan tahap '
                      'diatur admin.';
    end if;
    return new;
  end if;

  if (new.id, new.tanggal, new.customer_nama, new.customer_telp,
      new.customer_id, new.barang_type, new.barang_sn, new.keterangan,
      new.teknisi_id, new.harga, new.dp, new.tanggal_dp, new.tanggal_order,
      new.no_po, new.tanggal_selesai, new.service_order_id, new.created_by)
     is distinct from
     (old.id, old.tanggal, old.customer_nama, old.customer_telp,
      old.customer_id, old.barang_type, old.barang_sn, old.keterangan,
      old.teknisi_id, old.harga, old.dp, old.tanggal_dp, old.tanggal_order,
      old.no_po, old.tanggal_selesai, old.service_order_id, old.created_by)
  then
    raise exception 'Teknisi hanya boleh mengisi kode part, catatan, dan '
                    'menandai part terpasang. Harga, DP, dan data pesanan '
                    'diatur admin.';
  end if;

  if new.tahap is distinct from old.tahap
     and not (old.tahap = 'foto' and new.tahap = 'harga')
     and not (old.tahap = 'dipesan' and new.tahap = 'dipasang')
  then
    raise exception 'Teknisi hanya boleh menandai kode part sudah diisi '
                    'atau part sudah dipasang. Sisanya diatur admin.';
  end if;

  return new;
end;
$fn$;
