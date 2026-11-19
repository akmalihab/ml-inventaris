import os
import io
import csv
from datetime import datetime
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from supabase import create_client

# Load .env dari root project (satu level di atas folder api/)
load_dotenv(Path(__file__).parent.parent / ".env")

from api.schemas import PredictRequest, PredictResponse
from api.predict import predict_one, predict_batch_df, explain_item, model_version, threshold

app = FastAPI(title="ML Inventaris API")

cors_origins = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ORIGINS",
        "http://localhost:5173,https://app.lynxagent.my.id,http://localhost:8000"
    ).split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins if cors_origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_supabase_url = os.environ.get("SUPABASE_URL", "")
_supabase_key = os.environ.get("SUPABASE_KEY", "")
_db = create_client(_supabase_url, _supabase_key) if _supabase_url and _supabase_key else None


def _save_to_db(req: PredictRequest, result: dict) -> tuple[str | None, str | None]:
    """Simpan ke inventories + predictions. Return (inventory_id, prediction_id)."""
    if _db is None:
        return None, None

    # Cari room_id dari nama_ruangan
    room = _db.table("rooms").select("id").eq("nama", req.nama_ruangan).single().execute()
    room_id = room.data["id"] if room.data else None

    inv = _db.table("inventories").insert({
        "room_id": room_id,
        "nama_barang": req.nama_barang,
        "bahan": req.bahan,
        "kategori": req.kategori,
        "tahun_pembelian": req.tahun_pembelian,
        "jumlah": req.jumlah,
        "harga": req.harga,
    }).execute()
    inventory_id = inv.data[0]["id"]

    pred = _db.table("predictions").insert({
        "inventory_id": inventory_id,
        "prob_perlu_pemeliharaan": result["probabilitas"],
        "label_biner": result["label_biner"],
        "threshold": result["threshold"],
        "prioritas": result["prioritas"],
        "shap_top3": result["alasan_top3"],
        "model_version": result["model_version"],
    }).execute()
    prediction_id = pred.data[0]["id"]

    return inventory_id, prediction_id


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": model_version,
        "threshold_f2": round(threshold, 3),
    }


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    result = predict_one(req.model_dump())
    inventory_id, prediction_id = _save_to_db(req, result)
    return PredictResponse(
        **{k: v for k, v in result.items() if not k.startswith("_")},
        inventory_id=inventory_id,
        prediction_id=prediction_id,
    )


@app.post("/explain")
def explain(req: PredictRequest):
    return explain_item(req.model_dump())


@app.get("/inventaris/{inventory_id}/explain")
def explain_by_id(inventory_id: str):
    if _db is None:
        raise HTTPException(status_code=503, detail="Database tidak terhubung")
    inv = _db.table("inventories").select("*, rooms(nama)").eq("id", inventory_id).single().execute()
    if not inv.data:
        raise HTTPException(status_code=404, detail="Barang tidak ditemukan")
    d = inv.data
    payload = {
        "nama_barang": d["nama_barang"],
        "nama_ruangan": d["rooms"]["nama"] if d.get("rooms") else "-",
        "bahan": d["bahan"],
        "kategori": d["kategori"],
        "tahun_pembelian": d["tahun_pembelian"],
        "jumlah": d["jumlah"],
        "harga": float(d["harga"]),
    }
    res = explain_item(payload)
    res["inventory_id"] = inventory_id
    res["room_nama"] = payload["nama_ruangan"]
    return res


@app.post("/predict/batch")
def predict_batch(
    file: UploadFile = File(...),
    target_room_id: int | None = None,
):
    content = file.file.read().decode("utf-8")
    try:
        df = pd.read_csv(io.StringIO(content))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"CSV tidak valid: {e}")

    # Bersihkan whitespace nama kolom
    df.columns = df.columns.str.strip()

    required = {"nama_barang", "bahan", "kategori", "tahun_pembelian", "jumlah", "harga"}
    missing = required - set(df.columns)
    if missing:
        raise HTTPException(status_code=400, detail=f"Kolom tidak ada: {sorted(missing)}")

    # Sanitasi kolom 'jumlah': pastikan numeric >= 1 agar lolos constraint DB dan tidak division by zero
    df["jumlah"] = pd.to_numeric(df["jumlah"], errors="coerce").fillna(1).astype(int)
    df["jumlah"] = df["jumlah"].apply(lambda x: 1 if x <= 0 else x)

    # Sanitasi 'tahun_pembelian'
    df["tahun_pembelian"] = pd.to_numeric(df["tahun_pembelian"], errors="coerce").fillna(datetime.now().year).astype(int)

    # Sanitasi 'harga'
    df["harga"] = pd.to_numeric(df["harga"], errors="coerce")

    # Sanitasi string columns
    for col in ["nama_barang", "bahan", "kategori"]:
        df[col] = df[col].astype(str).str.strip()

    if "nama_ruangan" not in df.columns:
        df["nama_ruangan"] = "Adenium"
    else:
        df["nama_ruangan"] = df["nama_ruangan"].astype(str).str.strip()

    try:
        results, df_feat = predict_batch_df(df)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # Simpan ke DB bila tersedia
    if _db is not None:
        try:
            # Ambil semua rooms sekaligus
            rooms_data = _db.table("rooms").select("id,nama").execute().data
            room_map = {r["nama"].strip(): r["id"] for r in rooms_data}

            inv_rows = []
            for i, row in df_feat.iterrows():
                # Jika harga di CSV null, pakai harga_per_unit terimputasi * jumlah
                harga_raw = row.get("harga")
                jml = int(row["jumlah"]) if pd.notna(row.get("jumlah")) and int(row["jumlah"]) > 0 else 1

                if pd.notna(harga_raw) and float(harga_raw) > 0:
                    harga_val = float(harga_raw)
                else:
                    hpu = float(row.get("harga_per_unit", 100000))
                    harga_val = float(hpu * jml)

                # Validasi kategori ke check constraint
                kat = str(row["kategori"]).strip()
                if kat not in ("Elektronik", "Furnitur", "Pelengkap"):
                    kat = "Furnitur"  # default fallback jika anomali

                kondisi_asli_val = str(row["kondisi"]).strip() if "kondisi" in row and pd.notna(row.get("kondisi")) else None
                if kondisi_asli_val not in ("Baik", "Kurang Baik", "Rusak Berat"):
                    kondisi_asli_val = None

                if target_room_id is not None and target_room_id in room_map.values():
                    room_id = target_room_id
                else:
                    r_name = str(row.get("nama_ruangan", "Adenium")).strip()
                    room_id = room_map.get(r_name) or room_map.get("Adenium") or 1

                inv_rows.append({
                    "room_id": room_id,
                    "nama_barang": str(row["nama_barang"]),
                    "bahan": str(row["bahan"]),
                    "kategori": kat,
                    "tahun_pembelian": int(row["tahun_pembelian"]),
                    "jumlah": jml,
                    "harga": harga_val,
                    "triwulan": str(row["triwulan"]) if "triwulan" in row and pd.notna(row.get("triwulan")) else None,
                    "kondisi_asli": kondisi_asli_val,
                })

            # Chunk insert per 500 baris
            chunk_size = 500
            inv_ids = []
            for start_idx in range(0, len(inv_rows), chunk_size):
                chunk = inv_rows[start_idx:start_idx + chunk_size]
                res = _db.table("inventories").insert(chunk).execute()
                inv_ids.extend([r["id"] for r in res.data])

            # Chunk insert predictions
            pred_rows = []
            for inv_id, result in zip(inv_ids, results):
                pred_rows.append({
                    "inventory_id": inv_id,
                    "prob_perlu_pemeliharaan": result["probabilitas"],
                    "label_biner": 1 if result["label"] == "Perlu Pemeliharaan" else 0,
                    "threshold": round(threshold, 3),
                    "prioritas": result["prioritas"],
                    "shap_top3": None,  # batch tidak hitung SHAP per baris
                    "model_version": model_version,
                })

            for start_idx in range(0, len(pred_rows), chunk_size):
                chunk = pred_rows[start_idx:start_idx + chunk_size]
                _db.table("predictions").insert(chunk).execute()
        except Exception as db_err:
            raise HTTPException(status_code=500, detail=f"Database insert error: {db_err}")

    n_perlu = sum(1 for r in results if r["label"] == "Perlu Pemeliharaan")
    return {
        "total": len(results),
        "perlu_pemeliharaan": n_perlu,
        "baik": len(results) - n_perlu,
        "hasil": results,
    }


from pydantic import BaseModel as _Base

class KoreksiBody(_Base):
    koreksi_petugas: int

@app.patch("/predictions/{prediction_id}/koreksi")
def patch_koreksi(prediction_id: str, body: KoreksiBody):
    if body.koreksi_petugas not in (0, 1):
        raise HTTPException(status_code=422, detail="koreksi_petugas harus 0 atau 1")
    if _db is None:
        raise HTTPException(status_code=503, detail="Database tidak terkonfigurasi")
    _db.table("predictions").update({"koreksi_petugas": body.koreksi_petugas}).eq("id", prediction_id).execute()
    return {"ok": True}


@app.get("/predictions")
def get_predictions(room_id: int | None = None, limit: int = 50):
    if _db is None:
        return []
    q = (
        _db.table("predictions")
        .select("*, inventories(nama_barang, room_id, rooms(nama))")
        .order("created_at", desc=True)
        .limit(limit)
    )
    if room_id is not None:
        q = q.eq("inventories.room_id", room_id)
    return q.execute().data
