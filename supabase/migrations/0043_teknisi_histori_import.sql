-- Nama teknisi pada arsip lama tidak selalu mewakili akun aktif saat ini.
-- Simpan nama sumbernya tanpa menciptakan atau menyamakan akun pengguna palsu.

begin;

alter table public.service_orders
  add column if not exists teknisi_nama_histori text;

alter table public.claims
  add column if not exists teknisi_nama_histori text;

comment on column public.service_orders.teknisi_nama_histori is
  'Nama teknisi dari arsip impor. Dipakai bila teknisi_id tidak dapat dipetakan secara pasti.';

comment on column public.claims.teknisi_nama_histori is
  'Nama teknisi dari arsip impor. Dipakai bila teknisi_id tidak dapat dipetakan secara pasti.';

commit;
