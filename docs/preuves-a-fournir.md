# Preuves a fournir

Ce fichier sert de liste de verification pour la remise.

Compte Docker Hub Etudiant 1: `ajc479`
Image postgres publiee: `ajc479/inventaire-postgres:1.0` (et `:latest`)

| # | Preuve | Etat |
|---|--------|------|
| 1 | Depot GitHub avec structure initiale | A capturer |
| 2 | `psql`: `\dt` et `SELECT COUNT(*) FROM articles;` = 5 | OK (valide local) |
| 3 | Push du service postgres | A capturer |
| 4 | Push du service api | A capturer (Etudiant 2) |
| 5 | `docker compose ps` avec deux services healthy | OK (valide local) |
| 6 | Tests curl: health, GET, POST, PATCH, DELETE, stats | OK (valide local) |
| 7 | Historique GitHub avec commits des deux etudiants | A capturer |
| 8 | `docker images` avec tags `:1.0` et `:latest` | OK (postgres ajc479) |
| 9 | Pages Docker Hub avec tags visibles | OK (postgres public, api a faire par Etudiant 2) |
| 10 | Pull depuis un dossier vide avec Compose Docker Hub | En attente image api Etudiant 2 |
| 11 | Validation distante: Compose ps + health/articles/stats | En attente image api Etudiant 2 |
| 12 | CRUD distant: POST `HUB-001` + GET de confirmation | En attente image api Etudiant 2 |
| 13 | Persistance: article present apres `down` puis `up` | OK (valide local) |

