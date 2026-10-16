-- Servis yang dikerjakan pihak partner tetap merupakan turunan satu-ke-satu
-- dari nota. Identitas unit tidak disalin agar setiap perubahan nota langsung
-- terlihat juga pada laporan partner.

DO $$ BEGIN
  CREATE TYPE public.partner_service_status AS ENUM ('dikirim', 'selesai');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.service_partner_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_order_id uuid NOT NULL UNIQUE
    REFERENCES public.service_orders(id) ON DELETE CASCADE,
  status public.partner_service_status NOT NULL DEFAULT 'dikirim',
  hpp numeric(12,2) CHECK (hpp IS NULL OR hpp >= 0),
  up_biaya numeric(12,2) CHECK (up_biaya IS NULL OR up_biaya >= 0),
  catatan text,
  created_by uuid NOT NULL REFERENCES public.profiles(id) DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT partner_selesai_perlu_biaya CHECK (
    status <> 'selesai' OR (hpp IS NOT NULL AND up_biaya IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS service_partner_status_idx
  ON public.service_partner_orders(status, created_at DESC);

CREATE OR REPLACE FUNCTION public.sentuh_service_partner_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  IF NEW.status = 'dikirim' THEN
    NEW.hpp := NULL;
    NEW.up_biaya := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_service_partner_touch ON public.service_partner_orders;
CREATE TRIGGER trg_service_partner_touch
  BEFORE UPDATE ON public.service_partner_orders
  FOR EACH ROW EXECUTE FUNCTION public.sentuh_service_partner_order();

ALTER TABLE public.service_partner_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS service_partner_admin ON public.service_partner_orders;
CREATE POLICY service_partner_admin ON public.service_partner_orders
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

ALTER PUBLICATION supabase_realtime ADD TABLE public.service_partner_orders;
