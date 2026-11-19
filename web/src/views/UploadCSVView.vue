<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { api } from '../lib/api'
import { useInventarisStore } from '../stores/inventaris'
import type { BatchResult } from '../lib/api'

const store = useInventarisStore()

const file            = ref<File | null>(null)
const selectedTarget  = ref<string>('all') // 'all' = otomatis dari kolom CSV atau default
const loading         = ref(false)
const result          = ref<BatchResult | null>(null)
const error           = ref<string | null>(null)

onMounted(async () => {
  if (store.rooms.length === 0) {
    await store.fetchRooms()
  }
})

// Pagination
const currentPage = ref(1)
const pageSize = ref(15)

const totalPages = computed(() => {
  if (!result.value?.hasil.length) return 1
  return Math.max(1, Math.ceil(result.value.hasil.length / pageSize.value))
})

const paginatedHasil = computed(() => {
  if (!result.value?.hasil) return []
  const start = (currentPage.value - 1) * pageSize.value
  return result.value.hasil.slice(start, start + pageSize.value)
})

function setPage(p: number) {
  if (p >= 1 && p <= totalPages.value) {
    currentPage.value = p
  }
}

function onFile(e: Event) {
  const f = (e.target as HTMLInputElement).files?.[0]
  file.value = f ?? null
  result.value = null
  error.value = null
  currentPage.value = 1
}

async function upload() {
  if (!file.value) { error.value = 'Pilih file CSV dulu'; return }
  loading.value = true
  error.value = null
  result.value = null
  currentPage.value = 1
  try {
    const targetRoomId = selectedTarget.value === 'all' ? null : Number(selectedTarget.value)
    result.value = await api.predictBatch(file.value, targetRoomId)
    await store.fetchRoomSummaries()
  } catch (e: any) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="max-w-4xl space-y-6">
    <!-- Header -->
    <div>
      <h1 class="text-xl lg:text-2xl font-bold tracking-tight text-white font-heading">
        Upload CSV Massal
      </h1>
      <p class="text-xs text-slate-400 mt-1">
        Inference batch otomatis untuk data inventaris besar dengan simpan instan ke database.
      </p>
    </div>

    <!-- Upload Card & Instructions -->
    <div class="card-modern p-6 space-y-4">
      <div class="p-3.5 rounded-lg bg-slate-900/60 border border-slate-800 text-xs text-slate-300">
        <div class="font-semibold text-slate-200 mb-1 flex items-center gap-2">
          <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
          Format Kolom CSV Wajib:
        </div>
        <div class="font-mono text-[11px] text-emerald-400/90 break-words">
          nama_barang, bahan, kategori, tahun_pembelian, jumlah, harga
        </div>
        <div class="text-[11px] text-slate-500 mt-1">
          * Kolom <code class="text-slate-400">nama_ruangan</code>, <code class="text-slate-400">triwulan</code>, dan <code class="text-slate-400">kondisi</code> opsional. Bila harga kosong, sistem otomatis mengimputasi hierarkis.
        </div>
      </div>

      <!-- Pilihan Target Ruangan -->
      <div class="p-3.5 rounded-lg bg-slate-900/40 border border-slate-800 space-y-2">
        <label for="select-target-room" class="text-xs font-semibold text-slate-300 flex items-center justify-between">
          <span>Target Alokasi Ruangan:</span>
          <span class="text-[11px] font-normal text-slate-500">
            {{ selectedTarget === 'all' ? 'Sesuai kolom nama_ruangan di CSV' : 'Seluruh baris CSV dimasukkan ke ruangan ini' }}
          </span>
        </label>
        <select
          id="select-target-room"
          v-model="selectedTarget"
          class="input text-xs w-full py-2 bg-slate-950/80 border-slate-800"
        >
          <option value="all">Keseluruhan (Otomatis dari Kolom CSV / Campuran Ruangan)</option>
          <option disabled>────────── Pilih Ruangan Tertentu ──────────</option>
          <option v-for="r in store.rooms" :key="r.id" :value="String(r.id)">
            Ruang {{ r.nama }} (ID: {{ r.id }})
          </option>
        </select>
      </div>

      <!-- File Dropzone -->
      <div
        class="border-2 border-dashed rounded-xl p-8 text-center transition-all duration-200"
        :class="[
          file ? 'border-emerald-500/50 bg-emerald-500/5' : 'border-slate-800 hover:border-slate-700 bg-slate-900/40'
        ]"
      >
        <div class="w-12 h-12 rounded-xl bg-slate-800/80 border border-slate-700/60 text-slate-300 flex items-center justify-center mx-auto mb-3">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" /></svg>
        </div>
        
        <div v-if="!file" class="space-y-1">
          <label for="csv-file" class="text-sm font-semibold text-emerald-400 hover:text-emerald-300 cursor-pointer">
            Pilih file CSV dari perangkat
          </label>
          <p class="text-xs text-slate-500">Mendukung format .csv hingga ribuan baris</p>
        </div>
        <div v-else class="space-y-1">
          <p class="text-sm font-semibold text-slate-200">{{ file.name }}</p>
          <p class="text-xs text-slate-500 font-mono">{{ (file.size / 1024).toFixed(1) }} KB</p>
          <label for="csv-file" class="text-xs text-emerald-400 hover:underline cursor-pointer block pt-1">
            Ganti file
          </label>
        </div>

        <input
          id="csv-file"
          type="file"
          accept=".csv"
          @change="onFile"
          class="hidden"
        />
      </div>

      <!-- Action Button -->
      <div class="flex items-center justify-between pt-2">
        <button
          class="btn-primary px-5 py-2.5 shadow-md shadow-emerald-500/15"
          :disabled="loading || !file"
          @click="upload"
        >
          <svg v-if="loading" class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          <span v-if="loading">Memproses & Menyimpan…</span>
          <span v-else>Mulai Prediksi Batch & Simpan</span>
        </button>

        <span v-if="loading" class="text-xs text-slate-400 animate-pulse">
          Menginferensi model XGBoost & mengeksekusi bulk insert…
        </span>
      </div>
    </div>

    <!-- Error Alert -->
    <div v-if="error" role="alert" class="p-4 rounded-xl bg-rose-500/10 border border-rose-500/25 text-rose-400 text-xs">
      {{ error }}
    </div>

    <!-- Results Section -->
    <div v-if="result" class="space-y-4">
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div class="card-kpi text-center">
          <div class="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">Total Diproses</div>
          <div class="text-3xl font-extrabold font-mono text-white">{{ result.total.toLocaleString('id-ID') }}</div>
        </div>
        <div class="card-kpi text-center hover:border-emerald-500/30">
          <div class="text-xs font-semibold text-emerald-400 uppercase tracking-wider mb-1">Kondisi Baik</div>
          <div class="text-3xl font-extrabold font-mono text-emerald-400">{{ result.baik.toLocaleString('id-ID') }}</div>
        </div>
        <div class="card-kpi text-center hover:border-rose-500/30">
          <div class="text-xs font-semibold text-rose-400 uppercase tracking-wider mb-1">Perlu Pemeliharaan</div>
          <div class="text-3xl font-extrabold font-mono text-rose-400">{{ result.perlu_pemeliharaan.toLocaleString('id-ID') }}</div>
        </div>
      </div>

      <!-- Result Table Preview -->
      <div class="card-modern overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-800 bg-slate-900/40 flex items-center justify-between">
          <div class="font-heading font-semibold text-xs text-slate-200">
            Daftar Hasil Klasifikasi AI (Total {{ result.hasil.length.toLocaleString('id-ID') }} baris)
          </div>
          <span class="text-[11px] text-slate-500 font-mono">Tersimpan ke Supabase</span>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead class="sticky top-0 bg-slate-900/80 backdrop-blur-md border-b border-slate-800 z-10">
              <tr class="text-slate-400 uppercase tracking-wider text-[10px]">
                <th class="py-3 px-4 text-left font-semibold">Nama Barang</th>
                <th class="py-3 px-4 text-left font-semibold">Klasifikasi AI</th>
                <th class="py-3 px-4 text-right font-semibold">Probabilitas</th>
                <th class="py-3 px-4 text-center font-semibold">Prioritas</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60">
              <tr
                v-for="(h, i) in paginatedHasil"
                :key="i"
                class="hover:bg-slate-800/40 transition-colors duration-150"
              >
                <td class="py-2.5 px-4 font-medium text-slate-200">{{ h.nama_barang }}</td>
                <td class="py-2.5 px-4">
                  <span v-if="h.error" class="text-rose-400 text-xs">Error</span>
                  <span
                    v-else
                    :class="h.label === 'Perlu Pemeliharaan' ? 'badge-perlu' : 'badge-baik'"
                  >
                    {{ h.label }}
                  </span>
                </td>
                <td class="py-2.5 px-4 text-right font-mono text-slate-300">
                  {{ h.probabilitas !== undefined ? (h.probabilitas * 100).toFixed(1) + '%' : '-' }}
                </td>
                <td class="py-2.5 px-4 text-center">
                  <span
                    v-if="h.prioritas"
                    :class="{
                      'badge-tinggi': h.prioritas === 'Tinggi',
                      'badge-sedang': h.prioritas === 'Sedang',
                      'badge-baik':   h.prioritas === 'Baik',
                    }"
                  >
                    {{ h.prioritas }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Pagination Footer -->
        <div
          v-if="result.hasil.length > 0"
          class="flex flex-col sm:flex-row items-center justify-between gap-3 p-4 border-t border-slate-800 text-xs bg-slate-900/40"
        >
          <div class="text-slate-400 text-[11px]">
            Menampilkan <span class="font-mono text-slate-200">{{ ((currentPage - 1) * pageSize) + 1 }}</span>
            - <span class="font-mono text-slate-200">{{ Math.min(currentPage * pageSize, result.hasil.length) }}</span>
            dari <span class="font-mono text-slate-200">{{ result.hasil.length }}</span> baris
          </div>

          <div class="flex items-center gap-3">
            <div class="flex items-center gap-1.5 text-slate-400 text-[11px]">
              <span>Baris:</span>
              <select
                v-model.number="pageSize"
                class="bg-slate-900 border border-slate-700/80 rounded px-2 py-1 text-xs text-slate-200 focus:outline-none"
              >
                <option :value="10">10</option>
                <option :value="15">15</option>
                <option :value="25">25</option>
                <option :value="50">50</option>
                <option :value="100">100</option>
              </select>
            </div>

            <div class="flex items-center gap-1">
              <button
                @click="setPage(currentPage - 1)"
                :disabled="currentPage <= 1"
                class="px-2.5 py-1 rounded bg-slate-800 border border-slate-700 text-slate-300 hover:text-white disabled:opacity-40 disabled:cursor-not-allowed text-xs transition-colors"
              >
                &larr; Prev
              </button>
              <span class="px-2 font-mono text-[11px] text-slate-300">
                {{ currentPage }} / {{ totalPages }}
              </span>
              <button
                @click="setPage(currentPage + 1)"
                :disabled="currentPage >= totalPages"
                class="px-2.5 py-1 rounded bg-slate-800 border border-slate-700 text-slate-300 hover:text-white disabled:opacity-40 disabled:cursor-not-allowed text-xs transition-colors"
              >
                Next &rarr;
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
