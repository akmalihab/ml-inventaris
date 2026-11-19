# ML Inventaris — Klasifikasi Kondisi Inventaris Nonmedis RSD dr. Soebandi

Lanjutan skripsi S1 Akmal Ihab Syauqi (UNEJ, 2026) untuk mata kuliah Pembelajaran Mesin (Magister Informatika UII).

**Perubahan dari skripsi:**
- Model: Random Forest + SMOTE → **XGBoost + scale_pos_weight** (diputuskan 2026-11-18; SMOTE-NC hanya pembanding di CV)
- Kelas: 3 kelas (Baik / Kurang Baik / Rusak Berat) → **2 kelas biner**
  - `0 = Baik` (1.889)
  - `1 = Perlu Pemeliharaan` (412 = Kurang Baik 327 + Rusak Berat 85)
- Tambah **TreeSHAP** sebagai Explainable AI (global + per-barang)
- Threshold: hitung ulang F2/Youden untuk model scale_pos_weight (threshold lama 0,378 itu milik SMOTE-NC, jangan dipakai)
- Tanpa input foto — input hanya form (bahan, kategori, tahun pembelian, jumlah, harga)

**Set final notebook: hanya 01–04.** Notebook 05 asli (evaluasi skripsi) dan notebook RF lama tidak di folder aktif — tersimpan di `notebooks/archive/` sebagai arsip saja.

## Struktur folder

```
ml-inventaris/
├── environment.yml          # conda env ml-inventaris (Python 3.11)
├── requirements.txt         # cadangan pip
├── README.md                # file ini
├── .gitignore
├── data/
│   ├── raw/                 # TARUH inventaris_raw.csv DI SINI (jangan commit)
│   │   └── inventaris_raw.csv
│   ├── processed/           # hasil 02_preprocessing
│   └── external/            # referensi lain (kosong dulu)
├── notebooks/
│   ├── 01_data_understanding.ipynb      # REVISI — distribusi biner + cek SMOTE-NC
│   ├── 02_preprocessing.ipynb           # REVISI — REFERENCE_YEAR=2025, 2 output
│   ├── 03_xgboost_smotenc_shap.ipynb    # BARU — XGBoost + SMOTE-NC + TreeSHAP
│   └── 04_evaluation_and_analysis.ipynb # REVISI — evaluasi biner + SHAP vs RF
├── src/
│   ├── __init__.py
│   └── preprocessing.py     # fungsi cleaning + feature engineering (dari 02)
├── models/                  # .pkl hasil training (jangan commit)
├── outputs/
│   ├── figures/             # grafik evaluasi
│   ├── tables/              # csv metrik
│   └── shap/                # grafik SHAP global + lokal
└── docs/
    └── app-blueprint.md     # blueprint Web Vue + Android Flutter + Supabase + FastAPI
```

## Urutan kerja

1. Buat folder ini di laptop (lihat command PowerShell yang sudah diberikan)
2. Buat env `ml-inventaris` (lihat Langkah 0 di bawah)
3. Taruh `inventaris_raw.csv` di `data/raw/`
4. Jalankan berurutan **01 → 02 → 03 → 04**
   - 01: cek data + distribusi biner
   - 02: hasilkan `data/processed/inventaris_for_model.csv` (NaN dipertahankan) + `inventaris_processed.csv` (ter-imputasi, untuk EDA)
   - 03: CV 3 model, threshold F2/Youden, simpan `models/xgb_smotenc_binary.pkl`
   - 04: evaluasi detail + perbandingan SHAP vs RF importance
5. Model di `models/` dipakai FastAPI (Web + Android) nanti — lihat `docs/app-blueprint.md`

## Langkah 0 — Buat env conda (di laptop Windows)

Dilakukan di **Anaconda Prompt** (bukan PowerShell biasa, supaya `conda activate` langsung jalan).

```bat
conda env list
conda env create -f environment.yml
conda activate ml-inventaris
python --version
python -c "import sklearn, xgboost, imblearn, shap; print(sklearn.__version__, xgboost.__version__, shap.__version__)"
```

Yang harus terlihat:
- `python --version` → **Python 3.11.x** (bukan 3.13 base)
- Prompt berubah jadi `(ml-inventaris)`
- Import di atas tidak error

Kalau `conda env create` gagal karena env sudah ada:
```bat
conda env remove -n ml-inventaris
conda env create -f environment.yml
```

Jangan install di `base`, jangan pakai env `uas-bda` (PySpark) atau `skripsi-rfsmote` (jangan disentuh).
