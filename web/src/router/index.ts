import { createRouter, createWebHistory } from 'vue-router'

export default createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/',                    component: () => import('../views/DashboardView.vue') },
    { path: '/ruangan',             component: () => import('../views/RuanganView.vue') },
    { path: '/analisis-shap',       component: () => import('../views/AnalisisShapView.vue') },
    { path: '/inventaris/baru',     component: () => import('../views/TambahBarangView.vue') },
    { path: '/inventaris/:id',      component: () => import('../views/DetailBarangView.vue') },
    { path: '/upload',              component: () => import('../views/UploadCSVView.vue') },
    { path: '/pemeliharaan',        component: () => import('../views/PemeliharaanView.vue') },
  ],
})
