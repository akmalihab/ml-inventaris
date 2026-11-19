# PRD: Aplikasi ML Inventaris Nonmedis RSD dr. Soebandi

- **Versi:** 1.0
- **Tanggal:** 19 November 2026
- **Pemilik produk:** Akmal Ihab Syauqi (Bagas)
- **Status:** Draf untuk dibangun — fase training selesai, fase aplikasi belum dimulai
- **Dokumen terkait:** `docs/app-blueprint.md`, `notebooks/01-04`, skripsi S1
  *Penerapan Data Mining untuk Klasifikasi Kondisi Inventaris Nonmedis
  menggunakan Random Forest dan SMOTE* (UN EJ, disetujui 16 Juli 2026)
- **Menggantikan:** `PROMPT_OPCODE_FASE_APLIKASI.md` (versi prompt untuk
  opencode). Dokumen ini adalah sumber kebenaran yang sama, dibungkus
  sebagai PRD. Isi teknis tidak berubah.

## 1. Ringkasan

Aplikasi ini melanjutkan skripsi S1 Bagas menjadi produk yang bisa
dipakai: sistem klasifikasi kondisi inventaris nonmedis di RSD
dr. Soebandi, dengan aplikasi web untuk admin/manajer dan aplikasi
Android untuk petugas lapangan, yang saling terhubung lewat satu
backend dan satu database.

Masalah yang diselesaikan: penilaian kondisi inventaris di 12 ruangan
rawat inap kelas 3 masih manual dan subjektif, padahal tingkat hunian
sekitar 85%. Akibatnya barang yang sudah perlu pemeliharaan bisa
terlewat sampai rusak berat. Aplikasi ini memberi prediksi kondisi
barang beserta alasan dan prioritasnya, supaya pemeliharaan bisa
diantrekan sebelum barang rusak.

Produk ini dibuat untuk mata kuliah Pembelajaran Mesin, Magister
Informatika UII. Bukan produk komersial dan bukan pengganti sistem
rumah sakit yang sudah ada.

## 2. Tujuan dan kriteria sukses

Tujuan produk:

1. Petugas lapangan bisa memasukkan data satu barang di Android dan
   langsung mendapat prediksi kondisi, probabilitas, prioritas, dan
   tiga alasan yang bisa dibaca orang awam.
2. Admin dan manajer bisa melihat kondisi inventaris per 12 ruangan
   di web, mengoreksi label yang salah, dan mengelola antrean
   pemeliharaan.
3. Setiap prediksi yang dibuat tersimpan, bisa dilacak, dan koreksi
   petugas tersimpan sebagai data latih baru.

Produk ini dianggap berhasil bila demo end-to-end berikut berjalan:
input barang baru di Android, prediksi muncul, barang itu terlihat di
dashboard web tanpa refresh manual, koreksi label di web tersimpan,
dan status pemeliharaannya bisa diubah dari Antre menjadi Dikerjakan
lalu Selesai.

## 3. Pengguna

| Peran | Aplikasi | Yang dilakukan |
|---|---|---|
| Petugas lapangan | Android (Flutter) | Input barang, lihat hasil prediksi, koreksi bila prediksi salah, lihat daftar prioritas per ruangan |
| Admin / manajer | Web (Vue 3) | Lihat dashboard per ruangan, detail barang dan penjelasan SHAP, tambah/ubah/hapus inventaris, upload CSV massal, koreksi label, kelola antrean pemeliharaan |

Tidak ada peran lain di versi ini. Tidak ada pembedaan hak akses
berbasis role di luar pembagian aplikasi di atas.

## 4. Ruang lingkup

### 4.1 Yang termasuk

- API prediksi (FastAPI) yang memuat model final dan menghitung
  TreeSHAP per barang.
- Database Supabase: ruangan, inventaris, prediksi, tugas
  pemeliharaan, dengan Realtime antara Android dan web.
- Web admin/manajer: dashboard, detail barang, CRUD inventaris,
  upload CSV, koreksi label, antrean pemeliharaan.
- Android petugas: form input, hasil prediksi, koreksi, daftar
  prioritas.
- Demo end-to-end dan checklist demo.

### 4.2 Yang tidak termasuk (out of scope)

Yang berikut ini sengaja tidak dibuat di versi ini dan tidak boleh
ditambahkan tanpa keputusan baru:

- Input foto. Android hanya form. Foto tidak dipakai sebagai fitur
  model.
- Training di server. Training tetap di notebook di laptop, API
  hanya inference.
- Fitur model baru di luar lima fitur yang sudah dikunci. Tambah
  fitur berarti ulangi notebook 02-03 dulu.
- Auth dan role terpisah, login Android, mode offline, notifikasi
  push.
- Mode terang/gelap yang bisa diganti, animasi di luar hover dan
  transisi standar.
- Rate limit dan logging terstruktur di API.

## 5. Model machine learning (sudah dikunci)

Fase training sudah selesai. Semua angka di bagian ini berasal dari
notebook 01-04 yang sudah di-run dengan CSV asli. Model tidak boleh
diganti di fase aplikasi.

- **Model final:** XGBoost biner + `scale_pos_weight = 4,58`
  (1889/412). SMOTE-NC hanya pembanding di CV, bukan model final.
- **Bundle:** `models/xgb_scaleposweight_binary.pkl`, berisi
  `scaler`, `encoder`, `onehot`, `model`, `model_name`,
  `scale_pos_weight`, `threshold_default: 0.5`,
  `threshold_f2: 0.417`, `threshold_youden: 0.440`, `num_cols`,
  `cat_cols`, `reference_year: 2025`.
- **Kelas:** 0 = Baik (1.889 baris), 1 = Perlu Pemeliharaan
  (412 baris = Kurang Baik 327 + Rusak Berat 85). Data latih
  2.301 baris setelah cleaning. Label asli tiga kelas tetap
  disimpan sebagai `kondisi_asli` untuk audit.
- **Threshold keputusan:** 0,417 (F2-optimal, F2=0,746).
  Threshold 0,5 tidak dipakai sebagai keputusan. Threshold 0,378
  milik SMOTE-NC dan tidak boleh dipakai untuk model ini.
- **Metrik CV 5-fold (OOF), angka yang sah dikutip di laporan:**
  Balanced Accuracy 0,8210, ROC-AUC 0,9046, F1 0,6074,
  Recall 0,8496 di threshold 0,5 dan 0,9005 di threshold 0,417,
  PR-AUC 0,7012.
- **Fitur (5, urutan penting):** `bahan`, `kategori`, `umur`,
  `harga_per_unit`, `depresiasi_aset`.
  - `bahan`: Besi, Kaca, Kain, Kayu, Plastik.
  - `kategori`: Elektronik, Furnitur, Pelengkap.
  - `umur` = tahun berjalan - `tahun_pembelian`, dihitung dinamis,
    bukan hardcode tahun.
  - `harga_per_unit` = `harga` / `jumlah`.
  - `depresiasi_aset`: Elektronik saldo menurun ganda, masa
    manfaat 5 tahun; Furnitur/Pelengkap garis lurus, 10 tahun;
    di-cap maksimal sama dengan harga. Rumus ada di
    `src/preprocessing.py` (`depresiasi_row`, `add_depresiasi`)
    dan harus dipakai ulang, bukan ditulis ulang.
- **Imputasi harga bila `harga` kosong:** hierarkis, mean per
  `nama_barang`, lalu mean per `bahan`+`kategori`, lalu median.
  Referensi di `models/preprocessing_reference_v2.pkl`. Median
  mentah tidak boleh dipakai. Median mentah pernah membuat recall
  jatuh ke 0,31 di notebook 04 sebelum diperbaiki.
- **Prioritas dari probabilitas:** di atas 0,8 Tinggi, 0,5-0,8
  Sedang, di bawah 0,5 Baik. Label biner ditentukan threshold
  0,417, prioritas ditentukan probabilitas, keduanya dilaporkan.
- **Explainability (TreeSHAP):** SHAP global di web, mean |SHAP|
  harga_per_unit 1,1071, umur 0,7022, depresiasi_aset 0,6543,
  bahan 0,2821, kategori 0,2600. Top-3 alasan per barang ditulis
  sebagai kalimat biasa di Android. SHAP hanya dihitung dari data
  nyata, bukan data sintetik. Fitur one-hot bernilai 0, contohnya
  `bahan_Kayu` dengan nilai 0,000, tidak boleh ditampilkan
  mentah-mentah sebagai alasan. Yang ditampilkan adalah artinya,
  yaitu ketiadaan nilai itu yang mendorong prediksi.

## 6. Arsitektur dan teknologi

```
[Android Flutter] ──┐
                    ├─► [FastAPI /predict] ──► model models/xgb_scaleposweight_binary.pkl
[Web Vue 3] ────────┤         │  (feature engineering pakai ulang src/preprocessing.py)
                    │         ▼
                    └──► [Supabase Postgres + Realtime]
                          rooms / inventories / predictions / maintenance_tasks
```

- Satu project Supabase dipakai web dan Android. Alur data:
  Android input, FastAPI prediksi, hasil disimpan ke Supabase,
  web melihat lewat Realtime. Koreksi petugas di Android atau web
  tersimpan dan menjadi data latih baru.
- **Web:** Vue 3, Vite, TypeScript, Tailwind CSS, Pinia.
  Deploy target Vercel / Cloudflare Pages (`app.lynxagent.my.id`),
  development lokal di port 5173.
- **Android:** Flutter, project baru bernama `inventaris_ml`.
  Deploy ke HP nyata via USB debugging, tanpa emulator.
  Flutter SDK `C:\Users\ACER\develop\flutter`, `flutter doctor`
  hijau (Flutter 3.47.7).
- **API:** FastAPI, Python 3.11, conda env `ml-inventaris`.
  Jangan pakai env `base`, `uas-bda`, atau `skripsi-rfsmote`.
  Deploy target VPS (`ml.lynxagent.my.id`), development lokal
  di port 8000.
- **Database:** Supabase free tier (500 MB DB, 1 GB Storage,
  50 ribu auth). Cukup untuk tugas ini.
- **Secret:** API key dan URL Supabase dibaca dari `.env` lokal.
  Secret tidak dikirim lewat chat dan tidak di-commit. File
  `.env.example` hanya berisi nama variabel, tanpa nilai.

## 7. Kebutuhan fungsional

### 7.1 API prediksi (FastAPI, folder `api/`)

| ID | Kebutuhan | Kriteria penerimaan |
|---|---|---|
| FR-API-1 | `GET /health` mengembalikan status, nama model, dan threshold | Response `{"status": "ok", "model": "xgb_scaleposweight_binary v1", "threshold_f2": 0.417}` |
| FR-API-2 | `POST /predict` menerima satu barang dan mengembalikan prediksi | Request berisi `nama_barang`, `nama_ruangan`, `bahan`, `kategori`, `tahun_pembelian`, `jumlah`, `harga`. Response berisi `label_biner`, `label`, `probabilitas`, `prioritas`, `threshold: 0.417`, `alasan_top3` (3 item `{fitur, penjelasan}` kalimat biasa), `model_version` |
| FR-API-3 | Validasi input di `POST /predict` | `bahan` harus salah satu dari 5 nilai, `kategori` salah satu dari 3 nilai, `jumlah > 0`, `harga > 0`, `tahun_pembelian` 2011-2025. Input di luar itu ditolak dengan pesan error yang jelas |
| FR-API-4 | `POST /predict/batch` menerima upload CSV | Kolom sama seperti `data/raw/inventaris_raw.csv`. Response berisi array hasil per baris dan ringkasan jumlah Baik / Perlu |
| FR-API-5 | Model dimuat sekali saat start, threshold dibaca dari bundle | Threshold dan nama model tidak di-hardcode di kode. Feature engineering memakai ulang `src/preprocessing.py` |
| FR-API-6 | Test otomatis `test_api.py` | 2 dari 2 assert lolos: AC Panasonic 2 PK (Besi, Elektronik, tahun beli 2013, umur 12, harga per unit 10.845.230) probabilitas sekitar 0,996 dan label Perlu Pemeliharaan; barang Baik contoh dari `data/processed/inventaris_processed.csv` probabilitas di bawah 0,417 dan label Baik |
| FR-API-7 | CORS | Mengizinkan `http://localhost:5173` dan `https://app.lynxagent.my.id` |

### 7.2 Database (Supabase)

| ID | Kebutuhan | Kriteria penerimaan |
|---|---|---|
| FR-DB-1 | Skema empat tabel sesuai `docs/app-blueprint.md` | Tabel `rooms`, `inventories`, `predictions`, `maintenance_tasks` dibuat dari `supabase/migrations/001_schema.sql` |
| FR-DB-2 | Data ruangan | `select count(*) from rooms;` mengembalikan 12: Adenium, Anturium, Aster, Dahlia, Gardena, Lavender, Mawar, Melati A, Melati B, Sakura, Seruni, Tulip |
| FR-DB-3 | `POST /predict` menyimpan hasil | Setelah satu prediksi, baris baru muncul di `predictions` (berisi `prob_perlu_pemeliharaan`, `label_biner`, `threshold`, `prioritas`, `shap_top3` sebagai JSON, `model_version`) dan `inventory_id` serta `prediction_id` dikembalikan di response |
| FR-DB-4 | `GET /predictions?room_id=&limit=50` | Mengembalikan prediksi terbaru beserta nama barang dan nama ruangan, untuk dipakai web |
| FR-DB-5 | Koreksi petugas tersimpan | `predictions.koreksi_petugas` bisa diisi 0 atau 1, NULL berarti belum dikoreksi |

Catatan: `nama_ruangan`, `triwulan`, dan `nama_barang` disimpan
sebagai metadata di `inventories`. Ketiganya bukan fitur model,
sesuai notebook 02.

### 7.3 Web admin/manajer (folder `web/`)

| ID | Kebutuhan | Kriteria penerimaan |
|---|---|---|
| FR-WEB-1 | Dashboard (`/`) | Kartu per 12 ruangan (jumlah barang, jumlah Perlu Pemeliharaan, antrean Tinggi), distribusi kondisi, daftar prioritas Tinggi terbaru |
| FR-WEB-2 | Detail barang (`/inventaris/:id`) | Prediksi, probabilitas, prioritas, bagian "Kenapa diprediksi ini? Top-3 alasan" dari `shap_top3`, dan grafik SHAP global |
| FR-WEB-3 | Grafik SHAP global | Bar chart dari `outputs/tables/shap_global.csv` dengan nilai harga 1,1071, umur 0,7022, depresiasi 0,6543, bahan 0,2821, kategori 0,2600, lengkap dengan legenda dan tooltip, tidak hanya mengandalkan warna |
| FR-WEB-4 | CRUD inventaris | Form tambah barang dengan field yang sama seperti `POST /predict`, memanggil API, menampilkan hasil |
| FR-WEB-5 | Upload CSV massal | Upload CSV lewat `POST /predict/batch`, menampilkan ringkasan hasil |
| FR-WEB-6 | Koreksi dan antrean pemeliharaan | Tombol koreksi label petugas di detail barang, menyimpan ke `predictions.koreksi_petugas`. Daftar `maintenance_tasks` dengan status Antre, Dikerjakan, Selesai |

Aturan web: base URL API dari env `VITE_API_URL` (default
`http://localhost:8000` saat dev). URL Supabase tidak di-hardcode
di frontend. Data dibaca lewat FastAPI (`GET /predictions`),
Supabase Realtime hanya untuk update daftar. Bahasa Indonesia.
Probabilitas tampil sebagai persen, contoh 99,6%. Threshold dan
model tidak boleh diubah dari frontend.

### 7.4 Android petugas lapangan (folder `android/`)

| ID | Kebutuhan | Kriteria penerimaan |
|---|---|---|
| FR-AND-1 | Form input barang | Dropdown `bahan` (5 nilai) dan `kategori` (3 nilai), `nama_barang`, `nama_ruangan` (dropdown 12 ruangan), `tahun_pembelian`, `jumlah`, `harga`. Tombol Prediksi |
| FR-AND-2 | Hasil prediksi | Label (Baik / Perlu Pemeliharaan), probabilitas dalam persen, prioritas (Baik / Sedang / Tinggi, dengan warna), Top-3 alasan kalimat biasa dari `alasan_top3` API, bukan chart dan bukan kode fitur mentah |
| FR-AND-3 | Koreksi | Tombol "Prediksi salah? Koreksi" menyimpan `koreksi_petugas` (0 atau 1) via API |
| FR-AND-4 | Daftar prioritas | Barang Perlu Pemeliharaan per ruangan, dibaca dari Supabase Realtime (atau `GET /predictions`), urut probabilitas tertinggi dulu |

Aturan Android: base URL API dari konstanta di satu file config
(contoh `lib/config.dart`). Satu tempat saja yang diganti saat
pindah dari `http://<IP-laptop>:8000` (HP nyata, bukan localhost)
ke `https://ml.lynxagent.my.id`. State management pilih satu yang
paling sederhana dan konsisten (Provider atau Riverpod), jangan
campur. Model tidak disimpan di HP, tidak ada TFLite di versi ini,
prediksi selalu lewat FastAPI. Tidak ada input foto.

## 8. Design system

Design system ini berasal dari ui-ux-pro-max, query
"internal inventory dashboard hospital maintenance". Berlaku
untuk web dan Android supaya keduanya terlihat satu produk.

- **Pola:** Real-Time / Operations, data padat tapi tetap bisa
  dipindai. Label "live" hanya dipakai bila data memang dari
  sumber yang masih berjalan, sertakan waktu update dan status
  saat data basi. Tidak ada chart dekoratif, error tidak
  disembunyikan.
- **Token warna:** primary `#16A34A`, secondary `#22C55E`,
  accent dan destructive `#DC2626`, background `#0F172A`,
  foreground `#F8FAFC`, card `#111827`, muted `#1E293B`,
  muted foreground `#CBD5E1`, border `#334155`, ring `#16A34A`.
  Status: hijau Baik, amber Sedang, merah Perlu Pemeliharaan /
  Tinggi. Warna tidak ditulis sebagai hex mentah di komponen,
  pakai token di atas.
- **Tipografi:** heading Fira Code, body Fira Sans. Base font
  16px, line-height 1.5.
- **Aksesibilitas dan interaksi:** ikon SVG (Heroicons / Lucide),
  bukan emoji. Elemen yang bisa diklik punya cursor-pointer dan
  hover 150-300ms. Kontras teks minimal 4,5:1. Focus terlihat
  jelas saat navigasi keyboard. `prefers-reduced-motion`
  dihormati. Responsif di 375, 768, 1024, dan 1440px. Error form
  tampil di dekat field, ringkasan error di atas form bisa
  difokuskan (role alert, link ke field yang salah). Error tidak
  hanya ditandai border merah.
- **Android:** form pakai widget `Form` dengan `GlobalKey`,
  validasi saat submit dengan
  `_formKey.currentState!.validate()`, bukan validasi per field
  sendiri-sendiri. Layout pakai `Column` dan `Row` untuk susunan
  linear, bukan `Stack` untuk susunan sederhana. Target sentuh
  minimal 48dp. Error diumumkan ke screen reader. Beri feedback
  loading saat prediksi berjalan.

Catatan: query stack Vue di ui-ux-pro-max mengembalikan 0 hasil
untuk dashboard, tabel, dan form, jadi bagian web di atas memakai
panduan umum dari skill itu, bukan hasil query stack.

## 9. Kebutuhan non-fungsional

- **Kebenaran prediksi:** API harus mengembalikan angka yang sama
  dengan notebook untuk barang yang sama (toleransi 0,01).
  Benchmark ada di FR-API-6.
- **Konsistensi:** satu project Supabase dipakai web dan Android.
  Input di Android harus terlihat di web tanpa refresh manual.
- **Keamanan secret:** secret hanya di `.env` lokal, tidak di
  chat, tidak di-commit.
- **Perubahan minimal:** pakai helper dan pola yang sudah ada di
  project ini dulu. Jangan tambah dependensi untuk beberapa baris.
  Jangan buat abstraksi, wrapper, opsi, atau config "untuk nanti"
  yang tidak diminta. Hapus kode lebih baik daripada tambah kode.
- **Komentar kode:** hanya untuk alasan yang tidak terlihat dari
  kodenya, satu baris saja.

## 10. Alur end-to-end

1. Petugas membuka form di Android, mengisi data barang, menekan
   Prediksi.
2. FastAPI menghitung fitur (umur dinamis, harga per unit,
   depresiasi), memuat model, mengembalikan label, probabilitas,
   prioritas, dan Top-3 alasan, lalu menyimpan hasilnya ke
   Supabase.
3. Dashboard web menampilkan barang itu di ruangan yang sesuai,
   termasuk di daftar prioritas bila labelnya Perlu Pemeliharaan.
4. Admin membuka detail barang, membaca penjelasan SHAP, dan bila
   prediksi salah, mengoreksi label. Koreksi tersimpan.
5. Barang yang perlu pemeliharaan masuk antrean `maintenance_tasks`
   dengan status Antre, lalu bisa diubah menjadi Dikerjakan dan
   Selesai.

## 11. Milestone

| Fase | Isi | Selesai bila |
|---|---|---|
| Fase 1 | FastAPI + Supabase | FR-API-1 sampai FR-API-7 dan FR-DB-1 sampai FR-DB-5 terpenuhi. `POST /predict` AC Panasonic sekitar 0,996, `test_api.py` lolos 2/2, `rooms` berisi 12 baris |
| Fase 2 | Web Vue 3 | FR-WEB-1 sampai FR-WEB-6 terpenuhi. `npm run dev` jalan tanpa error, dashboard menampilkan 12 ruangan, grafik SHAP global tampil dengan 5 bar sesuai nilai di bagian 5 |
| Fase 3 | Android Flutter | FR-AND-1 sampai FR-AND-4 terpenuhi. `flutter run` di HP nyata, form AC Panasonic 2 PK menghasilkan Perlu Pemeliharaan sekitar 99,6%, koreksi tersimpan, input Android muncul di dashboard web |
| Fase 4 | Demo end-to-end | Alur di bagian 10 berjalan penuh. `docs/demo-checklist.md` berisi langkah demo dan angka yang harus terlihat di tiap langkah |

Urutan pengerjaan adalah Fase 1, lalu 2, lalu 3, lalu 4. Satu fase
selesai dan diverifikasi dulu sebelum lanjut ke fase berikutnya.

## 12. Risiko dan keterbatasan

- **SHAP pada fitur berkorelasi:** umur, harga per unit, dan
  depresiasi saling berkorelasi, jadi SHAP membagi kredit di antara
  ketiganya. Urutan SHAP tidak harus sama dengan feature importance
  Random Forest di skripsi (depresiasi pertama di sana). Ini dicatat
  sebagai keterbatasan, bukan dipaksakan sama.
- **Angka in-sample:** evaluasi in-sample di notebook 04 bersifat
  optimis dan tidak boleh dikutip sebagai performa generalisasi.
  Angka laporan yang sah adalah CV/OOF notebook 03 di bagian 5.
- **Supabase free tier:** batas 500 MB database cukup untuk tugas
  ini, tapi bukan untuk pemakaian rumah sakit sungguhan.
- **Model tidak di HP:** prediksi butuh koneksi ke FastAPI. Bila
  API tidak terjangkau, Android tidak bisa memprediksi di versi ini.
  Itu konsekuensi dari out of scope mode offline.

## 13. File dan dokumen terkait

- `docs/app-blueprint.md` — blueprint arsitektur dan skema SQL
- `notebooks/01-04` — training, sudah selesai
- `src/preprocessing.py` — rumus feature engineering, dipakai ulang
- `models/xgb_scaleposweight_binary.pkl` — model final
- `models/preprocessing_reference_v2.pkl` — referensi imputasi
- File baru yang dibuat di fase aplikasi: `api/`, `supabase/`,
  `web/`, `android/`, `docs/demo-checklist.md`, `.env.example`

File yang tidak boleh disentuh di fase aplikasi: `notebooks/`,
`data/raw/inventaris_raw.csv`, `data/processed/`,
`models/xgb_scaleposweight_binary.pkl`,
`models/preprocessing_reference_v2.pkl`, rumus di
`src/preprocessing.py`, `docs/app-blueprint.md`.
