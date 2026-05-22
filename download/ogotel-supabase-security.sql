-- ================================================================
-- OGOTEL CLOUD — CONFIGURATION SÉCURITÉ SUPABASE (RLS)
-- ================================================================
-- À exécuter dans : Supabase Dashboard → SQL Editor
-- 
-- IMPORTANT : Copiez TOUT le code ci-dessous (de cette ligne
-- jusqu'à la fin) et collez-le dans l'éditeur SQL de Supabase.
-- Ne copiez PAS le nom du fichier.
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

-- 1C. RPC sécurisé : Valider un code d'activation
-- Remplace l'accès direct à la table activation_codes
CREATE OR REPLACE FUNCTION public.validate_activation_code(p_code TEXT)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'valid', true,
    'id', ac.id,
    'plan_id', sp.id,
    'plan_name', sp.plan_name,
    'price', sp.price,
    'max_rooms', sp.max_rooms,
    'max_users', sp.max_users,
    'duration_days', sp.duration_days
  ) INTO v_result
  FROM public.activation_codes ac
  JOIN public.subscription_plans sp ON ac.plan_id = sp.id
  WHERE ac.code = UPPER(p_code)
    AND ac.is_used = false
    AND ac.expires_at > NOW();

  IF v_result IS NULL THEN
    v_result := json_build_object('valid', false);
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1D. RPC sécurisé : Marquer un code d'activation comme utilisé
CREATE OR REPLACE FUNCTION public.use_activation_code(p_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE public.activation_codes
  SET is_used = true, used_at = NOW()
  WHERE code = UPPER(p_code)
    AND is_used = false
    AND expires_at > NOW();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ================================================================
-- PARTIE 2 : ACTIVER ROW LEVEL SECURITY SUR TOUTES LES TABLES
-- ================================================================

DO $$ BEGIN
  ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table subscription_plans n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.activation_codes ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table activation_codes n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.hotels ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table hotels n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table user_profiles n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table rooms n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table clients n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table reservations n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table invoices n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table staff n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table activity_logs n existe pas encore';
END $$;

DO $$ BEGIN
  ALTER TABLE public.landing_requests ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table landing_requests n existe pas encore';
END $$;


-- ================================================================
-- PARTIE 3 : POLITIQUES RLS (ROW LEVEL SECURITY)
-- ================================================================

-- ────────────────────────────────────────────
-- 3.1 subscription_plans (lecture publique)
-- ────────────────────────────────────────────
DROP POLICY IF EXISTS "plans_select_all" ON public.subscription_plans;
CREATE POLICY "plans_select_all" ON public.subscription_plans
  FOR SELECT TO anon, authenticated
  USING (true);


-- ────────────────────────────────────────────
-- 3.2 activation_codes (super_admin uniquement)
-- ────────────────────────────────────────────
-- Les utilisateurs anon/auth utilisent les RPC à la place

DROP POLICY IF EXISTS "codes_select_super_admin" ON public.activation_codes;
CREATE POLICY "codes_select_super_admin" ON public.activation_codes
  FOR SELECT TO authenticated
  USING (public.is_super_admin());

DROP POLICY IF EXISTS "codes_insert_super_admin" ON public.activation_codes;
CREATE POLICY "codes_insert_super_admin" ON public.activation_codes
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS "codes_update_super_admin" ON public.activation_codes;
CREATE POLICY "codes_update_super_admin" ON public.activation_codes
  FOR UPDATE TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS "codes_delete_super_admin" ON public.activation_codes;
CREATE POLICY "codes_delete_super_admin" ON public.activation_codes
  FOR DELETE TO authenticated
  USING (public.is_super_admin());


-- ────────────────────────────────────────────
-- 3.3 hotels
-- ────────────────────────────────────────────
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

DROP POLICY IF EXISTS "hotels_update_super_admin" ON public.hotels;
CREATE POLICY "hotels_update_super_admin" ON public.hotels
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
-- 3.4 user_profiles
-- ────────────────────────────────────────────
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
-- 3.5 rooms (isolation par hotel)
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
-- 3.6 clients (isolation par hotel)
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
-- 3.7 reservations (isolation par hotel)
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
-- 3.8 invoices (isolation par hotel)
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
-- 3.9 staff (isolation par hotel)
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
-- 3.10 activity_logs (isolation par hotel)
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
-- 3.11 landing_requests
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
    -- Empêcher la modification du rôle
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Seul le super administrateur peut modifier le rôle';
    END IF;
    -- Empêcher la modification de l'hôtel assigné
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
--     (un hôtel suspendu ne peut pas se réactiver seul)
CREATE OR REPLACE FUNCTION public.protect_hotel_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    -- Empêcher un hôtel suspendu de se réactiver
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
-- FIN DU SCRIPT — Vérification
-- ================================================================
-- Exécutez cette requête séparément pour vérifier que RLS est actif :
--
-- SELECT tablename, rowsecurity FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;
--
-- Toutes les tables OGOTEL doivent afficher rowsecurity = true
-- ================================================================
