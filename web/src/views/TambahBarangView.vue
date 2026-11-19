<script setup lang="ts">
import { ref, reactive } from 'vue'
import { RouterLink } from 'vue-router'
import { api } from '../lib/api'
import type { PredictResponse } from '../lib/api'

const currentYear = new Date().getFullYear()
const currentMonth = new Date().getMonth() + 1
const currentQuarter = Math.ceil(currentMonth / 3)

const BAHAN    = ['Besi', 'Kaca', 'Kain', 'Kayu', 'Plastik']
const KATEGORI = ['Elektronik', 'Furnitur', 'Pelengkap']
const RUANGAN  = ['Adenium','Anturium','Aster','Dahlia','Gardena','Lavender','Mawar','Melati A','Melati B','Sakura','Seruni','Tulip']
const TAHUN_MIN = 1990
const TAHUN_MAX = currentYear

const form = reactive({
  nama_barang: '', nama_ruangan: 'Adenium', bahan: 'Besi', kategori: 'Elektronik',
  tahun_pembelian: currentYear, jumlah: 1, harga: 0, triwulan: `TW ${currentQuarter}`,
})

const errors   = reactive<Record<string, string>>({})
const loading  = ref(false)
const result   = ref<PredictResponse | null>(null)
const apiError = ref<string | null>(null)

function applyBenchmarkPreset() {
  form.nama_barang = 'AC Panasonic 2 PK'
  form.nama_ruangan = 'Adenium'
  form.bahan = 'Besi'
  form.kategori = 'Elektronik'
  form.tahun_pembelian = 2013
  form.jumlah = 1
  form.harga = 10845230
  form.triwulan = 'TW 2'
}

function resetWaktuOtomatis() {
  const now = new Date()
  form.tahun_pembelian = now.getFullYear()
  form.triwulan = `TW ${Math.ceil((now.getMonth() + 1) / 3)}`
}

function validate() {
  Object.keys(errors).forEach(k => delete errors[k])
  if (!form.nama_barang.trim()) errors.nama_barang = 'Wajib diisi'
  if (!form.nama_ruangan)       errors.nama_ruangan = 'Pilih ruangan'
  if (!form.bahan)              errors.bahan = 'Pilih bahan'
  if (!form.kategori)           errors.kategori = 'Pilih kategori'
  if (form.tahun_pembelian < TAHUN_MIN || form.tahun_pembelian > TAHUN_MAX)
    errors.tahun_pembelian = `${TAHUN_MIN}–${TAHUN_MAX}`
  if (form.jumlah < 1)  errors.jumlah = 'Min 1'
  if (form.harga <= 0)  errors.harga  = 'Harus > 0'
  return Object.keys(errors).length === 0
}

async function submit() {
  if (!validate()) return
  loading.value = true; apiError.value = null; result.value = null
  try { result.value = await api.predict({ ...form }) }
  catch (e: any) { apiError.value = e.message }
  finally { loading.value = false }
}
</script>

<template>
  <div class="max-w-3xl space-y-6">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="text-xl lg:text-2xl font-bold tracking-tight text-white font-heading">
          Tambah Aset & Prediksi Kondisi
        </h1>
        <p class="text-xs text-slate-400 mt-1">
          Input data inventaris nonmedis baru. Prediksi XGBoost dan faktor penjelas SHAP dihitung otomatis.
        </p>
      </div>
      <div class="flex items-center gap-2">
        <button
          type="button"
          @click="applyBenchmarkPreset"
          class="px-3 py-1.5 rounded-lg border border-amber-500/40 bg-amber-500/10 text-amber-400 hover:bg-amber-500/20 text-xs font-semibold flex items-center gap-1.5 transition-colors cursor-pointer"
        >
          <svg class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" /></svg>
          Preset AC Benchmark
        </button>
      </div>
    </div>

    <!-- Banner Waktu & Timezone Otomatis -->
    <div class="p-3.5 rounded-xl bg-emerald-500/10 border border-emerald-500/25 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
      <div class="flex items-center gap-2.5">
        <div class="w-8 h-8 rounded-lg bg-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
        </div>
        <div>
          <div class="font-semibold text-emerald-300">
            Periode Berjalan: Tahun {{ currentYear }} &middot; TW {{ currentQuarter }}
          </div>
          <div class="text-[11px] text-slate-400">
            Otomatis disinkronkan berdasarkan zona waktu lokal browser/sistem.
          </div>
        </div>
      </div>
      <button
        type="button"
        @click="resetWaktuOtomatis"
        class="px-2.5 py-1 rounded bg-slate-900 border border-slate-700 text-slate-300 hover:text-white text-[11px] font-medium transition-colors cursor-pointer shrink-0 self-start sm:self-auto"
      >
        Setel Ulang Waktu Ini
      </button>
    </div>

    <!-- Error summary -->
    <div
      v-if="Object.keys(errors).length"
      role="alert"
      tabindex="-1"
      id="error-summary"
      class="p-4 rounded-xl bg-rose-500/10 border border-rose-500/25 text-xs text-rose-400 space-y-1.5"
    >
      <p class="font-semibold flex items-center gap-1.5">
        <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" /></svg>
        Mohon lengkapi atau perbaiki kolom berikut:
      </p>
      <ul class="list-disc list-inside space-y-0.5 text-slate-300">
        <li v-for="(msg, field) in errors" :key="field">
          <a :href="`#field-${field}`" class="hover:underline hover:text-rose-300">{{ msg }}</a>
        </li>
      </ul>
    </div>

    <form @submit.prevent="submit" novalidate class="card-modern p-6 space-y-5">
      <!-- Nama barang -->
      <div>
        <label class="label" for="field-nama_barang">Nama Barang</label>
        <input
          id="field-nama_barang"
          v-model="form.nama_barang"
          class="input"
          :class="{ '!border-rose-500': errors.nama_barang }"
          placeholder="Contoh: AC Panasonic 2 PK"
        />
        <p v-if="errors.nama_barang" class="err-msg" role="alert">{{ errors.nama_barang }}</p>
      </div>

      <!-- Ruangan -->
      <div>
        <label class="label" for="field-nama_ruangan">Ruangan Rawat Inap</label>
        <select
          id="field-nama_ruangan"
          v-model="form.nama_ruangan"
          class="input"
          :class="{ '!border-rose-500': errors.nama_ruangan }"
        >
          <option value="" disabled>Pilih ruangan rawat inap…</option>
          <option v-for="r in RUANGAN" :key="r">{{ r }}</option>
        </select>
        <p v-if="errors.nama_ruangan" class="err-msg" role="alert">{{ errors.nama_ruangan }}</p>
      </div>

      <!-- Bahan + Kategori -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="label" for="field-bahan">Bahan / Material</label>
          <select
            id="field-bahan"
            v-model="form.bahan"
            class="input"
            :class="{ '!border-rose-500': errors.bahan }"
          >
            <option value="" disabled>Pilih material…</option>
            <option v-for="b in BAHAN" :key="b">{{ b }}</option>
          </select>
          <p v-if="errors.bahan" class="err-msg" role="alert">{{ errors.bahan }}</p>
        </div>
        <div>
          <label class="label" for="field-kategori">Kategori Barang</label>
          <select
            id="field-kategori"
            v-model="form.kategori"
            class="input"
            :class="{ '!border-rose-500': errors.kategori }"
          >
            <option value="" disabled>Pilih kategori…</option>
            <option v-for="k in KATEGORI" :key="k">{{ k }}</option>
          </select>
          <p v-if="errors.kategori" class="err-msg" role="alert">{{ errors.kategori }}</p>
        </div>
      </div>

      <!-- Tahun + Triwulan + Jumlah + Harga -->
      <div class="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div>
          <label class="label" for="field-tahun_pembelian">Tahun Pembelian</label>
          <input
            id="field-tahun_pembelian"
            v-model.number="form.tahun_pembelian"
            type="number"
            :min="TAHUN_MIN"
            :max="TAHUN_MAX"
            class="input font-mono"
            :class="{ '!border-rose-500': errors.tahun_pembelian }"
          />
          <p v-if="errors.tahun_pembelian" class="err-msg" role="alert">{{ errors.tahun_pembelian }}</p>
        </div>
        <div>
          <label class="label" for="field-triwulan">Triwulan (Otomatis)</label>
          <select
            id="field-triwulan"
            v-model="form.triwulan"
            class="input font-mono"
          >
            <option value="TW 1">TW 1 (Jan–Mar)</option>
            <option value="TW 2">TW 2 (Apr–Jun)</option>
            <option value="TW 3">TW 3 (Jul–Sep)</option>
            <option value="TW 4">TW 4 (Okt–Des)</option>
          </select>
        </div>
        <div>
          <label class="label" for="field-jumlah">Jumlah Unit</label>
          <input
            id="field-jumlah"
            v-model.number="form.jumlah"
            type="number"
            min="1"
            class="input font-mono"
            :class="{ '!border-rose-500': errors.jumlah }"
          />
          <p v-if="errors.jumlah" class="err-msg" role="alert">{{ errors.jumlah }}</p>
        </div>
        <div>
          <label class="label" for="field-harga">Harga Total (Rp)</label>
          <input
            id="field-harga"
            v-model.number="form.harga"
            type="number"
            min="1"
            class="input font-mono"
            :class="{ '!border-rose-500': errors.harga }"
            placeholder="10845230"
          />
          <p v-if="errors.harga" class="err-msg" role="alert">{{ errors.harga }}</p>
        </div>
      </div>

      <div class="pt-3 flex items-center justify-between border-t border-slate-800">
        <button
          type="submit"
          class="btn-primary px-6 py-2.5 shadow-md shadow-emerald-500/15"
          :disabled="loading"
        >
          <svg v-if="loading" class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          <span v-if="loading">Menginferensi Model…</span>
          <span v-else>Jalankan Prediksi AI & Simpan</span>
        </button>

        <span class="text-xs text-slate-500">Auto-save ke Supabase</span>
      </div>
    </form>

    <!-- API error -->
    <div
      v-if="apiError"
      role="alert"
      class="p-4 rounded-xl bg-rose-500/10 border border-rose-500/25 text-rose-400 text-xs"
    >
      {{ apiError }}
    </div>

    <!-- Hasil Prediksi -->
    <div v-if="result" class="card-modern p-6 space-y-4 border-emerald-500/30 bg-gradient-to-br from-[#0F1626] to-[#0A101D]">
      <div class="flex items-center justify-between border-b border-slate-800 pb-3">
        <div class="flex items-center gap-2">
          <div class="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse"></div>
          <h2 class="text-sm font-bold font-heading text-white">Hasil Klasifikasi AI</h2>
        </div>
        <div class="flex items-center gap-2">
          <span :class="result.label_biner === 1 ? 'badge-perlu' : 'badge-baik'">{{ result.label }}</span>
          <span
            :class="{
              'badge-tinggi': result.prioritas === 'Tinggi',
              'badge-sedang': result.prioritas === 'Sedang',
              'badge-baik':   result.prioritas === 'Baik',
            }"
          >
            {{ result.prioritas }}
          </span>
        </div>
      </div>

      <!-- Probability Bar -->
      <div class="p-4 rounded-lg bg-slate-900/60 border border-slate-800 space-y-2">
        <div class="flex justify-between text-xs">
          <span class="text-slate-400 font-medium">Tingkat Keyakinan Risiko (Probabilitas)</span>
          <span class="font-mono font-bold text-white">{{ (result.probabilitas * 100).toFixed(1) }}%</span>
        </div>
        <div class="w-full h-2.5 bg-slate-800 rounded-full overflow-hidden">
          <div
            class="h-full rounded-full transition-all duration-300"
            :class="result.probabilitas > 0.667 ? 'bg-rose-500' : result.probabilitas > 0.333 ? 'bg-amber-500' : 'bg-emerald-500'"
            :style="{ width: `${result.probabilitas * 100}%` }"
          ></div>
        </div>
        <div class="flex justify-between text-[10px] text-slate-500">
          <span class="text-emerald-400">0% - 33.3% Hijau</span>
          <span class="text-amber-400">33.4% - 66.7% Kuning</span>
          <span class="text-rose-400">66.8% - 100% Merah</span>
        </div>
      </div>

      <!-- Top 3 alasan -->
      <div v-if="result.alasan_top3?.length" class="space-y-2 pt-2 border-t border-slate-800/80">
        <div class="text-xs font-semibold text-slate-300 flex items-center gap-1.5">
          <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" /></svg>
          3 Alasan Keputusan Model (SHAP):
        </div>
        <ol class="space-y-1.5">
          <li
            v-for="(a, i) in result.alasan_top3"
            :key="i"
            class="text-xs text-slate-300 flex items-start gap-2 p-2.5 rounded-lg bg-slate-900/50 border border-slate-800/80"
          >
            <span class="font-mono text-emerald-400 font-bold shrink-0">#{{ (i as number) + 1 }}</span>
            <span>{{ a.penjelasan }}</span>
          </li>
        </ol>
      </div>

      <div v-if="result.inventory_id" class="pt-2 text-right">
        <RouterLink
          :to="`/inventaris/${result.inventory_id}`"
          class="btn-secondary text-xs inline-flex items-center gap-1.5"
        >
          Lihat Detail Barang & Grafik SHAP Global &rarr;
        </RouterLink>
      </div>
    </div>
  </div>
</template>

<style scoped>
.err-msg { @apply text-red-400 text-[11px] mt-0.5; }
</style>
