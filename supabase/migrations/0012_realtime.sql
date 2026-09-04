-- =====================================================================
--  Migrasi 0012 : menyalakan Realtime untuk semua tabel
--
--  Aplikasi tidak lagi menyimpan cerminan datanya sendiri. Setiap layar
--  membaca langsung dari sini, dan Postgres yang memberi tahu perubahan
--  begitu terjadi -- termasuk penghapusan, yang selama ini tidak pernah
--  sampai ke perangkat dan membuat admin dan teknisi melihat dua kenyataan
--  berbeda.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Ikutkan tabelnya ke publikasi Realtime
-- ---------------------------------------------------------------------
--  "alter publication ... add table" menolak tabel yang sudah terdaftar,
--  jadi tiap tabel diperiksa dulu. Tanpa ini, migrasinya hanya bisa
--  dijalankan sekali.
do $realtime$
declare
  t text;
begin
  foreach t in array array[
    'brands', 'part_types', 'profiles',
    'claims', 'claim_parts',
    'service_orders', 'shipments', 'customers',
    'brand_fees', 'revenue_settings',
    'brand_revenue_rules', 'brand_technician_shares',
    'store_settings', 'service_settings'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end
$realtime$;


-- ---------------------------------------------------------------------
--  2. REPLICA IDENTITY FULL
-- ---------------------------------------------------------------------
--  Inilah bagian yang menentukan, dan yang paling mudah terlewat.
--
--  Secara bawaan, kabar penghapusan dari Postgres hanya memuat kunci
--  primernya. Realtime tidak bisa menguji baris sepotong itu terhadap
--  aturan akses, jadi kabarnya dibuang diam-diam: baris hilang di server,
--  tetapi tidak ada perangkat yang diberi tahu -- persis keadaan yang
--  hendak dibereskan migrasi ini.
--
--  Dengan REPLICA IDENTITY FULL, seluruh isi baris lama ikut dikirim,
--  sehingga aturan aksesnya bisa diuji dan kabar penghapusan sampai.
--
--  Harganya: catatan WAL jadi lebih besar tiap kali ada perubahan. Tabel
--  di sini semuanya kecil -- ribuan baris, bukan jutaan -- jadi tambahan
--  itu tidak terasa.
do $identity$
declare
  t text;
begin
  foreach t in array array[
    'brands', 'part_types', 'profiles',
    'claims', 'claim_parts',
    'service_orders', 'shipments', 'customers',
    'brand_fees', 'revenue_settings',
    'brand_revenue_rules', 'brand_technician_shares',
    'store_settings', 'service_settings'
  ] loop
    execute format('alter table public.%I replica identity full', t);
  end loop;
end
$identity$;
