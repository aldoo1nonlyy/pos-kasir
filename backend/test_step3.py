import json
from app import create_app
from models import db, Book, Transaction, TransactionItem

def run_step3_tests():
    test_config = {
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:'
    }
    app = create_app(test_config=test_config)
    client = app.test_client()

    with app.app_context():
        # Clear existing sample books for a clean controlled test
        Book.query.delete()
        db.session.commit()

        # Create books with known prices
        books = [
            Book(barcode="B001", title="Top Bestseller A1", price=100000.0, stock=200, abc_class="C"),
            Book(barcode="B002", title="Second Bestseller A2", price=50000.0, stock=200, abc_class="C"),
            Book(barcode="B003", title="Moderate Seller B1", price=100000.0, stock=200, abc_class="C"),
            Book(barcode="B004", title="Moderate Seller B2", price=50000.0, stock=200, abc_class="C"),
            Book(barcode="B005", title="Low Seller C1", price=100000.0, stock=200, abc_class="C"),
            Book(barcode="B006", title="Low Seller C2", price=20000.0, stock=200, abc_class="C"),
            Book(barcode="B007", title="Zero Seller C3", price=50000.0, stock=200, abc_class="C")
        ]
        db.session.bulk_save_objects(books)
        db.session.commit()

        b1 = Book.query.filter_by(barcode="B001").first()
        b2 = Book.query.filter_by(barcode="B002").first()
        b3 = Book.query.filter_by(barcode="B003").first()
        b4 = Book.query.filter_by(barcode="B004").first()
        b5 = Book.query.filter_by(barcode="B005").first()
        b6 = Book.query.filter_by(barcode="B006").first()
        b7 = Book.query.filter_by(barcode="B007").first()

        id1, id2, id3, id4, id5, id6, id7 = b1.id, b2.id, b3.id, b4.id, b5.id, b6.id, b7.id

    # Create completed sales via Checkout API
    # Total revenue target: 10,000,000 IDR
    # B001: 70 * 100,000 = 7,000,000 (70%)  -> Class A (0% - 70%)
    # B002: 20 * 50,000  = 1,000,000 (10%)  -> Class A (70% - 80%)
    # B003: 10 * 100,000 = 1,000,000 (10%)  -> Class B (80% - 90%)
    # B004: 10 * 50,000  = 500,000   (5%)   -> Class B (90% - 95%)
    # B005: 4 * 100,000  = 400,000   (4%)   -> Class C (95% - 99%)
    # B006: 5 * 20,000   = 100,000   (1%)   -> Class C (99% - 100%)
    # B007: 0 sales      = 0         (0%)   -> Class C (100%)

    tx_payload = {
        "items": [
            {"book_id": id1, "qty": 70},
            {"book_id": id2, "qty": 20},
            {"book_id": id3, "qty": 10},
            {"book_id": id4, "qty": 10},
            {"book_id": id5, "qty": 4},
            {"book_id": id6, "qty": 5}
        ]
    }
    res = client.post('/api/checkout', json=tx_payload)
    assert res.status_code == 201, f"Checkout failed: {res.get_json()}"
    tx = res.get_json()
    assert tx['total_amount'] == 10000000.0, f"Expected 10M, got {tx['total_amount']}"

    # Also add a voided transaction to verify voided sales are NOT counted in ABC
    void_tx_payload = {
        "items": [
            {"book_id": id6, "qty": 10} # 200,000 sale that gets voided
        ]
    }
    res_void = client.post('/api/checkout', json=void_tx_payload)
    void_id = res_void.get_json()['id']
    client.post(f'/api/transactions/{void_id}/void', json={})

    # TEST 1: Preview ABC Analysis via GET /api/abc-analysis
    res_preview = client.get('/api/abc-analysis')
    assert res_preview.status_code == 200
    p_data = res_preview.get_json()
    assert p_data['total_revenue'] == 10000000.0
    assert p_data['class_distribution']['A']['count'] == 2
    assert p_data['class_distribution']['B']['count'] == 2
    assert p_data['class_distribution']['C']['count'] == 3
    print("[OK] Test 1: GET /api/abc-analysis preview calculated exact ABC distribution.")

    # In preview mode, database books should NOT have changed yet (still 'C')
    with app.app_context():
        book1 = db.session.get(Book, id1)
        assert book1.abc_class == 'C', "Preview mode should not mutate DB"
    print("[OK] Test 2: Preview mode did not mutate database.")

    # TEST 3: Run and APPLY ABC Analysis via POST /api/abc-analysis/run
    res_run = client.post('/api/abc-analysis/run', json={"apply": True})
    assert res_run.status_code == 200
    run_data = res_run.get_json()

    book_results = {b['barcode']: b for b in run_data['books']}
    assert book_results['B001']['new_class'] == 'A', f"B001 should be A, got {book_results['B001']['new_class']}"
    assert book_results['B002']['new_class'] == 'A', f"B002 should be A, got {book_results['B002']['new_class']}"
    assert book_results['B003']['new_class'] == 'B', f"B003 should be B, got {book_results['B003']['new_class']}"
    assert book_results['B004']['new_class'] == 'B', f"B004 should be B, got {book_results['B004']['new_class']}"
    assert book_results['B005']['new_class'] == 'C', f"B005 should be C, got {book_results['B005']['new_class']}"
    assert book_results['B006']['new_class'] == 'C', f"B006 should be C, got {book_results['B006']['new_class']}"
    assert book_results['B007']['new_class'] == 'C', f"B007 should be C, got {book_results['B007']['new_class']}"

    # TEST 4: Verify Database is updated!
    with app.app_context():
        assert db.session.get(Book, id1).abc_class == 'A'
        assert db.session.get(Book, id2).abc_class == 'A'
        assert db.session.get(Book, id3).abc_class == 'B'
        assert db.session.get(Book, id4).abc_class == 'B'
        assert db.session.get(Book, id5).abc_class == 'C'
        assert db.session.get(Book, id6).abc_class == 'C'
        assert db.session.get(Book, id7).abc_class == 'C'
    print("[OK] Test 3 & 4: POST /api/abc-analysis/run updated database books.abc_class successfully.")

    print("\nALL STEP 3 TESTS PASSED SUCCESSFULLY!")

if __name__ == '__main__':
    run_step3_tests()
