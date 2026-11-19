<script setup lang="ts">
import { ref, reactive } from 'vue'
import { RouterLink } from 'vue-router'
import { api } from '../lib/api'
import type { PredictResponse } from '../lib/api'

const BAHAN    = ['Besi', 'Kaca', 'Kain', 'Kayu', 'Plastik']
const KATEGORI = ['Elektronik', 'Furnitur', 'Pelengkap']
const RUANGAN  = ['Adenium','Anturium','Aster','Dahlia','Gardena','Lavender','Mawar','Melati A','Melati B','Sakura','Seruni','Tulip']
const TAHUN_MIN = 2011
const TAHUN_MAX = 2025

const form = reactive({
  nama_barang: '', nama_ruangan: '', bahan: '', kategori: '',
  tahun_pembelian: 2020, jumlah: 1, harga: 0,
})

const errors   = reactive<Record<string, string>>({})
const loading  = ref(false)
const result   = ref<PredictResponse | null>(null)
const apiError = ref<string | null>(null)

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
    <div>
      <h1 class="text-xl lg:text-2xl font-bold tracking-tight text-white font-heading">
        Tambah Aset & Prediksi Kondisi
      </h1>
      <p class="text-xs text-slate-400 mt-1">
        Input data inventaris nonmedis baru. Prediksi XGBoost dan faktor penjelas SHAP dihitung otomatis.
      </p>
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

      <!-- Tahun + Jumlah + Harga -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
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
            :class="result.probabilitas > 0.8 ? 'bg-gradient-to-r from-amber-500 to-rose-500' : result.probabilitas >= 0.417 ? 'bg-amber-500' : 'bg-emerald-500'"
            :style="{ width: `${result.probabilitas * 100}%` }"
          ></div>
        </div>
        <div class="flex justify-between text-[10px] text-slate-500">
          <span>0% (Aman)</span>
          <span class="font-mono text-emerald-400">Threshold: 41.7% (F2)</span>
          <span>100% (Kritis)</span>
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
