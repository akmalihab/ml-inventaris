<script setup lang="ts">
// Nilai dari outputs/tables/shap_global.csv — dikunci, tidak berubah tanpa rerun notebook
const SHAP = [
  { fitur: 'harga_per_unit',  label: 'Harga per Unit',   nilai: 1.1071 },
  { fitur: 'umur',            label: 'Umur',              nilai: 0.7022 },
  { fitur: 'depresiasi_aset', label: 'Depresiasi Aset',  nilai: 0.6543 },
  { fitur: 'bahan',           label: 'Bahan',             nilai: 0.2821 },
  { fitur: 'kategori',        label: 'Kategori',          nilai: 0.2600 },
]
const MAX = SHAP[0].nilai
</script>

<template>
  <div role="img" aria-label="Grafik kepentingan fitur global berdasarkan mean nilai absolut SHAP" class="space-y-4">
    <div class="space-y-2.5">
      <div
        v-for="(f, i) in SHAP"
        :key="f.fitur"
        class="p-3 rounded-lg bg-slate-900/60 border border-slate-800/80 flex items-center gap-4 hover:border-slate-700 transition-colors"
      >
        <!-- Rank & Label -->
        <div class="w-44 flex items-center gap-2.5 shrink-0">
          <span class="w-5 h-5 rounded-md bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 font-mono text-[10px] font-bold flex items-center justify-center shrink-0">
            {{ i + 1 }}
          </span>
          <span class="text-xs font-semibold text-slate-200 truncate">{{ f.label }}</span>
        </div>

        <!-- Progress Bar -->
        <div class="flex-1 bg-slate-800/80 rounded-full h-3 overflow-hidden" role="presentation">
          <div
            class="h-full rounded-full bg-gradient-to-r from-teal-500 to-emerald-400 shadow-sm shadow-emerald-500/20 transition-all duration-500"
            :style="{ width: `${(f.nilai / MAX * 100).toFixed(1)}%` }"
          />
        </div>

        <!-- Numeric Value -->
        <div class="w-16 text-right font-mono text-xs font-bold text-emerald-400 shrink-0" :title="`mean |SHAP| = ${f.nilai}`">
          {{ f.nilai.toFixed(4) }}
        </div>
      </div>
    </div>

    <div class="flex items-center justify-between text-[11px] text-slate-500 pt-1">
      <span>Sumber: Evaluasi CV 5-fold OOF (XGBoost + SPW)</span>
      <span class="font-mono">Metrik: mean |SHAP|</span>
    </div>
  </div>
</template>
