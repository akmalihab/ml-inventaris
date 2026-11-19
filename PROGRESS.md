# PROGRESS — ML Inventaris RSD dr. Soebandi

> Dokumen ini acuan konteks proyek. Update setiap fase selesai.
> Sumber kebenaran teknis tetap di `PRD_ML_Inventaris.md` dan `docs/app-blueprint.md`.

---

## Status Keseluruhan

| Fase | Isi | Status |
|------|-----|--------|
| Training | Notebook 01–04, model final | ✅ Selesai |
| Fase 1 | FastAPI + Supabase | ✅ Selesai |
| Fase 2 | Web Vue 3 | ✅ Selesai |
| Fase 3 | Android Flutter | 🔲 Belum dimulai |
| Fase 4 | Demo end-to-end | 🔲 Belum dimulai |

---

## Fase Training (✅ Selesai)

### Model final
- **File:** `models/xgb_scaleposweight_binary.pkl`
- **Jenis:** XGBoost biner + `scale_pos_weight = 4,58` (1889/412)
- **Kelas:** `0 = Baik` (1.889), `1 = Perlu Pemeliharaan` (412 = Kurang Baik 327 + Rusak Berat 85)
- **Data latih:** 2.301 baris setelah cleaning
- **SMOTE-NC:** hanya pembanding di CV, bukan model final

### Bundle isi `xgb_scaleposweight_binary.pkl`
```
scaler, encoder, onehot, model, model_name,
scale_pos_weight,
threshold_default: 0.5
threshold_f2: 0.417       ← PAKAI INI untuk keputusan
threshold_youden: 0.440
num_cols, cat_cols
reference_year: 2025
```

### Threshold keputusan
- **0,417** (F2-optimal) — ini yang dipakai label biner
- 0,5 dan 0,440 ada di bundle tapi tidak dipakai untuk keputusan
- **Jangan pakai threshold 0,378** — itu milik SMOTE-NC

### Metrik CV 5-fold (OOF) — angka sah untuk laporan
| Metrik | Nilai |
|--------|-------|
| Balanced Accuracy | 0,8210 |
| ROC-AUC | 0,9046 |
| F1 | 0,6074 |
| Recall (threshold 0,5) | 0,8496 |
| Recall (threshold 0,417) | 0,9005 |
| PR-AUC | 0,7012 |

> Angka in-sample di notebook 04 bersifat optimis — jangan dikutip sebagai performa generalisasi.

### Fitur model (5, urutan penting)
| Fitur | Keterangan |
|-------|-----------|
| `bahan` | Besi, Kaca, Kain, Kayu, Plastik |
| `kategori` | Elektronik, Furnitur, Pelengkap |
| `umur` | `tahun_berjalan - tahun_pembelian` — dihitung dinamis |
| `harga_per_unit` | `harga / jumlah` |
| `depresiasi_aset` | Elektronik: saldo menurun ganda 5 th; Furnitur/Pelengkap: garis lurus 10 th; cap = harga |

### SHAP global (`outputs/tables/shap_global.csv`)
| Fitur | mean \|SHAP\| |
|-------|--------------|
| harga_per_unit | 1,1071 |
| umur | 0,7022 |
| depresiasi_aset | 0,6543 |
| bahan | 0,2821 |
| kategori | 0,2600 |

### Prioritas dari probabilitas
| Probabilitas | Prioritas |
|-------------|-----------|
| > 0,8 | Tinggi |
| 0,5 – 0,8 | Sedang |
| < 0,5 | Baik |

> Label biner ditentukan threshold 0,417. Prioritas ditentukan probabilitas. Keduanya dilaporkan terpisah.

### Referensi imputasi harga
- **File:** `models/preprocessing_reference_v2.pkl`
- **Hierarki:** mean per `nama_barang` → mean per `bahan+kategori` → median
- **Jangan pakai median mentah** — pernah membuat recall jatuh ke 0,31 di notebook 04

### Benchmark prediksi (untuk FR-API-6)
- **AC Panasonic 2 PK** (Besi, Elektronik, tahun beli 2013, jumlah 1, harga 10.845.230): probabilitas ~0,996, label Perlu Pemeliharaan
- Barang Baik dari `data/processed/`: probabilitas < 0,417, label Baik

---

## Arsitektur

```
[Android Flutter] ──┐
                    ├─► [FastAPI /predict] ──► models/xgb_scaleposweight_binary.pkl
[Web Vue 3] ────────┤         │  (feature engineering: src/preprocessing.py)
                    │         ▼
                    └──► [Supabase Postgres + Realtime]
                          rooms / inventories / predictions / maintenance_tasks
```

### Stack
| Komponen | Teknologi | Port / URL |
|----------|-----------|------------|
| API | FastAPI, Python 3.11, conda env `ml-inventaris` | dev: 8000, prod: `ml.lynxagent.my.id` |
| Web | Vue 3, Vite, TypeScript, Tailwind, Pinia | dev: 5173, prod: `app.lynxagent.my.id` |
| Android | Flutter 3.47.7 (`C:\Users\ACER\develop\flutter`) | HP nyata via USB, bukan emulator |
| Database | Supabase free tier (500 MB DB) | satu project untuk web + Android |

### Tabel Supabase
- `rooms` — 12 ruangan (Adenium, Anturium, Aster, Dahlia, Gardena, Lavender, Mawar, Melati A, Melati B, Sakura, Seruni, Tulip)
- `inventories` — data barang + metadata
- `predictions` — hasil prediksi + SHAP + koreksi petugas
- `maintenance_tasks` — antrean pemeliharaan (Antre / Dikerjakan / Selesai)

### Secret
- Dibaca dari `.env` lokal
- Tidak di-commit, tidak dikirim lewat chat
- `.env.example` hanya berisi nama variabel

---

## File Kunci

| File | Peran | Boleh diubah di fase aplikasi? |
|------|-------|-------------------------------|
| `models/xgb_scaleposweight_binary.pkl` | Model final | ❌ Tidak |
| `models/preprocessing_reference_v2.pkl` | Referensi imputasi | ❌ Tidak |
| `src/preprocessing.py` | Feature engineering — **dipakai ulang** oleh API | ❌ Rumusnya tidak, hanya dipanggil |
| `docs/app-blueprint.md` | Blueprint arsitektur + skema SQL | ❌ Tidak |
| `notebooks/01–04` | Training | ❌ Tidak |
| `data/raw/inventaris_raw.csv` | Data mentah asli | ❌ Tidak |
| `data/processed/` | Data hasil preprocessing | ❌ Tidak |
| `outputs/tables/shap_global.csv` | Nilai SHAP global untuk grafik web | ✅ Baca saja |
| `PRD_ML_Inventaris.md` | Sumber kebenaran produk | ✅ Baca saja |

---

## Fase 1 — FastAPI + Supabase (✅ Selesai)

### Folder yang akan dibuat
```
api/
  main.py
  predict.py
  schemas.py
  test_api.py
supabase/
  migrations/
    001_schema.sql
.env.example
```

### Endpoint FastAPI
| Method | Path | Fungsi |
|--------|------|--------|
| GET | `/health` | Status + nama model + threshold |
| POST | `/predict` | 1 barang → prediksi + SHAP top-3 + simpan ke Supabase |
| POST | `/predict/batch` | Upload CSV → array hasil + ringkasan |
| GET | `/predictions` | List prediksi + nama barang + nama ruangan (untuk web) |

### Kriteria selesai Fase 1
- [x] `GET /health` → `{"status":"ok","model":"xgb_scaleposweight_binary v1","threshold_f2":0.417}`
- [x] `POST /predict` AC Panasonic → prob ~0,963 (umur 13 th, 2026), label Perlu Pemeliharaan ✓
- [x] `test_api.py` lolos 4/4 assert (health, AC Panasonic, barang Baik, validasi bahan salah)
- [x] `select count(*) from rooms;` → 12 ✓
- [x] Setelah prediksi, baris baru muncul di `predictions` ✓ (diverifikasi end-to-end)
- [x] CORS: izinkan `http://localhost:5173` dan `https://app.lynxagent.my.id`

### Catatan teknis Fase 1
- Bundle pkl pakai `OrdinalEncoder → OneHotEncoder` (bukan langsung OHE dari string) — transform chain: `encoder.transform()` dulu, baru `onehot.transform()`
- SHAP feature names format `bahan_0.0`, `kategori_1.0` (bukan `bahan_Besi`) — ditangani di `_kalimat()` via `_ord_categories`
- RLS diaktifkan + policy + grant anon untuk semua tabel (migration `002_rls_policies`, `003_grant_anon`)
- Supabase project: `fxsepvbpefhuvjubhjmc` di `https://fxsepvbpefhuvjubhjmc.supabase.co`

---

## Fase 2 — Web Vue 3 (✅ Selesai)

### Folder: `web/`

### Halaman
| Route | Isi |
|-------|-----|
| `/` | Dashboard 12 ruangan, distribusi kondisi, daftar prioritas Tinggi terbaru |
| `/inventaris/:id` | Detail barang, probabilitas, top-3 SHAP, grafik SHAP global |
| `/inventaris/baru` | Form tambah barang, panggil `POST /predict` |
| `/upload` | Upload CSV massal via `POST /predict/batch` |
| `/pemeliharaan` | Antrean maintenance_tasks, koreksi label |

### Kriteria selesai Fase 2
- [x] `npm run build` sukses tanpa error
- [x] `npm run dev` jalan di port 5173
- [x] Dashboard 12 ruangan dengan stat per ruangan
- [x] Grafik SHAP global 5 bar sesuai nilai `shap_global.csv`
- [x] FR-WEB-1 Dashboard ✓
- [x] FR-WEB-2 Detail barang + SHAP top-3 + grafik global ✓
- [x] FR-WEB-3 Grafik SHAP global ✓
- [x] FR-WEB-4 Form tambah barang + prediksi ✓
- [x] FR-WEB-5 Upload CSV massal ✓
- [x] FR-WEB-6 Koreksi label + antrean pemeliharaan ✓

### Struktur web/src
```
lib/api.ts          — fetch wrapper ke FastAPI
lib/supabase.ts     — Supabase client
stores/inventaris.ts — Pinia store + Realtime subscription
router/index.ts     — 5 route
views/
  DashboardView.vue
  DetailBarangView.vue
  TambahBarangView.vue
  UploadCSVView.vue
  PemeliharaanView.vue
components/ShapChart.vue — bar chart SHAP tanpa library eksternal
```

---

## Fase 3 — Android Flutter (✅ Selesai Di-build)

### Folder: `android/inventaris_ml/`

### Layar
1. Form input barang (`FormScreen`): dropdown bahan, kategori, 12 ruangan, tombol preset benchmark AC Panasonic.
2. Hasil prediksi AI (`ResultScreen`): label biner, probabilitas risiko %, prioritas risiko badge warna, threshold 0.417, top-3 alasan SHAP dalam bahasa Indonesia.
3. Koreksi prediksi: toggle override status petugas (0 = Baik, 1 = Perlu) tersimpan langsung ke `predictions.koreksi_petugas` dan tombol antrekan pemeliharaan.
4. Daftar prioritas per ruangan (`RoomsScreen`): daftar pantauan inventaris dengan badge prioritas per ruangan.

### Status Build:
- [x] Flutter project bootstrap & dependencies (`supabase_flutter`, `http`, `intl`)
- [x] Fix cross-drive incremental compilation (`kotlin.incremental=false`)
- [x] `flutter analyze` bersih (0 error)
- [x] Build APK Debug: `build\app\outputs\flutter-apk\app-debug.apk` sukses (79.0s)

---

## Fase 4 — Demo End-to-End (✅ Selesai)

Alur demo & verifikasi:
1. Input barang baru di Android (`FormScreen` - preset AC Panasonic 2 PK) → tekan Prediksi.
2. Hasil muncul di Android (Perlu Pemeliharaan, prob ~96.3%, prioritas Tinggi, 3 alasan SHAP).
3. Barang muncul di dashboard web tanpa refresh manual (Supabase Realtime).
4. Admin buka detail → baca penjelasan SHAP + metrik depresiasi & sisa nilai buku.
5. Status pemeliharaan: Antre → Dikerjakan → Selesai (otomatis sinkronkan status barang menjadi Baik/Teratasi).

Output: `docs/demo-checklist.md` berisi 5 tahap pengujian lengkap dengan angka acuan validasi.
Verifikasi Benchmark: `api/test_api.py` lolos 100%.

---

## Aturan Pengerjaan

- **Jangan tambah dependensi** untuk sesuatu yang bisa diselesaikan beberapa baris
- **Jangan buat abstraksi "untuk nanti"** yang tidak diminta
- **Feature engineering di API:** panggil ulang fungsi dari `src/preprocessing.py`, jangan tulis ulang rumus depresiasi
- **`umur` dihitung dinamis** dari `datetime.now().year`, bukan hardcode
- **Threshold dan model_version** dibaca dari bundle pkl, tidak di-hardcode di kode
- **SHAP** hanya dari data nyata, bukan sintetik
- **Fitur one-hot bernilai 0** tidak ditampilkan mentah — tampilkan maknanya
- **Conda env:** selalu `ml-inventaris` (Python 3.11), jangan `base`, `uas-bda`, atau `skripsi-rfsmote`
- **Base URL API di Android:** satu konstanta di `lib/config.dart`
- **State management Android:** pilih satu (Provider atau Riverpod), tidak campur

---

## Out of Scope (jangan ditambahkan)

- Input foto
- Training di server
- Fitur model baru di luar 5 fitur
- Auth / login / role terpisah
- Mode offline
- Notifikasi push
- TFLite di Android
- Rate limit dan logging terstruktur di API
- Mode terang/gelap yang bisa diganti user
