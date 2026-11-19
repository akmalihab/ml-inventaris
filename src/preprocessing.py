"""
Fungsi preprocessing — dipindah dari notebooks/02_preprocessing.ipynb
supaya bisa dipakai ulang oleh notebook 06 dan nanti oleh FastAPI.

Aturan yang dipertahankan dari skripsi:
- Duplikat exact (21) dibuang, duplikat logis (139) dipertahankan
- Outlier IQR dideteksi tapi TIDAK dibuang (kondisi nyata)
- Imputasi harga_per_unit hierarkis: nama_barang -> bahan+kategori -> median
- Depresiasi: Elektronik = saldo menurun ganda (5 th),
  Furnitur/Pelengkap = garis lurus (10 th), di-cap maksimal = harga
- Fitur akhir model: bahan, kategori, umur, harga_per_unit, depresiasi_aset
- Target biner baru: Baik=0, Perlu Pemeliharaan=1 (Kurang Baik + Rusak Berat)

Yang DIPERBAIKI untuk project baru:
- CURRENT_YEAR tidak lagi hardcode 2026 — dihitung dari tahun data / tahun berjalan
  saat prediksi, supaya umur tidak +1 tahun.
- Imputasi HARUS dihitung hanya dari data train (di dalam fold),
  jangan dari full data seperti di notebook 02 lama.
"""

import pandas as pd


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Strip string + buang duplikat exact saja."""
    df = df.copy()
    for col in ["bahan", "kategori", "kondisi", "nama_ruangan"]:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip()
    df = df.drop_duplicates()
    return df


def add_umur(df: pd.DataFrame, current_year: int) -> pd.DataFrame:
    df = df.copy()
    df["umur"] = current_year - df["tahun_pembelian"]
    return df


def add_harga_per_unit(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["harga_per_unit"] = df["harga"] / df["jumlah"]
    return df


def impute_harga_per_unit(df: pd.DataFrame, reference: dict) -> pd.DataFrame:
    """Imputasi hierarkis sesuai PRD: nama_barang -> bahan+kategori -> median."""
    df = df.copy()
    if "harga_per_unit" not in df.columns:
        df = add_harga_per_unit(df)

    nama_map = reference.get("harga_per_unit_nama_mean", {})
    group_map = reference.get("harga_per_unit_group_mean", {})
    median_val = reference.get("median_harga_per_unit", 0.0)

    # 1. Map nama_barang
    if "nama_barang" in df.columns:
        df["harga_per_unit"] = df["harga_per_unit"].fillna(df["nama_barang"].map(nama_map))

    # 2. Map (bahan, kategori)
    if "bahan" in df.columns and "kategori" in df.columns:
        # group_map key is tuple (bahan, kategori)
        group_series = df.apply(lambda r: group_map.get((r["bahan"], r["kategori"])), axis=1)
        df["harga_per_unit"] = df["harga_per_unit"].fillna(group_series)

    # 3. Fallback median
    df["harga_per_unit"] = df["harga_per_unit"].fillna(median_val)
    return df


def depresiasi_row(row) -> float:
    """Sama seperti notebook 02 cell 13."""
    umur = row["umur"]
    harga = row["harga_per_unit"]
    if row["kategori"] == "Elektronik":
        masa_manfaat = 5
        tarif = 2 / masa_manfaat
        nilai_buku = harga
        for _ in range(int(umur)):
            nilai_buku -= nilai_buku * tarif
        depresiasi = harga - nilai_buku
    else:
        masa_manfaat = 10
        depresiasi = (harga / masa_manfaat) * umur
    return round(min(depresiasi, harga), 2)


def add_depresiasi(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["depresiasi_aset"] = df.apply(depresiasi_row, axis=1)
    return df


def make_binary_target(df: pd.DataFrame) -> pd.DataFrame:
    """
    Simpan DUA kolom:
    - kondisi_asli: Baik / Kurang Baik / Rusak Berat (untuk audit)
    - kondisi_biner: 0=Baik, 1=Perlu Pemeliharaan
    """
    df = df.copy()
    df["kondisi_asli"] = df["kondisi"]
    df["kondisi_biner"] = df["kondisi"].map(
        {"Baik": 0, "Kurang Baik": 1, "Rusak Berat": 1}
    )
    return df


def select_model_features(df: pd.DataFrame) -> pd.DataFrame:
    """Kolom akhir yang masuk ke model — sama seperti df_final di 02."""
    return df[
        ["bahan", "kategori", "umur", "harga_per_unit", "depresiasi_aset", "kondisi_biner", "kondisi_asli"]
    ].copy()
