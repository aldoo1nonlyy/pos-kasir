 import json
from datetime import datetime, timedelta
from app import create_app
from models import db, Book

def run_step4_tests():
    test_config = {
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:'
    }
    app = create_app(test_config=test_config)
    client = app.test_client()

    now = datetime.now()

    with app.app_context():
        # Clear existing books
        Book.query.delete()
        db.session.commit()

        # Create books with controlled last_opname_date
        # Kelas A (siklus 7 hari):
        # b_a1: opname 8 hari lalu -> OVERDUE (terlambat 1 hari)
        # b_a2: opname 2 hari lalu -> OK (sisa 5 hari)
        b_a1 = Book(barcode="A001", title="Buku A Overdue", price=100000.0, stock=20, abc_class="A", last_opname_date=now - timedelta(days=8))
        b_a2 = Book(barcode="A002", title="Buku A On Time", price=100000.0, stock=30, abc_class="A", last_opname_date=now - timedelta(days=2))

        # Kelas B (siklus 30 hari):
        # b_b1: opname 35 hari lalu -> OVERDUE (terlambat 5 hari)
        # b_b2: opname 10 hari lalu -> OK (sisa 20 hari)
        b_b1 = Book(barcode="B001", title="Buku B Overdue", price=75000.0, stock=15, abc_class="B", last_opname_date=now - timedelta(days=35))
        b_b2 = Book(barcode="B002", title="Buku B On Time", price=75000.0, stock=25, abc_class="B", last_opname_date=now - timedelta(days=10))

        # Kelas C (siklus 90 hari):
        # b_c1: opname 95 hari lalu -> OVERDUE (terlambat 5 hari)
        # b_c2: opname 30 hari lalu -> OK (sisa 60 hari)
        b_c1 = Book(barcode="C001", title="Buku C Overdue", price=45000.0, stock=10, abc_class="C", last_opname_date=now - timedelta(days=95))
        b_c2 = Book(barcode="C002", title="Buku C On Time", price=45000.0, stock=40, abc_class="C", last_opname_date=now - timedelta(days=30))

        db.session.add_all([b_a1, b_a2, b_b1, b_b2, b_c1, b_c2])
        db.session.commit()

        id_a1 = b_a1.id
        id_a2 = b_a2.id
        id_b1 = b_b1.id
        id_c1 = b_c1.id

    # TEST 1: GET /opname-alerts & GET /api/opname-alerts
    for endpoint in ['/opname-alerts', '/api/opname-alerts']:
        res = client.get(endpoint)
        assert res.status_code == 200, f"Gagal akses {endpoint}: {res.get_json()}"
        data = res.get_json()
        assert data['total_alerts'] == 3, f"Harusnya 3 buku overdue, dapat {data['total_alerts']}"
        assert data['counts_by_class']['A'] == 1
        assert data['counts_by_class']['B'] == 1
        assert data['counts_by_class']['C'] == 1

        # Cek prioritas urutan: Kelas A harus di paling atas
        overdue_books = data['overdue_books']
        assert overdue_books[0]['barcode'] == "A001"
        assert overdue_books[0]['urgency_level'] == "CRITICAL"
        assert overdue_books[0]['cycle_days'] == 7
        assert overdue_books[0]['days_overdue'] >= 1

    print("[OK] Test 1: Endpoint /opname-alerts mengembalikan 3 buku overdue dengan prioritas Kelas A di urutan pertama.")

    # TEST 2: Filter berdasarkan Kelas ABC (?abc_class=A)
    res_a = client.get('/api/opname-alerts?abc_class=A')
    assert res_a.status_code == 200
    data_a = res_a.get_json()
    assert len(data_a['overdue_books']) == 1
    assert data_a['overdue_books'][0]['barcode'] == 'A001'
    print("[OK] Test 2: Filter query ?abc_class=A berhasil.")

    # TEST 3: Pencatatan Stock Opname melalui POST /api/opname
    opname_payload = {
        "book_id": id_a1,
        "actual_stock": 22, # penyesuaian stok fisik dari 20 ke 22
        "notes": "Penghitungan fisik rak display"
    }
    res_op = client.post('/api/opname', json=opname_payload)
    assert res_op.status_code == 200
    op_result = res_op.get_json()
    assert op_result['book']['stock'] == 22
    assert op_result['opname_status']['is_overdue'] is False
    print("[OK] Test 3: POST /api/opname berhasil mencatat opname dan mereset status jatuh tempo.")

    # TEST 4: Verifikasi alert berkurang setelah opname dilakukan
    res_after = client.get('/opname-alerts')
    data_after = res_after.get_json()
    assert data_after['total_alerts'] == 2, f"Harusnya 2 alert tersisa, dapat {data_after['total_alerts']}"
    assert data_after['counts_by_class']['A'] == 0, "Kelas A seharusnya sudah 0 alert"
    assert data_after['counts_by_class']['B'] == 1
    assert data_after['counts_by_class']['C'] == 1
    print("[OK] Test 4: Alert Kelas A otomatis bersih setelah opname dicatat.")

    print("\nSEMUA PENGUJIAN STEP 4 BERHASIL 100%!")

if __name__ == '__main__':
    run_step4_tests()
