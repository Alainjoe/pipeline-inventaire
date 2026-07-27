# Labo 2 — Deploiement sur cible distante (marche a suivre)

Cours 420-6A1-UC. Application : API Flask + PostgreSQL du Labo 1.

## Ce qui est deja pret

| Element                     | Valeur                                              |
| --------------------------- | --------------------------------------------------- |
| Depot GitHub                | https://github.com/Alainjoe/pipeline-inventaire       |
| Image postgres (publique)   | `ajc479/inventaire-postgres:1.0`                      |
| Image api 1.0 (publique)    | `ajc479/inventaire-api:1.0`                           |
| Image api 1.1 (a publier)   | `ajc479/inventaire-api:1.1` — route `/version` ajoutee |
| Compose Docker Hub          | `compose-hub.yml`                                     |
| Blueprint Render            | `render.yaml`                                         |
| Scripts de test             | `scripts/test-api-distante.ps1` / `.sh`               |

Les captures d'ecran vont dans `docs/preuves/`. Les scripts y ecrivent aussi
leurs sorties texte (`tests-<REFERENCE>-<date>.txt`).

---

## Etape 0 — Publier l'image api 1.1

A faire **avant** les parties A et B : `compose-hub.yml` et `render.yaml`
pointent tous les deux sur la 1.1.

```powershell
# Docker Desktop doit etre demarre
docker login
.\scripts\publier-v1.1.ps1
```

Puis pousser le code sur GitHub :

```powershell
git add compose-hub.yml render.yaml .env.render.example scripts docs services/api/app.py README.md
git commit -m "feat: labo2 - deploiement distant Codespaces et Render"
git push
```

---

## PARTIE A — GitHub Codespaces

### Etape 1 — Ouvrir le Codespace

github.com/Alainjoe/pipeline-inventaire > bouton vert **Code** > onglet
**Codespaces** > **Create codespace on main**.

Dans le terminal du Codespace :

```bash
docker --version
docker compose version
```

> **Preuve #1** — capture du terminal avec ces deux sorties.

### Etape 2 — Fichier .env

```bash
cp .env.example .env
# editer .env : POSTGRES_PASSWORD=VotreMotDePasse2026
```

### Etape 3 — Demarrer depuis Docker Hub

```bash
docker compose -f compose-hub.yml up -d
docker compose -f compose-hub.yml ps
```

> **Preuve #2** — capture de `ps` : les deux services `Up`, postgres `(healthy)`.

### Etape 4 — Publier le port 5000

Onglet **PORTS** (a cote de TERMINAL) > port 5000 > colonne **Visibility** >
clic droit > **Public**. Copier l'URL `https://xxxx-5000.app.github.dev`.

Depuis le navigateur de la machine locale (**pas** dans le Codespace) :

- `https://xxxx-5000.app.github.dev/health`
- `https://xxxx-5000.app.github.dev/articles`

> **Preuve #3** — navigateur local, `/health` en JSON.
> **Preuve #4** — navigateur local, `/articles` avec les 5 articles.

### Etape 5 — CRUD depuis l'exterieur

Depuis la machine locale (Windows) :

```powershell
.\scripts\test-api-distante.ps1 -BaseUrl https://xxxx-5000.app.github.dev -Reference CLOUD-001
```

> **Preuve #5** — capture du POST (HTTP 201) et du GET montrant `CLOUD-001`.

### Etape 6 — Test par le coequipier

Le coequipier ouvre `https://xxxx-5000.app.github.dev/health` et `/articles`
sur **sa** machine et **son** reseau.

> **Preuve #6** — capture de son navigateur.

### Etape 7 — Arret propre

```bash
docker compose -f compose-hub.yml down -v
```

> L'URL publique expire a la fermeture du Codespace (ou apres 30 min
> d'inactivite) et change a chaque session. C'est normal.

---

## PARTIE B — Render.com

### Etape 8 — Compte Render

https://render.com > **Get Started for Free** > s'inscrire avec GitHub.
Aucune carte de credit.

### Etape 9 — Base PostgreSQL

**New +** > **PostgreSQL** :

| Champ    | Valeur         |
| -------- | -------------- |
| Name     | inventaire-db  |
| Database | inventaire     |
| User     | admin          |
| Region   | Oregon         |
| Plan     | **Free**       |

Noter dans **Connections** : Host (externe), Port, Database, Username,
Password.

> **Preuve #7** — page de la base, informations de connexion (masquer le mot
> de passe sur la capture).

### Etape 10 — Initialiser le schema

Page de la base > onglet **Shell** (psql dans le navigateur) > copier-coller
le contenu de `services/postgres/init/01_schema.sql`, puis :

```sql
\dt
SELECT COUNT(*) FROM articles;
```

> **Preuve #8** — deux tables listees et `count = 5`.

### Etape 11 — Web Service

**New +** > **Web Service** > **Deploy an existing image from a registry** >
Image URL : `ajc479/inventaire-api:1.1` > **Next**.

| Champ  | Valeur                            |
| ------ | --------------------------------- |
| Name   | inventaire-api                    |
| Region | **la meme que la base** (Oregon)  |
| Plan   | Free                              |

**Advanced** > Environment Variables : recopier `.env.render.example`.

> **Important** : `POSTGRES_HOST` = l'**External Host**
> (`dpg-xxxx.oregon-postgres.render.com`), pas l'Internal Database URL.
> `POSTGRES_SSLMODE=require` : Render refuse les connexions externes en clair.

**Create Web Service**, attendre le statut **Live** (2-3 min).

> **Preuve #9** — tableau de bord : service **Live** + URL generee.

> Variante : **New +** > **Blueprint** > ce depot. `render.yaml` cree la base
> et le service, et branche les variables automatiquement.

### Etape 12 — Valider

Navigateur : `/health`, `/articles`, `/stats` sur
`https://inventaire-api-xxxx.onrender.com`.

```powershell
.\scripts\test-api-distante.ps1 -BaseUrl https://inventaire-api-xxxx.onrender.com -Reference RENDER-001
```

> **Preuve #10** — les 5 tests : health, GET initial, POST 201, GET
> `RENDER-001`, stats.
> **Preuve #11** — navigateur du coequipier sur l'URL Render.

> Premiere requete apres 15 min d'inactivite : 30-60 s (cold start du plan
> gratuit). Normal.

### Etape 13 — Persistance

```powershell
.\scripts\test-api-distante.ps1 -BaseUrl https://inventaire-api-xxxx.onrender.com -Reference PERSIST-001
```

Puis Render > Web Service > **Manual Deploy** > **Deploy latest reference**.
Apres redemarrage :

```powershell
curl.exe https://inventaire-api-xxxx.onrender.com/articles
```

> **Preuve #12** — `PERSIST-001` toujours present apres redemarrage. Les
> donnees vivent dans la base Render, independante du conteneur Flask.

### Etape 14 — Mise a jour de l'image

La route `/version` est deja dans `services/api/app.py` et l'image 1.1 a ete
publiee a l'etape 0. Sur Render : **Settings** > **Image URL** > passer de
`:1.0` a `:1.1` > **Save Changes** (redeploiement automatique).

```powershell
curl.exe https://inventaire-api-xxxx.onrender.com/version
# Attendu : {"auteurs":"Etudiant1 et Etudiant2","version":"1.1"}
```

> **Preuve #13** — `/version` renvoie `1.1`, sans perte de donnees.

### Etape 15 — README et commits

Le README contient deja les URLs publiques et les images (section
« Labo 2 »). Verifier l'historique GitHub : au moins un commit de chaque
coequipier.

> **Preuve #14** — historique GitHub du Labo 2 avec les deux coequipiers.

---

## Recapitulatif des 14 preuves

| #   | Partie | Preuve                                                   |
| --- | ------ | -------------------------------------------------------- |
| 1   | A      | Terminal Codespace : `docker --version` + `compose version` |
| 2   | A      | `docker compose ps` : deux services Up (healthy)          |
| 3   | A      | Navigateur local > URL Codespace > `/health`              |
| 4   | A      | Navigateur local > URL Codespace > `/articles` (5)        |
| 5   | A      | POST `CLOUD-001` (201) + GET confirmant                   |
| 6   | A      | Navigateur du coequipier > URL Codespace                  |
| 7   | B      | Page base Render : informations de connexion              |
| 8   | B      | psql Render : `\dt` + `COUNT(*) = 5`                      |
| 9   | B      | Tableau de bord Render : service **Live**                 |
| 10  | B      | 5 tests curl : health, GET, POST 201, GET, stats          |
| 11  | B      | Navigateur du coequipier > URL Render                     |
| 12  | B      | `PERSIST-001` present apres redemarrage                   |
| 13  | B      | `/version` renvoie `1.1`                                  |
| 14  | A+B    | Historique GitHub avec les deux coequipiers               |

## Depannage

| Symptome                              | Cause / solution                                                        |
| ------------------------------------- | ----------------------------------------------------------------------- |
| Port Codespace inaccessible           | Visibility encore sur **Private** dans l'onglet PORTS.                    |
| Render : 502 ou service qui redemarre | Logs Render. En general `POSTGRES_HOST` (Internal au lieu d'External) ou `POSTGRES_SSLMODE` manquant. |
| `psql` : connexion refusee            | Utiliser l'**External Host**. L'Internal ne marche qu'entre services Render de la meme region. |
| Premiere requete tres lente           | Cold start du plan gratuit (30-60 s).                                    |
| URL Codespace expiree                 | Relancer le Codespace et republier le port : l'URL change a chaque session. |
| Quota Codespaces epuise (120 h/mois)  | Faire uniquement la partie B (Render), sans limite d'heures.              |
