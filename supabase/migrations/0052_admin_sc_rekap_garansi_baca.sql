-- Admin SC memantau seluruh modul garansi, termasuk rekap brand. Ia perlu
-- membaca nilai awal dan hasil pencocokan, tetapi tidak boleh mengubahnya.
create policy fees_admin_sc_baca on public.brand_fees
  for select to authenticated
  using (public.is_admin() or public.is_admin_sc());

create policy settlements_admin_sc_baca on public.claim_settlements
  for select to authenticated
  using (public.is_admin() or public.is_admin_sc());
