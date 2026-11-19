import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import type { RealtimeChannel } from '@supabase/supabase-js'

export interface Room { id: number; nama: string }
export interface RoomSummary {
  id: number
  nama: string
  total: number
  perlu: number
  tinggi: number
}
export interface InventoryWithPrediction {
  id: string
  room_id: number
  nama_barang: string
  bahan: string
  kategori: string
  tahun_pembelian: number
  jumlah: number
  harga: number
  kondisi_asli?: string | null
  created_at: string
  rooms?: { nama: string }
  predictions?: Prediction[]
}
export interface Prediction {
  id: string
  inventory_id: string
  prob_perlu_pemeliharaan: number
  label_biner: number
  threshold: number
  prioritas: string
  shap_top3: { fitur: string; penjelasan: string }[]
  model_version: string
  koreksi_petugas: number | null
  created_at: string
  inventories?: { nama_barang: string; room_id: number; bahan: string; kategori: string; tahun_pembelian: number; jumlah: number; harga: number; rooms?: { nama: string } }
}
export interface MaintenanceTask {
  id: string
  prediction_id: string
  status: 'Antre' | 'Dikerjakan' | 'Selesai'
  created_at: string
  predictions?: Prediction
}

export const useInventarisStore = defineStore('inventaris', () => {
  const rooms = ref<Room[]>([])
  const roomSummaries = ref<RoomSummary[]>([])
  const predictions = ref<Prediction[]>([])
  const roomInventories = ref<InventoryWithPrediction[]>([])
  const tasks = ref<MaintenanceTask[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  let channel: RealtimeChannel | null = null

  async function fetchRooms() {
    const { data, error: e } = await supabase.from('rooms').select('*').order('id')
    if (e) { error.value = e.message; return }
    rooms.value = data ?? []
  }

  async function fetchRoomSummaries() {
    const { data, error: e } = await supabase.from('room_summary').select('*').order('id')
    if (e) { error.value = e.message; return }
    roomSummaries.value = (data ?? []).map(r => ({
      id: Number(r.id),
      nama: String(r.nama),
      total: Number(r.total),
      perlu: Number(r.perlu),
      tinggi: Number(r.tinggi),
    }))
  }

  async function fetchPredictions(room_id?: number) {
    loading.value = true
    error.value = null
    let q = supabase
      .from('predictions')
      .select('*, inventories(nama_barang, room_id, bahan, kategori, tahun_pembelian, jumlah, harga, rooms(nama))')
      .order('created_at', { ascending: false })
      .limit(200)
    if (room_id !== undefined) q = q.eq('inventories.room_id', room_id)
    const { data, error: e } = await q
    loading.value = false
    if (e) { error.value = e.message; return }
    predictions.value = (data ?? []).filter(p => p.inventories !== null)
  }

  async function fetchRoomInventories(roomId: number) {
    loading.value = true
    error.value = null
    const { data, error: e } = await supabase
      .from('inventories')
      .select('*, predictions(*), rooms(nama)')
      .eq('room_id', roomId)
      .order('created_at', { ascending: false })
    loading.value = false
    if (e) { error.value = e.message; return }
    roomInventories.value = (data ?? []) as InventoryWithPrediction[]
  }

  async function fetchTasks() {
    const { data, error: e } = await supabase
      .from('maintenance_tasks')
      .select('*, predictions(*, inventories(nama_barang, rooms(nama)))')
      .order('created_at', { ascending: false })
    if (e) { error.value = e.message; return }
    tasks.value = data ?? []
  }

  async function updateTaskStatus(id: string, status: MaintenanceTask['status']) {
    const t = tasks.value.find(x => x.id === id)
    const { error: e } = await supabase.from('maintenance_tasks').update({ status }).eq('id', id)
    if (e) throw new Error(e.message)
    if (t) {
      t.status = status
      if (t.prediction_id) {
        // Jika tugas Selesai -> otomatis koreksi_petugas = 0 (kondisi Baik / selesai perbaikan)
        // Jika kembali ke Antre / Dikerjakan -> reset koreksi_petugas ke null (kembali ke prediksi AI asli)
        const koreksiVal = status === 'Selesai' ? 0 : null
        await supabase
          .from('predictions')
          .update({ koreksi_petugas: koreksiVal })
          .eq('id', t.prediction_id)

        const p = predictions.value.find(x => x.id === t.prediction_id)
        if (p) p.koreksi_petugas = koreksiVal

        // Perbarui juga data roomInventories jika sedang dibuka di tab ruangan
        for (const inv of roomInventories.value) {
          const invPred = inv.predictions?.find(x => x.id === t.prediction_id)
          if (invPred) invPred.koreksi_petugas = koreksiVal
        }
      }
    }
    await Promise.all([
      fetchRoomSummaries(),
      fetchPredictions(),
    ])
  }

  async function addTask(prediction_id: string) {
    const { error: e } = await supabase.from('maintenance_tasks').insert({ prediction_id })
    if (e) throw new Error(e.message)
    await fetchTasks()
  }

  async function correctLabel(prediction_id: string, koreksi: 0 | 1) {
    const { error: e } = await supabase
      .from('predictions')
      .update({ koreksi_petugas: koreksi })
      .eq('id', prediction_id)
    if (e) throw new Error(e.message)
    const p = predictions.value.find(x => x.id === prediction_id)
    if (p) p.koreksi_petugas = koreksi
  }

  async function clearRoomInventories(roomId: number) {
    const { error: err } = await supabase.from('inventories').delete().eq('room_id', roomId)
    if (err) throw new Error(err.message)
    await Promise.all([
      fetchRoomInventories(roomId),
      fetchRoomSummaries(),
    ])
  }

  async function deleteInventory(id: string, roomId?: number) {
    const { error: err } = await supabase.from('inventories').delete().eq('id', id)
    if (err) throw new Error(err.message)
    if (roomId) await fetchRoomInventories(roomId)
    await fetchRoomSummaries()
  }

  function subscribeRealtime() {
    channel = supabase
      .channel('inventaris-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'predictions' }, () => {
        fetchPredictions()
        fetchRoomSummaries()
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'maintenance_tasks' }, () => fetchTasks())
      .subscribe()
  }

  function unsubscribe() {
    channel?.unsubscribe()
  }

  return {
    rooms,
    roomSummaries,
    predictions,
    roomInventories,
    tasks,
    loading,
    error,
    fetchRooms,
    fetchRoomSummaries,
    fetchPredictions,
    fetchRoomInventories,
    fetchTasks,
    updateTaskStatus,
    addTask,
    correctLabel,
    clearRoomInventories,
    deleteInventory,
    subscribeRealtime,
    unsubscribe,
  }
})
