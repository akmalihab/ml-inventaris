<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useInventarisStore } from '../stores/inventaris'
import type { InventoryWithPrediction } from '../stores/inventaris'

const route = useRoute()
const router = useRouter()
const store = useInventarisStore()

const selectedRoomId = ref<number>(1)
const searchQuery = ref('')
const filterStatus = ref<'semua' | 'baik' | 'perlu' | 'kritis'>('semua')
const filterKategori = ref('semua')

onMounted(async () => {
  await Promise.all([
    store.fetchRooms(),
    store.fetchRoomSummaries(),
  ])

  // Cek query parameter ?id=...
  if (route.query.id) {
    const qid = Number(route.query.id)
    if (store.rooms.some(r => r.id === qid)) {
      selectedRoomId.value = qid
    }
  } else if (store.rooms.length > 0) {
    selectedRoomId.value = store.rooms[0].id
  }

  loadRoomData(selectedRoomId.value)
})

watch(() => route.query.id, (newId) => {
  if (newId) {
    const qid = Number(newId)
    if (qid !== selectedRoomId.value && store.rooms.some(r => r.id === qid)) {
      selectedRoomId.value = qid
      loadRoomData(qid)
    }
  }
})

function switchRoom(id: number) {
  selectedRoomId.value = id
  router.replace({ query: { id } })
  loadRoomData(id)
}

async function loadRoomData(id: number) {
  await store.fetchRoomInventories(id)
}

const currentRoom = computed(() => {
  return store.rooms.find(r => r.id === selectedRoomId.value)
})

const currentSummary = computed(() => {
  return store.roomSummaries.find(s => s.id === selectedRoomId.value) ?? {
    id: selectedRoomId.value,
    nama: currentRoom.value?.nama ?? '-',
    total: store.roomInventories.length,
    perlu: store.roomInventories.filter(i => {
      const p = i.predictions?.[0]
      const eff = p?.koreksi_petugas ?? p?.label_biner ?? 0
      return eff === 1
    }).length,
    tinggi: store.roomInventories.filter(i => {
      const p = i.predictions?.[0]
      const eff = p?.koreksi_petugas ?? p?.label_biner ?? 0
      return eff === 1 && p?.prioritas === 'Tinggi'
    }).length,
  }
})

const filteredItems = computed(() => {
  return store.roomInventories.filter((item: InventoryWithPrediction) => {
    // Search nama barang
    if (searchQuery.value.trim()) {
      const q = searchQuery.value.toLowerCase()
      if (!item.nama_barang.toLowerCase().includes(q)) return false
    }

    // Filter kategori
    if (filterKategori.value !== 'semua') {
      if (item.kategori !== filterKategori.value) return false
    }

    // Filter status
    const pred = item.predictions?.[0]
    const effectiveLabel = pred?.koreksi_petugas ?? pred?.label_biner ?? 0
    const isPerlu = effectiveLabel === 1
    const isTinggi = isPerlu && pred?.prioritas === 'Tinggi'

    if (filterStatus.value === 'baik' && isPerlu) return false
    if (filterStatus.value === 'perlu' && !isPerlu) return false
    if (filterStatus.value === 'kritis' && !isTinggi) return false

    return true
  })
})

// Pagination
const currentPage = ref(1)
const pageSize = ref(15)

watch([searchQuery, filterStatus, filterKategori, selectedRoomId], () => {
  currentPage.value = 1
})

const totalPages = computed(() => {
  return Math.max(1, Math.ceil(filteredItems.value.length / pageSize.value))
})

const paginatedItems = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  return filteredItems.value.slice(start, start + pageSize.value)
})

function setPage(p: number) {
  if (p >= 1 && p <= totalPages.value) {
    currentPage.value = p
  }
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header Page -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="text-xl lg:text-2xl font-bold tracking-tight text-white font-heading">
          Eksplorasi Data Per Ruangan
        </h1>
        <p class="text-xs text-slate-400 mt-1">
          Daftar seluruh inventaris dan hasil inferensi AI spesifik untuk tiap Ruang Rawat Inap Kelas 3.
        </p>
      </div>
      <div class="flex items-center gap-2">
        <RouterLink to="/inventaris/baru" class="btn-primary text-xs">
          + Tambah Aset di Ruangan
        </RouterLink>
      </div>
    </div>

    <!-- 12 Rooms Chip Navigation Tabs -->
    <div class="card-modern p-3">
      <div class="text-[10px] font-semibold text-slate-500 uppercase tracking-wider px-2 mb-2">
        Pilih Dari 12 Ruang Rawat Inap:
      </div>
      <div class="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-thin">
        <button
          v-for="r in store.rooms"
          :key="r.id"
          @click="switchRoom(r.id)"
          class="shrink-0 px-3.5 py-2 rounded-lg text-xs font-semibold transition-all duration-150 flex items-center gap-2 border"
          :class="[
            selectedRoomId === r.id
              ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/40 shadow-sm'
              : 'bg-slate-900/60 text-slate-400 border-slate-800 hover:border-slate-700 hover:text-slate-200'
          ]"
        >
          <span class="font-mono text-[10px] w-4 h-4 rounded flex items-center justify-center bg-slate-800/80">
            {{ r.id }}
          </span>
          <span>{{ r.nama }}</span>
        </button>
      </div>
    </div>

    <!-- Room Summary KPI Metric -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <div class="card-kpi">
        <div class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Ruangan Aktif</div>
        <div class="mt-2 text-xl font-bold font-heading text-white truncate flex items-center gap-2">
          <span>{{ currentRoom?.nama ?? '-' }}</span>
          <span class="text-[11px] font-mono text-emerald-400 font-normal px-2 py-0.5 rounded bg-emerald-500/10 border border-emerald-500/20">
            ID: {{ selectedRoomId }}
          </span>
        </div>
        <div class="mt-2 text-[11px] text-slate-500">Unit Rawat Inap Kelas 3</div>
      </div>

      <div class="card-kpi">
        <div class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Aset Ruangan</div>
        <div class="mt-2 text-2xl font-extrabold font-mono text-white">
          {{ currentSummary.total }} <span class="text-xs font-sans text-slate-400 font-normal">item</span>
        </div>
        <div class="mt-2 text-[11px] text-slate-500">Terdaftar di database</div>
      </div>

      <div class="card-kpi hover:border-amber-500/30">
        <div class="text-xs font-semibold text-amber-400/90 uppercase tracking-wider">Perlu Pemeliharaan</div>
        <div class="mt-2 text-2xl font-extrabold font-mono text-amber-400">
          {{ currentSummary.perlu }}
          <span class="text-xs font-sans text-slate-400 font-normal">
            ({{ currentSummary.total > 0 ? Math.round((currentSummary.perlu / currentSummary.total) * 100) : 0 }}%)
          </span>
        </div>
        <div class="mt-2 text-[11px] text-amber-400/80">Probabilitas &ge; 0.417</div>
      </div>

      <div class="card-kpi hover:border-rose-500/30">
        <div class="text-xs font-semibold text-rose-400/90 uppercase tracking-wider">Prioritas Kritis</div>
        <div class="mt-2 text-2xl font-extrabold font-mono text-rose-400">
          {{ currentSummary.tinggi }} <span class="text-xs font-sans text-slate-400 font-normal">unit</span>
        </div>
        <div class="mt-2 text-[11px] text-rose-400/80">Probabilitas &gt; 80%</div>
      </div>
    </div>

    <!-- Filters & Table Section -->
    <div class="card-modern p-5 space-y-4">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-3 pb-3 border-b border-slate-800">
        <!-- Search bar -->
        <div class="relative flex-1 max-w-sm">
          <svg class="w-4 h-4 absolute left-3 top-3 text-slate-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
          <input
            v-model="searchQuery"
            class="input pl-9 text-xs"
            placeholder="Cari nama barang di ruangan ini…"
          />
        </div>

        <!-- Filter Buttons / Selectors -->
        <div class="flex items-center gap-2 flex-wrap">
          <select v-model="filterKategori" class="input text-xs w-auto py-2">
            <option value="semua">Semua Kategori</option>
            <option value="Elektronik">Elektronik</option>
            <option value="Furnitur">Furnitur</option>
            <option value="Pelengkap">Pelengkap</option>
          </select>

          <div class="flex items-center p-0.5 rounded-lg bg-slate-900 border border-slate-800 text-xs">
            <button
              @click="filterStatus = 'semua'"
              class="px-2.5 py-1 rounded-md transition-colors"
              :class="filterStatus === 'semua' ? 'bg-slate-800 text-white font-medium' : 'text-slate-400 hover:text-slate-200'"
            >
              Semua
            </button>
            <button
              @click="filterStatus = 'baik'"
              class="px-2.5 py-1 rounded-md transition-colors"
              :class="filterStatus === 'baik' ? 'bg-emerald-500/20 text-emerald-400 font-medium' : 'text-slate-400 hover:text-slate-200'"
            >
              Baik
            </button>
            <button
              @click="filterStatus = 'perlu'"
              class="px-2.5 py-1 rounded-md transition-colors"
              :class="filterStatus === 'perlu' ? 'bg-amber-500/20 text-amber-400 font-medium' : 'text-slate-400 hover:text-slate-200'"
            >
              Perlu
            </button>
            <button
              @click="filterStatus = 'kritis'"
              class="px-2.5 py-1 rounded-md transition-colors"
              :class="filterStatus === 'kritis' ? 'bg-rose-500/20 text-rose-400 font-medium' : 'text-slate-400 hover:text-slate-200'"
            >
              Kritis
            </button>
          </div>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="store.loading" class="py-12 text-center text-xs text-slate-400">
        Memuat data barang untuk {{ currentRoom?.nama }}…
      </div>

      <!-- Empty State -->
      <div v-else-if="filteredItems.length === 0" class="py-12 text-center space-y-2">
        <p class="text-sm font-semibold text-slate-300">Tidak ada barang yang sesuai filter</p>
        <p class="text-xs text-slate-500">
          Belum ada data barang atau kriteria pencarian tidak cocok di ruangan ini.
        </p>
      </div>

      <!-- Inventory Table -->
      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="border-b border-slate-800 bg-slate-900/60 text-slate-400 uppercase tracking-wider text-[10px]">
              <th class="py-3 px-4 text-left font-semibold">Nama Barang</th>
              <th class="py-3 px-3 text-left font-semibold">Spesifikasi</th>
              <th class="py-3 px-3 text-right font-semibold">Tahun</th>
              <th class="py-3 px-3 text-right font-semibold">Kuantitas</th>
              <th class="py-3 px-3 text-right font-semibold">Harga Total</th>
              <th class="py-3 px-4 text-left font-semibold">Status AI</th>
              <th class="py-3 px-3 text-right font-semibold">Probabilitas</th>
              <th class="py-3 px-4 text-center font-semibold">Aksi SHAP</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-800/60">
            <tr
              v-for="item in paginatedItems"
              :key="item.id"
              class="hover:bg-slate-800/40 transition-colors duration-150"
            >
              <!-- Nama -->
              <td class="py-3 px-4 font-medium text-slate-100 max-w-[200px]">
                <div class="truncate font-semibold">{{ item.nama_barang }}</div>
                <div class="text-[10px] text-slate-500 font-mono truncate">ID: {{ item.id.slice(0, 8) }}…</div>
              </td>

              <!-- Spesifikasi -->
              <td class="py-3 px-3 text-slate-300">
                <div>{{ item.kategori }}</div>
                <div class="text-[10px] text-slate-500">{{ item.bahan }}</div>
              </td>

              <!-- Tahun -->
              <td class="py-3 px-3 text-right font-mono text-slate-300">
                {{ item.tahun_pembelian }}
              </td>

              <!-- Kuantitas -->
              <td class="py-3 px-3 text-right font-mono text-slate-300">
                {{ item.jumlah }} unit
              </td>

              <!-- Harga -->
              <td class="py-3 px-3 text-right font-mono text-slate-200">
                Rp{{ Number(item.harga).toLocaleString('id-ID') }}
              </td>

              <!-- Status AI -->
              <td class="py-3 px-4 whitespace-nowrap">
                <span
                  v-if="item.predictions && item.predictions.length > 0"
                  :class="((item.predictions[0].koreksi_petugas ?? item.predictions[0].label_biner) === 1) ? 'badge-perlu' : 'badge-baik'"
                >
                  <template v-if="item.predictions[0].koreksi_petugas === 0">
                    Baik (Selesai Perbaikan)
                  </template>
                  <template v-else-if="item.predictions[0].koreksi_petugas === 1">
                    Perlu Pemeliharaan (Koreksi)
                  </template>
                  <template v-else>
                    {{ item.predictions[0].label_biner === 1 ? 'Perlu Pemeliharaan' : 'Baik' }}
                  </template>
                </span>
                <span v-else class="text-slate-500 text-[11px]">-</span>
              </td>

              <!-- Probabilitas -->
              <td class="py-3 px-3 text-right whitespace-nowrap">
                <span
                  v-if="item.predictions && item.predictions.length > 0"
                  class="font-mono font-bold"
                  :class="item.predictions[0].prob_perlu_pemeliharaan > 0.8 ? 'text-rose-400' : item.predictions[0].prob_perlu_pemeliharaan >= 0.417 ? 'text-amber-400' : 'text-emerald-400'"
                >
                  {{ (item.predictions[0].prob_perlu_pemeliharaan * 100).toFixed(1) }}%
                </span>
                <span v-else class="text-slate-500 font-mono text-[11px]">-</span>
              </td>

              <!-- Aksi -->
              <td class="py-3 px-4 text-center whitespace-nowrap">
                <div class="flex items-center justify-center gap-1.5">
                  <RouterLink
                    :to="`/analisis-shap?id=${item.id}`"
                    class="px-2.5 py-1 rounded-lg bg-teal-500/10 border border-teal-500/20 text-teal-300 hover:bg-teal-500 hover:text-white transition-all text-[11px] font-medium inline-flex items-center gap-1"
                    title="Buka Nilai SHAP Per Item"
                  >
                    <span>Nilai SHAP</span>
                  </RouterLink>
                  <RouterLink
                    :to="`/inventaris/${item.id}`"
                    class="p-1 rounded-lg bg-slate-800 border border-slate-700/60 text-slate-300 hover:text-white hover:bg-slate-700 transition-colors"
                    title="Buka Halaman Detail"
                  >
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" /></svg>
                  </RouterLink>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination Footer -->
      <div
        v-if="filteredItems.length > 0"
        class="flex flex-col sm:flex-row items-center justify-between gap-3 pt-3 border-t border-slate-800 text-xs"
      >
        <div class="text-slate-400 text-[11px]">
          Menampilkan <span class="font-mono text-slate-200">{{ ((currentPage - 1) * pageSize) + 1 }}</span>
          - <span class="font-mono text-slate-200">{{ Math.min(currentPage * pageSize, filteredItems.length) }}</span>
          dari <span class="font-mono text-slate-200">{{ filteredItems.length }}</span> total barang
        </div>

        <div class="flex items-center gap-3">
          <!-- Page Size selector -->
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
            </select>
          </div>

          <!-- Page Navigation Buttons -->
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
</template>
