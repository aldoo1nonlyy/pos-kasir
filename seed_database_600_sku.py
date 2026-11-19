import os
import sys

# Menjalankan seeder dari direktori backend/pos-backend
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
POS_BACKEND_DIR = os.path.join(SCRIPT_DIR, 'backend', 'pos-backend')

if POS_BACKEND_DIR not in sys.path:
    sys.path.insert(0, POS_BACKEND_DIR)

from seed_database_600_sku import seed_from_csv

if __name__ == '__main__':
    seed_from_csv()
