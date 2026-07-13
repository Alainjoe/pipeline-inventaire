import os
from datetime import date, datetime
from decimal import Decimal

import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request


app = Flask(__name__)


def get_conn():
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "postgres"),
        port=int(os.getenv("POSTGRES_PORT", 5432)),
        dbname=os.getenv("POSTGRES_DB", "inventaire"),
        user=os.getenv("POSTGRES_USER", "admin"),
        password=os.getenv("POSTGRES_PASSWORD", ""),
        cursor_factory=psycopg2.extras.RealDictCursor,
    )


def json_ready(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def clean_row(row):
    return {key: json_ready(value) for key, value in dict(row).items()}


@app.route("/health")
def health():
    try:
        conn = get_conn()
        conn.close()
        return jsonify({"statut": "ok", "db": "connectee"})
    except Exception as exc:
        return jsonify({"statut": "erreur", "detail": str(exc)}), 503


@app.route("/articles")
def liste_articles():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT a.id, a.reference, a.nom, a.description, a.quantite,
               a.prix_unitaire, c.nom AS categorie, a.cree_le
        FROM articles a
        LEFT JOIN categories c ON a.categorie_id = c.id
        WHERE a.actif = TRUE
        ORDER BY a.nom
        """
    )
    articles = [clean_row(row) for row in cur.fetchall()]
    conn.close()
    return jsonify({"articles": articles, "total": len(articles)})


@app.route("/articles/<int:article_id>")
def detail_article(article_id):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM articles WHERE id = %s AND actif = TRUE",
        (article_id,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return jsonify({"erreur": "introuvable"}), 404
    return jsonify(clean_row(row))


@app.route("/articles", methods=["POST"])
def creer_article():
    data = request.get_json(silent=True) or {}
    if not data.get("reference") or not data.get("nom"):
        return jsonify({"erreur": "reference et nom requis"}), 400

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute(
            """
            INSERT INTO articles(
                reference, nom, description, quantite, prix_unitaire, categorie_id
            )
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
            """,
            (
                data["reference"],
                data["nom"],
                data.get("description"),
                data.get("quantite", 0),
                data.get("prix_unitaire", 0),
                data.get("categorie_id"),
            ),
        )
        article_id = cur.fetchone()["id"]
        conn.commit()
        conn.close()
        return jsonify({"id": article_id, "message": "cree"}), 201
    except psycopg2.IntegrityError as exc:
        conn.rollback()
        conn.close()
        return jsonify({"erreur": "donnees invalides", "detail": str(exc).splitlines()[0]}), 400


@app.route("/articles/<int:article_id>", methods=["PATCH"])
def modifier_article(article_id):
    data = request.get_json(silent=True) or {}
    champs_valides = {
        "reference",
        "nom",
        "description",
        "quantite",
        "prix_unitaire",
        "categorie_id",
        "actif",
    }
    champs = {key: value for key, value in data.items() if key in champs_valides}
    if not champs:
        return jsonify({"erreur": "aucun champ valide"}), 400

    sets = ", ".join(f"{key} = %s" for key in champs)
    valeurs = list(champs.values()) + [article_id]

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute(
            f"UPDATE articles SET {sets} WHERE id = %s RETURNING id",
            valeurs,
        )
        row = cur.fetchone()
        conn.commit()
        conn.close()
    except psycopg2.IntegrityError as exc:
        conn.rollback()
        conn.close()
        return jsonify({"erreur": "donnees invalides", "detail": str(exc).splitlines()[0]}), 400

    if not row:
        return jsonify({"erreur": "introuvable"}), 404
    return jsonify({"id": article_id, "message": "mis a jour"})


@app.route("/articles/<int:article_id>", methods=["DELETE"])
def supprimer_article(article_id):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "UPDATE articles SET actif = FALSE WHERE id = %s AND actif = TRUE RETURNING id",
        (article_id,),
    )
    row = cur.fetchone()
    conn.commit()
    conn.close()
    if not row:
        return jsonify({"erreur": "introuvable"}), 404
    return jsonify({"id": article_id, "message": "supprime"})


@app.route("/stats")
def statistiques():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT COUNT(*) AS nb,
               COALESCE(SUM(quantite), 0) AS stock,
               COALESCE(ROUND(SUM(quantite * prix_unitaire)::numeric, 2), 0) AS valeur
        FROM articles
        WHERE actif = TRUE
        """
    )
    stats = clean_row(cur.fetchone())
    conn.close()
    return jsonify(stats)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("API_PORT", 5000)))

