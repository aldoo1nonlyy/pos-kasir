import os
import sqlite3
from flask import Flask, jsonify, request

app = Flask(__name__)

# Konfigurasi Path Database SQLite
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, 'pos_tokobuku.db')

def get_db_connection():
    """Membuka koneksi ke database SQLite pos_tokobuku.db"""
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(f"Database tidak ditemukan di path: {DB_PATH}")
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # Memungkinkan akses kolom via dictionary / key name
    return conn

@app.after_request
def add_cors_headers(response):
    """Menambahkan CORS headers agar dapat diakses dari web/client manapun"""
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    return response

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        "status": "online",
        "service": "POS Toko Buku Backend (Dynamic ABC)",
        "database": DB_PATH,
        "endpoints": {
            "calculate_abc": "GET /calculate-abc",
            "list_books": "GET /books"
        }
    })

@app.route('/calculate-abc', methods=['GET'])
def calculate_abc():
    """
    Endpoint GET /calculate-abc:
    1. Membaca tabel books dan transaction_items
    2. Menghitung total omset (subtotal) tiap buku (hanya transaksi completed)
    3. Mengurutkan buku berdasarkan omset dari terbesar ke terkecil
    4. Menghitung persentase kumulatif omset
    5. Menentukan kelas ABC:
       - 0% - 80%      -> Kelas A
       - 80.01% - 95%  -> Kelas B
       - 95.01% - 100% -> Kelas C
    6. Mengupdate kolom abc_class di tabel books
    7. Mengembalikan response JSON berisi daftar barang yang kelasnya berubah
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1 & 2. Hitung total omset per buku dengan query aggregasi
        # LEFT JOIN memastikan semua buku (termasuk yang belum terjual dengan omset = 0) ikut terhitung
        query = """
            SELECT 
                b.id,
                b.barcode,
                b.title,
                b.category,
                b.price,
                b.stock,
                b.abc_class AS current_class,
                COALESCE(SUM(CASE WHEN t.status = 'completed' THEN ti.subtotal ELSE 0 END), 0) AS total_omset,
                COALESCE(SUM(CASE WHEN t.status = 'completed' THEN ti.qty ELSE 0 END), 0) AS total_qty
            FROM books b
            LEFT JOIN transaction_items ti ON b.id = ti.book_id
            LEFT JOIN transactions t ON ti.transaction_id = t.id
            GROUP BY b.id
            ORDER BY total_omset DESC, b.id ASC
        """
        cursor.execute(query)
        books = cursor.fetchall()

        if not books:
            return jsonify({
                "status": "error",
                "message": "Tabel books kosong atau tidak ditemukan data."
            }), 404

        # Total omset keseluruhan toko buku
        total_revenue_all = sum(book['total_omset'] for book in books)

        cumulative_omset = 0
        updated_books = []
        db_updates = []
        class_summary = {'A': 0, 'B': 0, 'C': 0}

        # 3, 4, 5. Urutkan, hitung kumulatif, dan klasifikasikan
        for book in books:
            omset = book['total_omset']
            old_class = book['current_class']

            if total_revenue_all > 0 and omset > 0:
                cumulative_omset += omset
                cumulative_pct = (cumulative_omset / total_revenue_all) * 100.0

                # Ambang Batas Klasifikasi Pareto:
                # 0 - 80%      : Kelas A
                # 80.01 - 95%  : Kelas B
                # 95.01 - 100% : Kelas C
                if cumulative_pct <= 80.0:
                    new_class = 'A'
                elif cumulative_pct <= 95.0:
                    new_class = 'B'
                else:
                    new_class = 'C'
            else:
                cumulative_pct = 100.0 if total_revenue_all > 0 else 0.0
                new_class = 'C'

            class_summary[new_class] += 1

            # 6. Catat barang yang kelasnya berubah
            if old_class != new_class:
                db_updates.append((new_class, book['id']))
                updated_books.append({
                    "id": book['id'],
                    "barcode": book['barcode'],
                    "title": book['title'],
                    "category": book['category'],
                    "price": book['price'],
                    "stock": book['stock'],
                    "total_omset": omset,
                    "total_qty_sold": book['total_qty'],
                    "cumulative_percentage": round(cumulative_pct, 4),
                    "old_class": old_class,
                    "new_class": new_class
                })

        # Update ke database SQLite
        if db_updates:
            cursor.executemany(
                "UPDATE books SET abc_class = ? WHERE id = ?",
                db_updates
            )
            conn.commit()

        # 7. Return response JSON
        return jsonify({
            "status": "success",
            "message": "Kalkulasi ABC dan pembaruan database berhasil dilakukan.",
            "total_books_analyzed": len(books),
            "total_omset": total_revenue_all,
            "total_items_updated": len(updated_books),
            "class_distribution": class_summary,
            "updated_books": updated_books
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({
            "status": "error",
            "message": f"Terjadi kesalahan saat memproses kalkulasi ABC: {str(e)}"
        }), 500

    finally:
        if conn:
            conn.close()

@app.route('/books', methods=['GET'])
def get_books():
    """Helper endpoint untuk melihat daftar buku dan status kelas ABC saat ini."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, barcode, title, category, price, stock, abc_class, last_opname_date FROM books ORDER BY id ASC")
        rows = cursor.fetchall()
        return jsonify([
            {
                "id": r["id"],
                "barcode": r["barcode"],
                "title": r["title"],
                "category": r["category"],
                "price": r["price"],
                "stock": r["stock"],
                "abc_class": r["abc_class"],
                "last_opname_date": r["last_opname_date"]
            }
            for r in rows
        ]), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"[*] Menjalankan POS Flask Backend pada http://127.0.0.1:{port}...")
    app.run(host='0.0.0.0', port=port, debug=True)
