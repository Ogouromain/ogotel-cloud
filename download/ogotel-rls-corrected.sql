-- ================================================================
-- OGOTEL CLOUD — RLS CORRIGÉ (version finale)
-- ================================================================
-- À exécuter DANS : Supabase Dashboard → SQL Editor
-- 
-- INSTRUCTIONS :
-- 1. Allez sur https://supabase.com/dashboard
-- 2. Sélectionnez votre projet OGOTEL
-- 3. Cliquez sur "SQL Editor" dans le menu de gauche
-- 4. Cliquez sur "+ New query"
-- 5. COPIEZ-COLLEZ TOUT ce qui suit (de cette ligne jusqu'à "-- FIN")
-- 6. Cliquez sur "Run" (le bouton vert ▶)
-- ================================================================


-- ================================================================
-- PARTIE 1 : FONCTIONS UTILITAIRES
-- ================================================================

-- 1A. Vérifie si l'utilisateur connecté est super_admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 1B. Récupère l'hotel_id de l'utilisateur connecté
CREATE OR REPLACE FUNCTION public.get_my_hotel_id()
RETURNS UUID AS $$
DECLARE
  hid UUID;
BEGIN
  SELECT hotel_id INTO hid FROM public.user_profiles WHERE id = auth.uid();
  RETURN hid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;


-- ================================================================
-- PARTIE 2 : ACTIVER ROW LEVEL SECURITY SUR TOUTES LES TABLES
-- ================================================================

DO $$ BEGIN ALTER TABLE public.activation_codes ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table activation_codes inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.hotels ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table hotels inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table user_profiles inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table rooms inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table clients inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table reservations inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table invoices inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table staff inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table activity_logs inexistante'; END $$;
DO $$ BEGIN ALTER TABLE public.landing_requests ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Table landing_requests inexistante'; END $$;


-- ================================================================
-- PARTIE 3 : POLITIQUES RLS
-- ================================================================

-- ────────────────────────────────────────────
-- 3.1 activation_codes
-- ────────────────────────────────────────────
-- IMPORTANT : register.html utilise fetch() en anon,
-- donc on DOIT autoriser anon à LIRE et MODIFIER cette table.

-- Anon peut LIRE (pour vérifier le code lors de l'inscription)
DROP POLICY IF EXISTS "codes_select_anon" ON public.activation_codes;
CREATE POLICY "codes_select_anon" ON public.activation_codes
  FOR SELECT TO anon, authenticated
  USING (true);

-- Anon peut MODIFIER (pour marquer le code comme utilisé à l'inscription)
DROP POLICY IF EXISTS "codes_update_anon" ON public.activation_codes;
CREATE POLICY "codes_update_anon" ON public.activation_codes
  FOR UPDATE TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Super_admin peut tout faire (CRUD complet)
DROP POLICY IF EXISTS "codes_insert_super_admin" ON public.activation_codes;
CREATE POLICY "codes_insert_super_admin" ON public.activation_codes
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS "codes_delete_super_admin" ON public.activation_codes;
CREATE POLICY "codes_delete_super_admin" ON public.activation_codes
  FOR DELETE TO authenticated
  USING (public.is_super_admin());


-- ────────────────────────────────────────────
-- 3.2 hotels
-- ────────────────────────────────────────────
-- Anon peut insérer (création de l'hôtel lors de l'inscription)
DROP POLICY IF EXISTS "hotels_select" ON public.hotels;
CREATE POLICY "hotels_select" ON public.hotels
  FOR SELECT TO authenticated
  USING (
    public.is_super_admin()
    OR id = public.get_my_hotel_id()
  );

DROP POLICY IF EXISTS "hotels_insert_registration" ON public.hotels;
CREATE POLICY "hotels_insert_registration" ON public.hotels
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "hotels_update" ON public.hotels;
CREATE POLICY "hotels_update" ON public.hotels
  FOR UPDATE TO authenticated
  USING (
    public.is_super_admin()
    OR id = public.get_my_hotel_id()
  )
  WITH CHECK (
    public.is_super_admin()
    OR id = public.get_my_hotel_id()
  );

DROP POLICY IF EXISTS "hotels_delete_super_admin" ON public.hotels;
CREATE POLICY "hotels_delete_super_admin" ON public.hotels
  FOR DELETE TO authenticated
  USING (public.is_super_admin());


-- ────────────────────────────────────────────
-- 3.3 user_profiles
-- ────────────────────────────────────────────
-- Anon peut insérer (création du profil lors de l'inscription)
DROP POLICY IF EXISTS "profiles_select" ON public.user_profiles;
CREATE POLICY "profiles_select" ON public.user_profiles
  FOR SELECT TO authenticated
  USING (
    public.is_super_admin()
    OR id = auth.uid()
    OR hotel_id = public.get_my_hotel_id()
  );

DROP POLICY IF EXISTS "profiles_insert_registration" ON public.user_profiles;
CREATE POLICY "profiles_insert_registration" ON public.user_profiles
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "profiles_update" ON public.user_profiles;
CREATE POLICY "profiles_update" ON public.user_profiles
  FOR UPDATE TO authenticated
  USING (
    public.is_super_admin()
    OR id = auth.uid()
  )
  WITH CHECK (
    public.is_super_admin()
    OR id = auth.uid()
  );


-- ────────────────────────────────────────────
-- 3.4 rooms (isolation par hotel)
-- ────────────────────────────────────────────
DROP POLICY IF EXISTS "rooms_select" ON public.rooms;
CREATE POLICY "rooms_select" ON public.rooms
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "rooms_insert" ON public.rooms;
CREATE POLICY "rooms_insert" ON public.rooms
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "rooms_update" ON public.rooms;
CREATE POLICY "rooms_update" ON public.rooms
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id())
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "rooms_delete" ON public.rooms;
CREATE POLICY "rooms_delete" ON public.rooms
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());


-- ────────────────────────────────────────────
-- 3.5 clients (isolation par hotel)
-- ────────────────────────────────────────────
DROP POLICY IF EXISTS "clients_select" ON public.clients;
CREATE POLICY "clients_select" ON public.clients
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "clients_insert" ON public.clients;
CREATE POLICY "clients_insert" ON public.clients
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "clients_update" ON public.clients;
CREATE POLICY "clients_update" ON public.clients
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id())
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "clients_delete" ON public.clients;
CREATE POLICY "clients_delete" ON public.clients
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());


-- ────────────────────────────────────────────
-- 3.6 reservations (isolation par hotel)
-- ────────────────────────────────────────────
DROP POLICY IF EXISTS "reservations_select" ON public.reservations;
CREATE POLICY "reservations_select" ON public.reservations
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "reservations_insert" ON public.reservations;
CREATE POLICY "reservations_insert" ON public.reservations
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "reservations_update" ON public.reservations;
CREATE POLICY "reservations_update" ON public.reservations
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id())
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "reservations_delete" ON public.reservations;
CREATE POLICY "reservations_delete" ON public.reservations
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());


-- ────────────────────────────────────────────
-- 3.7 invoices (isolation par hotel)
-- ────────────────────────────────────────────
DROP POLICY IF EXISTS "invoices_select" ON public.invoices;
CREATE POLICY "invoices_select" ON public.invoices
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "invoices_insert" ON public.invoices;
CREATE POLICY "invoices_insert" ON public.invoices
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "invoices_update" ON public.invoices;
CREATE POLICY "invoices_update" ON public.invoices
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id())
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "invoices_delete" ON public.invoices;
CREATE POLICY "invoices_delete" ON public.invoices
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());


-- ────────────────────────────────────────────
-- 3.8 staff (isolation par hotel)
-- ────────────────────────────────────────────
DROP POLICY IF EXISTS "staff_select" ON public.staff;
CREATE POLICY "staff_select" ON public.staff
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "staff_insert" ON public.staff;
CREATE POLICY "staff_insert" ON public.staff
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "staff_update" ON public.staff;
CREATE POLICY "staff_update" ON public.staff
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id())
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "staff_delete" ON public.staff;
CREATE POLICY "staff_delete" ON public.staff
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());


-- ────────────────────────────────────────────
-- 3.9 activity_logs (isolation par hotel)
-- ────────────────────────────────────────────
DROP POLICY IF EXISTS "activity_logs_select" ON public.activity_logs;
CREATE POLICY "activity_logs_select" ON public.activity_logs
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());

DROP POLICY IF EXISTS "activity_logs_insert" ON public.activity_logs;
CREATE POLICY "activity_logs_insert" ON public.activity_logs
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR hotel_id = public.get_my_hotel_id());


-- ────────────────────────────────────────────
-- 3.10 landing_requests
-- ────────────────────────────────────────────
DROP POLICY IF EXISTS "landing_insert" ON public.landing_requests;
CREATE POLICY "landing_insert" ON public.landing_requests
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "landing_select_super_admin" ON public.landing_requests;
CREATE POLICY "landing_select_super_admin" ON public.landing_requests
  FOR SELECT TO authenticated
  USING (public.is_super_admin());

DROP POLICY IF EXISTS "landing_delete_super_admin" ON public.landing_requests;
CREATE POLICY "landing_delete_super_admin" ON public.landing_requests
  FOR DELETE TO authenticated
  USING (public.is_super_admin());


-- ================================================================
-- PARTIE 4 : TRIGGERS DE SÉCURITÉ
-- ================================================================

-- 4A. Protéger les colonnes sensibles dans user_profiles
--     Seul le super_admin peut changer : role, hotel_id
CREATE OR REPLACE FUNCTION public.protect_profile_columns()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Seul le super administrateur peut modifier le rôle';
    END IF;
    IF NEW.hotel_id IS DISTINCT FROM OLD.hotel_id THEN
      RAISE EXCEPTION 'Seul le super administrateur peut modifier l hotel assigné';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_protect_profile ON public.user_profiles;
CREATE TRIGGER trigger_protect_profile
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_columns();

-- 4B. Empêcher la modification de is_active sur hotels sauf par super_admin
CREATE OR REPLACE FUNCTION public.protect_hotel_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    IF OLD.is_active = false AND NEW.is_active = true THEN
      RAISE EXCEPTION 'Votre hôtel a été suspendu. Contactez le support.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_protect_hotel_status ON public.hotels;
CREATE TRIGGER trigger_protect_hotel_status
  BEFORE UPDATE ON public.hotels
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_hotel_status();


-- ================================================================
-- VÉRIFICATION — Exécutez ceci séparément pour vérifier :
--
-- SELECT tablename, rowsecurity FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;
--
-- Toutes les tables OGOTEL doivent afficher rowsecurity = true
-- ================================================================
-- FIN DU SCRIPT
