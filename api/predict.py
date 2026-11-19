"""
Logika prediksi: feature engineering, inference, SHAP, terjemahan alasan.
Pakai ulang src/preprocessing.py — jangan tulis ulang rumus depresiasi.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from datetime import datetime
import pandas as pd
import shap
import joblib

from src.preprocessing import add_umur, add_harga_per_unit, impute_harga_per_unit, add_depresiasi

# Muat bundle sekali saat modul diimpor
_BUNDLE_PATH = os.path.join(os.path.dirname(__file__), "..", "models", "xgb_scaleposweight_binary.pkl")
bundle = joblib.load(_BUNDLE_PATH)

_REF_PATH = os.path.join(os.path.dirname(__file__), "..", "models", "preprocessing_reference_v2.pkl")
_ref = joblib.load(_REF_PATH) if os.path.exists(_REF_PATH) else {}

model = bundle["model"]
scaler = bundle["scaler"]
encoder = bundle["encoder"]  # OrdinalEncoder — dijalankan dulu
onehot = bundle["onehot"]    # OneHotEncoder di atas hasil ordinal
threshold = bundle["threshold_f2"]
model_version = "xgb_scaleposweight_binary v1"
num_cols = bundle["num_cols"]   # ['umur', 'harga_per_unit', 'depresiasi_aset']
cat_cols = bundle["cat_cols"]   # ['bahan', 'kategori']

_explainer = None  # lazy init saat predict_one dipanggil pertama kali

# Mapping indeks onehot → nama kategori asli, untuk terjemahan alasan
# onehot difit di atas output OrdinalEncoder (angka), jadi feature names-nya "bahan_0.0" dll
_ord_categories = {col: list(cats) for col, cats in zip(cat_cols, encoder.categories_)}


def _prioritas(prob: float) -> str:
    if prob > 0.8:
        return "Tinggi"
    if prob >= 0.5:
        return "Sedang"
    return "Baik"


# Template kalimat per fitur + arah SHAP
_TEMPLATE = {
    "harga_per_unit": {
        1: lambda v: f"harga per unit Rp{v:,.0f} mendorong ke Perlu Pemeliharaan",
        -1: lambda v: f"harga per unit Rp{v:,.0f} menahan ke Baik",
    },
    "umur": {
        1: lambda v: f"umur {v:.0f} tahun mendorong ke Perlu Pemeliharaan",
        -1: lambda v: f"umur {v:.0f} tahun menahan ke Baik",
    },
    "depresiasi_aset": {
        1: lambda v: f"depresiasi aset Rp{v:,.0f} mendorong ke Perlu Pemeliharaan",
        -1: lambda v: f"depresiasi aset Rp{v:,.0f} menahan ke Baik",
    },
    "bahan": {
        1: lambda v: f"material {v} cenderung Perlu Pemeliharaan",
        -1: lambda v: f"material {v} cenderung Baik",
    },
    "kategori": {
        1: lambda v: f"kategori {v} cenderung Perlu Pemeliharaan",
        -1: lambda v: f"kategori {v} cenderung Baik",
    },
}


def _kalimat(fitur_encoded: str, shap_val: float, row_raw: pd.Series) -> dict:
    """
    Terjemahkan satu entri SHAP ke kalimat biasa.
    fitur_encoded: 'umur', 'harga_per_unit', 'depresiasi_aset',
    atau 'bahan_0.0'..'bahan_4.0', 'kategori_0.0'..'kategori_2.0' (ordinal->OHE).
    """
    arah = 1 if shap_val > 0 else -1

    # Fitur numerik langsung
    if fitur_encoded in _TEMPLATE:
        nilai = row_raw[fitur_encoded]
        return {"fitur": fitur_encoded, "penjelasan": _TEMPLATE[fitur_encoded][arah](nilai)}

    # Fitur dari onehot atas ordinal: "bahan_0.0", "kategori_1.0", dll
    for base in ("bahan", "kategori"):
        if fitur_encoded.startswith(base + "_"):
            nilai_kategori = row_raw[base]  # nilai string asli, e.g. "Besi"
            if shap_val == 0:
                # fitur ini tidak aktif — tampilkan ketiadaannya
                idx = int(float(fitur_encoded.split("_", 1)[1]))
                label_fitur = _ord_categories[base][idx]
                arah_str = "mendorong ke Perlu Pemeliharaan" if arah == 1 else "menahan ke Baik"
                return {"fitur": base, "penjelasan": f"bukan {label_fitur} {arah_str}"}
            return {"fitur": base, "penjelasan": _TEMPLATE[base][arah](nilai_kategori)}

    # Fallback
    arah_str = "mendorong ke Perlu Pemeliharaan" if arah == 1 else "menahan ke Baik"
    return {"fitur": fitur_encoded, "penjelasan": f"{fitur_encoded} {arah_str}"}


def predict_batch_df(df: pd.DataFrame) -> tuple[list[dict], pd.DataFrame]:
    """Prediksi banyak baris sekaligus — vectorized, tanpa SHAP per baris."""
    import numpy as np
    current_year = datetime.now().year
    df = add_umur(df, current_year)
    df = add_harga_per_unit(df)
    df = impute_harga_per_unit(df, _ref)
    df = add_depresiasi(df)

    X_num = scaler.transform(df[num_cols])
    X_ord = encoder.transform(df[cat_cols])
    X_cat = onehot.transform(X_ord)
    X = np.hstack([X_num, X_cat])

    probs = model.predict_proba(X)[:, 1]
    results = []
    for i, prob in enumerate(probs):
        prob = float(prob)
        results.append({
            "nama_barang": str(df.iloc[i].get("nama_barang", "")),
            "label": "Perlu Pemeliharaan" if prob >= threshold else "Baik",
            "probabilitas": round(prob, 6),
            "prioritas": _prioritas(prob),
        })
    return results, df


def predict_one(data: dict) -> dict:
    global _explainer
    import numpy as np
    if _explainer is None:
        _explainer = shap.TreeExplainer(model)
    df = pd.DataFrame([data])
    current_year = datetime.now().year
    df = add_umur(df, current_year)
    df = add_harga_per_unit(df)
    df = impute_harga_per_unit(df, _ref)
    df = add_depresiasi(df)
    row_raw = df.iloc[0]

    # Preprocessing: scale numerik, ordinal lalu onehot untuk kategorik
    X_num = scaler.transform(df[num_cols])
    X_ord = encoder.transform(df[cat_cols])
    X_cat = onehot.transform(X_ord)

    X = np.hstack([X_num, X_cat])

    prob = float(model.predict_proba(X)[0, 1])
    label_biner = int(prob >= threshold)
    label = "Perlu Pemeliharaan" if label_biner == 1 else "Baik"
    prioritas = _prioritas(prob)

    # SHAP untuk baris ini
    shap_vals = _explainer.shap_values(X)[0]  # shape: (n_features,)
    cat_feature_names = onehot.get_feature_names_out(cat_cols).tolist()
    all_feature_names = num_cols + cat_feature_names

    # Ambil top-3 |SHAP|, skip fitur onehot bernilai 0 yang tidak aktif
    # (PRD: fitur one-hot bernilai 0 tidak ditampilkan mentah)
    ranked = sorted(
        zip(all_feature_names, shap_vals),
        key=lambda x: abs(x[1]),
        reverse=True,
    )
    alasan = []
    seen_base = set()
    for fname, sval in ranked:
        base = fname.split("_")[0] if fname.startswith(("bahan_", "kategori_")) else fname
        if base in seen_base:
            continue
        seen_base.add(base)
        alasan.append(_kalimat(fname, sval, row_raw))
        if len(alasan) == 3:
            break

    return {
        "label_biner": label_biner,
        "label": label,
        "probabilitas": round(prob, 6),
        "prioritas": prioritas,
        "threshold": round(threshold, 3),
        "alasan_top3": alasan,
        "model_version": model_version,
        # fitur turunan untuk disimpan ke DB
        "_umur": int(row_raw["umur"]),
        "_harga_per_unit": float(row_raw["harga_per_unit"]),
        "_depresiasi_aset": float(row_raw["depresiasi_aset"]),
    }


def explain_item(data: dict) -> dict:
    """
    Hitung nilai SHAP lokal lengkap per fitur untuk 1 item barang.
    Mengembalikan kontribusi per 5 fitur utama (raw value, shap value, arah dorongan).
    """
    global _explainer
    import numpy as np
    if _explainer is None:
        _explainer = shap.TreeExplainer(model)

    df = pd.DataFrame([data])
    current_year = datetime.now().year
    df = add_umur(df, current_year)
    df = add_harga_per_unit(df)
    df = impute_harga_per_unit(df, _ref)
    df = add_depresiasi(df)
    row_raw = df.iloc[0]

    X_num = scaler.transform(df[num_cols])
    X_ord = encoder.transform(df[cat_cols])
    X_cat = onehot.transform(X_ord)
    X = np.hstack([X_num, X_cat])

    prob = float(model.predict_proba(X)[0, 1])
    label_biner = int(prob >= threshold)
    label = "Perlu Pemeliharaan" if label_biner == 1 else "Baik"
    prioritas = _prioritas(prob)

    shap_vals = _explainer.shap_values(X)[0]
    cat_feature_names = onehot.get_feature_names_out(cat_cols).tolist()
    all_names = num_cols + cat_feature_names

    # Agregasi ke 5 fitur domain utama
    agg_shap = {"depresiasi_aset": 0.0, "kategori": 0.0, "bahan": 0.0, "harga_per_unit": 0.0, "umur": 0.0}
    for name, val in zip(all_names, shap_vals):
        if name.startswith("bahan_"):
            agg_shap["bahan"] += float(val)
        elif name.startswith("kategori_"):
            agg_shap["kategori"] += float(val)
        elif name in agg_shap:
            agg_shap[name] += float(val)

    # Hitung metrik susut relatif
    harga_unit = float(row_raw["harga_per_unit"])
    depresiasi = float(row_raw["depresiasi_aset"])
    rasio_susut = min(100.0, max(0.0, (depresiasi / harga_unit) * 100)) if harga_unit > 0 else 0.0
    sisa_nilai_buku = max(0.0, harga_unit - depresiasi)

    # Format representasi untuk UI
    meta = {
        "depresiasi_aset": {
            "label": "Depresiasi Aset",
            "formatted": f"Rp{depresiasi:,.0f} ({rasio_susut:.1f}% susut)",
            "unit": "Rupiah",
        },
        "kategori": {
            "label": "Kategori Barang",
            "formatted": str(row_raw["kategori"]),
            "unit": "Kategori",
        },
        "bahan": {
            "label": "Bahan / Material",
            "formatted": str(row_raw["bahan"]),
            "unit": "Material",
        },
        "harga_per_unit": {
            "label": "Harga per Unit",
            "formatted": f"Rp{harga_unit:,.0f}",
            "unit": "Rupiah",
        },
        "umur": {
            "label": "Umur Aset",
            "formatted": f"{row_raw['umur']:.0f} tahun",
            "unit": "Tahun",
        },
    }

    feature_list = []
    for key, sval in agg_shap.items():
        m = meta[key]
        arah = 1 if sval > 0 else -1
        explanation = _TEMPLATE[key][arah](row_raw[key])
        if key == "depresiasi_aset":
            explanation += f" ({rasio_susut:.1f}% dari harga perolehan)"
        feature_list.append({
            "key": key,
            "label": m["label"],
            "raw_value": row_raw[key] if not isinstance(row_raw[key], (np.integer, np.floating)) else float(row_raw[key]),
            "formatted_value": m["formatted"],
            "shap_value": round(float(sval), 4),
            "direction": "up" if sval > 0 else "down",
            "impact": "Mendorong ke Perlu Pemeliharaan" if sval > 0 else "Menahan ke Kondisi Baik",
            "penjelasan": explanation,
        })

    # Urutkan berdasarkan besaran absolut pengaruh |SHAP|
    feature_list.sort(key=lambda x: abs(x["shap_value"]), reverse=True)

    base_val = _explainer.expected_value
    if hasattr(base_val, "__len__"):
        base_val = float(base_val[0])
    else:
        base_val = float(base_val)

    return {
        "nama_barang": str(row_raw.get("nama_barang", "")),
        "probabilitas": round(prob, 6),
        "label": label,
        "label_biner": label_biner,
        "prioritas": prioritas,
        "threshold": round(threshold, 3),
        "base_value": round(base_val, 4),
        "total_shap": round(sum(agg_shap.values()), 4),
        "rasio_susut_persen": round(rasio_susut, 1),
        "sisa_nilai_buku": round(sisa_nilai_buku, 2),
        "features": feature_list,
        "model_version": model_version,
    }
