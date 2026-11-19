import json
from app import create_app
from models import db, Book, Transaction, TransactionItem, Setting

def run_step2_tests():
    test_config = {
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:'
    }
    app = create_app(test_config=test_config)
    client = app.test_client()

    with app.app_context():
        book_a = Book.query.filter_by(abc_class='A').first()
        book_b = Book.query.filter_by(abc_class='B').first()
        book_c = Book.query.filter_by(abc_class='C').first()
        assert book_a and book_b and book_c

        init_stock_a = book_a.stock
        init_stock_b = book_b.stock
        init_stock_c = book_c.stock
        id_a, id_b, id_c = book_a.id, book_b.id, book_c.id

    print(f"Initial Stocks -> Book A ({id_a}): {init_stock_a}, Book B ({id_b}): {init_stock_b}, Book C ({id_c}): {init_stock_c}")

    # TEST 1: Checkout books (A and B) - Stock must auto-deduct
    checkout_payload = {
        "items": [
            {"book_id": id_a, "qty": 5},
            {"book_id": id_b, "qty": 3}
        ]
    }
    res = client.post('/api/checkout', json=checkout_payload)
    assert res.status_code == 201, f"Checkout failed: {res.get_json()}"
    tx1 = res.get_json()
    tx1_id = tx1['id']
    assert tx1['status'] == 'completed'
    assert len(tx1['items']) == 2

    # Check stock deduction
    with app.app_context():
        b_a = db.session.get(Book, id_a)
        b_b = db.session.get(Book, id_b)
        assert b_a.stock == init_stock_a - 5, f"Expected {init_stock_a - 5}, got {b_a.stock}"
        assert b_b.stock == init_stock_b - 3, f"Expected {init_stock_b - 3}, got {b_b.stock}"
    print("[OK] Test 1: Checkout auto-deducted stock correctly.")

    # TEST 2: Checkout with insufficient stock must fail (400) and not deduct
    res = client.post('/api/checkout', json={"items": [{"book_id": id_a, "qty": 99999}]})
    assert res.status_code == 400
    print("[OK] Test 2: Insufficient stock rejected with 400.")

    # TEST 3: Void transaction with Class A book WITHOUT PIN -> MUST BE REJECTED (403)
    res = client.post(f'/api/transactions/{tx1_id}/void', json={})
    assert res.status_code == 403
    assert res.get_json().get('requires_admin_pin') is True
    print("[OK] Test 3: Voiding Class A book without PIN blocked with 403.")

    # TEST 4: Void transaction with Class A book with WRONG PIN -> MUST BE REJECTED (403)
    res = client.post(f'/api/transactions/{tx1_id}/void', json={"admin_pin": "wrong_pin"})
    assert res.status_code == 403
    print("[OK] Test 4: Voiding Class A book with incorrect PIN blocked with 403.")

    # Ensure stocks are STILL deducted
    with app.app_context():
        b_a = db.session.get(Book, id_a)
        assert b_a.stock == init_stock_a - 5

    # TEST 5: Void transaction with Class A book with CORRECT PIN -> SUCCESS & AUTO-REVERT
    res = client.post(f'/api/transactions/{tx1_id}/void', json={"admin_pin": "123456"})
    assert res.status_code == 200
    assert res.get_json()['transaction']['status'] == 'voided'

    with app.app_context():
        b_a = db.session.get(Book, id_a)
        b_b = db.session.get(Book, id_b)
        assert b_a.stock == init_stock_a, f"Expected reverted stock {init_stock_a}, got {b_a.stock}"
        assert b_b.stock == init_stock_b, f"Expected reverted stock {init_stock_b}, got {b_b.stock}"
    print("[OK] Test 5: Voiding Class A book with valid PIN succeeded and fully reverted stock.")

    # TEST 6: Cannot void already voided transaction (400)
    res = client.post(f'/api/transactions/{tx1_id}/void', json={"admin_pin": "123456"})
    assert res.status_code == 400
    print("[OK] Test 6: Re-voiding already voided transaction rejected with 400.")

    # TEST 7: Checkout Class B & C only, then void WITHOUT PIN -> SHOULD SUCCEED without PIN
    res = client.post('/api/checkout', json={
        "items": [
            {"book_id": id_b, "qty": 2},
            {"book_id": id_c, "qty": 4}
        ]
    })
    assert res.status_code == 201
    tx2_id = res.get_json()['id']

    # Void tx2 without providing any admin_pin
    res = client.post(f'/api/transactions/{tx2_id}/void', json={})
    assert res.status_code == 200, f"Voiding Class B/C should not require PIN, got: {res.get_json()}"
    assert res.get_json()['transaction']['status'] == 'voided'

    with app.app_context():
        b_b = db.session.get(Book, id_b)
        b_c = db.session.get(Book, id_c)
        assert b_b.stock == init_stock_b
        assert b_c.stock == init_stock_c
    print("[OK] Test 7: Non-Class-A transaction voided without PIN and stock reverted.")

    # TEST 8: Verify GET /api/transactions
    res = client.get('/api/transactions')
    assert res.status_code == 200
    assert len(res.get_json()) == 2
    print("[OK] Test 8: GET /api/transactions returned all transactions.")

    print("\nALL STEP 2 TESTS PASSED SUCCESSFULLY!")

if __name__ == '__main__':
    run_step2_tests()
