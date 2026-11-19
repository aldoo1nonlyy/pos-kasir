# POS Kasir Toko Buku (Dynamic ABC Inventory Management)

Aplikasi Point of Sales (POS) dan Manajemen Inventori Toko Buku modern berbasis analisis **ABC (Prinsip Pareto 80/20)** dengan arsitektur **Flutter Frontend** dan **Python Flask Backend**.

---

## Fitur Utama

1. **Kasir Penjualan (POS)**
   - Pindai barcode ISBN / pencarian judul buku instan.
   - Perhitungan otomatis diskon, total tagihan, uang tunai, dan kembalian.
   - Pengurangan stok otomatis secara real-time saat checkout.
   - Filter koleksi buku per kategori (Kelas A, B, C) serta status ketersediaan stok.
   - Pengurutan katalog berdasarkan nama, harga, dan stok.

2. **Katalog & Stok Buku**
   - Manajemen katalog buku lengkap (Judul, Barcode ISBN, Harga, Stok, dan Kategori ABC).
   - Pencarian instan dan filter berdasarkan kategori maupun status stok.
   - Pengurutan multi-kriteria (ID, Judul A-Z/Z-A, Stok, Harga, dan Tanggal Cek Fisik).
   - Penyesuaian stok fisik (Stock Opname) langsung per judul buku.
   - Hak akses manajemen buku (Tambah, Edit, Hapus) dengan otorisasi Manajer.

3. **Riwayat Transaksi Penjualan**
   - Daftar transaksi lengkap beserta detail buku yang dibeli dan nominal.
   - Filter tanggal fleksibel: *Hari Ini*, *7 Hari Terakhir*, *30 Hari Terakhir*, *Bulan Ini*, serta **Kalender Rentang Tanggal Khusus (Date Range Picker)**.
   - Pengurutan transaksi: *Terbaru ke Terlama* atau *Terlama ke Terbaru*.
   - Filter status transaksi: *Semua*, *Lunas / Selesai*, atau *Dibatalkan (Void)*.
   - Cetak struk digital transaksi.
   - **Keamanan Pembatalan Transaksi (Void Rule)**: Pembatalan transaksi yang memuat buku **Kelas A (Terlaris)** wajib memasukkan PIN Manajer Toko (default: `123456`) untuk mencegah kecurangan.

4. **Peringatan Jadwal Cek Stok Fisik (Stock Opname)**
   - Jadwal pengecekan siklus otomatis berdasarkan prioritas penjualan:
     - **Kelas A (Paling Laris)**: Wajib diperiksa setiap 7 hari.
     - **Kelas B (Laris Sedang)**: Wajib diperiksa setiap 30 hari.
     - **Kelas C (Kurang Laris)**: Wajib diperiksa setiap 90 hari.
   - Kartu statistik responsif dan interaktif untuk menyaring buku yang jatuh tempo.
   - Filter kategori dan pengurutan berdasarkan keterlambatan, judul, dan stok.
   - Form pencatatan hasil cek fisik langsung mereset status jatuh tempo.

5. **Peringkat Buku Terlaris (Analisis ABC Pareto Dinamis)**
   - Klasifikasi otomatis 600 SKU buku berdasarkan kontribusi omzet riil:
     - **Kelas A**: Menyumbang ~80% dari total penjualan.
     - **Kelas B**: Menyumbang ~15% dari total penjualan.
     - **Kelas C**: Menyumbang ~5% dari total penjualan.
   - Pilihan rentang waktu analisis (7 hari, 30 hari, 90 hari, atau semua periode).
   - Preview distribusi persentase dan kurva akumulasi omzet.
   - Tombol *Terapkan ke Sistem* untuk mengupdate klasifikasi kelas buku di database.
   - Filter dan pengurutan tabel analisis berdasarkan omzet, qty terjual, dan judul.

---

## Struktur Folder

```text
pos_kasir/
├── backend/
│   ├── app.py                     # Entry point Flask REST API
│   ├── models.py                  # Model SQLAlchemy (Book, Transaction, TransactionItem, Setting)
│   ├── requirements.txt           # Dependensi Python
│   ├── pos-backend/
│   │   ├── pos_tokobuku.db        # Database SQLite (600 SKU Buku, 1080 Transaksi)
│   │   ├── books_dataset_600_sku.csv
│   │   └── transactions_dataset_600_sku.csv
│   ├── test_step1.py              # Unit test CRUD Buku & API
│   ├── test_step2.py              # Unit test POS Checkout & Void dengan PIN
│   ├── test_step3.py              # Unit test Analisis ABC Pareto
│   └── test_step4.py              # Unit test Opname Alert Logic
├── frontend/
│   ├── lib/
│   │   ├── main.dart              # Entry point Flutter
│   │   ├── providers/             # State management (Provider)
│   │   ├── screens/               # Layar aplikasi (POS, Inventory, History, Alerts, ABC)
│   │   └── services/              # HTTP client API service
│   └── pubspec.yaml               # Dependensi Flutter
├── run_app.ps1                    # Script launcher PowerShell (Backend + Web)
├── run_app.bat                    # Script launcher CMD
└── README.md
```

---

## Cara Menjalankan Aplikasi

### 1. Menggunakan Launcher Otomatis (Windows)
Jalankan file script launcher di root project:

```powershell
.\run_app.ps1
```
atau via Command Prompt:
```cmd
run_app.bat
```

### 2. Menjalankan secara Manual

#### Backend Flask
```powershell
cd backend
.\venv\Scripts\activate
python app.py
```
*Backend berjalan di: `http://127.0.0.1:5000`*

#### Frontend Flutter Web
```powershell
cd frontend
flutter run -d chrome --web-port=8080
```
*Frontend terbuka di browser: `http://localhost:8080`*

---

## Pengujian (Unit Tests)

Jalankan seluruh test suite backend untuk memverifikasi logika bisnis:

```powershell
python backend/test_step1.py
python backend/test_step2.py
python backend/test_step3.py
python backend/test_step4.py
```
