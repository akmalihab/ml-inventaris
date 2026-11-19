<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useInventarisStore } from '../stores/inventaris'
import { api, type ItemShapResponse } from '../lib/api'
import ShapChart from '../components/ShapChart.vue'

const route  = useRoute()
const router = useRouter()
const store  = useInventarisStore()

const inventory  = ref<any>(null)
const prediction = ref<any>(null)
const localShap  = ref<ItemShapResponse | null>(null)
const loading    = ref(true)
const error      = ref<string | null>(null)
const koreksiMsg = ref<string | null>(null)
const taskMsg    = ref<string | null>(null)

onMounted(async () => {
  const inv_id = route.params.id as string
  const { data: inv, error: e1 } = await supabase
    .from('inventories').select('*, rooms(nama)').eq('id', inv_id).single()
  if (e1) { error.value = e1.message; loading.value = false; return }
  inventory.value = inv

  const { data: pred, error: e2 } = await supabase
    .from('predictions').select('*').eq('inventory_id', inv_id)
    .order('created_at', { ascending: false }).limit(1).single()
  if (e2 && e2.code !== 'PGRST116') error.value = e2.message
  prediction.value = pred

  // Ambil nilai SHAP lokal lengkap untuk item ini
  try {
    localShap.value = await api.explainById(inv_id)
  } catch (err) {
    // optional fallback
  }

  loading.value = false
})

const prob = computed(() =>
  prediction.value ? (prediction.value.prob_perlu_pemeliharaan * 100).toFixed(1) + '%' : '-'
)

const probBar = computed(() =>
  prediction.value ? Math.round(prediction.value.prob_perlu_pemeliharaan * 100) : 0
)

const maxAbsLocalShap = computed(() => {
  if (!localShap.value?.features.length) return 1
  return Math.max(...localShap.value.features.map(f => Math.abs(f.shap_value)), 0.1)
})

async function koreksi(val: 0 | 1) {
  if (!prediction.value) return
  try {
    await store.correctLabel(prediction.value.id, val)
    prediction.value.koreksi_petugas = val
    koreksiMsg.value = `Koreksi tersimpan: ${val === 0 ? 'Baik' : 'Perlu Pemeliharaan'}`
  } catch (e: any) { koreksiMsg.value = 'Gagal: ' + e.message }
}

async function tambahAntrean() {
  if (!prediction.value) return
  try {
    await store.addTask(prediction.value.id)
    taskMsg.value = 'Ditambahkan ke antrean.'
  } catch (e: any) { taskMsg.value = 'Gagal: ' + e.message }
}

async function hapusAset() {
  if (!inventory.value) return
  if (!confirm(`Hapus aset "${inventory.value.nama_barang}" secara permanen?\nData prediksi dan riwayat pemeliharaan akan ikut terhapus.`)) {
    return
  }
  try {
    await store.deleteInventory(inventory.value.id, inventory.value.room_id)
    alert('Aset berhasil dihapus.')
    router.replace(`/ruangan?id=${inventory.value.room_id}`)
  } catch (err: any) {
    alert('Gagal menghapus aset: ' + err.message)
  }
}
</script>

<template>
  <div class="max-w-5xl space-y-6">
    <div class="flex items-center justify-between gap-4">
      <button
        class="inline-flex items-center gap-2 text-xs font-semibold text-slate-400 hover:text-white transition-colors cursor-pointer py-1"
        @click="router.back()"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
        </svg>
        Kembali ke Halaman Sebelumnya
      </button>

      <button
        v-if="inventory"
        @click="hapusAset"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-rose-500/30 bg-rose-500/10 text-rose-400 hover:bg-rose-500 hover:text-white text-xs font-semibold transition-colors cursor-pointer"
      >
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
        </svg>
        Hapus Aset Ini
      </button>
    </div>

    <div v-if="loading" class="card-modern p-12 text-center text-slate-400 text-xs">
      Memuat informasi aset…
    </div>
    <div v-else-if="error" role="alert" class="p-4 rounded-xl bg-rose-500/10 border border-rose-500/25 text-rose-400 text-xs">
      {{ error }}
    </div>

    <template v-else-if="inventory">
      <!-- Header barang -->
      <div class="card-modern p-6">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <span class="px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-[11px] font-mono">
                Ruang {{ inventory.rooms?.nama }}
              </span>
              <span class="text-xs text-slate-500 font-mono">ID: {{ inventory.id.slice(0, 8) }}…</span>
            </div>
            <h1 class="text-2xl font-bold font-heading text-white">{{ inventory.nama_barang }}</h1>
            <p class="text-xs text-slate-400 mt-1">
              {{ inventory.kategori }} &middot; Material {{ inventory.bahan }} &middot; Tahun Pembelian {{ inventory.tahun_pembelian }}
            </p>
          </div>

          <div v-if="prediction" class="flex items-center gap-2">
            <span :class="((prediction.koreksi_petugas ?? prediction.label_biner) === 1) ? 'badge-perlu' : 'badge-baik'" class="px-3 py-1 text-xs">
              <template v-if="prediction.koreksi_petugas === 0">
                Kondisi Baik (Selesai Perbaikan)
              </template>
              <template v-else-if="prediction.koreksi_petugas === 1">
                Perlu Pemeliharaan (Koreksi)
              </template>
              <template v-else>
                {{ prediction.label_biner === 1 ? 'Perlu Pemeliharaan' : 'Kondisi Baik' }}
              </template>
            </span>
            <span
              v-if="prediction.koreksi_petugas === 0"
              class="badge-baik px-3 py-1 text-xs"
            >
              Prioritas Teratasi
            </span>
            <span
              v-else
              :class="{
                'badge-tinggi': prediction.prioritas === 'Tinggi',
                'badge-sedang': prediction.prioritas === 'Sedang',
                'badge-baik':   prediction.prioritas === 'Baik',
              }"
              class="px-3 py-1 text-xs"
            >
              Prioritas {{ prediction.prioritas }}
            </span>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Info Barang -->
        <div class="card-modern p-6 space-y-4">
          <div class="flex items-center justify-between border-b border-slate-800 pb-3">
            <h2 class="text-xs font-semibold text-slate-300 uppercase tracking-wider font-heading">
              Spesifikasi & Nilai Aset
            </h2>
            <span class="text-[10px] text-slate-500 font-mono">Data Fisik</span>
          </div>
          <dl class="divide-y divide-slate-800/60 text-xs">
            <div class="dl-row"><dt>Tahun Pembelian</dt><dd class="font-mono">{{ inventory.tahun_pembelian }}</dd></div>
            <div class="dl-row"><dt>Kuantitas Unit</dt><dd class="font-mono">{{ inventory.jumlah }} unit</dd></div>
            <div class="dl-row"><dt>Harga Total</dt><dd class="font-mono font-bold text-slate-200">Rp{{ Number(inventory.harga).toLocaleString('id-ID') }}</dd></div>
            <div class="dl-row"><dt>Harga per Unit</dt><dd class="font-mono text-slate-300">Rp{{ Math.round(Number(inventory.harga) / inventory.jumlah).toLocaleString('id-ID') }}</dd></div>
            <div class="dl-row" v-if="localShap?.rasio_susut_persen !== undefined">
              <dt>Persentase Susut</dt>
              <dd class="font-mono font-bold" :class="localShap.rasio_susut_persen > 80 ? 'text-rose-400' : 'text-amber-400'">
                {{ localShap.rasio_susut_persen }}% dari harga awal
              </dd>
            </div>
            <div class="dl-row" v-if="localShap?.sisa_nilai_buku !== undefined">
              <dt>Sisa Nilai Buku</dt>
              <dd class="font-mono font-bold text-emerald-400">
                Rp{{ Number(localShap.sisa_nilai_buku).toLocaleString('id-ID') }}
              </dd>
            </div>
            <div class="dl-row" v-if="inventory.kondisi_asli"><dt>Label Dokumen Awal</dt><dd class="font-medium text-slate-300">{{ inventory.kondisi_asli }}</dd></div>
          </dl>
        </div>

        <!-- Prediksi & Alasan SHAP -->
        <div class="card-modern p-6 space-y-4" v-if="prediction">
          <div class="flex items-center justify-between border-b border-slate-800 pb-3">
            <h2 class="text-xs font-semibold text-slate-300 uppercase tracking-wider font-heading">
              Hasil Inferensi Model AI
            </h2>
            <span class="text-[10px] text-emerald-400 font-mono">XGBoost Decision</span>
          </div>

          <!-- Prob bar -->
          <div class="space-y-1.5 p-3 rounded-lg bg-slate-900/60 border border-slate-800">
            <div class="flex justify-between text-xs">
              <span class="text-slate-400">Probabilitas Kerusakan</span>
              <span class="font-mono font-extrabold text-white">{{ prob }}</span>
            </div>
            <div class="w-full h-2.5 bg-slate-800 rounded-full overflow-hidden">
              <div
                class="h-full rounded-full transition-all duration-500"
                :class="probBar > 80 ? 'bg-gradient-to-r from-amber-500 to-rose-500' : probBar > 41.7 ? 'bg-amber-500' : 'bg-emerald-500'"
                :style="{ width: `${probBar}%` }"
              />
            </div>
          </div>

          <dl class="divide-y divide-slate-800/60 text-xs">
            <div class="dl-row"><dt>Threshold Keputusan F2</dt><dd class="font-mono font-bold text-emerald-400">{{ prediction.threshold }}</dd></div>
            <div class="dl-row"><dt>Versi Model</dt><dd class="font-mono text-slate-400 text-[11px]">{{ prediction.model_version }}</dd></div>
            <div class="dl-row" v-if="prediction.koreksi_petugas !== null">
              <dt>Koreksi Petugas</dt>
              <dd>
                <span class="px-2 py-0.5 rounded text-[10px] font-semibold" :class="prediction.koreksi_petugas === 0 ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'">
                  {{ prediction.koreksi_petugas === 0 ? 'Dikonfirmasi Baik' : 'Dikonfirmasi Perlu Pemeliharaan' }}
                </span>
              </dd>
            </div>
          </dl>

          <!-- SHAP top-3 -->
          <div v-if="prediction.shap_top3?.length" class="pt-2 border-t border-slate-800">
            <h3 class="text-xs font-semibold text-slate-300 flex items-center gap-1.5 mb-2.5">
              <svg class="w-3.5 h-3.5 text-emerald-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" /></svg>
              Faktor Utama Keputusan (SHAP):
            </h3>
            <ol class="space-y-1.5">
              <li
                v-for="(a, i) in prediction.shap_top3"
                :key="i"
                class="flex items-start gap-2 text-xs text-slate-300 p-2.5 rounded-lg bg-slate-900/50 border border-slate-800"
              >
                <span class="font-mono text-emerald-400 font-bold shrink-0">#{{ (i as number) + 1 }}</span>
                <span class="leading-relaxed">{{ a.penjelasan }}</span>
              </li>
            </ol>
          </div>
        </div>
      </div>

      <!-- Aksi Tindak Lanjut -->
      <div v-if="prediction" class="card-modern p-6 space-y-4">
        <h2 class="text-xs font-semibold text-slate-300 uppercase tracking-wider font-heading">
          Tindak Lanjut & Intervensi Petugas
        </h2>
        <div class="flex flex-wrap gap-4 items-center justify-between">
          <div class="space-y-1.5">
            <p class="text-xs text-slate-400">Verifikasi / Koreksi manual klasifikasi:</p>
            <div class="flex gap-2">
              <button class="btn-secondary text-xs" @click="koreksi(0)">
                <span class="text-emerald-400">&check;</span> Validasi: Baik
              </button>
              <button class="btn-secondary text-xs" @click="koreksi(1)">
                <span class="text-rose-400">&cross;</span> Validasi: Perlu Pemeliharaan
              </button>
            </div>
          </div>
          <div>
            <button class="btn-primary text-xs px-4 py-2" @click="tambahAntrean">
              + Masukkan Antrean Pemeliharaan
            </button>
          </div>
        </div>
        <p v-if="koreksiMsg" role="status" class="text-xs text-emerald-400">{{ koreksiMsg }}</p>
        <p v-if="taskMsg" role="status" class="text-xs text-emerald-400">{{ taskMsg }}</p>
      </div>

      <!-- Local SHAP per item -->
      <div v-if="localShap" class="card-modern p-6 space-y-5">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
          <div>
            <h2 class="text-xs font-semibold text-slate-300 uppercase tracking-wider font-heading flex items-center gap-2">
              <span class="w-2 h-2 rounded-full bg-teal-400"></span>
              Nilai Kontribusi SHAP Spesifik Item Ini (Local Attribution)
            </h2>
            <p class="text-[11px] text-slate-400 mt-0.5">Pengaruh masing-masing atribut barang terhadap probabilitas kerusakan aset ini.</p>
          </div>
          <RouterLink
            :to="`/analisis-shap?id=${inventory.id}`"
            class="text-xs text-teal-400 hover:text-teal-300 inline-flex items-center gap-1 font-medium"
          >
            Halaman Analisis Lengkap &rarr;
          </RouterLink>
        </div>

        <div class="space-y-3">
          <div
            v-for="feat in localShap.features"
            :key="feat.key"
            class="p-3.5 rounded-xl bg-slate-900/60 border border-slate-800/80 space-y-1.5"
          >
            <div class="flex items-center justify-between text-xs">
              <div class="flex items-center gap-2">
                <span class="font-bold text-slate-200">{{ feat.label }}</span>
                <span class="px-2 py-0.5 rounded bg-slate-800 text-[10px] font-mono text-slate-300">
                  {{ feat.formatted_value }}
                </span>
              </div>
              <div class="flex items-center gap-2">
                <span
                  class="font-mono font-bold text-xs"
                  :class="feat.shap_value > 0 ? 'text-rose-400' : 'text-emerald-400'"
                >
                  {{ feat.shap_value > 0 ? `+${feat.shap_value.toFixed(4)}` : feat.shap_value.toFixed(4) }}
                </span>
                <span
                  class="text-[9px] font-semibold px-1.5 py-0.5 rounded"
                  :class="feat.direction === 'up' ? 'bg-rose-500/10 text-rose-400 border border-rose-500/20' : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'"
                >
                  {{ feat.direction === 'up' ? '&uarr; Mendorong Rusak' : '&darr; Menahan Baik' }}
                </span>
              </div>
            </div>

            <!-- Proportional Bar -->
            <div class="w-full bg-slate-800/80 rounded-full h-2.5 overflow-hidden">
              <div
                class="h-full rounded-full transition-all duration-500"
                :class="feat.shap_value > 0 ? 'bg-gradient-to-r from-amber-500 to-rose-500' : 'bg-gradient-to-r from-teal-500 to-emerald-400'"
                :style="{ width: `${Math.max(5, (Math.abs(feat.shap_value) / maxAbsLocalShap) * 100)}%` }"
              ></div>
            </div>
            <p class="text-[11px] text-slate-400 italic">
              {{ feat.penjelasan }}
            </p>
          </div>
        </div>
      </div>

      <!-- SHAP Global Chart -->
      <div class="card-modern p-6 space-y-4">
        <div class="flex items-center justify-between border-b border-slate-800 pb-3">
          <div>
            <h2 class="text-xs font-semibold text-slate-300 uppercase tracking-wider font-heading">
              Kepentingan Fitur Global (Mean |SHAP|)
            </h2>
            <p class="text-[11px] text-slate-500">Bobot pengaruh tiap fitur secara keseluruhan terhadap model XGBoost</p>
          </div>
          <span class="font-mono text-[10px] text-slate-400 px-2 py-0.5 rounded bg-slate-800">5 Fitur</span>
        </div>
        <ShapChart />
      </div>
    </template>
  </div>
</template>

<style scoped>
.dl-row { @apply flex justify-between py-2 text-xs items-center; }
.dl-row dt { @apply text-slate-400; }
.dl-row dd { @apply text-slate-100 font-medium; }
</style>
