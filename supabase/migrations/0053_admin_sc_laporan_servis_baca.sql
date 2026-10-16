-- Tambahan akses baca khusus Admin SC. Kebijakan lama untuk admin/teknisi
-- tidak disentuh; kebijakan SELECT digabungkan PostgreSQL secara OR.
create policy so_admin_sc_baca on public.service_orders
  for select to authenticated using (public.is_admin_sc());

create policy mb_admin_sc_baca on public.metode_bayar
  for select to authenticated using (public.is_admin_sc());

create policy kirim_admin_sc_baca on public.shipments
  for select to authenticated using (public.is_admin_sc());
