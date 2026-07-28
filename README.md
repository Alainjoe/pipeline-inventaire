# Laboratoire 1 - Inventaire Docker

Projet Flask + PostgreSQL conteneurise pour le laboratoire de pipeline de
deploiement.

## Structure

```text
services/
  api/
    app.py
    requirements.txt
    Dockerfile
  postgres/
    init/
      01_schema.sql
    Dockerfile
docker-compose.yml
docker-compose.hub.yml
.env.example
```

## Prerequis

- Docker
- Docker Compose
- Un compte GitHub pour le depot du binome
- Un ou deux comptes Docker Hub pour publier les images

## Configuration locale

Copier le template d'environnement, puis remplir le mot de passe si besoin.

```bash
cp .env.example .env
```

Exemple de contenu local:

```env
POSTGRES_USER=admin
POSTGRES_PASSWORD=VotreMotDePasse2026
POSTGRES_DB=inventaire
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
API_PORT=5000
```

Le fichier `.env` ne doit pas etre committe.

## Demarrage depuis le code source

```bash
docker compose up --build -d
docker compose ps
```

L'API est disponible sur:

```text
http://localhost:5000
```

## Endpoints API

```bash
curl http://localhost:5000/health
curl http://localhost:5000/articles
curl http://localhost:5000/articles/1
curl http://localhost:5000/stats
curl http://localhost:5000/version
```

Creer un article:

```bash
curl -X POST http://localhost:5000/articles \
  -H "Content-Type: application/json" \
  -d '{"reference":"TEST-001","nom":"Article binome","quantite":10,"prix_unitaire":15.99,"categorie_id":2}'
```

Modifier un article:

```bash
curl -X PATCH http://localhost:5000/articles/6 \
  -H "Content-Type: application/json" \
  -d '{"quantite":50}'
```

Supprimer logiquement un article:

```bash
curl -X DELETE http://localhost:5000/articles/6
```

## Images Docker Hub

Remplacer les valeurs ci-dessous par les vrais noms Docker Hub.

```text
postgres  : ajc479/inventaire-postgres:1.0   (publie, public)
api v1.0  : ajc479/inventaire-api:1.0        (publie, public)
api v1.1  : ajc479/inventaire-api:1.1        (route /version - Labo 2)
```

Construction et tags:

```bash
docker build -t ETUDIANT1/inventaire-postgres:1.0 ./services/postgres
docker tag ETUDIANT1/inventaire-postgres:1.0 ETUDIANT1/inventaire-postgres:latest

docker build -t ETUDIANT2/inventaire-api:1.0 ./services/api
docker tag ETUDIANT2/inventaire-api:1.0 ETUDIANT2/inventaire-api:latest
```

Publication:

```bash
docker login
docker push ETUDIANT1/inventaire-postgres:1.0
docker push ETUDIANT1/inventaire-postgres:latest
docker push ETUDIANT2/inventaire-api:1.0
docker push ETUDIANT2/inventaire-api:latest
```

## Deploiement depuis Docker Hub

Dans un dossier vide sur la machine du coequipier, creer un `.env`, puis copier
`docker-compose.hub.yml` sous le nom `docker-compose.yml`.

Si vous voulez garder le fichier tel quel, vous pouvez aussi fournir les images
avec des variables:

```bash
POSTGRES_IMAGE=ETUDIANT1/inventaire-postgres:1.0 \
API_IMAGE=ETUDIANT2/inventaire-api:1.0 \
docker compose -f docker-compose.hub.yml up -d
```

Sous PowerShell:

```powershell
$env:POSTGRES_IMAGE="ETUDIANT1/inventaire-postgres:1.0"
$env:API_IMAGE="ETUDIANT2/inventaire-api:1.0"
docker compose -f docker-compose.hub.yml up -d
```

## Verification des donnees

Le script SQL cree automatiquement:

- 4 categories
- 5 articles initiaux

Verifier avec:

```bash
docker compose exec postgres psql -U admin -d inventaire -c "\dt"
docker compose exec postgres psql -U admin -d inventaire -c "SELECT COUNT(*) FROM articles;"
```

## Persistance

Les donnees sont conservees dans le volume Docker `pgdata`.

```bash
docker compose down
docker compose up -d
curl http://localhost:5000/articles
```

Pour nettoyer completement:

```bash
docker compose down -v
```

---

# Laboratoire 2 - Deploiement distant

Marche a suivre detaillee et liste des 14 preuves:
[docs/labo2-deploiement-distant.md](docs/labo2-deploiement-distant.md)

Equipe : Alain Joseph Camara (postgres) et Djooliany Dor (api).

## URLs publiques

```text
API (Render) : https://inventaire-api-1-1.onrender.com
Health       : https://inventaire-api-1-1.onrender.com/health
Articles     : https://inventaire-api-1-1.onrender.com/articles
Version      : https://inventaire-api-1-1.onrender.com/version
Stats        : https://inventaire-api-1-1.onrender.com/stats
Codespace    : https://<nom-codespace>-5000.app.github.dev  (temporaire, change
               a chaque session ; port 5000 a passer en Public dans l'onglet PORTS)
```

Base de donnees Render : `inventaire-db`, base `inventaire_mixx`, region Oregon,
plan Free (expire le 27 aout 2026).

## Reproduire le deploiement Codespaces (Partie A)

1. Ouvrir un Codespace sur ce depot (Code > Codespaces > Create codespace on main)
2. `cp .env.example .env` puis remplir `POSTGRES_PASSWORD`
3. `docker compose -f compose-hub.yml up -d`
4. Onglet PORTS: port 5000 > Visibility > **Public**
5. Tester: `https://xxxx-5000.app.github.dev/health`

## Reproduire le deploiement Render (Partie B)

1. Creer une base PostgreSQL sur render.com (plan Free), region Oregon.
   Noter le nom reel de la base : Render ajoute un suffixe (`inventaire_mixx`).
2. Injecter `services/postgres/init/01_schema.sql`. Le shell psql dans le
   navigateur n'existe plus sur le plan Free : passer par un conteneur, avec
   l'**External Host** (le nom long) et `PGSSLMODE=require`.

```powershell
$env:PGPASSWORD="<mot de passe Render>"
$env:PGHOST="dpg-xxxxx.oregon-postgres.render.com"
Get-Content services/postgres/init/01_schema.sql | docker run --rm -i `
  -e PGPASSWORD=$env:PGPASSWORD -e PGSSLMODE=require postgres:16 `
  psql -h $env:PGHOST -U admin -d inventaire_mixx
```

3. Creer un Web Service > Existing Image : `docker.io/ajc479/inventaire-api:1.1`,
   meme region que la base, plan Free, Health Check Path `/health`.
4. Variables d'environnement (voir `.env.render.example`). Ne pas definir
   `API_PORT` : Render injecte `PORT`, que `app.py` prend en priorite.
5. Tester: `https://inventaire-api-1-1.onrender.com/health`

Raccourci: New + > Blueprint > ce depot. `render.yaml` cree la base et le
service et branche les variables automatiquement.

## Tester une API distante

```powershell
.\scripts\test-api-distante.ps1 -BaseUrl https://VOTRE-URL -Reference RENDER-001
```

```bash
./scripts/test-api-distante.sh https://VOTRE-URL RENDER-001
```

Les deux scripts enchainent health, GET, POST 201, GET de verification, stats
et version, et ecrivent le journal dans `docs/preuves/`.

## Mettre a jour l'API

```powershell
.\scripts\publier-v1.1.ps1 -Tag 1.2
# puis Render > Web Service > Settings > Image URL -> ajc479/inventaire-api:1.2
```

