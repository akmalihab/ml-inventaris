const BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:8000'

export interface PredictRequest {
  nama_barang: string
  nama_ruangan: string
  bahan: string
  kategori: string
  tahun_pembelian: number
  jumlah: number
  harga: number
}

export interface Alasan {
  fitur: string
  penjelasan: string
}

export interface PredictResponse {
  label_biner: number
  label: string
  probabilitas: number
  prioritas: string
  threshold: number
  alasan_top3: Alasan[]
  model_version: string
  inventory_id?: string
  prediction_id?: string
}

export interface BatchResult {
  total: number
  perlu_pemeliharaan: number
  baik: number
  hasil: Array<{ nama_barang: string; label?: string; probabilitas?: number; prioritas?: string; error?: string }>
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }))
    throw new Error(JSON.stringify(err.detail ?? err))
  }
  return res.json()
}

export interface ItemShapFeature {
  key: string
  label: string
  raw_value: string | number
  formatted_value: string
  shap_value: number
  direction: 'up' | 'down'
  impact: string
  penjelasan: string
}

export interface ItemShapResponse {
  nama_barang: string
  probabilitas: number
  label: string
  label_biner: number
  prioritas: string
  threshold: number
  base_value: number
  total_shap: number
  rasio_susut_persen?: number
  sisa_nilai_buku?: number
  features: ItemShapFeature[]
  model_version: string
  inventory_id?: string
  room_nama?: string
}

export const api = {
  health: () => request<{ status: string; model: string; threshold_f2: number }>('/health'),

  predict: (body: PredictRequest) =>
    request<PredictResponse>('/predict', { method: 'POST', body: JSON.stringify(body) }),

  explain: (body: PredictRequest) =>
    request<ItemShapResponse>('/explain', { method: 'POST', body: JSON.stringify(body) }),

  explainById: (inventoryId: string) =>
    request<ItemShapResponse>(`/inventaris/${inventoryId}/explain`),

  predictBatch: async (file: File, targetRoomId?: number | null): Promise<BatchResult> => {
    const form = new FormData()
    form.append('file', file)
    const qs = targetRoomId ? `?target_room_id=${targetRoomId}` : ''
    const res = await fetch(`${BASE}/predict/batch${qs}`, { method: 'POST', body: form })
    if (!res.ok) {
      const text = await res.text()
      try {
        const err = JSON.parse(text)
        throw new Error(err.detail ?? text)
      } catch {
        throw new Error(text || `HTTP ${res.status}: ${res.statusText}`)
      }
    }
    return res.json()
  },

  predictions: (room_id?: number, limit = 50) => {
    const qs = new URLSearchParams({ limit: String(limit) })
    if (room_id !== undefined) qs.set('room_id', String(room_id))
    return request<any[]>(`/predictions?${qs}`)
  },

  correctLabel: (prediction_id: string, koreksi: 0 | 1) =>
    request<unknown>(`/predictions/${prediction_id}/koreksi`, {
      method: 'PATCH',
      body: JSON.stringify({ koreksi_petugas: koreksi }),
    }),
}
