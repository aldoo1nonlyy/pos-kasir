import os
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_restful import Api, Resource
from flask_cors import CORS
from models import db, Book, Transaction, TransactionItem, Setting

def create_app(test_config=None):
    app = Flask(__name__)
    CORS(app)

    pos_backend_db = os.path.abspath(os.path.join(os.path.dirname(__file__), 'pos-backend', 'pos_tokobuku.db'))
    instance_db = os.path.join(app.instance_path, 'bookstore_pos.db')
    os.makedirs(app.instance_path, exist_ok=True)

    if os.path.exists(pos_backend_db):
        db_path = pos_backend_db
    else:
        db_path = instance_db

    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    if test_config:
        app.config.update(test_config)

    db.init_app(app)

    with app.app_context():
        db.create_all()
        _seed_initial_data(app)

    @app.route('/', methods=['GET'])
    def index():
        return jsonify({
            "status": "online",
            "service": "POS Toko Buku Backend (Dynamic ABC)",
            "database": db_path,
            "endpoints": {
                "calculate_abc": "GET /calculate-abc",
                "list_books": "GET /books",
                "api_books": "GET /api/books",
                "api_transactions": "GET /api/transactions",
                "api_checkout": "POST /api/checkout",
                "api_opname_alerts": "GET /opname-alerts"
            }
        })

    api = Api(app)
    _register_routes(api)

    return app

def _seed_initial_data(app=None):
    """Seed default settings and catalog if tables are empty."""
    is_testing = app.config.get('TESTING', False) if app else False

    # Ensure default admin pin setting exists
    if not Setting.query.first():
        default_setting = Setting(id=1, key='admin_pin', value='123456', admin_pin='123456')
        db.session.add(default_setting)
        db.session.commit()

    # Seed catalog if empty
    if not Book.query.first():
        base_dir = os.path.dirname(os.path.abspath(__file__))
        books_csv = os.path.join(base_dir, 'pos-backend', 'books_dataset_600_sku.csv')
        tx_csv = os.path.join(base_dir, 'pos-backend', 'transactions_dataset_600_sku.csv')

        if not is_testing and os.path.exists(books_csv) and os.path.exists(tx_csv):
            import csv
            with open(books_csv, mode="r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    b = Book(
                        id=int(row["id"]),
                        barcode=row["barcode"],
                        title=row["title"],
                        category=row["category"],
                        price=float(row["price"]),
                        stock=int(row["stock"]),
                        abc_class='C',
                        last_opname_date=datetime.strptime(row["last_opname_date"], '%Y-%m-%d')
                    )
                    db.session.add(b)

            tx_headers = {}
            tx_items = []
            with open(tx_csv, mode="r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    t_id = int(row["transaction_id"])
                    sub = float(row["subtotal"])
                    if t_id not in tx_headers:
                        tx_headers[t_id] = {
                            "timestamp": datetime.strptime(row["timestamp"], '%Y-%m-%d %H:%M:%S'),
                            "total_amount": 0.0,
                            "status": row["status"]
                        }
                    tx_headers[t_id]["total_amount"] += sub
                    tx_items.append((t_id, int(row["book_id"]), int(row["qty"]), sub))

            for t_id, t_data in sorted(tx_headers.items()):
                t = Transaction(
                    id=t_id,
                    timestamp=t_data["timestamp"],
                    total_amount=t_data["total_amount"],
                    status=t_data["status"]
                )
                db.session.add(t)

            for t_id, b_id, qty, sub in tx_items:
                ti = TransactionItem(
                    transaction_id=t_id,
                    book_id=b_id,
                    qty=qty,
                    subtotal=sub
                )
                db.session.add(ti)

            db.session.commit()
        else:
            sample_books = [
                Book(
                    barcode="9786020332956",
                    title="Filosofi Teras",
                    price=98000.0,
                    stock=45,
                    abc_class="A",
                    last_opname_date=datetime.now()
                ),
                Book(
                    barcode="9786020633176",
                    title="Atomic Habits (Edisi Bahasa Indonesia)",
                    price=108000.0,
                    stock=50,
                    abc_class="A",
                    last_opname_date=datetime.now()
                ),
                Book(
                    barcode="9786020651927",
                    title="Psychology of Money",
                    price=85000.0,
                    stock=30,
                    abc_class="A",
                    last_opname_date=datetime.now()
                ),
                Book(
                    barcode="9789793062792",
                    title="Laskar Pelangi",
                    price=79000.0,
                    stock=25,
                    abc_class="B",
                    last_opname_date=datetime.now()
                ),
                Book(
                    barcode="9786022914082",
                    title="Bumi Manusia",
                    price=115000.0,
                    stock=20,
                    abc_class="B",
                    last_opname_date=datetime.now()
                ),
                Book(
                    barcode="9789791227025",
                    title="Kamus Lengkap Bahasa Indonesia",
                    price=65000.0,
                    stock=15,
                    abc_class="C",
                    last_opname_date=datetime.now()
                ),
                Book(
                    barcode="9786024246945",
                    title="Buku Catatan Saku Garis",
                    price=18000.0,
                    stock=60,
                    abc_class="C",
                    last_opname_date=datetime.now()
                )
            ]
            db.session.bulk_save_objects(sample_books)
            db.session.commit()

# --- Health Check API ---
class HealthCheckAPI(Resource):
    def get(self):
        return {
            'status': 'healthy',
            'system': 'Bookstore POS Backend',
            'version': '1.0.0',
            'timestamp': datetime.now().isoformat()
        }, 200

# --- Books CRUD APIs (STEP 1) ---
class BookListAPI(Resource):
    def get(self):
        """
        List all books.
        Query parameters:
        - search: search keyword for title or barcode (case-insensitive)
        - abc_class: filter by 'A', 'B', or 'C'
        """
        query = Book.query

        search = request.args.get('search', '').strip()
        if search:
            query = query.filter(
                (Book.title.ilike(f"%{search}%")) | (Book.barcode.ilike(f"%{search}%"))
            )

        abc_class = request.args.get('abc_class', '').strip().upper()
        if abc_class in ['A', 'B', 'C']:
            query = query.filter_by(abc_class=abc_class)

        books = query.order_by(Book.id.asc()).all()
        return [book.to_dict() for book in books], 200

    def post(self):
        """
        Create a new book.
        Required JSON fields: barcode, title, price
        Optional JSON fields: stock, abc_class, last_opname_date
        """
        data = request.get_json(silent=True) or {}

        barcode = str(data.get('barcode', '')).strip()
        title = str(data.get('title', '')).strip()
        raw_price = data.get('price')
        raw_stock = data.get('stock', 0)
        abc_class = str(data.get('abc_class', 'C')).strip().upper()
        raw_last_opname = data.get('last_opname_date')

        # Validation
        if not barcode:
            return {'error': 'Barcode wajib diisi'}, 400
        if not title:
            return {'error': 'Judul buku (title) wajib diisi'}, 400
        if raw_price is None:
            return {'error': 'Harga buku (price) wajib diisi'}, 400

        try:
            price = float(raw_price)
            if price < 0:
                return {'error': 'Harga buku tidak boleh negatif'}, 400
        except (ValueError, TypeError):
            return {'error': 'Harga buku harus berupa angka valid'}, 400

        try:
            stock = int(raw_stock)
            if stock < 0:
                return {'error': 'Stok buku tidak boleh negatif'}, 400
        except (ValueError, TypeError):
            return {'error': 'Stok buku harus berupa bilangan bulat valid'}, 400

        if abc_class not in ['A', 'B', 'C']:
            return {'error': "abc_class harus bernilai 'A', 'B', atau 'C'"}, 400

        # Check barcode uniqueness
        existing_book = Book.query.filter_by(barcode=barcode).first()
        if existing_book:
            return {'error': f"Buku dengan barcode '{barcode}' sudah ada ({existing_book.title})"}, 409

        # Parse last_opname_date if provided
        last_opname_date = datetime.now()
        if raw_last_opname:
            try:
                last_opname_date = datetime.fromisoformat(raw_last_opname)
            except ValueError:
                return {'error': 'Format last_opname_date tidak valid (gunakan format ISO 8601)'}, 400

        new_book = Book(
            barcode=barcode,
            title=title,
            price=price,
            stock=stock,
            abc_class=abc_class,
            last_opname_date=last_opname_date
        )

        db.session.add(new_book)
        db.session.commit()

        return new_book.to_dict(), 201

class BookDetailAPI(Resource):
    def get(self, book_id):
        """Retrieve a specific book by ID."""
        book = db.session.get(Book, book_id)
        if not book:
            return {'error': f'Buku dengan ID {book_id} tidak ditemukan'}, 404
        return book.to_dict(), 200

    def put(self, book_id):
        """Update an existing book by ID."""
        book = db.session.get(Book, book_id)
        if not book:
            return {'error': f'Buku dengan ID {book_id} tidak ditemukan'}, 404

        data = request.get_json(silent=True) or {}

        # Barcode update check
        if 'barcode' in data:
            new_barcode = str(data['barcode']).strip()
            if not new_barcode:
                return {'error': 'Barcode tidak boleh kosong'}, 400
            if new_barcode != book.barcode:
                conflict = Book.query.filter_by(barcode=new_barcode).first()
                if conflict and conflict.id != book.id:
                    return {'error': f"Barcode '{new_barcode}' sudah digunakan buku lain ({conflict.title})"}, 409
                book.barcode = new_barcode

        # Title update
        if 'title' in data:
            new_title = str(data['title']).strip()
            if not new_title:
                return {'error': 'Judul buku tidak boleh kosong'}, 400
            book.title = new_title

        # Price update
        if 'price' in data:
            try:
                new_price = float(data['price'])
                if new_price < 0:
                    return {'error': 'Harga buku tidak boleh negatif'}, 400
                book.price = new_price
            except (ValueError, TypeError):
                return {'error': 'Harga buku harus berupa angka valid'}, 400

        # Stock update
        if 'stock' in data:
            try:
                new_stock = int(data['stock'])
                if new_stock < 0:
                    return {'error': 'Stok buku tidak boleh negatif'}, 400
                book.stock = new_stock
            except (ValueError, TypeError):
                return {'error': 'Stok buku harus berupa bilangan bulat valid'}, 400

        # ABC Class update
        if 'abc_class' in data:
            new_abc = str(data['abc_class']).strip().upper()
            if new_abc not in ['A', 'B', 'C']:
                return {'error': "abc_class harus bernilai 'A', 'B', atau 'C'"}, 400
            book.abc_class = new_abc

        # Last Opname Date update
        if 'last_opname_date' in data:
            try:
                book.last_opname_date = datetime.fromisoformat(data['last_opname_date'])
            except (ValueError, TypeError):
                return {'error': 'Format last_opname_date tidak valid (gunakan format ISO 8601)'}, 400

        db.session.commit()
        return book.to_dict(), 200

    def delete(self, book_id):
        """Delete a book by ID."""
        book = db.session.get(Book, book_id)
        if not book:
            return {'error': f'Buku dengan ID {book_id} tidak ditemukan'}, 404

        db.session.delete(book)
        db.session.commit()
        return {'message': f"Buku '{book.title}' (ID: {book_id}) berhasil dihapus"}, 200

class BookBarcodeLookupAPI(Resource):
    def get(self, barcode):
        """Lookup a book directly by barcode for barcode scanner zero-delay integration."""
        book = Book.query.filter_by(barcode=barcode.strip()).first()
        if not book:
            return {'error': f"Buku dengan barcode '{barcode}' tidak ditemukan"}, 404
        return book.to_dict(), 200

# --- POS Checkout & Transactions API (STEP 2) ---
class CheckoutAPI(Resource):
    def post(self):
        """
        POS Checkout endpoint.
        Deducts stock immediately in books table.
        Payload format:
        {
            "items": [
                {"book_id": 1, "qty": 2},
                {"barcode": "9786020332956", "qty": 1}
            ]
        }
        """
        data = request.get_json(silent=True) or {}
        items_data = data.get('items', [])

        if not items_data or not isinstance(items_data, list):
            return {'error': 'Daftar item belanja (items) tidak boleh kosong'}, 400

        total_amount = 0.0
        prepared_items = []

        # Pass 1: Validation and stock availability verification
        for idx, item in enumerate(items_data):
            book_id = item.get('book_id')
            barcode = item.get('barcode')
            raw_qty = item.get('qty', item.get('quantity', 1))

            try:
                qty = int(raw_qty)
                if qty <= 0:
                    return {'error': f'Jumlah item pada baris ke-{idx + 1} harus lebih dari 0'}, 400
            except (ValueError, TypeError):
                return {'error': f'Format kuantitas pada baris ke-{idx + 1} tidak valid'}, 400

            book = None
            if book_id is not None:
                book = db.session.get(Book, book_id)
            elif barcode:
                book = Book.query.filter_by(barcode=str(barcode).strip()).first()

            if not book:
                identifier = f"ID {book_id}" if book_id else f"barcode '{barcode}'"
                return {'error': f'Buku dengan {identifier} tidak ditemukan'}, 404

            # Stock check
            if book.stock < qty:
                return {
                    'error': f"Stok buku '{book.title}' tidak mencukupi (Tersedia: {book.stock}, Diminta: {qty})"
                }, 400

            subtotal = round(book.price * qty, 2)
            total_amount += subtotal

            prepared_items.append({
                'book': book,
                'qty': qty,
                'subtotal': subtotal
            })

        # Pass 2: Create transaction and auto-deduct stock
        new_transaction = Transaction(
            total_amount=round(total_amount, 2),
            status='completed',
            timestamp=datetime.now()
        )
        db.session.add(new_transaction)
        db.session.flush()

        for p_item in prepared_items:
            book = p_item['book']
            qty = p_item['qty']
            subtotal = p_item['subtotal']

            # Auto-deduct stock immediately
            book.stock -= qty

            t_item = TransactionItem(
                transaction_id=new_transaction.id,
                book_id=book.id,
                qty=qty,
                subtotal=subtotal
            )
            db.session.add(t_item)

        db.session.commit()
        return new_transaction.to_dict(), 201

class TransactionListAPI(Resource):
    def get(self):
        """
        List all transactions.
        Optional query param:
        - status: 'completed' or 'voided'
        - start_date: YYYY-MM-DD
        - end_date: YYYY-MM-DD
        - sort: 'asc' or 'desc' (default: 'desc')
        """
        query = Transaction.query
        status = request.args.get('status', '').strip().lower()
        if status in ['completed', 'voided']:
            query = query.filter_by(status=status)

        start_date = request.args.get('start_date')
        if start_date:
            query = query.filter(Transaction.timestamp >= f"{start_date} 00:00:00")

        end_date = request.args.get('end_date')
        if end_date:
            query = query.filter(Transaction.timestamp <= f"{end_date} 23:59:59")

        sort_order = request.args.get('sort', 'desc').strip().lower()
        if sort_order == 'asc':
            query = query.order_by(Transaction.timestamp.asc())
        else:
            query = query.order_by(Transaction.timestamp.desc())

        transactions = query.all()
        return [t.to_dict() for t in transactions], 200

class TransactionDetailAPI(Resource):
    def get(self, transaction_id):
        """Get detail of a specific transaction."""
        transaction = db.session.get(Transaction, transaction_id)
        if not transaction:
            return {'error': f'Transaksi dengan ID {transaction_id} tidak ditemukan'}, 404
        return transaction.to_dict(), 200

class TransactionVoidAPI(Resource):
    def post(self, transaction_id):
        """
        Void a transaction and auto-revert stock.
        SECURITY RULE: If ANY book in the voided transaction has abc_class == 'A',
        the request MUST provide a valid 'admin_pin' in the request body to authorize the void.
        """
        transaction = db.session.get(Transaction, transaction_id)
        if not transaction:
            return {'error': f'Transaksi dengan ID {transaction_id} tidak ditemukan'}, 404

        if transaction.status == 'voided':
            return {'error': f'Transaksi #{transaction_id} sudah dibatalkan sebelumnya (status: voided)'}, 400

        # Check if ANY book in this transaction is Class A
        has_class_a = False
        class_a_books = []
        for item in transaction.items:
            if item.book and item.book.abc_class == 'A':
                has_class_a = True
                class_a_books.append(item.book.title)

        data = request.get_json(silent=True) or {}
        provided_pin = str(data.get('admin_pin', '')).strip()

        # Enforce Security Rule: Class A books require Admin PIN authorization
        if has_class_a:
            if not provided_pin:
                return {
                    'error': f"PIN Manajer diperlukan! Transaksi #{transaction_id} memuat buku Kategori A (Buku Terlaris: {', '.join(class_a_books)}).",
                    'requires_admin_pin': True
                }, 403

            setting = Setting.query.first()
            current_admin_pin = (setting.admin_pin or setting.value) if setting else '123456'

            if provided_pin != current_admin_pin:
                return {
                    'error': 'PIN Manajer salah! Pembatalan transaksi buku terlaris (Kategori A) ditolak.',
                    'requires_admin_pin': True
                }, 403

        # Auto-revert stock for all items
        for item in transaction.items:
            if item.book:
                item.book.stock += item.qty

        transaction.status = 'voided'
        db.session.commit()

        return {
            'message': f'Transaksi #{transaction_id} berhasil dibatalkan (voided) dan stok telah dikembalikan.',
            'transaction': transaction.to_dict()
        }, 200

class SettingAPI(Resource):
    def get(self):
        """Get system settings status."""
        setting = Setting.query.first()
        if not setting:
            setting = Setting(id=1, key='admin_pin', value='123456', admin_pin='123456')
            db.session.add(setting)
            db.session.commit()
        pin_val = setting.admin_pin or setting.value
        return {'id': setting.id, 'admin_pin_set': bool(pin_val)}, 200

    def put(self):
        """Update admin PIN."""
        data = request.get_json(silent=True) or {}
        new_pin = str(data.get('admin_pin', '')).strip()
        current_pin = str(data.get('current_pin', '')).strip()

        if not new_pin or len(new_pin) < 4:
            return {'error': 'PIN Admin baru minimal 4 karakter/digit'}, 400

        setting = Setting.query.first()
        if not setting:
            setting = Setting(id=1, key='admin_pin', value=new_pin, admin_pin=new_pin)
            db.session.add(setting)
        else:
            current_stored_pin = setting.admin_pin or setting.value
            if current_stored_pin and current_stored_pin != current_pin:
                return {'error': 'PIN Admin saat ini tidak cocok'}, 403
            setting.admin_pin = new_pin
            setting.value = new_pin

        db.session.commit()
        return {'message': 'PIN Admin berhasil diperbarui'}, 200

# --- Dynamic ABC Inventory Analysis Logic (STEP 3) ---
def perform_abc_analysis(days=None, apply_updates=True):
    """
    Dynamic ABC Inventory Analysis Algorithm:
    a. Calculate total revenue for each book (qty sold * price) from completed transactions over specific period.
    b. Sort books descending by total revenue.
    c. Calculate cumulative revenue percentage.
    d. Classify:
       - Class A: Top books contributing to 0% - 80% of total revenue.
       - Class B: Next books contributing to 80.1% - 95% of total revenue.
       - Class C: Bottom books contributing to 95.1% - 100% of total revenue (or 0 sales).
    e. If apply_updates is True, update the `abc_class` column in the `books` table.
    """
    now = datetime.now()
    tx_query = Transaction.query.filter_by(status='completed')

    if days is not None and days > 0:
        latest_tx = Transaction.query.filter_by(status='completed').order_by(Transaction.timestamp.desc()).first()
        # Jika transaksi terakhir berada di luar jendela now-days (misal dataset historis), gunakan anchor tanggal transaksi terbaru
        ref_date = latest_tx.timestamp if (latest_tx and (now - latest_tx.timestamp).days > days) else now
        cutoff_date = ref_date - timedelta(days=days)
        tx_query = tx_query.filter(Transaction.timestamp >= cutoff_date)

    completed_txs = tx_query.all()
    completed_tx_ids = [tx.id for tx in completed_txs]

    all_books = Book.query.all()
    book_map = {b.id: b for b in all_books}
    book_revenue = {b.id: 0.0 for b in all_books}
    book_qty_sold = {b.id: 0 for b in all_books}

    if completed_tx_ids:
        items = TransactionItem.query.filter(TransactionItem.transaction_id.in_(completed_tx_ids)).all()
        for item in items:
            if item.book_id in book_revenue:
                book_revenue[item.book_id] += item.subtotal
                book_qty_sold[item.book_id] += item.qty

    total_revenue = sum(book_revenue.values())

    # Urutkan omset terbesar ke terkecil, dengan tie-breaker ID buku terkecil (sesuai spesifikasi dataset Pareto)
    sorted_book_ids = sorted(
        book_revenue.keys(),
        key=lambda bid: (-book_revenue[bid], bid)
    )

    details = []
    cumulative_rev = 0.0

    for bid in sorted_book_ids:
        book = book_map[bid]
        rev = book_revenue[bid]
        qty = book_qty_sold[bid]
        old_class = book.abc_class

        if total_revenue > 0 and rev > 0:
            cumulative_rev += rev
            cum_pct = (cumulative_rev / total_revenue) * 100.0
            rev_pct = (rev / total_revenue) * 100.0

            if cum_pct <= 80.0:
                new_class = 'A'
            elif cum_pct <= 95.0:
                new_class = 'B'
            else:
                new_class = 'C'
        else:
            rev_pct = 0.0
            cum_pct = 100.0 if total_revenue > 0 else 0.0
            new_class = 'C'

        if apply_updates:
            book.abc_class = new_class

        details.append({
            'book_id': book.id,
            'barcode': book.barcode,
            'title': book.title,
            'category': getattr(book, 'category', 'Umum'),
            'price': book.price,
            'stock': book.stock,
            'qty_sold': qty,
            'revenue': round(rev, 2),
            'revenue_percentage': round(rev_pct, 2),
            'cumulative_percentage': round(min(cum_pct, 100.0), 2),
            'old_class': old_class,
            'new_class': new_class
        })

    if apply_updates:
        db.session.commit()

    changed_books = [d for d in details if d['old_class'] != d['new_class']]
    count_a = sum(1 for d in details if d['new_class'] == 'A')
    count_b = sum(1 for d in details if d['new_class'] == 'B')
    count_c = sum(1 for d in details if d['new_class'] == 'C')
    total_count = len(details)

    return {
        'total_revenue': round(total_revenue, 2),
        'total_books_analyzed': total_count,
        'total_items_updated': len(changed_books),
        'period_days': days if days else 'all_time',
        'applied_to_database': apply_updates,
        'class_distribution': {
            'A': {
                'count': count_a,
                'percentage': round((count_a / total_count * 100), 1) if total_count else 0
            },
            'B': {
                'count': count_b,
                'percentage': round((count_b / total_count * 100), 1) if total_count else 0
            },
            'C': {
                'count': count_c,
                'percentage': round((count_c / total_count * 100), 1) if total_count else 0
            }
        },
        'updated_books': changed_books,
        'books': details
    }

class ABCAnalysisAPI(Resource):
    def get(self):
        """Preview ABC Analysis."""
        raw_days = request.args.get('days')
        days = int(raw_days) if raw_days and raw_days.isdigit() else None
        apply_updates = request.args.get('apply', 'false').strip().lower() == 'true'

        result = perform_abc_analysis(days=days, apply_updates=apply_updates)
        return result, 200

    def post(self):
        """Run ABC Analysis and save to DB."""
        data = request.get_json(silent=True) or {}
        raw_days = data.get('days')
        days = int(raw_days) if raw_days is not None and str(raw_days).isdigit() else None
        apply_updates = data.get('apply', True)

        result = perform_abc_analysis(days=days, apply_updates=bool(apply_updates))
        return result, 200

class CalculateAbcAPI(Resource):
    def get(self):
        """
        Endpoint GET /calculate-abc:
        1. Membaca transaksi dan buku
        2. Menghitung total omset tiap buku dan urutkan terbesar ke terkecil
        3. Hitung persentase kumulatif
        4. Update kolom abc_class di database: 0-80% = A, 80.01-95% = B, 95.01-100% = C
        5. Return response JSON berisi daftar barang yang kelasnya berubah
        """
        result = perform_abc_analysis(apply_updates=True)
        return {
            'status': 'success',
            'message': 'Kategori buku terlaris dan pembaruan database berhasil dilakukan.',
            'total_books_analyzed': result.get('total_books_analyzed', 0),
            'total_revenue': result.get('total_revenue', 0.0),
            'total_omset': result.get('total_revenue', 0.0),
            'total_items_updated': result.get('total_items_updated', 0),
            'class_distribution': {
                'A': result.get('class_distribution', {}).get('A', {}).get('count', 0),
                'B': result.get('class_distribution', {}).get('B', {}).get('count', 0),
                'C': result.get('class_distribution', {}).get('C', {}).get('count', 0)
            },
            'updated_books': result.get('updated_books', []),
            'books': result.get('books', [])
        }, 200

# --- Stock Opname Alert Logic (STEP 4) ---
# Aturan Siklus Opname Berdasarkan Kategori ABC:
# - Kelas A: Wajib opname setiap 7 hari (Prioritas Tinggi - Fast Moving / High Value)
# - Kelas B: Wajib opname setiap 30 hari (Prioritas Menengah)
# - Kelas C: Wajib opname setiap 90 hari (Prioritas Rendah - Slow Moving)
OPNAME_INTERVAL_DAYS = {
    'A': 7,
    'B': 30,
    'C': 90
}

URGENCY_INFO = {
    'A': {'level': 'CRITICAL', 'label': 'Kritis (Perlu Opname Segera)', 'color': 'red'},
    'B': {'level': 'WARNING',  'label': 'Peringatan (Jadwal Bulanan)',    'color': 'amber'},
    'C': {'level': 'NORMAL',   'label': 'Normal (Jadwal Triwulanan)',     'color': 'blue'}
}

def get_opname_status(book, now=None):
    """Menghitung status opname buku, apakah sudah jatuh tempo (overdue) atau belum."""
    if now is None:
        now = datetime.now()

    last_date = book.last_opname_date or now
    cycle_days = OPNAME_INTERVAL_DAYS.get(book.abc_class, 90)
    due_date = last_date + timedelta(days=cycle_days)

    delta_since = now - last_date
    delta_overdue = now - due_date

    days_since_opname = delta_since.days
    days_overdue = max(0, delta_overdue.days)
    is_overdue = now > due_date

    urgency = URGENCY_INFO.get(book.abc_class, URGENCY_INFO['C'])

    return {
        'book_id': book.id,
        'barcode': book.barcode,
        'title': book.title,
        'price': book.price,
        'stock': book.stock,
        'abc_class': book.abc_class,
        'last_opname_date': last_date.isoformat(),
        'next_opname_due': due_date.isoformat(),
        'cycle_days': cycle_days,
        'days_since_opname': days_since_opname,
        'days_overdue': days_overdue if is_overdue else 0,
        'is_overdue': is_overdue,
        'urgency_level': urgency['level'],
        'urgency_label': urgency['label']
    }

class OpnameAlertsAPI(Resource):
    def get(self):
        """
        API Endpoint untuk mengembalikan daftar buku yang telah jatuh tempo (overdue) untuk stock opname.
        Parameter Query:
        - abc_class: Filter berdasarkan 'A', 'B', atau 'C'
        - all: Jika 'true', tampilkan seluruh buku beserta status jatuh temponya
        """
        now = datetime.now()
        query = Book.query

        class_filter = request.args.get('abc_class', '').strip().upper()
        if class_filter in ['A', 'B', 'C']:
            query = query.filter_by(abc_class=class_filter)

        show_all = request.args.get('all', 'false').strip().lower() == 'true'

        all_books = query.all()
        overdue_books = []
        all_book_statuses = []

        for book in all_books:
            status = get_opname_status(book, now=now)
            all_book_statuses.append(status)
            if status['is_overdue']:
                overdue_books.append(status)

        # Urutkan buku yang overdue berdasarkan prioritas kelas (A -> B -> C) dan hari keterlambatan terbesar
        class_order = {'A': 0, 'B': 1, 'C': 2}
        overdue_books.sort(
            key=lambda item: (class_order.get(item['abc_class'], 3), -item['days_overdue'])
        )

        count_a = sum(1 for b in overdue_books if b['abc_class'] == 'A')
        count_b = sum(1 for b in overdue_books if b['abc_class'] == 'B')
        count_c = sum(1 for b in overdue_books if b['abc_class'] == 'C')

        target_list = all_book_statuses if show_all else overdue_books

        return {
            'timestamp': now.isoformat(),
            'total_alerts': len(overdue_books),
            'total_books_checked': len(all_books),
            'counts_by_class': {
                'A': count_a,
                'B': count_b,
                'C': count_c
            },
            'overdue_books': target_list
        }, 200

class OpnameRecordAPI(Resource):
    def post(self, book_id=None):
        """
        Mencatat penyelesaian stock opname buku.
        Memperbarui `last_opname_date` menjadi tanggal hari ini dan memperbarui stok fisik jika diinput.
        Payload JSON:
        {
            "book_id": 1,          // jika tidak disertakan dalam URL
            "actual_stock": 45,    // opsional: memperbarui stok fisik
            "notes": "Fisik rak sesuai"
        }
        """
        data = request.get_json(silent=True) or {}
        target_id = book_id or data.get('book_id')

        if not target_id:
            return {'error': 'book_id wajib disertakan'}, 400

        book = db.session.get(Book, target_id)
        if not book:
            return {'error': f'Buku dengan ID {target_id} tidak ditemukan'}, 404

        raw_actual_stock = data.get('actual_stock')
        if raw_actual_stock is not None:
            try:
                actual_stock = int(raw_actual_stock)
                if actual_stock < 0:
                    return {'error': 'Stok fisik tidak boleh bernilai negatif'}, 400
                book.stock = actual_stock
            except (ValueError, TypeError):
                return {'error': 'Format actual_stock tidak valid'}, 400

        # Perbarui tanggal opname terakhir ke waktu sekarang
        book.last_opname_date = datetime.now()
        db.session.commit()

        new_status = get_opname_status(book)

        return {
            'message': f"Pemeriksaan stok fisik untuk buku '{book.title}' berhasil dicatat.",
            'book': book.to_dict(),
            'opname_status': new_status
        }, 200

def _register_routes(api):
    # Base & Health
    api.add_resource(HealthCheckAPI, '/api/health')
    
    # Books CRUD (Step 1)
    api.add_resource(BookListAPI, '/api/books', '/books')
    api.add_resource(BookDetailAPI, '/api/books/<int:book_id>')
    api.add_resource(BookBarcodeLookupAPI, '/api/books/barcode/<string:barcode>')

    # POS Transactions (Step 2)
    api.add_resource(CheckoutAPI, '/api/checkout')
    api.add_resource(TransactionListAPI, '/api/transactions')
    api.add_resource(TransactionDetailAPI, '/api/transactions/<int:transaction_id>')
    api.add_resource(TransactionVoidAPI, '/api/transactions/<int:transaction_id>/void')
    api.add_resource(SettingAPI, '/api/settings')

    # Dynamic ABC Analysis (Step 3 & Calculate-ABC)
    api.add_resource(ABCAnalysisAPI, '/api/abc-analysis', '/api/abc-analysis/calculate', '/api/abc-analysis/run')
    api.add_resource(CalculateAbcAPI, '/calculate-abc', '/api/calculate-abc', '/api/calculate_abc')

    # Stock Opname Alert Logic (Step 4)
    api.add_resource(OpnameAlertsAPI, '/opname-alerts', '/api/opname-alerts')
    api.add_resource(OpnameRecordAPI, '/api/opname', '/api/books/<int:book_id>/opname')

app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
