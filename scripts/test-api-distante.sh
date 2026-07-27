#!/usr/bin/env bash
# test-api-distante.sh — Labo 2 : valide une API deployee a distance (Linux/Codespace).
#
# Usage :
#   ./scripts/test-api-distante.sh https://xxxx-5000.app.github.dev CLOUD-001
#   ./scripts/test-api-distante.sh https://inventaire-api-xxxx.onrender.com RENDER-001
set -u

BASE_URL="${1:-}"
REFERENCE="${2:-CLOUD-001}"
SORTIE_DIR="${3:-docs/preuves}"

if [ -z "$BASE_URL" ]; then
  echo "Usage : $0 <URL_PUBLIQUE> [REFERENCE]" >&2
  exit 2
fi

BASE_URL="${BASE_URL%/}"
mkdir -p "$SORTIE_DIR"
LOG="$SORTIE_DIR/tests-$REFERENCE-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee -a "$LOG") 2>&1

echo "Cible   : $BASE_URL"
echo "Date    : $(date '+%Y-%m-%d %H:%M:%S')"
echo "Note    : sur Render (plan gratuit) la 1re requete peut prendre 30-60 s (cold start)."

echo
echo "=== 1. GET /health ==="
curl -sS --max-time 120 "$BASE_URL/health"; echo

echo
echo "=== 2. GET /articles (liste initiale) ==="
curl -sS --max-time 120 "$BASE_URL/articles"; echo

echo
echo "=== 3. POST /articles ($REFERENCE) ==="
curl -sS --max-time 120 -w '\nHTTP %{http_code}\n' \
     -X POST "$BASE_URL/articles" \
     -H 'Content-Type: application/json' \
     -d "{\"reference\":\"$REFERENCE\",\"nom\":\"Article deploiement distant\",\"quantite\":5,\"prix_unitaire\":9.99}"

echo
echo "=== 4. GET /articles (verification) ==="
LISTE=$(curl -sS --max-time 120 "$BASE_URL/articles")
echo "$LISTE"
echo
case "$LISTE" in
  *"$REFERENCE"*) echo "OK : $REFERENCE present." ;;
  *) echo "ECHEC : $REFERENCE absent."; exit 1 ;;
esac

echo
echo "=== 5. GET /stats ==="
curl -sS --max-time 120 "$BASE_URL/stats"; echo

echo
echo "=== 6. GET /version ==="
curl -sS --max-time 120 "$BASE_URL/version"; echo
echo "(404 ici = image 1.0 encore deployee, normal avant l'etape 10)"

echo
echo "TERMINE. Journal complet : $LOG"
