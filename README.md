# Dompetku

Aplikasi Flutter untuk manajemen keuangan pribadi dengan fokus pada pencatatan transaksi harian, pemantauan saldo 2 akun, dan sinkronisasi data ke Google Sheets.

## ✨ Fitur Terbaru

- **Catat transaksi Income / Expense**
  - Input deskripsi, nominal, tipe transaksi, akun, dan kategori.
  - Kategori otomatis menyesuaikan tipe transaksi (income vs expense).

- **2 akun dana terpisah**
  - `Dompet`
  - `ATM/E-Wallet`

- **Transfer antar akun internal**
  - Transfer dicatat sebagai pasangan transaksi (expense dari akun asal + income ke akun tujuan).
  - Bisa tambah catatan opsional saat transfer.

- **Ringkasan keuangan real-time**
  - Total balance
  - Total income
  - Total expense
  - Breakdown saldo per akun

- **Pencarian & filter transaksi**
  - Search by judul, kategori, dan akun
  - Filter berdasarkan tipe transaksi (`ALL`, `INCOME`, `EXPENSE`)
  - Filter berdasarkan akun (`ALL`, `Dompet`, `ATM/E-Wallet`)

- **Manajemen transaksi cepat**
  - Swipe untuk hapus transaksi
  - Pull-to-refresh daftar transaksi

- **Penyimpanan lokal SQLite**
  - Data transaksi tersimpan lokal menggunakan `sqflite`.

- **Sinkronisasi Google Sheets (opsional)**
  - Sync manual dari tombol cloud di AppBar.
  - Auto-sync best effort setelah tambah/hapus transaksi & transfer.
  - Pengaturan sync (enabled, webhook URL, secret) bisa diubah dari dalam aplikasi dan disimpan via `shared_preferences`.

---

## 🧱 Tech Stack

- Flutter (Material 3, Dark Theme)
- Provider (state management)
- SQLite (`sqflite`)
- HTTP (`http`) untuk webhook sync
- Shared Preferences untuk simpan konfigurasi sync

---

## 🚀 Menjalankan Project

```bash
flutter pub get
flutter run
```

---

## 🔄 Setup Sync ke Google Sheets

### 1) Buat Google Apps Script Webhook

1. Buka `script.google.com`
2. Buat project baru
3. Salin isi `docs/google_sheets_webhook.gs`
4. Deploy → **New deployment** → **Web app**
   - Execute as: **Me**
   - Who has access: **Anyone with the link**
5. Copy URL web app (akhiran `/exec`)

### 2) Konfigurasi di aplikasi

Konfigurasi dapat dilakukan dengan 2 cara:

- **Via UI aplikasi (direkomendasikan)**
  - Buka ikon **Settings** di AppBar
  - Isi webhook URL, secret (opsional), lalu aktifkan sync

- **Via default config code** (opsional)
  - Edit `lib/config/google_sheets_sync_config.dart`

```dart
class GoogleSheetsSyncConfig {
  static const bool enabled = false;
  static const String webhookUrl = '';
  static const String secret = '';
}
```

### 3) Sheet yang akan dibuat/update

- `Transactions`
- `Summary`

---

## 📁 Struktur Utama

- `lib/screens/dashboard_screen.dart` → UI dashboard, input transaksi, filter, transfer, sync setting
- `lib/viewmodels/finance_viewmodel.dart` → business logic, kalkulasi saldo, auto-sync
- `lib/database/db_helper.dart` → SQLite helper
- `lib/services/google_sheets_sync_service.dart` → service HTTP untuk kirim data ke webhook
- `docs/google_sheets_webhook.gs` → script Apps Script penerima sync

---

## 📝 Catatan

- Jika `sync` tidak aktif atau `webhookUrl` kosong, sinkronisasi tidak berjalan.
- Sinkronisasi bersifat **best effort**: jika internet/webhook gagal, data lokal tetap aman di SQLite.
- Versi aplikasi saat ini: **1.0.3+2004**.
