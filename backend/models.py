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

    def to_dict(self):
        return {
            'id': self.id,
            'key': self.key,
            'value': self.value,
            'admin_pin': self.admin_pin or self.value or '123456'
        }
