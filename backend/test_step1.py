import json
from app import create_app
from models import db, Book, Setting

def run_tests():
    # Setup test app with in-memory SQLite database
    test_config = {
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:'
    }
    app = create_app(test_config=test_config)
    client = app.test_client()

    with app.app_context():
        # Verify initial seeds
        setting = Setting.query.first()
        assert setting is not None, "Setting should be seeded"
        assert setting.admin_pin == '123456', f"Default admin PIN should be '123456', got {setting.admin_pin}"
        
        books_count = Book.query.count()
        assert books_count == 7, f"Expected 7 seeded books, got {books_count}"
        print(f"[OK] Database initialized and seeded with {books_count} sample books and Setting table.")

    # 1. Test Health Check
    res = client.get('/api/health')
    assert res.status_code == 200
    assert res.get_json()['status'] == 'healthy'
    print("[OK] Health check passed.")

    # 2. Test GET /api/books
    res = client.get('/api/books')
    assert res.status_code == 200
    books = res.get_json()
    assert len(books) == 7
    print(f"[OK] GET /api/books returned {len(books)} books.")

    # 3. Test Search and Filter
    res = client.get('/api/books?search=Filosofi')
    assert res.status_code == 200
    assert len(res.get_json()) == 1
    assert res.get_json()[0]['title'] == 'Filosofi Teras'
    print("[OK] GET /api/books?search=Filosofi correctly filtered.")

    res = client.get('/api/books?abc_class=A')
    assert res.status_code == 200
    for b in res.get_json():
        assert b['abc_class'] == 'A'
    print("[OK] GET /api/books?abc_class=A correctly filtered.")

    # 4. Test POST /api/books (Create new book)
    new_book_payload = {
        "barcode": "9786021234567",
        "title": "Clean Code in Python",
        "price": 145000.0,
        "stock": 12,
        "abc_class": "B"
    }
    res = client.post('/api/books', json=new_book_payload)
    assert res.status_code == 201
    created_book = res.get_json()
    new_id = created_book['id']
    assert created_book['title'] == "Clean Code in Python"
    assert created_book['barcode'] == "9786021234567"
    print(f"[OK] POST /api/books created book with ID {new_id}.")

    # 5. Test Duplicate Barcode rejection (409)
    res = client.post('/api/books', json=new_book_payload)
    assert res.status_code == 409
    print("[OK] Duplicate barcode validation (409 Conflict) passed.")

    # 6. Test GET /api/books/<id>
    res = client.get(f'/api/books/{new_id}')
    assert res.status_code == 200
    assert res.get_json()['title'] == "Clean Code in Python"
    print(f"[OK] GET /api/books/{new_id} verified.")

    # 7. Test PUT /api/books/<id>
    update_payload = {
        "price": 150000.0,
        "stock": 18
    }
    res = client.put(f'/api/books/{new_id}', json=update_payload)
    assert res.status_code == 200
    updated_book = res.get_json()
    assert updated_book['price'] == 150000.0
    assert updated_book['stock'] == 18
    print(f"[OK] PUT /api/books/{new_id} updated price and stock.")

    # 8. Test GET /api/books/barcode/<barcode>
    res = client.get(f'/api/books/barcode/9786021234567')
    assert res.status_code == 200
    assert res.get_json()['id'] == new_id
    print("[OK] Barcode lookup endpoint /api/books/barcode/<barcode> passed.")

    # 9. Test DELETE /api/books/<id>
    res = client.delete(f'/api/books/{new_id}')
    assert res.status_code == 200
    res = client.get(f'/api/books/{new_id}')
    assert res.status_code == 404
    print(f"[OK] DELETE /api/books/{new_id} and 404 verification passed.")

    print("\nALL STEP 1 TESTS PASSED SUCCESSFULLY!")

if __name__ == '__main__':
    run_tests()
