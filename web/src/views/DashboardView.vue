<script setup lang="ts">
import { onMounted, onUnmounted, computed, ref } from 'vue'
import { useInventarisStore } from '../stores/inventaris'
import { RouterLink } from 'vue-router'

const store = useInventarisStore()

const pageKritis = ref(1)
const sizeKritis = 5

onMounted(async () => {
  await Promise.all([
    store.fetchRooms(),
    store.fetchRoomSummaries(),
    store.fetchPredictions(),
    store.fetchTasks(),
  ])
  store.subscribeRealtime()
})
onUnmounted(() => store.unsubscribe())

const roomStats = computed(() => {
  if (store.roomSummaries.length > 0) {
    return store.roomSummaries
  }
  return store.rooms.map(room => ({
    ...room,
    total: 0,
    perlu: 0,
    tinggi: 0,
  }))
})

const totalBarang = computed(() =>
  roomStats.value.reduce((acc, r) => acc + r.total, 0)
)
const totalPerlu = computed(() =>
  roomStats.value.reduce((acc, r) => acc + r.perlu, 0)
)
const totalTinggi = computed(() =>
  roomStats.value.reduce((acc, r) => acc + r.tinggi, 0)
)
const totalBaik = computed(() =>
  Math.max(0, totalBarang.value - totalPerlu.value)
)

const allPrioritasTinggi = computed(() =>
  store.predictions.filter(p => p.prioritas === 'Tinggi' && p.koreksi_petugas !== 0)
)

const totalPagesKritis = computed(() =>
  Math.max(1, Math.ceil(allPrioritasTinggi.value.length / sizeKritis))
)

const paginatedPrioritasTinggi = computed(() => {
  const start = (pageKritis.value - 1) * sizeKritis
  return allPrioritasTinggi.value.slice(start, start + sizeKritis)
})
</script>

<template>
  <div class="space-y-7">
    <!-- Top Greeting & Live Stats Indicator -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2">
      <div>
        <h1 class="text-xl lg:text-2xl font-bold tracking-tight text-white font-heading">
          Dashboard Monitoring Kondisi Aset
        </h1>
        <p class="text-xs text-slate-400 mt-1">
          Inventaris non-medis 12 Ruang Rawat Inap Kelas 3 — Klasifikasi XGBoost (Threshold F2: 0.417)
        </p>
      </div>
      <div class="flex items-center gap-2 self-start sm:self-auto">
        <RouterLink to="/inventaris/baru" class="btn-primary text-xs shadow-md shadow-emerald-500/10">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
          Tambah Aset
        </RouterLink>
        <RouterLink to="/upload" class="btn-secondary text-xs">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" /></svg>
          Upload CSV
        </RouterLink>
      </div>
    </div>

    <div v-if="store.error" role="alert" class="p-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs">
      {{ store.error }}
    </div>

    <!-- KPI Metric Cards Row -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Total Barang -->
      <div class="card-kpi group">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Aset Terdaftar</span>
          <div class="w-9 h-9 rounded-lg bg-slate-800/80 border border-slate-700/60 flex items-center justify-center text-slate-300 group-hover:text-emerald-400 transition-colors">
            <svg class="w-4.5 h-4.5" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" /></svg>
          </div>
        </div>
        <div class="mt-3 flex items-baseline gap-2">
          <span class="text-3xl font-extrabold font-mono text-white tracking-tight">{{ totalBarang.toLocaleString('id-ID') }}</span>
          <span class="text-[11px] text-slate-400 font-medium">unit</span>
        </div>
        <div class="mt-2 text-[11px] text-slate-500 flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 rounded-full bg-slate-400"></span> 12 ruangan rawat inap
        </div>
      </div>

      <!-- Kondisi Baik -->
      <div class="card-kpi group hover:border-emerald-500/30">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold text-emerald-400/90 uppercase tracking-wider">Kondisi Baik</span>
          <div class="w-9 h-9 rounded-lg bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
            <svg class="w-4.5 h-4.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </div>
        </div>
        <div class="mt-3 flex items-baseline gap-2">
          <span class="text-3xl font-extrabold font-mono text-emerald-400 tracking-tight">{{ totalBaik.toLocaleString('id-ID') }}</span>
          <span class="text-[11px] text-slate-400 font-medium">
            ({{ totalBarang > 0 ? ((totalBaik / totalBarang) * 100).toFixed(1) : 0 }}%)
          </span>
        </div>
        <div class="mt-2 text-[11px] text-emerald-500/80 flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span> Probabilitas &lt; 0.417
        </div>
      </div>

      <!-- Perlu Pemeliharaan -->
      <div class="card-kpi group hover:border-amber-500/30">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold text-amber-400/90 uppercase tracking-wider">Perlu Pemeliharaan</span>
          <div class="w-9 h-9 rounded-lg bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
            <svg class="w-4.5 h-4.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" /></svg>
          </div>
        </div>
        <div class="mt-3 flex items-baseline gap-2">
          <span class="text-3xl font-extrabold font-mono text-amber-400 tracking-tight">{{ totalPerlu.toLocaleString('id-ID') }}</span>
          <span class="text-[11px] text-slate-400 font-medium">
            ({{ totalBarang > 0 ? ((totalPerlu / totalBarang) * 100).toFixed(1) : 0 }}%)
          </span>
        </div>
        <div class="mt-2 text-[11px] text-amber-400/80 flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span> Probabilitas &ge; 0.417
        </div>
      </div>

      <!-- Prioritas Tinggi -->
      <div class="card-kpi group hover:border-rose-500/30">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold text-rose-400/90 uppercase tracking-wider">Prioritas Kritis</span>
          <div class="w-9 h-9 rounded-lg bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400">
            <svg class="w-4.5 h-4.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" /></svg>
          </div>
        </div>
        <div class="mt-3 flex items-baseline gap-2">
          <span class="text-3xl font-extrabold font-mono text-rose-400 tracking-tight">{{ totalTinggi.toLocaleString('id-ID') }}</span>
          <span class="text-[11px] text-slate-400 font-medium">unit</span>
        </div>
        <div class="mt-2 text-[11px] text-rose-400/80 flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 rounded-full bg-rose-400"></span> Probabilitas &gt; 80% (Urgent)
        </div>
      </div>
    </div>

    <!-- Main Grid: Room Cards + Priority Table -->
    <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
      <!-- Left: 12 Ruangan Grid (7 cols on lg) -->
      <section class="lg:col-span-7 space-y-3">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-sm font-bold font-heading text-white">Status 12 Ruangan Rawat Inap</h2>
            <p class="text-xs text-slate-400">Distribusi aset dan kondisi beban pemeliharaan tiap unit</p>
          </div>
          <span class="text-[11px] font-mono text-slate-400 px-2.5 py-1 rounded bg-slate-800/80 border border-slate-700/60">
            12 Unit
          </span>
        </div>

        <div v-if="store.loading && roomStats.length === 0" class="text-slate-400 text-xs py-8 text-center card-modern">
          Memuat data ruangan…
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <RouterLink
            v-for="r in roomStats"
            :key="r.id"
            :to="'/ruangan?id=' + r.id"
            class="card-interactive p-4 relative group block cursor-pointer"
            title="Klik untuk membuka data ruangan ini"
          >
            <!-- Card Header -->
            <div class="flex items-center justify-between mb-3">
              <div class="flex items-center gap-2 min-w-0">
                <div class="w-7 h-7 rounded-lg bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400 text-xs font-mono font-bold shrink-0">
                  {{ r.id }}
                </div>
                <h3 class="font-heading text-sm font-semibold text-slate-100 truncate group-hover:text-emerald-400 transition-colors">
                  {{ r.nama }}
                </h3>
              </div>
              <span
                v-if="r.tinggi > 0"
                class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-rose-500/15 text-rose-300 border border-rose-500/30"
              >
                {{ r.tinggi }} Kritis
              </span>
              <span
                v-else
                class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/15 text-emerald-300 border border-emerald-500/30"
              >
                Terkendali
              </span>
            </div>

            <!-- Stats Metrics -->
            <div class="grid grid-cols-3 gap-2 py-2 border-y border-slate-800/70 text-center">
              <div>
                <div class="text-xs font-mono font-bold text-slate-200">{{ r.total }}</div>
                <div class="text-[10px] text-slate-400 font-medium mt-0.5">Total</div>
              </div>
              <div>
                <div class="text-xs font-mono font-bold text-amber-400">{{ r.perlu }}</div>
                <div class="text-[10px] text-slate-400 font-medium mt-0.5">Perlu</div>
              </div>
              <div>
                <div class="text-xs font-mono font-bold text-rose-400">{{ r.tinggi }}</div>
                <div class="text-[10px] text-slate-400 font-medium mt-0.5">Tinggi</div>
              </div>
            </div>

            <!-- Progress Bar Rasio Pemeliharaan -->
            <div class="mt-3">
              <div class="flex justify-between text-[10px] text-slate-400 mb-1">
                <span>Beban Pemeliharaan</span>
                <span class="font-mono text-slate-300">{{ r.total > 0 ? Math.round((r.perlu / r.total) * 100) : 0 }}%</span>
              </div>
              <div class="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden">
                <div
                  class="h-full rounded-full transition-all duration-300"
                  :class="[
                    (r.total > 0 && (r.perlu / r.total) > 0.5) ? 'bg-gradient-to-r from-amber-500 to-rose-500' : 'bg-emerald-500'
                  ]"
                  :style="{ width: `${r.total > 0 ? Math.min(100, (r.perlu / r.total) * 100) : 0}%` }"
                ></div>
              </div>
            </div>
          </RouterLink>
        </div>
      </section>

      <!-- Right: Prioritas Tinggi Table (5 cols on lg) -->
      <section class="lg:col-span-5 space-y-3">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-sm font-bold font-heading text-white">Antrean Prioritas Kritis</h2>
            <p class="text-xs text-slate-400">Aset dengan risiko kegagalan tertinggi (&gt; 80%)</p>
          </div>
          <RouterLink to="/pemeliharaan" class="text-xs text-emerald-400 hover:text-emerald-300 font-medium inline-flex items-center gap-1 transition-colors">
            Lihat Semua &rarr;
          </RouterLink>
        </div>

        <div v-if="allPrioritasTinggi.length === 0" class="card-modern p-8 text-center space-y-3">
          <div class="w-12 h-12 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center mx-auto">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </div>
          <p class="text-sm text-slate-300 font-medium">Semua aset dalam status aman</p>
          <p class="text-xs text-slate-500 max-w-xs mx-auto">Tidak ada barang dengan prediksi prioritas Tinggi saat ini.</p>
        </div>

        <div v-else class="card-modern overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full text-xs">
              <thead>
                <tr class="border-b border-slate-800 bg-slate-900/60 text-slate-400 uppercase tracking-wider text-[10px]">
                  <th class="text-left px-4 py-3 font-semibold">Nama Barang</th>
                  <th class="text-left px-3 py-3 font-semibold">Ruangan</th>
                  <th class="text-right px-3 py-3 font-semibold">Prob</th>
                  <th class="text-center px-4 py-3 font-semibold">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-800/60">
                <tr
                  v-for="p in paginatedPrioritasTinggi"
                  :key="p.id"
                  class="hover:bg-slate-800/40 transition-colors duration-150 group"
                >
                  <td class="px-4 py-3 font-medium text-slate-100 max-w-[150px] truncate">
                    {{ p.inventories?.nama_barang ?? '-' }}
                    <span class="block text-[10px] text-slate-500 truncate font-normal">
                      {{ p.inventories?.kategori ?? '-' }}
                    </span>
                  </td>
                  <td class="px-3 py-3 text-slate-300 whitespace-nowrap">
                    <span class="px-2 py-0.5 rounded bg-slate-800 border border-slate-700/60 text-[11px]">
                      {{ p.inventories?.rooms?.nama ?? '-' }}
                    </span>
                  </td>
                  <td class="px-3 py-3 text-right whitespace-nowrap">
                    <span class="font-mono font-bold text-rose-400">
                      {{ (p.prob_perlu_pemeliharaan * 100).toFixed(0) }}%
                    </span>
                  </td>
                  <td class="px-4 py-3 text-center whitespace-nowrap">
                    <RouterLink
                      :to="`/inventaris/${p.inventory_id}`"
                      class="inline-flex items-center justify-center w-7 h-7 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 hover:bg-emerald-500 hover:text-white transition-all shadow-sm"
                      title="Lihat Detail & Analisis SHAP"
                    >
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" /></svg>
                    </RouterLink>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Pagination Footer Mini -->
          <div
            v-if="allPrioritasTinggi.length > sizeKritis"
            class="flex items-center justify-between p-3 border-t border-slate-800 text-[11px] bg-slate-900/50"
          >
            <span class="text-slate-400 font-mono">
              {{ ((pageKritis - 1) * sizeKritis) + 1 }}-{{ Math.min(pageKritis * sizeKritis, allPrioritasTinggi.length) }} dari {{ allPrioritasTinggi.length }}
            </span>
            <div class="flex items-center gap-1">
              <button
                @click="pageKritis = Math.max(1, pageKritis - 1)"
                :disabled="pageKritis <= 1"
                class="px-2 py-0.5 rounded bg-slate-800 border border-slate-700 text-slate-300 hover:text-white disabled:opacity-40 disabled:cursor-not-allowed"
              >
                &larr;
              </button>
              <span class="px-1.5 font-mono text-slate-300">{{ pageKritis }}/{{ totalPagesKritis }}</span>
              <button
                @click="pageKritis = Math.min(totalPagesKritis, pageKritis + 1)"
                :disabled="pageKritis >= totalPagesKritis"
                class="px-2 py-0.5 rounded bg-slate-800 border border-slate-700 text-slate-300 hover:text-white disabled:opacity-40 disabled:cursor-not-allowed"
              >
                &rarr;
              </button>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.card-kpi {
  @apply bg-[#111827] border border-[#334155] rounded p-3 flex flex-col gap-1;
}
.kpi-label { @apply text-[11px] text-[#CBD5E1] font-medium uppercase tracking-wide; }
.kpi-value { @apply text-2xl font-heading font-bold leading-none; }
.section-title { @apply text-xs font-heading font-semibold text-[#CBD5E1] uppercase tracking-widest; }
</style>
