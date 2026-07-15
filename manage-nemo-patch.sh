#!/usr/bin/env bash
# Nemo Progress Graph Patch Manager
# For Linux Mint 22.3 (Nemo 6.6.3+zena)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="${SCRIPT_DIR}/backup/patched"
ORIGINAL_DIR="${SCRIPT_DIR}/backup/original"

PACKAGES=(
    "nemo"
    "nemo-data"
    "nemo-dbg"
    "libnemo-extension1"
    "libnemo-extension-dev"
    "gir1.2-nemo-3.0"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
    cat <<EOF
Nemo Progress Graph Patch Manager

Usage:
  $0 install      Back up original packages and install the graph patch
  $0 uninstall    Restore the original packages
  $0 status       Show current installation status
  $0 help         Show this help

Project directory: ${SCRIPT_DIR}
EOF
}

ensure_dirs() {
    mkdir -p "${PATCH_DIR}" "${ORIGINAL_DIR}"
}

download_originals() {
    echo -e "${YELLOW}==>${NC} Backing up original Nemo packages..."
    cd "${ORIGINAL_DIR}"
    local missing=0
    for pkg in "${PACKAGES[@]}"; do
        if [[ ! -f "${pkg}_6.6.3+zena_*.deb" ]] && [[ ! -f "${pkg}_6.6.3+zena_amd64.deb" ]] && [[ ! -f "${pkg}_6.6.3+zena_all.deb" ]]; then
            echo "  Downloading ${pkg}..."
            if ! apt-get download "${pkg}" 2>/dev/null; then
                echo -e "${RED}ERROR:${NC} Could not download ${pkg}."
                missing=1
            fi
        else
            echo "  ${pkg} already backed up."
        fi
    done
    cd - >/dev/null
    if [[ ${missing} -eq 1 ]]; then
        echo -e "${RED}ABORT:${NC} Not all original packages could be backed up."
        exit 1
    fi
    echo -e "${GREEN}==>${NC} Original packages backed up to ${ORIGINAL_DIR}"
}

check_patched_packages() {
    local missing=()
    for pkg in "${PACKAGES[@]}"; do
        if ! compgen -G "${PATCH_DIR}/${pkg}_*.deb" >/dev/null; then
            missing+=("${pkg}")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}ERROR:${NC} The following patched packages are missing in ${PATCH_DIR}:"
        printf '  - %s\n' "${missing[@]}"
        echo "Please build them first with: dpkg-buildpackage -us -uc -b"
        exit 1
    fi
}

install_patch() {
    ensure_dirs
    download_originals
    check_patched_packages

    echo -e "${YELLOW}==>${NC} Installing patched Nemo packages..."
    pkexec dpkg -i "${PATCH_DIR}"/*.deb

    echo -e "${YELLOW}==>${NC} Fixing possible missing dependencies..."
    pkexec apt-get install -f -y

    echo -e "${GREEN}==>${NC} Installation complete."
    echo "Please restart Nemo with: nemo -q && nemo"
}

uninstall_patch() {
    if [[ ! -d "${ORIGINAL_DIR}" ]] || [[ -z "$(ls -A "${ORIGINAL_DIR}" 2>/dev/null)" ]]; then
        echo -e "${RED}ERROR:${NC} No original packages found in ${ORIGINAL_DIR}"
        exit 1
    fi

    echo -e "${YELLOW}==>${NC} Restoring original Nemo packages..."
    pkexec dpkg -i "${ORIGINAL_DIR}"/*.deb

    echo -e "${YELLOW}==>${NC} Fixing possible missing dependencies..."
    pkexec apt-get install -f -y

    echo -e "${GREEN}==>${NC} Restore complete."
    echo "Please restart Nemo with: nemo -q && nemo"
}

show_status() {
    echo -e "${YELLOW}Currently installed Nemo packages:${NC}"
    dpkg -l | grep -E '^(ii|iU)\s+(nemo|libnemo-extension|gir1\.2-nemo)' || true

    echo ""
    if [[ -d "${PATCH_DIR}" ]] && [[ -n "$(ls -A "${PATCH_DIR}" 2>/dev/null)" ]]; then
        echo -e "${GREEN}Patched packages found:${NC} ${PATCH_DIR}"
    else
        echo -e "${RED}No patched packages found.${NC}"
    fi

    if [[ -d "${ORIGINAL_DIR}" ]] && [[ -n "$(ls -A "${ORIGINAL_DIR}" 2>/dev/null)" ]]; then
        echo -e "${GREEN}Original packages backed up:${NC} ${ORIGINAL_DIR}"
    else
        echo -e "${RED}No original packages backed up.${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Binary comparison:${NC}"
    if [[ -f /usr/bin/nemo ]] && [[ -f "${PATCH_DIR}/nemo_6.6.3+zena_amd64.deb" ]]; then
        tmpdir="$(mktemp -d)"
        dpkg-deb -x "${PATCH_DIR}/nemo_6.6.3+zena_amd64.deb" "${tmpdir}" >/dev/null
        if cmp -s "${tmpdir}/usr/bin/nemo" /usr/bin/nemo; then
            echo -e "${GREEN}Currently installed nemo matches the patched package.${NC}"
        else
            echo -e "${YELLOW}Currently installed nemo differs from the patched package.${NC}"
        fi
        rm -rf "${tmpdir}"
    fi
}

case "${1:-}" in
    install)
        install_patch
        ;;
    uninstall|remove|restore)
        uninstall_patch
        ;;
    status)
        show_status
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command:${NC} $1"
        show_help
        exit 1
        ;;
esac
