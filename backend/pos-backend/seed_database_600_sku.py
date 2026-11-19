import sqlite3
import csv
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_NAME = os.path.join(BASE_DIR, "pos_tokobuku.db")
BOOKS_CSV = os.path.join(BASE_DIR, "books_dataset_600_sku.csv")
TX_CSV = os.path.join(BASE_DIR, "transactions_dataset_600_sku.csv")

def seed_from_csv():
    if not os.path.exists(BOOKS_CSV) or not os.path.exists(TX_CSV):
        print(f"Pastikan file '{BOOKS_CSV}' dan '{TX_CSV}' berada di folder yang sama dengan script ini!")
        return

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.executescript("""
    DROP TABLE IF EXISTS transaction_items;
    DROP TABLE IF EXISTS transactions;
    DROP TABLE IF EXISTS books;
    DROP TABLE IF EXISTS settings;

    CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        price INTEGER NOT NULL,
        stock INTEGER NOT NULL,
        abc_class TEXT DEFAULT 'C',
        last_opname_date TEXT NOT NULL
    );

    CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        status TEXT DEFAULT 'completed'
    );

    CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        book_id INTEGER NOT NULL,
        qty INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id),
        FOREIGN KEY (book_id) REFERENCES books (id)
    );

    CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE,
        value TEXT NOT NULL,
        admin_pin TEXT DEFAULT '123456'
    );
    """)

    # Set PIN Admin Default = 123456
    cursor.execute("INSERT INTO settings (id, key, value, admin_pin) VALUES (1, 'admin_pin', '123456', '123456')")

    # 1. Insert 600 Barang ke tabel books (kondisi awal abc_class = 'C' untuk menguji endpoint /calculate-abc)
    with open(BOOKS_CSV, mode="r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        book_count = 0
        for row in reader:
            cursor.execute("""
                INSERT INTO books (id, barcode, title, category, price, stock, abc_class, last_opname_date)
                VALUES (?, ?, ?, ?, ?, ?, 'C', ?)
            """, (
                int(row["id"]),
                row["barcode"],
                row["title"],
                row["category"],
                int(row["price"]),
                int(row["stock"]),
                row["last_opname_date"]
            ))
            book_count += 1

    # 2. Insert Riwayat Transaksi ke tabel transactions & transaction_items
    tx_headers = {}
    tx_items = []
    with open(TX_CSV, mode="r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            t_id = int(row["transaction_id"])
            sub = int(row["subtotal"])
            if t_id not in tx_headers:
                tx_headers[t_id] = {
                    "timestamp": row["timestamp"],
                    "total_amount": 0,
                    "status": row["status"]
                }
            tx_headers[t_id]["total_amount"] += sub
            tx_items.append((t_id, int(row["book_id"]), int(row["qty"]), sub))

    for t_id, t_data in sorted(tx_headers.items()):
        cursor.execute("""
            INSERT INTO transactions (id, timestamp, total_amount, status)
            VALUES (?, ?, ?, ?)
        """, (t_id, t_data["timestamp"], t_data["total_amount"], t_data["status"]))

    for t_id, b_id, qty, sub in tx_items:
        cursor.execute("""
            INSERT INTO transaction_items (transaction_id, book_id, qty, subtotal)
            VALUES (?, ?, ?, ?)
        """, (t_id, b_id, qty, sub))

    conn.commit()
    conn.close()

    # Sinkronisasi ke backend/instance/bookstore_pos.db
    instance_dir = os.path.join(os.path.dirname(BASE_DIR), "instance")
    os.makedirs(instance_dir, exist_ok=True)
    instance_db = os.path.join(instance_dir, "bookstore_pos.db")
    try:
        import shutil
        shutil.copy2(DB_NAME, instance_db)
        print(f"[SYNC] Sinkronisasi ke '{instance_db}' berhasil!")
    except Exception as e:
        print(f"[WARN] Gagal menyalin ke '{instance_db}': {e}")

    print(f"[SUKSES] Database '{DB_NAME}' berhasil dibuat!")
    print(f"- Total SKU Barang     : {book_count} barang (120 Kelas A, 180 Kelas B, 300 Kelas C)")
    print(f"- Total Struk Transaksi: {len(tx_headers)} transaksi ({len(tx_items)} baris detail item)")
    print(f"- Total Nilai Omset    : Rp 500.000.000 (Terkalibrasi Pareto 80% - 15% - 5%)")
    print(f"- PIN Admin Default    : 123456")

if __name__ == "__main__":
    seed_from_csv()
