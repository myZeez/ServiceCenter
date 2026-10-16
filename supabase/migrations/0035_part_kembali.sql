-- =====================================================================
--  Migrasi 0035 : jejak pengembalian unit/part klaim ke brand
-- =====================================================================

alter table claims
  add column if not exists tanggal_part_kembali timestamptz;

comment on column claims.tanggal_part_kembali is
  'Waktu unit/part klaim yang sudah close diserahkan kembali ke brand. '
  'Null berarti masih menunggu dikembalikan.';

create index if not exists claims_part_kembali_pending_idx
  on claims (brand_id, tanggal_close)
  where status = 'close'
    and jenis = 'brand'
    and tanggal_part_kembali is null;

-- Penyerahan ke brand adalah tindakan administrasi/logistik. Teknisi tetap
-- dapat mengubah status, catatan, keluhan, part, dan teknisi klaim sesuai
-- penjaga utama, tetapi tidak dapat menandai unit sebagai sudah dikembalikan.
create or replace function claims_guard_part_kembali()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.tanggal_part_kembali is distinct from old.tanggal_part_kembali
     and not is_admin()
  then
    raise exception 'Hanya admin yang boleh menandai part kembali ke brand.';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_claims_guard_part_kembali on claims;
create trigger trg_claims_guard_part_kembali
  before update of tanggal_part_kembali on claims
  for each row execute function claims_guard_part_kembali();
