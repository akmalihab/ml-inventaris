# ML Inventaris Nonmedis — RSD dr. Soebandi

> Sistem Klasifikasi & Prediksi Kondisi Inventaris Nonmedis Berbasis Machine Learning (XGBoost + TreeSHAP) dengan Dashboard Web (Vue 3) dan Aplikasi Mobile Lapangan (Flutter Android).

Lanjutan penelitian skripsi S1 Akmal Ihab Syauqi (Universitas Jember, disetujui Juli 2026) untuk mata kuliah Pembelajaran Mesin, Magister Informatika Universitas Islam Indonesia (UII).

---

## 1. Ringkasan Eksekutif & Latar Belakang

Penilaian kondisi inventaris nonmedis di 12 ruangan rawat inap kelas 3 RSD dr. Soebandi selama ini dilakukan secara manual, berkala, dan cenderung subjektif. Tingkat hunian ruangan (Bed Occupancy Rate) yang tinggi (~85%) menyebabkan beban penggunaan aset sangat intensif, sehingga barang yang mengalami degradasi sering kali terlambat diidentifikasi hingga mencapai status rusak berat.

Aplikasi ini mengintegrasikan model machine learning klasifikasi biner dan Explainable AI (XAI) ke dalam sistem operasional nyata:
- **Petugas Lapangan (Android)**: Menginput spesifikasi aset secara mobile, langsung memperoleh prediksi kelayakan, tingkat risiko, dan 3 alasan utama (SHAP) dalam bahasa yang mudah dipahami, serta dapat melakukan koreksi verifikasi fisik.
- **Admin & Manajemen (Web)**: Memantau kondisi seluruh ruangan secara terpusat, membaca interpretasi SHAP global dan lokal, mengelola data massal via CSV, serta mengatur alur tugas pemeliharaan.

---

## 2. Arsitektur Sistem

Seluruh komponen client (Web dan Android) terhubung ke satu backend inferensi (FastAPI) dan satu basis data operasional realtime (Supabase Postgres):

```
┌─────────────────────────────────┐
│     Petugas Lapangan Mobile     │
│       (Android Flutter)         │
└────────────────┬────────────────┘
                 │
                 ├──► [FastAPI /predict] ──► Model: models/xgb_scaleposweight_binary.pkl
                 │          │                (Feature Engineering: src/preprocessing.py)
                 │          ▼
┌────────────────┴────────────────┐
│      Admin & Manajemen Web      │◄──────── [Supabase Postgres + Realtime]
│         (Vue 3 + Vite)          │           rooms / inventories / predictions / maintenance_tasks
└─────────────────────────────────┘
```

### Stack Teknologi
- **Machine Learning Core**: Python 3.11, XGBoost, Scikit-Learn, SHAP (TreeExplainer).
- **Backend API**: FastAPI, Uvicorn, Pydantic v2.
- **Database & Realtime**: Supabase Postgres, Realtime WebSockets, Database Views.
- **Web Frontend**: Vue 3 (Composition API), Vite, TypeScript, Tailwind CSS, Pinia.
- **Mobile Client**: Flutter 3.47.7, Dart, Supabase Flutter Client.

---

## 3. Spesifikasi Model Machine Learning (Locked)

Model telah melalui evaluasi 5-fold cross validation pada data inventaris riil RSD dr. Soebandi:

- **Algoritma Final**: XGBoost Binary Classifier dengan pembobotan kelas `scale_pos_weight = 4.58` (1.889 Baik / 412 Perlu Pemeliharaan).
- **File Bundle**: `models/xgb_scaleposweight_binary.pkl` (memuat scaler, encoder, model, threshold, dan konstanta referensi).
- **Target Kelas**:
  - `0 = Baik` (1.889 baris data latih).
  - `1 = Perlu Pemeliharaan` (412 baris = gabungan kondisi Kurang Baik & Rusak Berat).
- **Threshold Keputusan**: **`0.417`** (F2-optimal, mengutamakan *Recall* untuk meminimalkan risiko aset rusak terlewat).
- **Metrik CV 5-Fold (Out-Of-Fold)**:
  - Balanced Accuracy: `0.8210`
  - ROC-AUC: `0.9046`
  - Recall (Threshold 0.417): `0.9005`
  - PR-AUC: `0.7012`
- **Fitur Terpilih (5 Fitur Terkunci)**:
  1. `bahan`: Besi, Kaca, Kain, Kayu, Plastik.
  2. `kategori`: Elektronik, Furnitur, Pelengkap.
  3. `umur`: Tahun berjalan dinamis dikurangi `tahun_pembelian`.
  4. `harga_per_unit`: Total perolehan dibagi kuantitas barang.
  5. `depresiasi_aset`: Dihitung otomatis berbasis masa manfaat (Elektronik saldo menurun ganda 5 thn; Furnitur/Pelengkap garis lurus 10 thn).
- **Imputasi Harga**: Hierarkis bertingkat (mean nama barang $\rightarrow$ mean bahan+kategori $\rightarrow$ median) melalui `models/preprocessing_reference_v2.pkl`.

---

## 4. Prioritas & Explainability (TreeSHAP)

### Penentuan Prioritas Operasional
| Probabilitas Risiko ($P$) | Prioritas | Tindakan |
|---|---|---|
| $P > 0.80$ | **Tinggi (Kritis)** | Tindakan segera / masuk antrean kritis |
| $0.50 \le P \le 0.80$ | **Sedang** | Penjadwalan inspeksi berkala |
| $P < 0.50$ | **Baik** | Pemeliharaan rutin / monitoring |

> **Catatan:** Label biner ditentukan oleh threshold $0.417$, sedangkan prioritas ditentukan oleh nilai probabilitas kontinu.

### Fitur SHAP & Metrik Tambahan
- **SHAP Lokal**: Menghitung kontribusi tiap fitur terhadap log-odds risiko untuk setiap barang secara instan via endpoint `/explain`.
- **Translasi Alasan Manusiawi**: Representasi SHAP diterjemahkan menjadi 3 kalimat bahasa Indonesia sederhana pada antarmuka Android dan Web.
- **Rasio Susut (%) & Sisa Nilai Buku**: Depresiasi aset dikonversi menjadi persentase penurunan nilai terhadap harga asli dan taksiran sisa nilai buku (Rp).

---

## 5. Fitur Produk

### A. Web Admin / Manajemen (`/web`)
1. **Executive Dashboard**: Ringkasan beban per 12 ruangan, statistik rasio aset terawat, antrean prioritas kritis terkini, dan toggle Dark/Light mode persisten.
2. **Data Ruangan & Inventaris**: Tabel inventaris per ruangan responsif, filter status dinamis, dan pagination interaktif.
3. **Analisis SHAP**: Visualisasi kontribusi fitur lokal per barang, perbandingan terhadap SHAP global, serta metrik susut nilai buku.
4. **Alur Pemeliharaan**: Antrean pemeliharaan (`Antre` $\rightarrow$ `Dikerjakan` $\rightarrow$ `Selesai`). Status `Selesai` otomatis menyinkronkan status aset menjadi Baik di seluruh sistem.
5. **Batch Upload CSV**: Upload data inventaris massal dengan evaluasi otomatis dan logging Supabase.

### B. Aplikasi Android Petugas (`/android/inventaris_ml`)
1. **Form Input Barang**: Pemilihan 12 ruangan, spesifikasi aset, dan tombol preset benchmark (AC Panasonic 2 PK).
2. **Layar Hasil Prediksi**: Probabilitas, badge prioritas berwarna, threshold $0.417$, dan 3 alasan penentu rekomendasi AI.
3. **Koreksi Verifikasi Fisik**: Opsi override petugas lapangan jika kondisi aktual berbeda, langsung tersimpan ke `predictions.koreksi_petugas`.
4. **Pantau Inventaris Ruangan**: Pencarian cepat dan monitoring status aset langsung dari ponsel.

---

## 6. Struktur Direktori Proyek

```
ml-inventaris/
├── api/                             # Backend FastAPI
│   ├── main.py                      # Endpoint REST (/predict, /explain, /batch)
│   ├── predict.py                   # Engine inferensi & TreeSHAP
│   ├── schemas.py                   # Skema validasi Pydantic
│   └── test_api.py                  # Unit testing & benchmark prediksi
├── web/                             # Web Frontend Vue 3 + Vite
│   ├── src/
│   │   ├── views/                   # Dashboard, Ruangan, Detail, SHAP, Tugas
│   │   ├── stores/                  # Pinia store & Supabase Realtime
│   │   ├── style.css                # Tailwind CSS + Light/Dark theme overrides
│   │   └── App.vue                  # Shell navigasi & topbar
│   └── package.json
├── android/inventaris_ml/           # Aplikasi Mobile Flutter
│   ├── lib/
│   │   ├── screens/                 # FormScreen, ResultScreen, RoomsScreen
│   │   ├── services/                # ApiService & SupabaseService
│   │   ├── models/                  # Data models Dart
│   │   ├── config.dart              # Konfigurasi endpoint
│   │   └── main.dart                # Entry point aplikasi
│   └── pubspec.yaml
├── models/                          # Binary model & referensi preprocessing
├── notebooks/                       # 01-04 Eksperimen ML & Validasi
├── src/                             # Preprocessing module
├── supabase/migrations/             # Skema SQL & Views
├── PRD_ML_Inventaris.md             # Dokumen Product Requirements
├── PROGRESS.md                      # Pelacak kemajuan fase
└── README.md                        # File dokumentasi ini
```

---

## 7. Panduan Menjalankan Sistem

### Prasyarat Lingkungan
- Conda / Miniconda (Python 3.11)
- Node.js (v18+) & npm
- Flutter SDK (v3.24+) & Android SDK Platform 35

### 1. Menjalankan Backend FastAPI
```bash
# Aktifkan conda environment
conda activate ml-inventaris

# Jalankan server API (port 8000)
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
```
Akses dokumentasi Swagger UI di: `http://localhost:8000/docs`

### 2. Menjalankan Web Frontend
```bash
cd web

# Salin konfigurasi environment jika belum ada
cp .env.example .env

# Install dependensi dan jalankan dev server
npm install
npm run dev
```
Buka dashboard web di: `http://localhost:5173`

### 3. Menjalankan Aplikasi Android (Flutter)
Bila menggunakan HP fisik via kabel USB (USB Debugging aktif):
```bash
# Forward port agar HP bisa menjangkau FastAPI di laptop
adb reverse tcp:8000 tcp:8000

# Jalankan Flutter ke device
cd android/inventaris_ml
flutter run
```
*Catatan: Konfigurasi default API diarahkan ke `http://10.0.2.2:8000` (untuk emulator) atau `http://127.0.0.1:8000` (bila menggunakan `adb reverse`). Pengaturan dapat disesuaikan di `lib/config.dart`.*

---

## 8. Verifikasi Benchmark Prediksi

Pengujian integritas model dilakukan menggunakan data uji acuan (*golden test*):
- **Kasus Uji Aset Kritis (AC Panasonic 2 PK)**:
  - Input: Besi, Elektronik, Tahun Beli 2013, Kuantitas 1, Harga Rp10.845.230.
  - Hasil Inferensi: Probabilitas risiko $\approx 0.996$, Label: **Perlu Pemeliharaan**, Prioritas: **Tinggi**.
- **Jalankan Uji Otomatis**:
  ```bash
  python -m pytest api/test_api.py -v
  ```

---

## 9. Lisensi & Hak Cipta
Dikembangkan untuk keperluan akademik Magister Informatika UII & RSD dr. Soebandi Jember.
