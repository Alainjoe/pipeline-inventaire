# Guide Etudiant 2 — service API

Ce fichier liste **tout** ce que l'Etudiant 2 (responsable du service `api`)
doit faire. L'Etudiant 1 (postgres) a deja termine sa partie.

## Etat actuel (fait par Etudiant 1)

- Depot GitHub public : https://github.com/Alainjoe/pipeline-inventaire
- Image postgres publiee et **publique** : `ajc479/inventaire-postgres:1.0` (+ `:latest`)
- Code des deux services (`services/api`, `services/postgres`) deja dans le repo
- Pipeline local valide : build, compose up, CRUD, persistance

## Ce qu'il te reste (Etudiant 2)

Remplace partout `TONCOMPTE` par ton vrai nom d'utilisateur Docker Hub.

---

### Etape 1 — Cloner le depot

```powershell
git clone https://github.com/Alainjoe/pipeline-inventaire.git
cd pipeline-inventaire
```

### Etape 2 — Creer le fichier .env local

Le `.env` n'est pas dans le depot (il contient le mot de passe). Recree-le :

```powershell
Copy-Item .env.example .env
```

Puis edite `.env` et mets le meme mot de passe que l'equipe :

```env
POSTGRES_USER=admin
POSTGRES_PASSWORD=VotreMotDePasse2026
POSTGRES_DB=inventaire
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
API_PORT=5000
```

### Etape 3 — Faire un commit (Preuve #7)

Le labo exige au moins un commit de chaque etudiant dans l'historique GitHub.
Fais une petite modif (ex: ajoute ton nom dans le README) puis :

```powershell
git add README.md
git commit -m "docs: Etudiant 2 - service api"
git push
```

> Avant le premier push, connecte-toi : `gh auth login` (ou identifiants Git).

### Etape 4 — Construire et tagger l'image api (Preuve #8)

```powershell
docker build -t TONCOMPTE/inventaire-api:1.0 ./services/api
docker tag TONCOMPTE/inventaire-api:1.0 TONCOMPTE/inventaire-api:latest
docker images | Select-String inventaire-api
```

> Capture `docker images` montrant `:1.0` et `:latest`.

### Etape 5 — Publier sur Docker Hub (Preuves #4 image, #9)

```powershell
docker login
docker push TONCOMPTE/inventaire-api:1.0
docker push TONCOMPTE/inventaire-api:latest
```

Puis sur https://hub.docker.com : ouvre le repo `inventaire-api` et verifie
qu'il est **Public** (sinon Settings > Make public). Capture la page des tags.

> Astuce : dans Account Settings > Default privacy, mets **Public** avant de
> pousser, le repo sera public directement.

### Etape 6 — Validation croisee (Preuves #10, #11, #12)

Test sur une machine vierge / dossier vide, en n'utilisant QUE les images
Docker Hub (pas de code source).

```powershell
mkdir test-depuis-hub
cd test-depuis-hub
```

Cree un `.env` dans ce dossier (memes valeurs qu'a l'etape 2).

Cree un `docker-compose.yml` avec les **images** (pas de build) :

```yaml
services:
  postgres:
    image: ajc479/inventaire-postgres:1.0
    env_file: .env
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks: [app_net]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    image: TONCOMPTE/inventaire-api:1.0
    env_file: .env
    ports:
      - "5000:5000"
    networks: [app_net]
    depends_on:
      postgres:
        condition: service_healthy

networks:
  app_net:
    driver: bridge

volumes:
  pgdata:
```

Lance (Docker telecharge les images depuis le Hub) :

```powershell
docker compose up -d      # Preuve #10 : capture le pull des 2 images
docker compose ps         # Preuve #11 : 2 services healthy
curl.exe http://localhost:5000/health
curl.exe http://localhost:5000/articles
curl.exe http://localhost:5000/stats
```

CRUD distant (Preuve #12) :

```powershell
Invoke-RestMethod -Uri http://localhost:5000/articles -Method Post -ContentType "application/json" -Body '{"reference":"HUB-001","nom":"Test depuis Docker Hub","quantite":5,"prix_unitaire":9.99}'
curl.exe http://localhost:5000/articles     # HUB-001 doit apparaitre
```

---

## Rappels importants

- **PowerShell** : utilise `curl.exe` (pas `curl`) et `Invoke-RestMethod` pour
  le POST/PATCH/DELETE (PowerShell 5.1 casse le JSON passe a curl.exe).
- Toujours faire `cd` dans le bon dossier avant `docker compose`.
- `docker compose down` garde le volume ; `docker compose down -v` efface tout.
- Ton compte Docker Hub reel peut differer du nom affiche : verifie-le dans
  Account (menu haut-droit) — c'est lui le namespace de push.

## Preuves a la charge d'Etudiant 2

| # | Preuve |
|---|--------|
| 7 | Ton commit dans l'historique GitHub |
| 8 | `docker images` image api `:1.0` + `:latest` |
| 9 | Page Docker Hub `inventaire-api` (tags visibles) |
| 10 | `docker compose up` depuis dossier vide (pull des 2 images) |
| 11 | `docker compose ps` distant + curl health/articles/stats |
| 12 | POST `HUB-001` + GET confirmant sa presence |
