# Validation locale

Date de validation: 2026-07-13

## Fichiers

- Compilation Python: `python -m py_compile services/api/app.py` OK
- Configuration Compose: `docker compose config` OK

## Docker Compose

`docker compose ps`:

```text
nouveaudossier4-api-1        Up (healthy)   0.0.0.0:5000->5000/tcp
nouveaudossier4-postgres-1   Up (healthy)   5432/tcp
```

## Tests API

`GET /health`:

```json
{"db":"connectee","statut":"ok"}
```

`GET /articles`:

```json
{"total":5}
```

`GET /stats`:

```json
{"nb":5,"stock":112,"valeur":15788.88}
```

Cycle CRUD teste avec la reference `CODEX-231531476`:

```json
{
  "created_id": 6,
  "post_status": 201,
  "patch_status": 200,
  "delete_status": 200
}
```

Apres suppression logique, `GET /articles` retourne encore `total: 5`.

## Tests PostgreSQL

Tables creees:

```text
articles
categories
```

Articles actifs:

```text
SELECT COUNT(*) FROM articles WHERE actif = TRUE;
5
```

