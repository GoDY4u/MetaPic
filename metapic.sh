#!/usr/bin/env bash
# s.sh - Extract GPS coordinates and key metadata from images
# Works on Termux, Linux, and macOS
# Usage: ./s.sh <image1> [image2 ...]

set -euo pipefail

# ---- Color & style ----
if command -v tput &>/dev/null && [ -t 1 ]; then
    BOLD=$(tput bold)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1)
    CYAN=$(tput setaf 6)
    BLUE=$(tput setaf 4)
    RESET=$(tput sgr0)
else
    BOLD=""; GREEN=""; YELLOW=""; RED=""; CYAN=""; BLUE=""; RESET=""
fi

usage() {
    cat <<EOF
${BOLD}Usage:${RESET} $(basename "$0") [-h] <image1> [image2 ...]
Extract GPS coordinates and key metadata from images, with a Google Maps link.

${BOLD}Options:${RESET}
  -h    Show this help.

${BOLD}Examples:${RESET}
  $(basename "$0") photo.jpg
  $(basename "$0") ~/storage/dcim/Camera/*.jpg
EOF
    exit 0
}

error() {
    echo -e "${RED}${BOLD}Error:${RESET} $*" >&2
    exit 1
}

# ---- Package manager detection ----
detect_pkg_manager() {
    if [[ -n "${TERMUX_VERSION:-}" ]] || command -v pkg &>/dev/null; then
        echo "pkg install -y exiftool"
    elif command -v apt-get &>/dev/null; then
        echo "sudo apt-get install -y libimage-exiftool-perl"
    elif command -v dnf &>/dev/null; then
        echo "sudo dnf install -y perl-Image-ExifTool"
    elif command -v yum &>/dev/null; then
        echo "sudo yum install -y perl-Image-ExifTool"
    elif command -v pacman &>/dev/null; then
        echo "sudo pacman -S --noconfirm perl-image-exiftool"
    elif command -v brew &>/dev/null; then
        echo "brew install exiftool"
    elif command -v zypper &>/dev/null; then
        echo "sudo zypper install -y exiftool"
    else
        echo ""
    fi
}

install_exiftool() {
    echo -e "${YELLOW}exiftool is not installed.${RESET}"
    local cmd
    cmd=$(detect_pkg_manager)
    if [[ -z "$cmd" ]]; then
        error "Could not detect a package manager. Install exiftool manually:
    - Termux: pkg install exiftool
    - Debian/Ubuntu: sudo apt install libimage-exiftool-perl
    - Fedora: sudo dnf install perl-Image-ExifTool
    - Arch: sudo pacman -S perl-image-exiftool
    - macOS: brew install exiftool
    - openSUSE: sudo zypper install exiftool"
    fi
    echo -e "${CYAN}Will run:${RESET} $cmd"
    read -r -p "Do you want to install it now? [Y/n] " answer
    if [[ "$answer" =~ ^[Nn]$ ]]; then
        error "Installation cancelled."
    fi
    if ! eval "$cmd"; then
        error "Installation failed. Please install exiftool manually."
    fi
    echo -e "${GREEN}exiftool installed successfully.${RESET}"
}

check_deps() {
    if ! command -v exiftool &>/dev/null; then
        install_exiftool
    fi
    if [[ -n "${TERMUX_VERSION:-}" && ! -d ~/storage/downloads ]]; then
        echo -e "${YELLOW}ℹ️  To access /sdcard, run: termux-setup-storage${RESET}"
    fi
}

# ---- Build card for one file ----
print_card() {
    local file="$1"

    # Extract all metadata (one call, tab-separated)
    local meta
    meta=$(exiftool -fast -T \
        -FileName \
        -Make \
        -Model \
        -DateTimeOriginal \
        -ImageSize \
        -Software \
        -LensModel \
        -Aperture \
        -ExposureTime \
        -ISO \
        -FocalLength \
        -Flash \
        -MeteringMode \
        -WhiteBalance \
        -SceneCaptureType \
        -ProfileCreator \
        -Copyright \
        -DeviceManufacturer \
        -FileModifyDate \
        "$file" 2>/dev/null) || true

    if [[ -z "$meta" ]]; then
        return
    fi

    IFS=$'\t' read -r fname make model date_orig image_size software lens_model \
        aperture exposure iso focal_len flash metering wb scene \
        profile_creator copyright device_manufacturer file_mod_date <<< "$meta"

    # GPS extraction (decimal, with -n)
    local gps_raw gps_lat_dec gps_lon_dec gps_alt gps_speed gps_dir
    gps_raw=$(exiftool -n -p '$GPSLatitude,$GPSLongitude' "$file" 2>/dev/null) || true
    if [[ "$gps_raw" =~ ^(-?[0-9.]+),(-?[0-9.]+)$ ]]; then
        gps_lat_dec="${BASH_REMATCH[1]}"
        gps_lon_dec="${BASH_REMATCH[2]}"
        gps_alt=$(exiftool -n -p '$GPSAltitude' "$file" 2>/dev/null || true)
        gps_speed=$(exiftool -n -p '$GPSSpeed' "$file" 2>/dev/null || true)
        gps_dir=$(exiftool -n -p '$GPSImgDirection' "$file" 2>/dev/null || true)
    else
        gps_lat_dec=""; gps_lon_dec=""
        gps_alt=""; gps_speed=""; gps_dir=""
    fi

    # Format OS string nicely
    local os_str=""
    if [[ -n "$software" ]]; then
        # If device is Apple and software looks like a version number → "iOS 15.7"
        if [[ "$make" == *"Apple"* && "$software" =~ ^[0-9.]+$ ]]; then
            os_str="iOS ${software}"
        else
            os_str="$software"
        fi
    fi

    # --- Print card ---
    echo -e "${BLUE}┌─────────────────────────────────────────────────┐${RESET}"
    printf "${BLUE}│${RESET} ${BOLD}📁 %s${RESET}\n" "$fname"
    echo -e "${BLUE}├─────────────────────────────────────────────────┤${RESET}"

    [[ -n "$make" || -n "$model" ]] && \
        printf "${BLUE}│${RESET}   📱 ${BOLD}%s %s${RESET}\n" "$make" "$model"
    [[ -n "$date_orig" ]] && printf "${BLUE}│${RESET}   🕒 %s\n" "$date_orig"
    [[ -n "$image_size" ]] && printf "${BLUE}│${RESET}   📐 %s\n" "$image_size"
    [[ -n "$os_str" ]] && printf "${BLUE}│${RESET}   💿 %s\n" "$os_str"
    [[ -n "$lens_model" ]] && printf "${BLUE}│${RESET}   🔭 %s\n" "$lens_model"

    # Company / creator
    if [[ -n "$profile_creator" || -n "$copyright" || -n "$device_manufacturer" ]]; then
        echo -e "${BLUE}├─────────────────────────────────────────────────┤${RESET}"
        [[ -n "$profile_creator" ]] && printf "${BLUE}│${RESET}   🏢 Profile Creator: %s\n" "$profile_creator"
        [[ -n "$copyright" ]] && printf "${BLUE}│${RESET}   ©️  Copyright: %s\n" "$copyright"
        [[ -n "$device_manufacturer" ]] && printf "${BLUE}│${RESET}   🏭 Device Manuf.: %s\n" "$device_manufacturer"
    fi

    # Camera settings
    if [[ -n "$aperture" || -n "$exposure" || -n "$iso" || -n "$focal_len" ]]; then
        echo -e "${BLUE}├─────────────────────────────────────────────────┤${RESET}"
        [[ -n "$aperture" ]] && printf "${BLUE}│${RESET}   ⚙️  Aperture: %s\n" "$aperture"
        [[ -n "$exposure" ]] && printf "${BLUE}│${RESET}   ⚙️  Exposure: %s\n" "$exposure"
        [[ -n "$iso" ]] && printf "${BLUE}│${RESET}   ⚙️  ISO: %s\n" "$iso"
        [[ -n "$focal_len" ]] && printf "${BLUE}│${RESET}   ⚙️  Focal length: %s\n" "$focal_len"
    fi

    # Other settings
    if [[ -n "$flash" || -n "$metering" || -n "$wb" || -n "$scene" ]]; then
        echo -e "${BLUE}├─────────────────────────────────────────────────┤${RESET}"
        [[ -n "$flash" ]] && printf "${BLUE}│${RESET}   🔆 Flash: %s\n" "$flash"
        [[ -n "$metering" ]] && printf "${BLUE}│${RESET}   📊 Metering: %s\n" "$metering"
        [[ -n "$wb" ]] && printf "${BLUE}│${RESET}   ⚖️  White Balance: %s\n" "$wb"
        [[ -n "$scene" ]] && printf "${BLUE}│${RESET}   🎬 Scene: %s\n" "$scene"
    fi

    # GPS
    echo -e "${BLUE}├─────────────────────────────────────────────────┤${RESET}"
    if [[ -n "$gps_lat_dec" && -n "$gps_lon_dec" ]]; then
        printf "${BLUE}│${RESET}   📍 Latitude: %s\n" "$gps_lat_dec"
        printf "${BLUE}│${RESET}   📍 Longitude: %s\n" "$gps_lon_dec"
        [[ -n "$gps_alt" ]] && printf "${BLUE}│${RESET}   ⛰️  Altitude: %s m\n" "$gps_alt"
        [[ -n "$gps_speed" ]] && printf "${BLUE}│${RESET}   🚀 Speed: %s km/h\n" "$gps_speed"
        [[ -n "$gps_dir" ]] && printf "${BLUE}│${RESET}   🧭 Direction: %s°\n" "$gps_dir"
        printf "${BLUE}│${RESET}   🌐 ${CYAN}https://www.google.com/maps?q=%s,%s${RESET}\n" "$gps_lat_dec" "$gps_lon_dec"
    else
        echo -e "${BLUE}│${RESET}   ${YELLOW}📍 No GPS data${RESET}"
    fi

    [[ -n "$file_mod_date" ]] && printf "${BLUE}│${RESET}   📅 Modified: %s\n" "$file_mod_date"

    echo -e "${BLUE}└─────────────────────────────────────────────────┘${RESET}"
    echo ""
}

# ---- Main ----
FILES=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        *) FILES+=("$1") ;;
    esac
    shift
done

[[ ${#FILES[@]} -eq 0 ]] && usage

check_deps

for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}${BOLD}File not found:${RESET} $file" >&2
        continue
    fi
    print_card "$file"
done
