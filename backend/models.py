from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()

class Book(db.Model):
    __tablename__ = 'books'
    id = db.Column(db.Integer, primary_key=True)
    barcode = db.Column(db.String(50), unique=True, nullable=False, index=True)
    title = db.Column(db.String(200), nullable=False)
    category = db.Column(db.String(100), default='Umum', nullable=True)
    price = db.Column(db.Float, nullable=False)
    stock = db.Column(db.Integer, default=0, nullable=False)
    abc_class = db.Column(db.String(1), default='C', nullable=False)  # 'A', 'B', or 'C'
    last_opname_date = db.Column(db.DateTime, default=datetime.now, nullable=False)

    def __init__(self, barcode=None, title=None, category='Umum', price=0.0, stock=0, abc_class='C', last_opname_date=None, id=None, **kwargs):
        super().__init__(**kwargs)
        if id is not None:
            self.id = id
        self.barcode = barcode
        self.title = title
        self.category = category
        self.price = price
        self.stock = stock
        self.abc_class = abc_class
        if last_opname_date is not None:
            self.last_opname_date = last_opname_date
        else:
            self.last_opname_date = datetime.now()

    def to_dict(self):
        return {
            'id': self.id,
            'barcode': self.barcode,
            'title': self.title,
            'category': self.category or 'Umum',
            'price': self.price,
            'stock': self.stock,
            'abc_class': self.abc_class,
            'last_opname_date': self.last_opname_date.isoformat() if self.last_opname_date else None
        }

class Transaction(db.Model):
    __tablename__ = 'transactions'
    id = db.Column(db.Integer, primary_key=True)
    timestamp = db.Column(db.DateTime, default=datetime.now, nullable=False)
    total_amount = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(20), default='completed', nullable=False)  # 'completed' or 'voided'

    items = db.relationship('TransactionItem', backref='transaction', lazy=True, cascade='all, delete-orphan')

    def __init__(self, timestamp=None, total_amount=0.0, status='completed', items=None, id=None, **kwargs):
        super().__init__(**kwargs)
        if id is not None:
            self.id = id
        if timestamp is not None:
            self.timestamp = timestamp
        else:
            self.timestamp = datetime.now()
        self.total_amount = total_amount
        self.status = status
        if items is not None:
            self.items = items

    def to_dict(self):
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
            'total_amount': self.total_amount,
            'status': self.status,
            'items': [item.to_dict() for item in self.items]
        }

class TransactionItem(db.Model):
    __tablename__ = 'transaction_items'
    id = db.Column(db.Integer, primary_key=True)
    transaction_id = db.Column(db.Integer, db.ForeignKey('transactions.id'), nullable=False)
    book_id = db.Column(db.Integer, db.ForeignKey('books.id'), nullable=False)
    qty = db.Column(db.Integer, nullable=False)
    subtotal = db.Column(db.Float, nullable=False)

    book = db.relationship('Book')

    def __init__(self, transaction_id=None, book_id=None, qty=0, subtotal=0.0, book=None, id=None, **kwargs):
        super().__init__(**kwargs)
        if id is not None:
            self.id = id
        if transaction_id is not None:
            self.transaction_id = transaction_id
        if book_id is not None:
            self.book_id = book_id
        self.qty = qty
        self.subtotal = subtotal
        if book is not None:
            self.book = book

    def to_dict(self):
        return {
            'id': self.id,
            'transaction_id': self.transaction_id,
            'book_id': self.book_id,
            'book': self.book.to_dict() if self.book else {
                'id': self.book_id,
                'barcode': '-',
                'title': 'Buku Dihapus',
                'price': 0.0,
                'stock': 0,
                'abc_class': 'C'
            },
            'qty': self.qty,
            'subtotal': self.subtotal
        }

class Setting(db.Model):
    __tablename__ = 'settings'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    key = db.Column(db.String(50), nullable=True)
    value = db.Column(db.String(200), nullable=True)
    admin_pin = db.Column(db.String(50), nullable=True, default='123456')

    def __init__(self, key=None, value=None, admin_pin='123456', id=None, **kwargs):
        super().__init__(**kwargs)
        if id is not None:
            self.id = id
        self.key = key
        self.value = value
        self.admin_pin = admin_pin

    def to_dict(self):
        return {
            'id': self.id,
            'key': self.key,
            'value': self.value,
            'admin_pin': self.admin_pin or self.value or '123456'
        }
