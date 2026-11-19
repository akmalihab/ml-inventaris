# Blueprint Aplikasi — ML Inventaris (Web Vue + Android Flutter + Supabase + FastAPI)

Lanjutan skripsi S1 (RSD dr. Soebandi) untuk mata kuliah Pembelajaran Mesin.
Dokumen ini blueprint sisi **aplikasi** saja — training tetap di `notebooks/01–04`.

## Keputusan yang sudah dikunci (jangan diubah tanpa diskusi)

- Model: **XGBoost biner + scale_pos_weight + TreeSHAP** (`notebooks/03`, diputuskan 2026-11-18 — SMOTE-NC hanya pembanding di CV)
- Kelas: `0 = Baik` (1.889) / `1 = Perlu Pemeliharaan` (412 = Kurang Baik 327 + Rusak Berat 85)
- Label asli 3 kelas **tetap disimpan** di database (`kondisi_asli`) untuk audit
- **Tanpa input foto** — Android hanya form; foto tidak dipakai sebagai fitur model
- Fitur model (5): `bahan`, `kategori`, `umur`, `harga_per_unit`, `depresiasi_aset`
- Kategori: `Elektronik`, `Furnitur`, `Pelengkap` (bahan: 5 nilai unik — lihat `notebooks/01`)
- Prioritas dari probabilitas XGBoost: `> 0,8` Tinggi, `0,5–0,8` Sedang, `< 0,5` Baik
- Threshold keputusan: **bukan hardcode 0,5** — pakai threshold hasil tuning F2/Youden dari `notebooks/03`
- Penjelasan: TreeSHAP global di Web, Top-3 alasan kalimat biasa di Android
- Env training: conda `ml-inventaris` (Python 3.11) — jangan pakai `uas-bda` / `skripsi-rfsmote`

## Arsitektur

```
[Android Flutter] ──┐
                    ├─► [FastAPI /predict] ──► model models/xgb_scaleposweight_binary.pkl
[Web Vue 3] ────────┤         │  (feature engineering pakai ulang src/preprocessing.py)
                    │         ▼
                    └──► [Supabase Postgres + Realtime]
                          rooms / inventories / predictions / maintenance_tasks
```

- Satu project Supabase dipakai berdua. Android input → FastAPI prediksi → simpan ke
  Supabase → Web langsung melihat lewat Realtime. Koreksi petugas di Android/Web
  tersimpan dan menjadi data latih baru (feedback loop).
- Deploy gratis: Web di Vercel/Cloudflare Pages (`app.lynxagent.my.id`),
  FastAPI di VPS lynx.agent (`ml.lynxagent.my.id`) — fallback: Hugging Face Spaces (CPU gratis).
  Supabase free tier: 500 MB DB, 1 GB Storage, 50 rb auth (cukup untuk tugas ini).

## Skema Supabase (SQL — jalankan di SQL Editor)

```sql
create table rooms (
  id smallint primary key,
  nama text unique not null
);
-- 12 ruangan: Adenium, Anturium, Aster, Dahlia, Gardena, Lavender, Mawar,
-- Melati A, Melati B, Sakura, Seruni, Tulip

create table inventories (
  id uuid primary key default gen_random_uuid(),
  room_id smallint references rooms(id),
  nama_barang text not null,
  bahan text not null,              -- 5 nilai unik, cek notebooks/01
  kategori text not null check (kategori in ('Elektronik','Furnitur','Pelengkap')),
  tahun_pembelian int not null,
  jumlah int not null check (jumlah > 0),
  harga numeric not null,           -- harga total; harga_per_unit = harga / jumlah
  triwulan text,                    -- metadata saja, BUKAN fitur model
  kondisi_asli text check (kondisi_asli in ('Baik','Kurang Baik','Rusak Berat')),
  created_at timestamptz default now()
);

create table predictions (
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid references inventories(id),
  prob_perlu_pemeliharaan numeric not null,   -- probabilitas XGBoost kelas 1
  label_biner int not null check (label_biner in (0,1)),
  threshold numeric not null,                 -- threshold F2/Youden dari notebooks/03
  prioritas text check (prioritas in ('Baik','Sedang','Tinggi')),
  shap_top3 jsonb,                            -- [{fitur, nilai_shap, arah}] kalimat Top-3
  model_version text not null,                -- mis. 'xgb_scaleposweight_binary v1'
  koreksi_petugas int check (koreksi_petugas in (0,1)),  -- NULL = belum dikoreksi
  created_at timestamptz default now()
);

create table maintenance_tasks (
  id uuid primary key default gen_random_uuid(),
  prediction_id uuid references predictions(id),
  status text not null default 'Antre'
    check (status in ('Antre','Dikerjakan','Selesai')),
  created_at timestamptz default now()
);
```

Catatan: `nama_ruangan`, `triwulan`, `nama_barang` disimpan sebagai metadata di
`inventories` — benar untuk aplikasi, tapi **bukan fitur model** (sesuai `notebooks/02`).

## Kontrak FastAPI (folder baru `api/`)

Model dimuat sekali saat start. Feature engineering **pakai ulang** fungsi dari
`src/preprocessing.py` (`add_umur`, `add_harga_per_unit`, `add_depresiasi`) —
jangan tulis ulang rumus depresiasi di API. `umur` dihitung dinamis dari tahun
berjalan, jangan hardcode tahun. Imputasi harga (reference.pkl v2, mean
`harga_per_unit`) hanya dipakai bila `harga` kosong saat input.

```
GET  /health            -> {"status":"ok","model":"xgb_scaleposweight_binary v1"}
POST /predict           -> 1 barang (dari form Android)
POST /predict/batch     -> banyak barang (upload CSV, seperti Unggah CSV di POC Streamlit)
```

Request `POST /predict`:

```json
{
  "nama_barang": "Kursi Tunggu Pasien",
  "nama_ruangan": "Anturium",
  "bahan": "Besi",
  "kategori": "Furnitur",
  "tahun_pembelian": 2019,
  "jumlah": 9,
  "harga": 7677000
}
```

Response:

```json
{
  "label_biner": 1,
  "label": "Perlu Pemeliharaan",
  "probabilitas": 0.82,
  "prioritas": "Tinggi",
  "threshold": 0.42,
  "alasan_top3": [
    {"fitur": "depresiasi_aset", "penjelasan": "depresiasi tinggi mendorong ke Perlu Pemeliharaan"},
    {"fitur": "umur", "penjelasan": "umur 6 tahun mendorong ke Perlu Pemeliharaan"},
    {"fitur": "harga_per_unit", "penjelasan": "harga per unit rendah menahan ke Baik"}
  ],
  "model_version": "xgb_scaleposweight_binary v1"
}
```

- `threshold` dan `model_version` dibaca dari artefak `notebooks/03`
  (`outputs/tables/` + `models/xgb_scaleposweight_binary.pkl`) — **isi nilainya setelah
  run notebook 03 dengan CSV asli**, jangan tebak.
- `alasan_top3`: TreeSHAP dihitung di API untuk barang itu, diambil 3 |SHAP|
  terbesar, diterjemahkan ke kalimat biasa (bukan chart) untuk Android.
- SHAP **hanya** dihitung dari data nyata, bukan data sintetik (model final tidak pakai SMOTE-NC).

## Pembagian layar (scope minimal)

**Web Vue 3 + Vite + TypeScript + Tailwind + Pinia** (admin/manajer):
1. Dashboard per 12 ruangan + distribusi kondisi + antrean prioritas
2. Detail barang: prediksi + "Kenapa diprediksi ini? Top-3 alasan" (SHAP) + grafik SHAP global
3. CRUD inventaris + upload CSV massal (batch via `POST /predict/batch`)
4. Koreksi label petugas + daftar `maintenance_tasks` (Antre → Dikerjakan → Selesai)

**Android Flutter** (petugas lapangan):
1. Form input barang (bahan, kategori, tahun beli, jumlah, harga) → prediksi instan
2. Hasil: label + probabilitas + prioritas + Top-3 alasan kalimat biasa
3. Koreksi bila prediksi salah (tersimpan ke `predictions.koreksi_petugas`)
4. Daftar prioritas pemeliharaan per ruangan (baca dari Supabase Realtime)

## Urutan pengerjaan

1. Selesaikan training dulu: env `ml-inventaris` → run `01 → 02 → 03 → 04`
   (butuh `inventaris_raw.csv` di `data/raw/`; angka metrik asli menunggu run ini)
2. Catat dari hasil `03`: threshold F2/Youden + nama file model + urutan fitur SHAP
3. Buat `api/` (FastAPI) + `supabase/` (migrasi SQL di atas) — uji `POST /predict`
   dengan 1 barang yang hasil notebook-nya sudah diketahui, cocokkan angkanya
4. Buat Web (dashboard + detail SHAP), lalu Android (form + prediksi + koreksi)
5. Demo end-to-end: input di Android → muncul di Web via Realtime → koreksi →
   masuk antrean pemeliharaan

## Yang sengaja TIDAK ada

- Input foto / Storage foto (diputuskan: tanpa foto)
- Training di server — training tetap di Colab/laptop, API hanya inference
- Fitur baru di luar 5 fitur model — tambah fitur = ulangi `notebooks/02–03` dulu
