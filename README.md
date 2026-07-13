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
postgres : ajc479/inventaire-postgres:1.0   (publie, public)
api      : ETUDIANT2/inventaire-api:1.0      (a publier par Etudiant 2)
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

