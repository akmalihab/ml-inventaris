"""
Test otomatis Fase 1 — FR-API-6.
Jalankan: conda run -n ml-inventaris python api/test_api.py
API harus sudah jalan di http://localhost:8000.
"""

import requests

BASE = "http://localhost:8000"


def test_health():
    r = requests.get(f"{BASE}/health")
    assert r.status_code == 200
    d = r.json()
    assert d["status"] == "ok"
    assert "threshold_f2" in d
    print("✓ /health:", d)


def test_ac_panasonic():
    payload = {
        "nama_barang": "AC Panasonic 2 PK",
        "nama_ruangan": "Adenium",
        "bahan": "Besi",
        "kategori": "Elektronik",
        "tahun_pembelian": 2013,
        "jumlah": 1,
        "harga": 10845230,
    }
    r = requests.post(f"{BASE}/predict", json=payload)
    assert r.status_code == 200, r.text
    d = r.json()
    prob = d["probabilitas"]
    assert prob > 0.95, f"Ekspektasi prob > 0.95, dapat {prob}"
    assert d["label"] == "Perlu Pemeliharaan", f"Ekspektasi Perlu Pemeliharaan, dapat {d['label']}"
    assert len(d["alasan_top3"]) == 3
    print(f"✓ AC Panasonic: prob={prob:.4f}, label={d['label']}, prioritas={d['prioritas']}")
    print(f"  Alasan: {[a['penjelasan'] for a in d['alasan_top3']]}")


def test_barang_baik():
    # Barang baru murah, baru dibeli — harusnya Baik
    payload = {
        "nama_barang": "Kursi Plastik",
        "nama_ruangan": "Mawar",
        "bahan": "Plastik",
        "kategori": "Furnitur",
        "tahun_pembelian": 2024,
        "jumlah": 10,
        "harga": 500000,
    }
    r = requests.post(f"{BASE}/predict", json=payload)
    assert r.status_code == 200, r.text
    d = r.json()
    prob = d["probabilitas"]
    assert prob < 0.417, f"Ekspektasi prob < 0.417, dapat {prob}"
    assert d["label"] == "Baik", f"Ekspektasi Baik, dapat {d['label']}"
    print(f"✓ Barang Baik: prob={prob:.4f}, label={d['label']}")


def test_validasi_bahan_salah():
    payload = {
        "nama_barang": "X",
        "nama_ruangan": "Mawar",
        "bahan": "Emas",   # tidak valid
        "kategori": "Furnitur",
        "tahun_pembelian": 2020,
        "jumlah": 1,
        "harga": 100000,
    }
    r = requests.post(f"{BASE}/predict", json=payload)
    assert r.status_code == 422, f"Ekspektasi 422, dapat {r.status_code}"
    print("✓ Validasi bahan salah ditolak dengan 422")


if __name__ == "__main__":
    print("=== Test API ML Inventaris ===")
    test_health()
    test_ac_panasonic()
    test_barang_baik()
    test_validasi_bahan_salah()
    print("\n✅ Semua test lolos")
