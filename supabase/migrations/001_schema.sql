-- Skema Supabase ML Inventaris
-- Jalankan di SQL Editor Supabase, urut dari atas ke bawah.

create table rooms (
  id smallint primary key,
  nama text unique not null
);

insert into rooms (id, nama) values
  (1,  'Adenium'),
  (2,  'Anturium'),
  (3,  'Aster'),
  (4,  'Dahlia'),
  (5,  'Gardena'),
  (6,  'Lavender'),
  (7,  'Mawar'),
  (8,  'Melati A'),
  (9,  'Melati B'),
  (10, 'Sakura'),
  (11, 'Seruni'),
  (12, 'Tulip');

create table inventories (
  id               uuid primary key default gen_random_uuid(),
  room_id          smallint references rooms(id),
  nama_barang      text not null,
  bahan            text not null,
  kategori         text not null check (kategori in ('Elektronik','Furnitur','Pelengkap')),
  tahun_pembelian  int  not null,
  jumlah           int  not null check (jumlah > 0),
  harga            numeric not null,
  triwulan         text,
  kondisi_asli     text check (kondisi_asli in ('Baik','Kurang Baik','Rusak Berat')),
  created_at       timestamptz default now()
);

create table predictions (
  id                       uuid primary key default gen_random_uuid(),
  inventory_id             uuid references inventories(id),
  prob_perlu_pemeliharaan  numeric not null,
  label_biner              int     not null check (label_biner in (0,1)),
  threshold                numeric not null,
  prioritas                text check (prioritas in ('Baik','Sedang','Tinggi')),
  shap_top3                jsonb,
  model_version            text not null,
  koreksi_petugas          int check (koreksi_petugas in (0,1)),
  created_at               timestamptz default now()
);

create table maintenance_tasks (
  id            uuid primary key default gen_random_uuid(),
  prediction_id uuid references predictions(id),
  status        text not null default 'Antre'
                  check (status in ('Antre','Dikerjakan','Selesai')),
  created_at    timestamptz default now()
);

-- Enable Realtime untuk web + Android
alter publication supabase_realtime add table inventories;
alter publication supabase_realtime add table predictions;
alter publication supabase_realtime add table maintenance_tasks;
