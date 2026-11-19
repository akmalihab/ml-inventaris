from pydantic import BaseModel, Field, field_validator
from typing import Optional


BAHAN_VALID = {"Besi", "Kaca", "Kain", "Kayu", "Plastik"}
KATEGORI_VALID = {"Elektronik", "Furnitur", "Pelengkap"}


class PredictRequest(BaseModel):
    nama_barang: str
    nama_ruangan: str
    bahan: str
    kategori: str
    tahun_pembelian: int = Field(..., ge=1990, le=2030)
    jumlah: int = Field(..., gt=0)
    harga: float = Field(..., gt=0)

    @field_validator("bahan")
    @classmethod
    def bahan_valid(cls, v):
        if v not in BAHAN_VALID:
            raise ValueError(f"bahan harus salah satu dari {sorted(BAHAN_VALID)}")
        return v

    @field_validator("kategori")
    @classmethod
    def kategori_valid(cls, v):
        if v not in KATEGORI_VALID:
            raise ValueError(f"kategori harus salah satu dari {sorted(KATEGORI_VALID)}")
        return v


class Alasan(BaseModel):
    fitur: str
    penjelasan: str


class PredictResponse(BaseModel):
    label_biner: int
    label: str
    probabilitas: float
    prioritas: str
    threshold: float
    alasan_top3: list[Alasan]
    model_version: str
    inventory_id: Optional[str] = None
    prediction_id: Optional[str] = None
