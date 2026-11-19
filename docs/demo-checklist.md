# Checklist & Skenario Demo End-to-End

Panduan demonstrasi terpadu untuk pengujian sistem ML Inventaris Nonmedis RSD dr. Soebandi, menghubungkan **Aplikasi Android Flutter**, **Backend FastAPI**, **Supabase Realtime**, dan **Dashboard Web Vue 3**.

---

## Prasyarat Sebelum Demo Dimulai

Pastikan seluruh service aktif:

1. **Backend FastAPI**:
   ```bash
   conda activate ml-inventaris
   uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
   ```
   *Verifikasi: Buka `http://localhost:8000/health` $\rightarrow$ status `"ok"`, model `"xgb_scaleposweight_binary v1"`, threshold `0.417`.*

2. **Web Frontend (Vue 3)**:
   ```bash
   cd web
   npm run dev
   ```
   *Verifikasi: Buka `http://localhost:5173` di browser.*

3. **Aplikasi Android**:
   ```bash
   adb reverse tcp:8000 tcp:8000
   cd android/inventaris_ml
   flutter run
   ```
   *Bisa juga menggunakan build APK `app-debug.apk` yang sudah terpasang di HP Android.*

---

## Langkah Skenario Demo (5 Tahap)

### Tahap 1: Input Barang di Aplikasi Android (Kasus Aset Kritis)
- **Tindakan**:
  1. Buka aplikasi Android **ML Inventaris**.
  2. Pada tab **Input & Prediksi**, tekan tombol **Preset AC** di pojok kanan atas AppBar (atau ketik manual).
  3. Form terisi otomatis:
     - Nama Barang: `AC Panasonic 2 PK`
     - Ruang Rawat Inap: `Adenium (ID: 1)`
     - Kategori: `Elektronik`
     - Bahan: `Besi`
     - Tahun Beli: `2013`
     - Jumlah: `1` unit
     - Harga Perolehan: `Rp10.845.230`
  4. Tekan tombol hijau: **Prediksi Kondisi & Prioritas AI**.
- **Angka & Bukti yang Harus Terlihat di Android**:
  - [ ] Layar berpindah ke **Hasil Prediksi & SHAP**.
  - [ ] Status: **Status AI: PERLU PEMELIHARAAN** (badge merah/rose).
  - [ ] Probabilitas Risiko: **`96.3%`** (atau $\ge 95\%$).
  - [ ] Prioritas: **`Prioritas Tinggi`**.
  - [ ] Threshold Model: **`0.417`**.
  - [ ] 3 Alasan Utama Rekomendasi AI (SHAP):
    1. *kategori Elektronik cenderung Perlu Pemeliharaan*
    2. *depresiasi aset Rp10,831,065 mendorong ke Perlu Pemeliharaan*
    3. *material Besi cenderung Baik*

---

### Tahap 2: Buat Tugas Pemeliharaan dari Android
- **Tindakan**:
  1. Pada layar hasil prediksi di Android, scroll ke bagian bawah.
  2. Tekan tombol hitam: **Masukkan ke Antrean Pemeliharaan**.
- **Angka & Bukti yang Harus Terlihat di Android**:
  - [ ] Snackbar notifikasi hijau muncul: *"Tugas pemeliharaan berhasil dimasukkan ke antrean!"*.
  - [ ] Tombol berubah menjadi disable: *"Sudah Masuk Antrean Pemeliharaan"*.

---

### Tahap 3: Verifikasi Sinkronisasi Realtime di Dashboard Web
- **Tindakan**:
  1. Buka browser pada halaman **Dashboard Web (`http://localhost:5173/`)**.
  2. **Tanpa menekan refresh browser (F5)**, amati pembaruan otomatis via Supabase Realtime.
- **Angka & Bukti yang Harus Terlihat di Web**:
  - [ ] Indikator topbar menunjukkan status hijau berkedip: **Supabase Realtime**.
  - [ ] Pada widget **Antrean Prioritas Kritis**, baris teratas muncul:
    - Nama: `AC Panasonic 2 PK` (Elektronik)
    - Ruangan: `Adenium`
    - Prob: `96%`
  - [ ] Pada kartu ruangan **Adenium**, counter `Perlu Pemeliharaan` dan `Prioritas Tinggi` bertambah 1.

---

### Tahap 4: Pemeriksaan Detail Aset & Analisis SHAP di Web
- **Tindakan**:
  1. Di tabel antrean kritis web, klik tombol aksi panah $(\rightarrow)$ pada baris `AC Panasonic 2 PK` (atau buka menu **Analisis SHAP**).
  2. Pilih ruangan `Adenium` dan barang `AC Panasonic 2 PK`.
- **Angka & Bukti yang Harus Terlihat di Web**:
  - [ ] Header aset menampilkan:
    - Status: `Perlu Pemeliharaan`
    - Prioritas: `Prioritas Tinggi`
    - Probabilitas Risiko: `96.3%`
  - [ ] Metrik Depresiasi:
    - Tingkat Penurunan Nilai: `100%` susut.
    - Sisa Nilai Buku: `Rp14.165` (dari harga awal Rp10.845.230).
  - [ ] Grafik Bar SHAP Lokal:
    - Bar merah panjang pada `depresiasi_aset` ($+0.6543$) dan `kategori` ($+0.2600$).
    - Bar hijau penahan pada `bahan` (Besi).

---

### Tahap 5: Eksekusi Alur Tugas Pemeliharaan & Sinkronisasi Selesai
- **Tindakan**:
  1. Buka menu **Antrean Tugas (`/pemeliharaan`)** di web.
  2. Cari `AC Panasonic 2 PK` pada ruangan `Adenium`.
  3. Ubah dropdown status alur dari **Antre** $\rightarrow$ **Dikerjakan** $\rightarrow$ **Selesai**.
- **Angka & Bukti yang Harus Terlihat di Sistem**:
  - [ ] Badge status alur berubah menjadi hijau: **Selesai**.
  - [ ] Di database, kolom `predictions.koreksi_petugas` otomatis tersinkronisasi menjadi `0` (status Baik setelah perbaikan).
  - [ ] Kembali ke menu **Dashboard (`/`)**:
    - Barang `AC Panasonic 2 PK` **otomatis hilang** dari tabel *Antrean Prioritas Kritis*.
    - Counter prioritas tinggi pada kartu ruangan `Adenium` berkurang kembali.
  - [ ] Buka menu **Data Ruangan (`/ruangan`)** $\rightarrow$ pilih `Adenium`:
    - Status barang berubah menjadi **`Baik (Selesai Perbaikan)`** berwarna hijau.
  - [ ] Buka aplikasi Android $\rightarrow$ tab **Pantau Ruangan** $\rightarrow$ pilih `Adenium`:
    - Status `AC Panasonic 2 PK` berubah menjadi **`Kondisi Baik`** (hijau).

---

## Rangkuman Validasi Parameter

| Parameter | Nilai Acuan (*Expected Value*) | Status Uji |
|---|---|---|
| Probabilitas AC Panasonic 2 PK | $\ge 95\%$ ($96.3\%$) | [Pass] |
| Label Keputusan Model | `Perlu Pemeliharaan` ($P \ge 0.417$) | [Pass] |
| Label Kondisi Barang Baru (Kursi) | `Baik` ($P < 0.417$) | [Pass] |
| Latensi Sinkronisasi Realtime Web | $< 1$ detik tanpa reload halaman | [Pass] |
| Auto-Resolve Tugas Pemeliharaan | Update `Selesai` mereset `koreksi_petugas = 0` | [Pass] |
