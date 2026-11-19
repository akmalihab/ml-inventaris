<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useInventarisStore } from '../stores/inventaris'
import type { MaintenanceTask } from '../stores/inventaris'

const store = useInventarisStore()
const STATUS: MaintenanceTask['status'][] = ['Antre', 'Dikerjakan', 'Selesai']

const searchQuery = ref('')
const filterStatus = ref<'Semua' | MaintenanceTask['status']>('Semua')

const currentPage = ref(1)
const pageSize = ref(10)

onMounted(() => store.fetchTasks())

watch([searchQuery, filterStatus], () => {
  currentPage.value = 1
})

async function ubahStatus(id: string, status: MaintenanceTask['status']) {
  await store.updateTaskStatus(id, status)
}

const filteredTasks = computed(() => {
  return store.tasks.filter(t => {
    if (filterStatus.value !== 'Semua' && t.status !== filterStatus.value) return false
    if (searchQuery.value.trim()) {
      const q = searchQuery.value.toLowerCase()
      const nama = t.predictions?.inventories?.nama_barang?.toLowerCase() ?? ''
      const ruangan = t.predictions?.inventories?.rooms?.nama?.toLowerCase() ?? ''
      if (!nama.includes(q) && !ruangan.includes(q)) return false
    }
    return true
  })
})

const totalPages = computed(() => {
  return Math.max(1, Math.ceil(filteredTasks.value.length / pageSize.value))
})

const paginatedTasks = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  return filteredTasks.value.slice(start, start + pageSize.value)
})

function setPage(p: number) {
  if (p >= 1 && p <= totalPages.value) {
    currentPage.value = p
  }
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-xl lg:text-2xl font-bold tracking-tight text-white font-heading">
        Antrean Tugas Pemeliharaan
      </h1>
      <p class="text-xs text-slate-400 mt-1">
        Daftar tindak lanjut perbaikan inventaris dari hasil inferensi model XGBoost.
      </p>
    </div>

    <div v-if="store.error" role="alert" class="p-4 rounded-xl bg-rose-500/10 border border-rose-500/25 text-rose-400 text-xs">
      {{ store.error }}
    </div>

    <div v-if="store.tasks.length === 0" class="card-modern p-12 text-center space-y-3">
      <div class="w-12 h-12 rounded-xl bg-slate-800/80 border border-slate-700/60 text-slate-400 flex items-center justify-center mx-auto">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
      </div>
      <p class="text-sm font-semibold text-slate-200">Tidak ada antrean pemeliharaan aktif</p>
      <p class="text-xs text-slate-500 max-w-sm mx-auto">
        Tugas pemeliharaan dapat ditambahkan dari halaman detail aset yang terprediksi memerlukan tindakan.
      </p>
    </div>

    <div v-else class="card-modern overflow-hidden space-y-0">
      <!-- Toolbar Filter & Search -->
      <div class="p-4 border-b border-slate-800 bg-slate-900/40 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="relative flex-1 max-w-sm">
          <svg class="w-4 h-4 absolute left-3 top-2.5 text-slate-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
          <input
            v-model="searchQuery"
            class="input pl-9 text-xs py-1.5"
            placeholder="Cari barang atau ruangan…"
          />
        </div>

        <div class="flex items-center gap-1.5 p-0.5 rounded-lg bg-slate-900 border border-slate-800 text-xs self-start sm:self-auto">
          <button
            v-for="st in (['Semua', 'Antre', 'Dikerjakan', 'Selesai'] as const)"
            :key="st"
            @click="filterStatus = st"
            class="px-2.5 py-1 rounded-md transition-colors"
            :class="filterStatus === st ? 'bg-slate-800 text-white font-medium' : 'text-slate-400 hover:text-slate-200'"
          >
            {{ st }}
          </button>
        </div>
      </div>

      <div v-if="filteredTasks.length === 0" class="py-12 text-center text-xs text-slate-400">
        Tidak ada tugas yang sesuai filter.
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="bg-slate-900/60 border-b border-slate-800 text-slate-400 uppercase tracking-wider text-[10px]">
              <th class="text-left px-5 py-3.5 font-semibold">Nama Barang</th>
              <th class="text-left px-4 py-3.5 font-semibold">Ruangan</th>
              <th class="text-left px-4 py-3.5 font-semibold">Dibuat</th>
              <th class="text-left px-4 py-3.5 font-semibold">Status Alur</th>
              <th class="text-right px-5 py-3.5 font-semibold">Ubah Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-800/60">
            <tr v-for="t in paginatedTasks" :key="t.id" class="hover:bg-slate-800/40 transition-colors duration-150">
              <td class="px-5 py-3.5 font-medium text-slate-100 max-w-[200px] truncate">
                {{ t.predictions?.inventories?.nama_barang ?? '-' }}
              </td>
              <td class="px-4 py-3.5 text-slate-300 whitespace-nowrap">
                <span class="px-2 py-0.5 rounded bg-slate-800 border border-slate-700/60 text-[11px]">
                  {{ t.predictions?.inventories?.rooms?.nama ?? '-' }}
                </span>
              </td>
              <td class="px-4 py-3.5 text-slate-400 whitespace-nowrap font-mono text-[11px]">
                {{ new Date(t.created_at).toLocaleDateString('id-ID', { day:'2-digit', month:'short', year:'numeric' }) }}
              </td>
              <td class="px-4 py-3.5 whitespace-nowrap">
                <span :class="{
                  'badge-baik':   t.status === 'Selesai',
                  'badge-sedang': t.status === 'Dikerjakan',
                  'badge-tinggi': t.status === 'Antre',
                }">{{ t.status }}</span>
              </td>
              <td class="px-5 py-3.5 text-right whitespace-nowrap">
                <select
                  :value="t.status"
                  @change="ubahStatus(t.id, ($event.target as HTMLSelectElement).value as MaintenanceTask['status'])"
                  class="bg-[#090E1A] border border-slate-700 rounded-lg px-2.5 py-1 text-xs text-slate-200 cursor-pointer focus:outline-none focus:border-emerald-500"
                >
                  <option v-for="s in STATUS" :key="s">{{ s }}</option>
                </select>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination Footer -->
      <div
        v-if="filteredTasks.length > 0"
        class="flex flex-col sm:flex-row items-center justify-between gap-3 p-4 border-t border-slate-800 text-xs bg-slate-900/40"
      >
        <div class="text-slate-400 text-[11px]">
          Menampilkan <span class="font-mono text-slate-200">{{ ((currentPage - 1) * pageSize) + 1 }}</span>
          - <span class="font-mono text-slate-200">{{ Math.min(currentPage * pageSize, filteredTasks.length) }}</span>
          dari <span class="font-mono text-slate-200">{{ filteredTasks.length }}</span> tugas
        </div>

        <div class="flex items-center gap-3">
          <div class="flex items-center gap-1.5 text-slate-400 text-[11px]">
            <span>Baris:</span>
            <select
              v-model.number="pageSize"
              class="bg-slate-900 border border-slate-700/80 rounded px-2 py-1 text-xs text-slate-200 focus:outline-none"
            >
              <option :value="5">5</option>
              <option :value="10">10</option>
              <option :value="20">20</option>
              <option :value="50">50</option>
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
</template>
