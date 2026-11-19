<template>
  <div class="min-h-screen bg-[#090D16] flex text-slate-100 font-sans selection:bg-emerald-500/20 selection:text-emerald-300">
    <!-- Sidebar -->
    <aside class="w-64 shrink-0 bg-[#0C1220] border-r border-slate-800/80 flex flex-col justify-between">
      <div>
        <!-- Brand Header -->
        <div class="px-5 py-5 border-b border-slate-800/80 flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-tr from-emerald-600 to-teal-400 flex items-center justify-center shadow-lg shadow-emerald-500/20 text-white shrink-0">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
          </div>
          <div class="min-w-0">
            <div class="font-heading font-bold text-sm text-white tracking-tight flex items-center gap-1.5">
              <span>START</span>
              <span class="text-[9px] font-mono px-1.5 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">AI</span>
            </div>
            <p class="text-[10px] text-slate-400 truncate mt-0.5" title="Sistem Terpadu Alat Rumah Tangga">Sistem Terpadu ART</p>
          </div>
        </div>

        <!-- Navigation Links -->
        <div class="px-3 py-4">
          <div class="text-[10px] font-semibold text-slate-500 uppercase tracking-wider px-3 mb-2">Navigasi Utama</div>
          <nav class="space-y-1">
            <RouterLink to="/" class="nav-item">
              <svg-icon name="grid" />
              <span>Dashboard</span>
            </RouterLink>
            <RouterLink to="/ruangan" class="nav-item">
              <svg-icon name="room" />
              <span>Data Per Ruangan</span>
            </RouterLink>
            <RouterLink to="/analisis-shap" class="nav-item">
              <svg-icon name="sparkles" />
              <span>Analisis SHAP Barang</span>
            </RouterLink>
            <RouterLink to="/inventaris/baru" class="nav-item">
              <svg-icon name="plus" />
              <span>Tambah Barang</span>
            </RouterLink>
            <RouterLink to="/upload" class="nav-item">
              <svg-icon name="upload" />
              <span>Upload CSV Massal</span>
            </RouterLink>
            <RouterLink to="/pemeliharaan" class="nav-item">
              <svg-icon name="wrench" />
              <span>Antrean Pemeliharaan</span>
            </RouterLink>
          </nav>
        </div>
      </div>

      <!-- Footer Info Badge -->
      <div class="p-4 border-t border-slate-800/80 bg-slate-900/30">
        <div class="p-3 rounded-lg bg-[#0F1626] border border-slate-800/90 text-[11px] space-y-1.5">
          <div class="flex items-center justify-between text-slate-400">
            <span>Model Engine</span>
            <span class="font-mono text-emerald-400 font-semibold text-[10px]">XGBoost + SPW</span>
          </div>
          <div class="flex items-center justify-between text-slate-400">
            <span>Decision (F2)</span>
            <span class="font-mono text-slate-200 text-[10px]">&ge; 0.417</span>
          </div>
          <div class="flex items-center justify-between text-slate-400 pt-1 border-t border-slate-800">
            <span>Status</span>
            <span class="inline-flex items-center gap-1 text-[10px] text-emerald-400 font-medium">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span> Active
            </span>
          </div>
        </div>
      </div>
    </aside>

    <!-- Main Content Area -->
    <div class="flex-1 flex flex-col min-w-0">
      <!-- Topbar Header -->
      <header class="h-14 bg-[#0C1220]/80 backdrop-blur-md border-b border-slate-800/80 flex items-center px-6 justify-between shrink-0 sticky top-0 z-20">
        <div class="flex items-center gap-3">
          <div class="slot-title"></div>
        </div>
        <div class="flex items-center gap-3">
          <!-- Dark / Light Mode Toggle Button -->
          <button
            @click="toggleTheme"
            class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border text-xs font-medium transition-all duration-150"
            :class="isDark ? 'bg-slate-900/80 border-slate-800 text-slate-300 hover:text-white hover:border-slate-700' : 'bg-white border-slate-300 text-slate-700 hover:bg-slate-50 hover:border-slate-400 shadow-sm'"
            :title="isDark ? 'Beralih ke Mode Terang (Light Mode)' : 'Beralih ke Mode Gelap (Dark Mode)'"
          >
            <!-- Sun icon when dark (click to light) -->
            <svg v-if="isDark" class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />
            </svg>
            <!-- Moon icon when light (click to dark) -->
            <svg v-else class="w-3.5 h-3.5 text-indigo-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />
            </svg>
            <span class="text-[11px] font-medium">{{ isDark ? 'Terang' : 'Gelap' }}</span>
          </button>

          <!-- Supabase Realtime Indicator -->
          <div class="flex items-center gap-2 px-3 py-1 rounded-full bg-slate-900/80 border border-slate-800">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span class="text-xs font-medium text-slate-300">Supabase Realtime</span>
          </div>
        </div>
      </header>

      <!-- Main Body -->
      <main class="flex-1 overflow-auto p-6 lg:p-8">
        <RouterView />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

const isDark = ref(true)

onMounted(() => {
  const saved = localStorage.getItem('theme')
  if (saved) {
    isDark.value = saved === 'dark'
  } else {
    isDark.value = true
  }
  applyTheme()
})

function toggleTheme() {
  isDark.value = !isDark.value
  localStorage.setItem('theme', isDark.value ? 'dark' : 'light')
  applyTheme()
}

function applyTheme() {
  if (isDark.value) {
    document.documentElement.classList.add('dark')
    document.documentElement.classList.remove('light')
  } else {
    document.documentElement.classList.remove('dark')
    document.documentElement.classList.add('light')
  }
}

const SvgIcon = {
  props: ['name'],
  template: `
    <svg v-if="name==='grid'" class="w-4.5 h-4.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" /></svg>
    <svg v-if="name==='room'" class="w-4.5 h-4.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.75a1.5 1.5 0 011.5-1.5h3a1.5 1.5 0 011.5 1.5V21" /></svg>
    <svg v-if="name==='sparkles'" class="w-4.5 h-4.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z" /></svg>
    <svg v-if="name==='plus'" class="w-4.5 h-4.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
    <svg v-if="name==='upload'" class="w-4.5 h-4.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" /></svg>
    <svg v-if="name==='wrench'" class="w-4.5 h-4.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M11.42 15.17L17.25 21A2.652 2.652 0 0021 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 11-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 004.486-6.336l-3.276 3.277a3.004 3.004 0 01-2.25-2.25l3.276-3.276a4.5 4.5 0 00-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437l1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008z" /></svg>
  `
}
</script>

<style scoped>
.nav-item {
  @apply flex items-center gap-3 px-3 py-2.5 rounded-lg text-xs font-semibold text-slate-400
         hover:bg-slate-800/60 hover:text-slate-100 transition-all duration-150 cursor-pointer;
}
.router-link-active.nav-item {
  @apply text-white bg-gradient-to-r from-emerald-500/20 to-transparent border-l-2 border-emerald-500 font-semibold shadow-sm;
}
</style>
