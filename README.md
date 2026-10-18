# MutcoApp

Mutco adalah aplikasi Android berbasis Flutter untuk mendeteksi biji kopi dan cacat visual dari foto, menghitung nilai cacat, serta menampilkan estimasi golongan mutu berdasarkan perhitungan yang diterapkan dalam aplikasi dengan acuan SNI 01-2907-2008.

Model YOLO11s dalam format ONNX disertakan di dalam aplikasi dan dijalankan pada perangkat. Foto untuk analisis dan riwayat pemindaian disimpan secara lokal.

## Unduh aplikasi

APK tersedia di halaman [GitHub Releases](https://github.com/mutco/MutcoApp/releases). Karena repositori ini privat, pengguna harus memiliki akses ke repositori untuk mengunduhnya.

APK rilis uji v1.0.0 membutuhkan Android 7.0 (API 24) atau lebih baru. APK universal mendukung `arm64-v8a`, `armeabi-v7a`, dan `x86_64`, dengan ukuran sekitar 153 MB. File `SHA256SUMS.txt` pada rilis dapat digunakan untuk memeriksa integritas unduhan.

1. Buka rilis yang ingin digunakan dan unduh file `.apk` pada bagian **Assets**.
2. Buka APK di perangkat Android. Jika diminta, izinkan pemasangan aplikasi dari sumber tersebut.
3. Jalankan **Mutco** dan izinkan akses kamera untuk mengambil foto. Foto juga dapat dipilih dari galeri.

Rilis awal ditujukan untuk pengujian dan evaluasi. Konfigurasi Android saat ini menggunakan kunci debug untuk menandatangani APK release. Sebelum distribusi produksi, gunakan kunci penandatanganan rilis khusus dan simpan kunci tersebut dengan aman agar pembaruan aplikasi dapat dipasang secara konsisten.

## Fitur

- Mengambil foto dengan kamera atau memilih foto dari galeri, termasuk pemotongan foto sebelum analisis.
- Satu sesi dapat berisi satu atau banyak foto dari galeri maupun kamera. Foto diproses bergiliran, hasil cacat dijumlahkan, dan foto gagal dapat dicoba ulang tanpa memproses ulang foto yang berhasil.
- Deteksi 21 kelas objek, meliputi biji normal, jenis cacat biji, kulit kopi, kulit tanduk, serta ranting/tanah/batu.
- Menampilkan kotak deteksi, label, jumlah objek per kelas, nilai cacat, dan estimasi golongan mutu.
- Menyimpan, mengganti nama, melihat kembali, dan menghapus riwayat pemindaian.
- Menyimpan gambar hasil deteksi sebagai PNG di Android.
- Materi belajar berupa tabel nilai cacat dan rentang golongan mutu.
- Tema terang/gelap, bahasa Indonesia/Inggris, serta pengaturan ambang confidence dan IoU untuk deteksi.

## Cara menggunakan

1. Letakkan sampel biji kopi pada latar gelap dengan pencahayaan lampu. Disarankan jarak kamera sekitar 15 cm dari biji kopi.
2. Buka menu pindai, ambil foto atau pilih gambar dari galeri, lalu sesuaikan area foto.
3. Tambahkan foto lewat ikon galeri/kamera bila diperlukan. Setiap foto harus berisi bagian sampel yang berbeda agar biji yang sama tidak terhitung dua kali.
4. Jalankan analisis dan periksa hasil deteksi serta ringkasan nilai cacat gabungan. Ketuk thumbnail atau geser gambar untuk melihat foto lain.
5. Simpan seluruh sesi sebagai satu entri riwayat. Tombol unduh mengekspor foto yang sedang dipilih.

Hasil aplikasi merupakan estimasi visual dari objek dalam foto. Perhitungan mutu tidak menggantikan pengujian SNI lengkap: bobot contoh uji 300 g, kadar air, bau, dan persyaratan lain tetap perlu diperiksa. Pencahayaan, posisi objek, tumpang tindih, dan kualitas foto dapat memengaruhi hasil deteksi.

## Menjalankan proyek

Siapkan Flutter SDK dengan Dart yang memenuhi batas `^3.13.4` pada `pubspec.yaml`, Android SDK, dan perangkat Android atau emulator. Gunakan konfigurasi Java yang sesuai dengan Flutter/Gradle; proyek menargetkan Java 17.

```sh
flutter pub get
flutter run
```

Model harus tersedia pada `assets/models/mutco_yolo11s_best.onnx`. Model tersebut sudah termasuk dalam repositori dan didaftarkan sebagai aset pada `pubspec.yaml`.

## Pengujian dan build

```sh
flutter analyze
flutter test
flutter build apk --release
```

APK hasil build berada di `build/app/outputs/flutter-apk/app-release.apk`. Versi aplikasi saat ini adalah `1.0.1+2` (tag `v1.0.1`).

Pengujian yang tersedia mencakup pemotongan gambar, decoder keluaran YOLO, perhitungan nilai cacat dan mutu, IoU, dialog penggantian nama riwayat, rekap 110 foto, penyimpanan dan penghapusan sesi banyak foto, serta pengulangan foto gagal. Kamera, inferensi model pada perangkat, dan ekspor gambar perlu diuji langsung pada perangkat Android.

## Struktur proyek

| Folder | Isi |
| --- | --- |
| `lib/app/` | Pengaturan aplikasi, tema, dan bahasa |
| `lib/features/` | Layar beranda, pindai, hasil, riwayat, belajar, dan pengaturan |
| `lib/services/` | Persiapan gambar dan inferensi ONNX |
| `lib/core/` | Kelas objek, bobot cacat, dan perhitungan mutu |
| `lib/data/` | Data deteksi dan penyimpanan riwayat lokal |
| `assets/` | Model ONNX dan gambar identitas aplikasi |
| `test/` | Pengujian otomatis |
| `android/` | Konfigurasi dan integrasi Android |
| `tools/` | Utilitas pendukung pengembangan |

Target rilis saat ini adalah Android. Folder platform lain berasal dari proyek Flutter; keberadaannya tidak berarti seluruh fitur telah diverifikasi pada platform tersebut.
