-- =====================================================================
--  DURCISSEMENT SÉCURITÉ SUPABASE — Pradice Services Nettoyage
--  À exécuter UNE fois, à la main, dans Supabase > SQL Editor
--  (projet dwoniijdxmgeyxaxlamk), APRÈS avoir :
--    1. désactivé les inscriptions publiques (voir étape 0 ci-dessous) ;
--    2. remplacé VOTRE-EMAIL-ADMIN par l'e-mail du compte admin ;
--    3. fait une sauvegarde (Database > Backups) par précaution.
--
--  Étape 0 (dans le tableau de bord, pas en SQL) :
--    Authentication > Sign In / Providers > désactiver
--    « Allow new users to sign up ». Puis Authentication > Users :
--    supprimer tout compte que vous ne reconnaissez pas.
--
--  Ce script remplace TOUTES les règles d'accès (policies) existantes
--  des tables settings, services, gallery, jobs, promotions, leads et
--  du stockage « media » par des règles réservées au seul admin.
--  Le tout s'exécute dans une transaction : en cas d'erreur, rien
--  n'est modifié.
-- =====================================================================
begin;

-- ---------- 1. Liste des administrateurs ----------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

insert into public.admins(user_id)
select id from auth.users where email = 'VOTRE-EMAIL-ADMIN'
on conflict do nothing;

do $$ begin
  if not exists (select 1 from public.admins) then
    raise exception 'Aucun admin trouvé : vérifiez l''e-mail VOTRE-EMAIL-ADMIN';
  end if;
end $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------- 2. On efface les anciennes règles -----------------------
do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies
           where schemaname = 'public'
             and tablename in ('settings','services','gallery','jobs','promotions','leads')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.settings   enable row level security;
alter table public.services   enable row level security;
alter table public.gallery    enable row level security;
alter table public.jobs       enable row level security;
alter table public.promotions enable row level security;
alter table public.leads      enable row level security;

-- ---------- 3. Contenu du site : lecture publique, écriture admin ---
create policy lecture_publique on public.settings   for select using (true);
create policy lecture_publique on public.gallery    for select using (true);
create policy lecture_publique on public.services   for select using (published or public.is_admin());
create policy lecture_publique on public.jobs       for select using (published or public.is_admin());
create policy lecture_publique on public.promotions for select using (active or public.is_admin());

create policy ecriture_admin on public.settings   for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy ecriture_admin on public.gallery    for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy ecriture_admin on public.services   for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy ecriture_admin on public.jobs       for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy ecriture_admin on public.promotions for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- 4. Demandes (leads) -------------------------------------
-- Le public ne peut remplir QUE « type » et « payload » : impossible
-- d'imposer un statut, un id ou une date piégés.
revoke insert, update, delete on public.leads from anon, authenticated;
grant insert (type, payload) on public.leads to anon, authenticated;
grant update (status) on public.leads to authenticated;
grant delete on public.leads to authenticated;

alter table public.leads drop constraint if exists leads_type_ok;
alter table public.leads add constraint leads_type_ok
  check (type in ('devis','contact','recrutement')) not valid;
alter table public.leads drop constraint if exists leads_payload_ok;
alter table public.leads add constraint leads_payload_ok
  check (jsonb_typeof(payload::jsonb) = 'object' and pg_column_size(payload) < 8000) not valid;
alter table public.leads drop constraint if exists leads_status_ok;
alter table public.leads add constraint leads_status_ok
  check (status in ('nouveau','traité','archivé')) not valid;

create policy depot_public on public.leads for insert to anon, authenticated with check (true);
create policy lecture_admin on public.leads for select to authenticated using (public.is_admin());
create policy modif_admin   on public.leads for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy suppr_admin   on public.leads for delete to authenticated using (public.is_admin());

-- Limitation de débit : 5 demandes max par adresse IP sur 10 minutes,
-- et 200 max au total par heure (anti-robot). L'IP n'est pas stockée
-- en clair : seulement une empreinte (hachage).
alter table public.leads add column if not exists ip_hash text;

create or replace function public.leads_limite_debit()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  h json := coalesce(current_setting('request.headers', true), '{}')::json;
  ip text := split_part(coalesce(h->>'cf-connecting-ip', h->>'x-forwarded-for', 'inconnue'), ',', 1);
begin
  new.ip_hash := encode(extensions.digest(ip || 'pradice-sel-2026', 'sha256'), 'hex');
  new.status  := 'nouveau';
  if (select count(*) from public.leads
       where ip_hash = new.ip_hash and created_at > now() - interval '10 minutes') >= 5 then
    raise exception 'Trop de demandes, réessayez plus tard.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.leads where created_at > now() - interval '1 hour') >= 200 then
    raise exception 'Service momentanément saturé.' using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists leads_limite_debit on public.leads;
create trigger leads_limite_debit before insert on public.leads
  for each row execute function public.leads_limite_debit();

-- ---------- 5. Stockage des photos (bucket « media ») ---------------
-- Images uniquement, 5 Mo max ; envoi/modif/suppression réservés à
-- l'admin. Les photos restent visibles publiquement via leur lien,
-- mais la LISTE des fichiers n'est plus consultable par tout le monde.
update storage.buckets
   set public = true,
       file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg','image/png','image/webp','image/avif','image/gif']
 where id = 'media';

do $$ declare r record; begin
  for r in select policyname from pg_policies
           where schemaname = 'storage' and tablename = 'objects'
             and (coalesce(qual,'') ilike '%media%' or coalesce(with_check,'') ilike '%media%')
  loop
    execute format('drop policy %I on storage.objects', r.policyname);
  end loop;
end $$;

create policy media_lecture_admin on storage.objects for select to authenticated
  using (bucket_id = 'media' and public.is_admin());
create policy media_envoi_admin on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and public.is_admin());
create policy media_modif_admin on storage.objects for update to authenticated
  using (bucket_id = 'media' and public.is_admin()) with check (bucket_id = 'media' and public.is_admin());
create policy media_suppr_admin on storage.objects for delete to authenticated
  using (bucket_id = 'media' and public.is_admin());

commit;
