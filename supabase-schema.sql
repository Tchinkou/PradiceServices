-- ============================================================
-- Pradice Services Nettoyage — schéma Supabase
-- À coller intégralement dans Supabase > SQL Editor > New query > Run
-- ============================================================

-- Extension nécessaire pour générer des UUID
create extension if not exists "pgcrypto";

-- ============================================================
-- 1. SETTINGS — un seul enregistrement, toutes les infos globales du site
-- ============================================================
create table if not exists settings (
  id smallint primary key default 1,
  brand_name text not null default 'Pradice Services Nettoyage',
  tagline text not null default 'Propreté garantie, satisfaction assurée',
  logo_url text,
  hero_title text default 'Propreté garantie,',
  hero_title_accent text default 'satisfaction assurée',
  hero_tagline text default 'Simplifiez-vous la tâche !',
  hero_subtitle text default 'La société multi-services prête à répondre à tous vos besoins !',
  hero_image_url text,
  hero_image_url_1 text,
  hero_image_url_3 text,
  engage_image_url text,
  google_rating text default '',
  google_review_count int default 0,
  google_reviews_url text default '',
  about_text text default 'Depuis 2023, Pradice Services Nettoyage accompagne les particuliers et les professionnels d''Indre-et-Loire dans l''entretien de leurs espaces, avec une exigence constante de qualité et une démarche éco-responsable.',
  phone text default '07 84 76 95 36',
  whatsapp text default '33784769536',
  email text default 'pradiceservices@gmail.com',
  address_line text default '3 rue Victor Grossein',
  postal_code text default '37000',
  city text default 'Tours',
  country text default 'France',
  hours_weekday text default '8h00 – 18h00',
  hours_saturday text default '9h00 – 16h00',
  hours_sunday text default 'Fermé',
  zone_text text default 'Tours et l''Indre-et-Loire (37)',
  facebook_url text default 'https://www.facebook.com/profile.php?id=61559238324968',
  instagram_url text default 'https://www.instagram.com/servicespradice',
  color_green text default '#1f6b34',
  color_green_light text default '#3fa15a',
  color_blue text default '#0d3b66',
  color_blue_light text default '#1a6fb5',
  values jsonb default '[
    {"emoji":"🤝","title":"Respect du client","text":"Une écoute attentive et un service adapté à vos besoins réels."},
    {"emoji":"🌿","title":"Écologie","text":"Des produits certifiés et une politique de réduction des déchets."},
    {"emoji":"⭐","title":"Qualité","text":"Un contrôle rigoureux à chaque intervention, sans compromis."},
    {"emoji":"👔","title":"Professionnalisme","text":"Une équipe formée, ponctuelle et respectueuse de vos lieux."},
    {"emoji":"✅","title":"Fiabilité","text":"Des engagements tenus et une équipe disponible 6j/7."}
  ]'::jsonb,
  legal_mentions text default 'Pradice Services Nettoyage — 3 rue Victor Grossein, 37000 Tours, France.',
  legal_privacy text default 'Vos données ne sont utilisées que pour traiter votre demande et ne sont jamais partagées.',
  updated_at timestamptz default now()
);

insert into settings (id) values (1) on conflict (id) do nothing;

-- Si la table `settings` existait déjà avant l'ajout de ces colonnes
-- (site créé avec une version antérieure de ce script), on les ajoute
-- sans rien casser — sans effet si elles existent déjà.
alter table settings add column if not exists hero_tagline text default 'Simplifiez-vous la tâche !';
alter table settings add column if not exists hero_image_url_1 text;
alter table settings add column if not exists hero_image_url_3 text;
alter table settings add column if not exists engage_image_url text;
alter table settings add column if not exists google_rating text default '';
alter table settings add column if not exists google_review_count int default 0;
alter table settings add column if not exists google_reviews_url text default '';

-- ============================================================
-- 2. SERVICES — chaque prestation, avec sa propre page
-- ============================================================
create table if not exists services (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  category text not null check (category in ('pro','particulier')),
  title text not null,
  short_desc text not null default '',
  intro text default '',
  details text default '',
  includes jsonb default '[]'::jsonb,
  image_url text,
  icon text default 'bureau',
  sort_order int default 0,
  published boolean default true,
  created_at timestamptz default now()
);

-- ============================================================
-- 3. GALLERY — photos avant/après, liées ou non à un service
-- ============================================================
create table if not exists gallery (
  id uuid primary key default gen_random_uuid(),
  service_id uuid references services(id) on delete set null,
  before_url text,
  after_url text,
  caption text default '',
  sort_order int default 0,
  created_at timestamptz default now()
);

-- ============================================================
-- 4. LEADS — soumissions des formulaires contact, devis & recrutement
-- ============================================================
create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('contact','devis','recrutement')),
  payload jsonb not null,
  status text default 'nouveau' check (status in ('nouveau','traité','archivé')),
  created_at timestamptz default now()
);

-- Si la table existait déjà avec l'ancienne contrainte (sans 'recrutement'),
-- on la remplace — sans effet si elle est déjà à jour.
alter table leads drop constraint if exists leads_type_check;
alter table leads add constraint leads_type_check check (type in ('contact','devis','recrutement'));

-- ============================================================
-- 5. JOBS — offres d'emploi affichées sur la page Recrutement
-- ============================================================
create table if not exists jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  contract_type text default 'CDI',
  location text default '',
  description text default '',
  requirements jsonb default '[]'::jsonb,
  published boolean default true,
  sort_order int default 0,
  created_at timestamptz default now()
);

-- ============================================================
-- 6. PROMOTIONS — offres promotionnelles affichées sur l'accueil
-- ============================================================
create table if not exists promotions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text default '',
  badge_text text default 'Promo',
  image_url text,
  valid_until date,
  active boolean default true,
  sort_order int default 0,
  created_at timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table settings   enable row level security;
alter table services   enable row level security;
alter table gallery    enable row level security;
alter table leads      enable row level security;
alter table jobs       enable row level security;
alter table promotions enable row level security;

-- Lecture publique (le site vitrine doit pouvoir tout afficher)
create policy "public read settings" on settings for select using (true);
create policy "public read published services" on services for select using (published = true);
create policy "public read gallery" on gallery for select using (true);
create policy "public read published jobs" on jobs for select using (published = true);
create policy "public read active promotions" on promotions for select using (active = true);

-- Écriture réservée aux utilisateurs connectés (= toi, l'admin)
create policy "admin write settings" on settings for update using (auth.role() = 'authenticated');
create policy "admin all services" on services for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "admin all gallery" on gallery for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "admin all jobs" on jobs for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "admin all promotions" on promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Formulaires publics : n'importe qui peut créer un lead, seul l'admin peut le lire/modifier
create policy "public insert leads" on leads for insert with check (true);
create policy "admin read leads" on leads for select using (auth.role() = 'authenticated');
create policy "admin update leads" on leads for update using (auth.role() = 'authenticated');
create policy "admin delete leads" on leads for delete using (auth.role() = 'authenticated');

-- ============================================================
-- 5. SEED — services de départ (repris du site actuel)
-- ============================================================
insert into services (slug, category, title, short_desc, intro, details, includes, icon, sort_order) values
('entretien-bureaux','pro','Entretien de bureaux','Nettoyage régulier des sols, surfaces, sanitaires et espaces communs.',
 'Un espace de travail propre, c''est une équipe plus productive et une meilleure image pour vos visiteurs.',
 'Dépoussiérage des postes de travail, nettoyage des sols, désinfection des sanitaires, vidage des corbeilles, nettoyage des parties communes.',
 '["Dépoussiérage des surfaces et mobilier","Nettoyage et désinfection des sanitaires","Lavage des sols","Vidage des corbeilles et tri sélectif","Nettoyage des espaces communs et cuisine"]', 'bureau', 1),
('locaux-commerciaux','pro','Nettoyage de locaux commerciaux','Nettoyage de boutiques, restaurants, agences et autres espaces accueillant du public.',
 'Vos clients jugent votre commerce dès les premières secondes.',
 'Nettoyage des vitrines, sols, surfaces de vente, espaces d''accueil et sanitaires clients.',
 '["Nettoyage vitrines et devanture","Entretien des sols et surfaces de vente","Sanitaires clients et personnel","Interventions en horaires décalés"]', 'boutique', 2),
('remise-en-etat','pro','Remise en état','Nettoyage approfondi après travaux, déménagement ou état des lieux de sortie.',
 'Fin de travaux, déménagement, état des lieux : nous remettons votre bien à neuf.',
 'Dépoussiérage complet, évacuation des résidus, nettoyage des sols, vitres, sanitaires et rangements.',
 '["Dépoussiérage complet toutes surfaces","Nettoyage sols, murs et plinthes","Vitres intérieures","Cuisine et sanitaires"]', 'remise', 3),
('nettoyage-approfondi','pro','Nettoyage approfondi','Désinfection complète, nettoyage haute pression et élimination des micro-organismes.',
 'Pour les environnements exigeants ou un nettoyage en profondeur ponctuel.',
 'Nettoyage haute pression, désinfection des points de contact, élimination des bactéries et moisissures.',
 '["Désinfection des points de contact","Nettoyage haute pression","Traitement anti-moisissures","Produits certifiés"]', 'desinfection', 4),
('entretien-commerces','pro','Entretien des commerces','Entretien quotidien ou hebdomadaire adapté à l''activité du commerce.',
 'Un contrat d''entretien sur-mesure pour garder votre commerce impeccable au quotidien.',
 'Planning récurrent et checklist de contrôle qualité pour un niveau de propreté constant.',
 '["Fréquence adaptée à votre activité","Checklist qualité à chaque passage","Interlocuteur dédié"]', 'commerce', 5),
('fin-de-chantier','pro','Nettoyage de fin de chantier','Élimination des poussières, déchets de construction et résidus de matériaux.',
 'Après travaux, nous réalisons la mise en propreté finale.',
 'Dépoussiérage complet, retrait des résidus, nettoyage des vitres et huisseries, évacuation des petits déchets.',
 '["Dépoussiérage sols, murs et plafonds","Retrait résidus peinture / plâtre / colle","Nettoyage vitres et huisseries"]', 'chantier', 6),
('nettoyage-domicile','particulier','Nettoyage de domicile','Nettoyage de logements et domiciles pour particuliers, ponctuel ou régulier.',
 'Confiez l''entretien de votre logement à une équipe de confiance.',
 'Dépoussiérage, aspiration et lavage des sols, cuisine et salle de bain, rangement léger.',
 '["Dépoussiérage toutes pièces","Sols aspirés et lavés","Cuisine et salle de bain désinfectées"]', 'domicile', 7),
('nettoyage-airbnb','particulier','Nettoyage Airbnb & locations saisonnières','Remise en état rapide entre deux locations, linge et literie sur demande.',
 'Un logement impeccable entre chaque voyageur.',
 'Nettoyage complet, changement des draps et serviettes, réassort des produits d''accueil.',
 '["Intervention rapide entre 2 locations","Changement linge et literie","Réassort produits d''accueil"]', 'airbnb', 8),
('nettoyage-vehicules','particulier','Nettoyage de véhicules','Nettoyage intérieur et extérieur de véhicules particuliers et professionnels.',
 'Un véhicule propre à l''intérieur comme à l''extérieur, sans vous déplacer.',
 'Aspiration complète, nettoyage des sièges et plastiques, vitres, carrosserie et jantes.',
 '["Aspiration complète intérieur/coffre","Nettoyage sièges et plastiques","Carrosserie et jantes"]', 'vehicule', 9),
('nettoyage-vitres','particulier','Nettoyage de vitres','Vitres, baies vitrées et vérandas sans traces, pour particuliers et professionnels.',
 'Des vitres parfaitement transparentes, sans traces ni auréoles.',
 'Nettoyage des vitres intérieures et extérieures, baies vitrées, vérandas et encadrements.',
 '["Vitres intérieures et extérieures","Baies vitrées et vérandas","Matériel professionnel sans traces"]', 'vitres', 10),
('tapis-canapes','particulier','Nettoyage tapis & canapés','Nettoyage en profondeur des textiles d''ameublement par injection-extraction.',
 'Redonnez éclat et fraîcheur à vos tapis, moquettes et canapés.',
 'Traitement par injection-extraction, détachage ciblé, séchage rapide.',
 '["Nettoyage par injection-extraction","Détachage ciblé","Élimination odeurs et acariens"]', 'tapis', 11),
('contrats-entretien','particulier','Contrats d''entretien réguliers','Un forfait sur-mesure, hebdomadaire ou mensuel, pour un intérieur toujours impeccable.',
 'Simplifiez-vous la vie avec un contrat d''entretien régulier.',
 'Fréquence, tâches prioritaires et horaires définis ensemble. Contrat flexible et ajustable.',
 '["Fréquence sur-mesure","Équipe dédiée et régulière","Tarif fixe et prévisible"]', 'contrat', 12)
on conflict (slug) do nothing;

-- ============================================================
-- 7. SEED — une offre d'emploi de départ (modifiable/supprimable dans l'admin)
-- ============================================================
insert into jobs (title, contract_type, location, description, requirements, sort_order)
select 'Agent(e) d''entretien polyvalent(e)', 'CDI', 'Tours et agglomération',
 'Nous recherchons une personne sérieuse et autonome pour intervenir chez nos clients particuliers et professionnels.',
 '["Expérience appréciée mais non obligatoire","Permis B souhaité","Ponctualité et discrétion"]', 1
where not exists (select 1 from jobs);

-- ============================================================
-- 8. STORAGE — bucket public pour logo / photos (à créer aussi via l'interface, voir instructions)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

create policy "public read media" on storage.objects for select using (bucket_id = 'media');
create policy "admin write media" on storage.objects for insert with check (bucket_id = 'media' and auth.role() = 'authenticated');
create policy "admin update media" on storage.objects for update using (bucket_id = 'media' and auth.role() = 'authenticated');
create policy "admin delete media" on storage.objects for delete using (bucket_id = 'media' and auth.role() = 'authenticated');
