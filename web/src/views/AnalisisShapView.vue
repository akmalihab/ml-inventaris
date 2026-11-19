<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { api, type ItemShapResponse } from '../lib/api'
import { useInventarisStore } from '../stores/inventaris'
import { supabase } from '../lib/supabase'

const route = useRoute()
const router = useRouter()
const store = useInventarisStore()

const loading = ref(false)
const error = ref<string | null>(null)
const shapData = ref<ItemShapResponse | null>(null)

// Selector states
const selectedRoomId = ref<number | null>(null)
const roomItems = ref<any[]>([])
const selectedInventoryId = ref<string>('')

onMounted(async () => {
  await store.fetchRooms()

  if (route.query.id) {
    selectedInventoryId.value = String(route.query.id)
    await loadShapById(selectedInventoryId.value)
  } else if (store.rooms.length > 0) {
    selectedRoomId.value = store.rooms[0].id
    await loadItemsInRoom(selectedRoomId.value)
  }
})

watch(() => route.query.id, async (newId) => {
  if (newId && newId !== selectedInventoryId.value) {
    selectedInventoryId.value = String(newId)
    await loadShapById(selectedInventoryId.value)
  }
})

async function onRoomChange() {
  if (!selectedRoomId.value) return
  await loadItemsInRoom(selectedRoomId.value)
}

async function loadItemsInRoom(roomId: number) {
  const { data } = await supabase
    .from('inventories')
    .select('id, nama_barang, kategori, bahan, tahun_pembelian, harga, jumlah')
    .eq('room_id', roomId)
    .order('nama_barang')
  roomItems.value = data ?? []
  if (roomItems.value.length > 0) {
    selectedInventoryId.value = roomItems.value[0].id
    await loadShapById(selectedInventoryId.value)
  } else {
    shapData.value = null
  }
}

async function onItemChange() {
  if (!selectedInventoryId.value) return
  router.replace({ query: { id: selectedInventoryId.value } })
  await loadShapById(selectedInventoryId.value)
}

async function loadShapById(id: string) {
  loading.value = true
  error.value = null
  try {
    const res = await api.explainById(id)
    shapData.value = res
  } catch (e: any) {
    error.value = e.message || 'Gagal menghitung nilai SHAP item ini.'
  } finally {
    loading.value = false
  }
}

// Skala max SHAP untuk visualisasi bar yang proporsional
const maxAbsShap = computed(() => {
  if (!shapData.value?.features.length) return 1
  return Math.max(...shapData.value.features.map(f => Math.abs(f.shap_value)), 0.1)
})
</script>

<template>
  <div class="max-w-5xl space-y-7">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="text-xl lg:text-2xl font-bold tracking-tight text-white font-heading">
          Analisis Kontribusi SHAP Per Item
        </h1>
        <p class="text-xs text-slate-400 mt-1">
          Dekomposisi nilai SHAP lokal (Local Feature Attribution) untuk setiap barang inventaris.
        </p>
      </div>
      <RouterLink to="/ruangan" class="btn-secondary text-xs">
        &larr; Kembali ke Data Ruangan
      </RouterLink>
    </div>

    <!-- Barang Selector Bar -->
    <div class="card-modern p-5 space-y-3">
      <div class="text-xs font-semibold text-slate-300 uppercase tracking-wider flex items-center gap-2">
        <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
        Pilih Aset untuk Dianalisis:
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <!-- Room Selector -->
        <div>
          <label class="label">Ruang Rawat Inap</label>
          <select v-model="selectedRoomId" @change="onRoomChange" class="input text-xs">
            <option v-for="r in store.rooms" :key="r.id" :value="r.id">
              {{ r.nama }} (ID: {{ r.id }})
            </option>
          </select>
        </div>

        <!-- Item Selector -->
        <div>
          <label class="label">Pilih Barang di Ruangan</label>
          <select
            v-model="selectedInventoryId"
            @change="onItemChange"
            class="input text-xs"
            :disabled="roomItems.length === 0"
          >
            <option v-if="roomItems.length === 0" disabled value="">
              Tidak ada barang di ruangan ini
            </option>
            <option v-for="item in roomItems" :key="item.id" :value="item.id">
              {{ item.nama_barang }} ({{ item.kategori }} - {{ item.bahan }})
            </option>
          </select>
        </div>
      </div>
    </div>

    <!-- Error Alert -->
    <div v-if="error" role="alert" class="p-4 rounded-xl bg-rose-500/10 border border-rose-500/25 text-rose-400 text-xs">
      {{ error }}
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="card-modern p-12 text-center text-xs text-slate-400 space-y-2">
      <div class="w-8 h-8 border-2 border-emerald-500 border-t-transparent rounded-full animate-spin mx-auto"></div>
      <p>Menghitung TreeExplainer SHAP untuk aset ini…</p>
    </div>

    <!-- Main SHAP Dashboard View -->
    <div v-else-if="shapData" class="space-y-6">
      <!-- Item Profile Summary Header -->
      <div class="card-modern p-6">
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div class="space-y-1">
            <div class="flex items-center gap-2">
              <span class="px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-[11px] font-mono">
                Ruang {{ shapData.room_nama ?? '-' }}
              </span>
              <span class="text-xs text-slate-500 font-mono">ID: {{ (shapData.inventory_id ?? '').slice(0, 8) }}…</span>
            </div>
            <h2 class="text-2xl font-bold font-heading text-white">{{ shapData.nama_barang }}</h2>
            <p class="text-xs text-slate-400">
              Model: <span class="font-mono text-slate-300">{{ shapData.model_version }}</span>
            </p>
          </div>

          <!-- Decision Badges -->
          <div class="flex items-center gap-2.5">
            <div
              :class="shapData.label_biner === 1 ? 'badge-perlu' : 'badge-baik'"
              class="px-3.5 py-1.5 text-xs font-semibold"
            >
              {{ shapData.label }}
            </div>
            <div
              :class="{
                'badge-tinggi': shapData.prioritas === 'Tinggi',
                'badge-sedang': shapData.prioritas === 'Sedang',
                'badge-baik':   shapData.prioritas === 'Baik',
              }"
              class="px-3.5 py-1.5 text-xs font-semibold"
            >
              Prioritas {{ shapData.prioritas }}
            </div>
          </div>
        </div>

        <!-- 4 Metric summary boxes -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mt-6 pt-5 border-t border-slate-800/80">
          <div class="p-3 rounded-lg bg-slate-900/60 border border-slate-800">
            <div class="text-[10px] text-slate-400 uppercase tracking-wider font-semibold">Probabilitas Risiko</div>
            <div class="text-2xl font-mono font-extrabold mt-1" :class="shapData.probabilitas >= 0.417 ? 'text-rose-400' : 'text-emerald-400'">
              {{ (shapData.probabilitas * 100).toFixed(1) }}%
            </div>
          </div>
          <div class="p-3 rounded-lg bg-slate-900/60 border border-slate-800">
            <div class="text-[10px] text-slate-400 uppercase tracking-wider font-semibold">Threshold F2</div>
            <div class="text-2xl font-mono font-extrabold text-slate-200 mt-1">
              {{ shapData.threshold }}
            </div>
          </div>
          <div class="p-3 rounded-lg bg-slate-900/60 border border-slate-800">
            <div class="text-[10px] text-slate-400 uppercase tracking-wider font-semibold">Akumulasi SHAP (&Sigma;)</div>
            <div class="text-2xl font-mono font-extrabold mt-1" :class="shapData.total_shap >= 0 ? 'text-rose-400' : 'text-emerald-400'">
              {{ shapData.total_shap >= 0 ? `+${shapData.total_shap.toFixed(4)}` : shapData.total_shap.toFixed(4) }}
            </div>
          </div>
          <div class="p-3 rounded-lg bg-slate-900/60 border border-slate-800">
            <div class="text-[10px] text-slate-400 uppercase tracking-wider font-semibold">Base Value Model</div>
            <div class="text-2xl font-mono font-extrabold text-slate-300 mt-1">
              {{ shapData.base_value.toFixed(4) }}
            </div>
          </div>
        </div>

        <!-- Tingkat Penurunan Nilai / Depresiasi Relatif -->
        <div v-if="shapData.rasio_susut_persen !== undefined" class="mt-4 p-4 rounded-xl bg-slate-900/80 border border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div class="space-y-1">
            <div class="text-[10px] text-slate-400 uppercase tracking-wider font-semibold flex items-center gap-1.5">
              <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
              Tingkat Penurunan Nilai (Depresiasi Relatif Terhadap Harga)
            </div>
            <div class="text-xs text-slate-300">
              Aset telah menyusut <span class="font-mono font-bold text-amber-400">{{ shapData.rasio_susut_persen }}%</span> dari harga perolehan. Sisa nilai buku saat ini: <span class="font-mono font-bold text-emerald-400">Rp{{ Number(shapData.sisa_nilai_buku ?? 0).toLocaleString('id-ID') }}</span>
            </div>
          </div>
          <!-- Progress bar susut -->
          <div class="w-full sm:w-56 space-y-1 shrink-0">
            <div class="w-full bg-slate-800 rounded-full h-2 overflow-hidden">
              <div
                class="h-full rounded-full transition-all duration-500"
                :class="shapData.rasio_susut_persen > 80 ? 'bg-rose-500' : shapData.rasio_susut_persen > 50 ? 'bg-amber-500' : 'bg-emerald-500'"
                :style="{ width: `${shapData.rasio_susut_persen}%` }"
              ></div>
            </div>
            <div class="flex justify-between text-[10px] font-mono text-slate-400">
              <span>0% Baru</span>
              <span class="text-amber-400 font-bold">{{ shapData.rasio_susut_persen }}% susut</span>
              <span>100% Habis</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Local Feature Attribution Waterfall / Bar Chart -->
      <div class="card-modern p-6 space-y-5">
        <div class="flex items-center justify-between border-b border-slate-800 pb-3">
          <div>
            <h3 class="text-sm font-bold font-heading text-white">
              Grafik Kontribusi Fitur SHAP Item Ini
            </h3>
            <p class="text-xs text-slate-400 mt-0.5">
              Arah dan besaran dampak tiap atribut barang terhadap keputusan model.
            </p>
          </div>
          <div class="flex items-center gap-3 text-[11px]">
            <span class="inline-flex items-center gap-1.5 text-rose-400 font-medium">
              <span class="w-2.5 h-2.5 rounded bg-rose-500"></span> Mendorong Rusak (+)
            </span>
            <span class="inline-flex items-center gap-1.5 text-emerald-400 font-medium">
              <span class="w-2.5 h-2.5 rounded bg-emerald-500"></span> Menahan Baik (&minus;)
            </span>
          </div>
        </div>

        <!-- Visual Bars -->
        <div class="space-y-4">
          <div
            v-for="feat in shapData.features"
            :key="feat.key"
            class="p-4 rounded-xl bg-slate-900/60 border border-slate-800/80 hover:border-slate-700 transition-all space-y-2"
          >
            <!-- Feature Header -->
            <div class="flex items-center justify-between text-xs">
              <div class="flex items-center gap-2">
                <span class="font-bold text-slate-200">{{ feat.label }}</span>
                <span class="px-2 py-0.5 rounded bg-slate-800 text-[11px] font-mono text-slate-300">
                  {{ feat.formatted_value }}
                </span>
              </div>
              <div class="flex items-center gap-2">
                <span
                  class="font-mono font-bold text-sm"
                  :class="feat.shap_value > 0 ? 'text-rose-400' : 'text-emerald-400'"
                >
                  {{ feat.shap_value > 0 ? `+${feat.shap_value.toFixed(4)}` : feat.shap_value.toFixed(4) }}
                </span>
                <span
                  class="text-[10px] font-semibold px-2 py-0.5 rounded"
                  :class="feat.direction === 'up' ? 'bg-rose-500/10 text-rose-400 border border-rose-500/20' : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'"
                >
                  {{ feat.direction === 'up' ? '&uarr; Mendorong Pemeliharaan' : '&darr; Menahan ke Baik' }}
                </span>
              </div>
            </div>

            <!-- Proportional Bar -->
            <div class="w-full bg-slate-800/80 rounded-full h-3 overflow-hidden">
              <div
                class="h-full rounded-full transition-all duration-500"
                :class="feat.shap_value > 0 ? 'bg-gradient-to-r from-amber-500 to-rose-500' : 'bg-gradient-to-r from-teal-500 to-emerald-400'"
                :style="{ width: `${Math.max(5, (Math.abs(feat.shap_value) / maxAbsShap) * 100)}%` }"
              ></div>
            </div>

            <!-- Descriptive Explanation -->
            <p class="text-xs text-slate-400 italic">
              &ldquo;{{ feat.penjelasan }}&rdquo;
            </p>
          </div>
        </div>
      </div>

      <!-- Feature Comparison Table -->
      <div class="card-modern overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-800 bg-slate-900/40">
          <h3 class="text-xs font-semibold text-slate-300 uppercase tracking-wider font-heading">
            Tabel Rekapitulasi Nilai SHAP Per Fitur
          </h3>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead>
              <tr class="border-b border-slate-800 bg-slate-900/60 text-slate-400 uppercase tracking-wider text-[10px]">
                <th class="py-3 px-4 text-left font-semibold">Nama Fitur</th>
                <th class="py-3 px-4 text-left font-semibold">Nilai Aset</th>
                <th class="py-3 px-4 text-right font-semibold">Nilai SHAP</th>
                <th class="py-3 px-4 text-left font-semibold">Arah Dampak</th>
                <th class="py-3 px-4 text-left font-semibold">Interpretasi Model</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60">
              <tr
                v-for="feat in shapData.features"
                :key="feat.key"
                class="hover:bg-slate-800/40 transition-colors"
              >
                <td class="py-3 px-4 font-semibold text-slate-200">{{ feat.label }}</td>
                <td class="py-3 px-4 font-mono text-slate-300">{{ feat.formatted_value }}</td>
                <td
                  class="py-3 px-4 text-right font-mono font-bold"
                  :class="feat.shap_value > 0 ? 'text-rose-400' : 'text-emerald-400'"
                >
                  {{ feat.shap_value > 0 ? `+${feat.shap_value.toFixed(4)}` : feat.shap_value.toFixed(4) }}
                </td>
                <td class="py-3 px-4">
                  <span
                    class="inline-flex items-center gap-1 font-medium"
                    :class="feat.direction === 'up' ? 'text-rose-400' : 'text-emerald-400'"
                  >
                    {{ feat.direction === 'up' ? '&plus; Meningkatkan Risiko' : '&minus; Menurunkan Risiko' }}
                  </span>
                </td>
                <td class="py-3 px-4 text-slate-400">{{ feat.impact }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
