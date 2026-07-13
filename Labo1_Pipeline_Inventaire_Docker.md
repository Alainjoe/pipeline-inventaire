# Laboratoire 1 — Pipeline de déploiement conteneurisé

**API Flask + PostgreSQL — GitHub — Docker Hub — Validation sur machine
distante**

**Cours :** 420-6A1-UC — Automatisation et conteneurs  
**Remise :** Selon les directives du professeur  
**Étudiant 1 :**
\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_  
**Étudiant 2 :**
\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_  
**Groupe :** \_\_\_\_\_\_\_\_\_\_\_\_  
**Dépôt GitHub :**
\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

**Objectif général :** En binôme, développer deux services Docker (API
Flask + PostgreSQL), les versionner sur GitHub, construire leurs images,
les publier sur Docker Hub, puis valider que le déploiement fonctionne
depuis la machine du coéquipier en ne s’appuyant que sur les images
publiées.

## Contexte et progression

Les TP précédents vous ont appris à écrire un Dockerfile (TP3) et à
orchestrer plusieurs conteneurs Flask (TP4). Ce laboratoire ajoute les
dimensions qui manquaient pour un déploiement réel :

- **Base de données persistante :** PostgreSQL avec schéma SQL
  auto-initialisé.
- **Travail en binôme :** chaque coéquipier est responsable d’un service
  ; GitHub sert de point de coordination.
- **Registre d’images :** les images sont publiées sur Docker Hub et
  testées depuis l’autre machine.
- **Validation croisée :** le test final se fait sur une machine qui n’a
  jamais vu le code source.

**Répartition des services :**

| Service    | Rôle                                                       | Responsable |
|------------|------------------------------------------------------------|-------------|
| `postgres` | Base de données PostgreSQL 15 — stocke l’inventaire        | Étudiant 1  |
| `api`      | API Flask CRUD — lit/écrit dans PostgreSQL, répond en JSON | Étudiant 2  |

> **Note architecture :** Les deux services communiquent via un réseau
> Docker interne. Seule l’API est accessible depuis l’extérieur (port
> 5000). PostgreSQL n’est jamais exposé directement.

# PARTIE A — Développement et versionnement GitHub

## Étape 1 — Initialiser le dépôt GitHub (binôme)

*Objectif : créer un dépôt GitHub partagé et l’arborescence du projet
avant d’écrire le moindre code.*

### 1.1 Créer le dépôt GitHub

Un seul dépôt pour les deux services. L’étudiant 1 le crée et ajoute
l’étudiant 2 comme collaborateur (Settings \> Collaborators \> Add
people).

- Nom suggéré : `inventaire-labo2`
- Visibilité : **Public** (facilitera le pull depuis Docker Hub)
- Cocher : **Add a README file**

### 1.2 Cloner et créer l’arborescence

```
git clone https://github.com/VOTRE_USER/inventaire-labo2.git
cd inventaire-labo2

mkdir -p services/api services/postgres/init

# Vérifier
find . -not -path './.git/*' -type d
```

Structure attendue :

```
inventaire-labo2/
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
  .env.example
  .gitignore
  README.md
```

### 1.3 Créer .gitignore et .env.example

Créer `.gitignore` :

```
.env
__pycache__/
*.pyc
.DS_Store
```

Créer `.env.example` (template sans valeurs sensibles) :

```
POSTGRES_USER=admin
POSTGRES_PASSWORD=
POSTGRES_DB=inventaire
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
API_PORT=5000
```

> **ATTENTION :** Ne jamais committer le fichier `.env`. Il contient des
> mots de passe. Le `.gitignore` l’exclut automatiquement. Partagez le
> mot de passe entre coéquipiers par message privé.

### 1.4 Créer le fichier .env local

```
cp .env.example .env
# Éditer .env et remplir POSTGRES_PASSWORD=VotreMotDePasse2026
```

> **Preuve \#1 :** Capture d’écran du dépôt GitHub montrant la structure
> du projet après le premier push (README, .gitignore, .env.example,
> dossiers services/).

## Étape 2 — Service PostgreSQL (Étudiant 1)

*Objectif : créer le service de base de données avec son schéma SQL
initial et son Dockerfile.*

### 2.1 Script d’initialisation SQL

Créer le fichier `services/postgres/init/01_schema.sql` :

```
-- 01_schema.sql
-- Exécuté automatiquement par postgres:15 au premier démarrage
-- si et seulement si le volume de données est vide.

CREATE TABLE IF NOT EXISTS categories (
    id   SERIAL PRIMARY KEY,
    nom  VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS articles (
    id            SERIAL PRIMARY KEY,
    reference     VARCHAR(50)    NOT NULL UNIQUE,
    nom           VARCHAR(200)   NOT NULL,
    description   TEXT,
    quantite      INTEGER        NOT NULL DEFAULT 0 CHECK (quantite >= 0),
    prix_unitaire NUMERIC(10,2)  NOT NULL CHECK (prix_unitaire >= 0),
    categorie_id  INTEGER        REFERENCES categories(id) ON DELETE SET NULL,
    actif         BOOLEAN        DEFAULT TRUE,
    cree_le       TIMESTAMP      DEFAULT NOW()
);

-- Données initiales
INSERT INTO categories (nom) VALUES
    ('Electronique'), ('Peripherique'), ('Stockage'), ('Reseau');

INSERT INTO articles (reference, nom, quantite, prix_unitaire, categorie_id)
VALUES
    ('CPU-001', 'Processeur AMD Ryzen 7',  15, 349.99, 1),
    ('RAM-001', 'Barrette RAM 16GB DDR5',  42,  89.99, 1),
    ('SSD-001', 'SSD NVMe 1TB',            28, 129.99, 3),
    ('KBD-001', 'Clavier mecanique TKL',   19,  79.99, 2),
    ('NET-001', 'Switch 24 ports Gigabit',  8, 199.99, 4);
```

> **Concept clé — Init scripts :** L’image officielle `postgres:15`
> exécute automatiquement tous les fichiers `*.sql` placés dans
> `/docker-entrypoint-initdb.d/` lors du premier démarrage, à condition
> que le volume soit vide. C’est le mécanisme standard pour créer un
> schéma sans étape manuelle.

### 2.2 Dockerfile PostgreSQL

Créer `services/postgres/Dockerfile` :

```
FROM postgres:15

# Copier le script SQL dans le dossier d'initialisation
COPY init/01_schema.sql /docker-entrypoint-initdb.d/

HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}
```

### 2.3 Tester PostgreSQL seul

Avant de continuer, valider que le schéma s’initialise correctement :

```
# Démarrer PostgreSQL seul pour tester
docker build -t test-postgres ./services/postgres

docker run -d --name test-pg \
    -e POSTGRES_USER=admin \
    -e POSTGRES_PASSWORD=TestPass123 \
    -e POSTGRES_DB=inventaire \
    test-postgres

# Attendre 5 secondes, puis se connecter
docker exec -it test-pg psql -U admin -d inventaire

-- Dans psql :
\dt                             -- doit lister articles et categories
SELECT COUNT(*) FROM articles;  -- doit retourner 5
\q

# Nettoyer
docker stop test-pg && docker rm test-pg
docker rmi test-postgres
```

> **Preuve \#2 :** Capture d’écran du shell psql montrant `\dt` (deux
> tables) et `SELECT COUNT(*) FROM articles` retournant 5.

### 2.4 Commiter le service postgres

```
git add services/postgres/
git commit -m "feat: service postgres avec schema SQL initial"
git push
```

> **Preuve \#3 :** Capture d’écran du terminal ou de GitHub montrant le
> push réussi du service postgres.

## Étape 3 — Service API Flask (Étudiant 2)

*Objectif : développer l’API Flask avec les opérations CRUD, connectée à
PostgreSQL via des variables d’environnement.*

### 3.1 requirements.txt

Créer `services/api/requirements.txt` :

```
flask==3.0.0
psycopg2-binary==2.9.9
```

### 3.2 app.py — API Flask CRUD

Créer `services/api/app.py` :

```
import os, psycopg2, psycopg2.extras
from flask import Flask, jsonify, request

app = Flask(__name__)

def get_conn():
    return psycopg2.connect(
        host     = os.getenv('POSTGRES_HOST', 'postgres'),
        port     = int(os.getenv('POSTGRES_PORT', 5432)),
        dbname   = os.getenv('POSTGRES_DB',   'inventaire'),
        user     = os.getenv('POSTGRES_USER',  'admin'),
        password = os.getenv('POSTGRES_PASSWORD', ''),
        cursor_factory=psycopg2.extras.RealDictCursor
    )

# GET /health — santé du service
@app.route('/health')
def health():
    try:
        conn = get_conn(); conn.close()
        return jsonify({'statut': 'ok', 'db': 'connectee'})
    except Exception as e:
        return jsonify({'statut': 'erreur', 'detail': str(e)}), 503

# GET /articles — liste tous les articles actifs
@app.route('/articles')
def liste():
    conn = get_conn(); cur = conn.cursor()
    cur.execute(
        'SELECT a.id, a.reference, a.nom, a.quantite, a.prix_unitaire,'
        ' c.nom AS categorie FROM articles a'
        ' LEFT JOIN categories c ON a.categorie_id = c.id'
        ' WHERE a.actif = TRUE ORDER BY a.nom'
    )
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return jsonify({'articles': rows, 'total': len(rows)})

# GET /articles/<id> — détail d'un article
@app.route('/articles/<int:aid>')
def detail(aid):
    conn = get_conn(); cur = conn.cursor()
    cur.execute('SELECT * FROM articles WHERE id=%s AND actif=TRUE', (aid,))
    row = cur.fetchone(); conn.close()
    if not row:
        return jsonify({'erreur': 'introuvable'}), 404
    return jsonify(dict(row))

# POST /articles — créer un article
@app.route('/articles', methods=['POST'])
def creer():
    d = request.get_json()
    if not d or not d.get('reference') or not d.get('nom'):
        return jsonify({'erreur': 'reference et nom requis'}), 400
    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute(
            'INSERT INTO articles(reference, nom, description, quantite,'
            ' prix_unitaire, categorie_id) VALUES(%s,%s,%s,%s,%s,%s) RETURNING id',
            (d['reference'], d['nom'], d.get('description'),
             d.get('quantite', 0), d.get('prix_unitaire', 0), d.get('categorie_id'))
        )
        nid = cur.fetchone()['id']; conn.commit(); conn.close()
        return jsonify({'id': nid, 'message': 'cree'}), 201
    except psycopg2.IntegrityError:
        conn.rollback(); conn.close()
        return jsonify({'erreur': 'reference en double'}), 409

# PATCH /articles/<id> — modifier un article
@app.route('/articles/<int:aid>', methods=['PATCH'])
def modifier(aid):
    d = request.get_json()
    champs = {k: v for k, v in d.items()
              if k in ('nom', 'description', 'quantite', 'prix_unitaire', 'actif')}
    if not champs:
        return jsonify({'erreur': 'aucun champ valide'}), 400
    sets = ', '.join(f'{k}=%s' for k in champs)
    conn = get_conn(); cur = conn.cursor()
    cur.execute(f'UPDATE articles SET {sets} WHERE id=%s RETURNING id',
                list(champs.values()) + [aid])
    ok = cur.fetchone(); conn.commit(); conn.close()
    if not ok:
        return jsonify({'erreur': 'introuvable'}), 404
    return jsonify({'message': 'mis a jour', 'id': aid})

# DELETE /articles/<id> — suppression logique
@app.route('/articles/<int:aid>', methods=['DELETE'])
def supprimer(aid):
    conn = get_conn(); cur = conn.cursor()
    cur.execute('UPDATE articles SET actif=FALSE WHERE id=%s RETURNING id', (aid,))
    ok = cur.fetchone(); conn.commit(); conn.close()
    if not ok:
        return jsonify({'erreur': 'introuvable'}), 404
    return jsonify({'message': 'supprime', 'id': aid})

# GET /stats — statistiques de l'inventaire
@app.route('/stats')
def stats():
    conn = get_conn(); cur = conn.cursor()
    cur.execute(
        'SELECT COUNT(*) nb, SUM(quantite) stock,'
        ' ROUND(SUM(quantite*prix_unitaire)::numeric, 2) valeur'
        ' FROM articles WHERE actif=TRUE'
    )
    return jsonify(dict(cur.fetchone()))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('API_PORT', 5000)))
```

> **Suppression logique :** La route DELETE met `actif=FALSE` au lieu de
> supprimer la ligne. L’article disparaît des listes mais reste dans la
> base pour l’historique. C’est la pratique standard en production.

### 3.3 Dockerfile de l’API

Créer `services/api/Dockerfile` :

```
FROM python:3.11-slim

# libpq-dev est nécessaire pour psycopg2 (driver client PostgreSQL)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

EXPOSE 5000

HEALTHCHECK --interval=15s --timeout=5s --retries=4 \
    CMD python -c \
    "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
```

### 3.4 Commiter le service api

```
git add services/api/
git commit -m "feat: service api Flask CRUD inventaire"
git push
```

> **Preuve \#4 :** Capture d’écran du terminal ou de GitHub montrant le
> push réussi du service api.

## Étape 4 — Docker Compose et tests locaux (binôme)

*Objectif : écrire le fichier Compose, démarrer les deux services et
valider tous les endpoints.*

### 4.1 Créer docker-compose.yml

Créer `docker-compose.yml` à la racine du projet :

```
services:

  postgres:
    build: ./services/postgres
    env_file: .env
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - app_net
    healthcheck:
      test: ["CMD-SHELL",
             "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build: ./services/api
    env_file: .env
    ports:
      - "${API_PORT:-5000}:5000"
    networks:
      - app_net
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c",
             "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"]
      interval: 15s
      timeout: 5s
      retries: 4

networks:
  app_net:
    driver: bridge

volumes:
  pgdata:
```

> **ATTENTION :** Le double `$$` (ex: `$$POSTGRES_USER`) est obligatoire
> dans les chaînes `test:`. Un seul `$` serait interprété par Compose
> comme une variable vide au lieu d’être transmis au shell du conteneur.

### 4.2 Démarrer et vérifier

```
# Depuis la racine du projet
docker compose up --build -d

# Vérifier l'état des deux services
docker compose ps

# Résultat attendu :
# NAME                     STATUS
# inventaire-postgres-1    Up X seconds (healthy)
# inventaire-api-1         Up X seconds (healthy)
```

> **Preuve \#5 :** Capture d’écran de `docker compose ps` montrant les
> deux services en état `Up (healthy)`.

### 4.3 Tester tous les endpoints

**GET /health**

```
curl http://localhost:5000/health
# Attendu : {"db": "connectee", "statut": "ok"}
```

**GET /articles (liste initiale)**

```
curl http://localhost:5000/articles
# Attendu : liste des 5 articles initiaux
```

**POST /articles (créer)**

```
curl -X POST http://localhost:5000/articles \
     -H 'Content-Type: application/json' \
     -d '{"reference":"TEST-001","nom":"Article binome",
          "quantite":10,"prix_unitaire":15.99,"categorie_id":2}'
# Attendu : HTTP 201 — {"id": 6, "message": "cree"}
```

**PATCH /articles/6 (modifier)**

```
curl -X PATCH http://localhost:5000/articles/6 \
     -H 'Content-Type: application/json' \
     -d '{"quantite": 50}'
# Attendu : {"id": 6, "message": "mis a jour"}
```

**DELETE /articles/6 (suppression logique)**

```
curl -X DELETE http://localhost:5000/articles/6
# Attendu : {"id": 6, "message": "supprime"}
curl http://localhost:5000/articles
# L'article TEST-001 ne doit plus apparaître
```

**GET /stats**

```
curl http://localhost:5000/stats
# Attendu : {"nb": 5, "stock": ..., "valeur": ...}
```

> **Preuve \#6 :** Captures d’écran des six tests curl : health, GET
> liste, POST 201, PATCH, DELETE, stats.

### 4.4 Commiter docker-compose.yml et README

Créer un `README.md` minimal :

```
# Laboratoire 2 — Inventaire Docker

## Prérequis
- Docker et Docker Compose installés
- Copier .env.example en .env et remplir POSTGRES_PASSWORD

## Déploiement depuis le code source
git clone https://github.com/VOTRE_USER/inventaire-labo2.git
cd inventaire-labo2
cp .env.example .env   # remplir POSTGRES_PASSWORD
docker compose up --build -d

## Images Docker Hub
- postgres : ETUDIANT1/inventaire-postgres:1.0
- api      : ETUDIANT2/inventaire-api:1.0

## Déploiement depuis Docker Hub (sans code source)
# Voir Partie B du laboratoire

## Tester
curl http://localhost:5000/health
curl http://localhost:5000/articles
curl http://localhost:5000/stats
git add docker-compose.yml README.md
git commit -m "feat: docker-compose, README"
git push
```

> **Preuve \#7 :** Capture d’écran du dépôt GitHub montrant les commits
> des deux étudiants dans l’historique (au moins un commit par
> étudiant).

# PARTIE B — Construction des images et publication sur Docker Hub

## Étape 5 — Construire et tagger les images

*Objectif : produire deux images Docker versionnées, une par service,
prêtes à être publiées.*

### 5.1 Convention de nommage obligatoire

Format : `USERNAME_DOCKERHUB/NOM_IMAGE:VERSION`

Chaque étudiant construit l’image de **son** service avec **son** nom
d’utilisateur Docker Hub.

### 5.2 Étudiant 1 — image postgres

```
# Depuis la racine du projet
docker build -t ETUDIANT1/inventaire-postgres:1.0 ./services/postgres

# Ajouter le tag latest
docker tag ETUDIANT1/inventaire-postgres:1.0 \
           ETUDIANT1/inventaire-postgres:latest

# Vérifier
docker images | grep inventaire-postgres
```

### 5.3 Étudiant 2 — image api

```
docker build -t ETUDIANT2/inventaire-api:1.0 ./services/api
docker tag ETUDIANT2/inventaire-api:1.0 ETUDIANT2/inventaire-api:latest

docker images | grep inventaire-api
```

> **Preuve \#8 :** Captures d’écran de `docker images` montrant les deux
> images taguées `:1.0` et `:latest` (une capture par étudiant).
>
> **ATTENTION :** Remplacez `ETUDIANT1` et `ETUDIANT2` par vos vrais
> noms d’utilisateurs Docker Hub dans toutes les commandes.

## Étape 6 — Publier les images sur Docker Hub

*Objectif : pousser les deux images sur Docker Hub afin qu’elles soient
accessibles depuis n’importe quelle machine.*

### 6.1 Se connecter à Docker Hub

```
# Chaque étudiant se connecte avec son propre compte
docker login
# Entrer votre nom d'utilisateur et mot de passe Docker Hub
```

### 6.2 Pousser les images

**Étudiant 1 :**

```
docker push ETUDIANT1/inventaire-postgres:1.0
docker push ETUDIANT1/inventaire-postgres:latest
```

**Étudiant 2 :**

```
docker push ETUDIANT2/inventaire-api:1.0
docker push ETUDIANT2/inventaire-api:latest
```

### 6.3 Vérifier sur hub.docker.com

Ouvrir `https://hub.docker.com/u/VOTRE_USERNAME` et confirmer que les
deux repositories sont visibles avec les tags `:1.0` et `:latest`.

> **Preuve \#9 :** Captures d’écran des pages Docker Hub de chaque
> image, montrant les tags `:1.0` et `:latest` disponibles (une capture
> par étudiant).

### 6.4 Mettre à jour le README avec les références des images

```
# Mettre à jour README.md avec les noms exacts des images publiées
git add README.md
git commit -m "docs: ajout references images Docker Hub"
git push
```

# PARTIE C — Validation croisée sur machine distante

## Étape 7 — Déploiement depuis Docker Hub (machine du coéquipier)

*Objectif : prouver que les images publiées sur Docker Hub suffisent à
déployer l’application sur n’importe quelle machine, sans cloner le code
source.*

> **Principe de la validation croisée :** Chaque étudiant effectue ce
> test sur la machine de son coéquipier (ou dans un dossier vide). Si le
> déploiement fonctionne sans le code source, les images Docker Hub sont
> autosuffisantes et le livrable est reproductible.

### 7.1 Préparer la machine de test

```
# Supprimer les images locales si elles existent (simuler machine vierge)
docker rmi ETUDIANT1/inventaire-postgres:1.0 2>/dev/null || true
docker rmi ETUDIANT2/inventaire-api:1.0 2>/dev/null || true

# Vérifier qu'elles ne sont plus en cache
docker images | grep inventaire
# Résultat attendu : aucune ligne
```

### 7.2 Créer un dossier de test vide

```
# Créer un dossier vide — NE PAS cloner le dépôt
mkdir test-depuis-hub
cd test-depuis-hub

# Créer le fichier .env avec les mêmes valeurs que le projet
cat > .env << 'EOF'
POSTGRES_USER=admin
POSTGRES_PASSWORD=VotreMotDePasse2026
POSTGRES_DB=inventaire
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
API_PORT=5000
EOF
```

### 7.3 Créer le docker-compose.yml pour Docker Hub

Ce fichier utilise `image:` au lieu de `build:` — il télécharge les
images depuis Docker Hub :

```
# docker-compose.yml (version Docker Hub — sans build)
services:

  postgres:
    image: ETUDIANT1/inventaire-postgres:1.0
    env_file: .env
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - app_net
    healthcheck:
      test: ["CMD-SHELL",
             "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    image: ETUDIANT2/inventaire-api:1.0
    env_file: .env
    ports:
      - "5000:5000"
    networks:
      - app_net
    depends_on:
      postgres:
        condition: service_healthy

networks:
  app_net:
    driver: bridge

volumes:
  pgdata:
```

### 7.4 Lancer et valider

```
# Lancer — Docker télécharge automatiquement les images
docker compose up -d

# Observer le pull dans le terminal :
# Pulling postgres ... done
# Pulling api     ... done

# Vérifier les services
docker compose ps

# Tester
curl http://localhost:5000/health
curl http://localhost:5000/articles
curl http://localhost:5000/stats
```

> **Preuve \#10 :** Capture d’écran du `docker compose up -d` depuis le
> dossier vide, montrant le pull automatique des deux images depuis
> Docker Hub.
>
> **Preuve \#11 :** Capture d’écran de `docker compose ps` (deux
> services healthy) ET des trois curl (health, articles, stats) — depuis
> la machine du coéquipier.
>
> **ATTENTION :** Si le pull échoue avec “image not found”, vérifiez que
> les images sont en **Public** sur Docker Hub (Repositories \> votre
> image \> Settings \> Make Public).

### 7.5 Test CRUD depuis la machine distante

```
# Créer un article depuis la machine du coéquipier
curl -X POST http://localhost:5000/articles \
     -H 'Content-Type: application/json' \
     -d '{"reference":"HUB-001","nom":"Test depuis Docker Hub",
          "quantite":5,"prix_unitaire":9.99}'
# Attendu : HTTP 201

# Vérifier
curl http://localhost:5000/articles
# HUB-001 doit apparaître dans la liste
```

> **Preuve \#12 :** Capture d’écran du POST réussi (HTTP 201) et du GET
> confirmant la présence de l’article HUB-001 — depuis la machine du
> coéquipier.

## Étape 8 — Persistance et nettoyage

*Objectif : vérifier que les données survivent à un redémarrage, puis
nettoyer proprement.*

### 8.1 Tester la persistance

```
# Arrêter SANS supprimer les volumes
docker compose down

# Relancer
docker compose up -d

# Vérifier que les données sont toujours là
curl http://localhost:5000/articles
# HUB-001 doit toujours être présent
```

> **Preuve \#13 :** Capture d’écran montrant HUB-001 présent après
> `docker compose down + up`. Cela prouve que le volume `pgdata` a
> survécu.

### 8.2 Nettoyage complet

```
# Supprimer conteneurs ET volumes (efface toutes les données)
docker compose down -v

docker volume ls | grep pgdata
# Résultat attendu : aucune ligne
```

> `docker compose down` **vs** `down -v` **:** Sans `-v`, les volumes
> nommés sont conservés. Avec `-v`, tout est supprimé. En production, on
> ne fait jamais `down -v` sans sauvegarde préalable.

# Récapitulatif des preuves requises

| \#  | Étape               | Description                                                    |
|-----|---------------------|----------------------------------------------------------------|
| 1   | Dépôt GitHub        | Structure initiale visible — les deux étudiants collaborateurs |
| 2   | Schema SQL          | psql : `\dt` + `SELECT COUNT(*) FROM articles` = 5             |
| 3   | Commit postgres     | Push du service postgres sur GitHub                            |
| 4   | Commit api          | Push du service api sur GitHub                                 |
| 5   | Compose ps local    | Deux services `Up (healthy)`                                   |
| 6   | Tests CRUD locaux   | 6 appels curl : health, GET, POST 201, PATCH, DELETE, stats    |
| 7   | Commits des deux    | Historique GitHub avec commits des deux étudiants              |
| 8   | Images taguées      | `docker images` — deux images `:1.0` et `:latest`              |
| 9   | Pages Docker Hub    | Pages web avec les tags `:1.0` et `:latest` (un par étudiant)  |
| 10  | Pull depuis le vide | `docker compose up -d` depuis dossier vide — pull visible      |
| 11  | Validation distante | `compose ps` + 3 curl — depuis la machine du coéquipier        |
| 12  | CRUD distant        | POST HUB-001 + GET confirmant la présence                      |
| 13  | Persistance         | HUB-001 présent après `down + up`                              |

# Critères d’évaluation

| Pondération | Critère              | Description                                                                   |
|-------------|----------------------|-------------------------------------------------------------------------------|
| 20%         | API fonctionnelle    | Les 6 routes (health, GET, POST, PATCH, DELETE, stats) fonctionnent en local  |
| 15%         | Schema PostgreSQL    | Script SQL exécuté automatiquement, 5 articles présents au démarrage          |
| 15%         | Versionnement GitHub | Dépôt avec commits des deux étudiants, .gitignore, .env.example, README       |
| 15%         | Images Docker Hub    | Deux images publiées avec tags `:1.0` et `:latest`                            |
| 20%         | Validation distante  | Déploiement réussi depuis machine vierge avec images Docker Hub uniquement    |
| 10%         | Persistance          | Données présentes après `docker compose down + up`                            |
| 5%          | Qualité README       | Procédure reproductible : clone ou Docker Hub, .env, compose up, URLs de test |

# Aide-mémoire — Commandes essentielles

| Commande                                                   | Description                                     |
|------------------------------------------------------------|-------------------------------------------------|
| `docker compose up --build -d`                             | Construire et démarrer depuis le code source    |
| `docker compose up -d`                                     | Démarrer avec images existantes (ou Docker Hub) |
| `docker compose ps`                                        | Lister services et état de santé                |
| `docker compose logs -f api`                               | Logs en temps réel du service api               |
| `docker compose exec postgres psql -U admin -d inventaire` | Shell psql                                      |
| `docker compose down`                                      | Arrêter — volumes conservés                     |
| `docker compose down -v`                                   | Arrêter — volumes supprimés                     |
| `docker build -t USER/image:1.0 ./services/X`              | Construire et tagger une image                  |
| `docker tag image:1.0 image:latest`                        | Ajouter le tag latest                           |
| `docker login`                                             | S’authentifier sur Docker Hub                   |
| `docker push USER/image:1.0`                               | Publier sur Docker Hub                          |
| `docker pull USER/image:1.0`                               | Télécharger depuis Docker Hub                   |
| `docker rmi USER/image:1.0`                                | Supprimer une image locale                      |
| `docker images \| grep inventaire`                         | Lister les images filtrées                      |
| `docker volume ls`                                         | Lister tous les volumes Docker                  |

*Hamza Errami — Été 2026*
