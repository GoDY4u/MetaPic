# MetaPic

Extract GPS coordinates and key metadata from images — then get a Google Maps link instantly.

**MetaPic** reads EXIF data from photos (JPEG, HEIC, TIFF, etc.) and presents it as a beautiful card in your terminal. It works on **Termux (Android)**, **Linux**, and **macOS**, and can even install `exiftool` automatically if it's missing.

---

## ✨ Features

- 📸 **Device & OS** – Phone model, manufacturer, and operating system.
- 📍 **GPS coordinates** – Latitude, longitude, altitude, speed, and direction (converted to decimal).
- 🌐 **Google Maps link** – Ready to open directly from the terminal.
- ⚙️ **Camera settings** – Aperture, shutter speed, ISO, focal length.
- 🔭 **Lens info** – Lens model.
- 🏢 **Company / Copyright** – Creator, copyright, and device manufacturer.
- 💅 **Styled output** – Colored box with icons; adapts to terminals without color.
- 📱 **Termux‑ready** – Gives friendly tips about `termux-setup-storage`.

---

## 📦 Requirements

- **Bash** (4.0 or later)
- **[exiftool](https://exiftool.org/)** – if not installed, MetaPic offers to install it automatically using your package manager.

---

## 🚀 Installation

Clone the repository or just download the script and make it executable:

```bash
git clone https://github.com/GoDY4u/MetaPic
cd MetaPic
chmod +x metapic.sh
```
---

## Usage (Example)

```bash
./metapic.sh img.jpg
