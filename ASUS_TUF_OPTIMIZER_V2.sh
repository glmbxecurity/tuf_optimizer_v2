#!/bin/bash
# ==============================================================================
#  TUF OPTIMIZER v2.0 — Gestor de energía (Modular)
#  Autor: Revisado y mejorado
# ==============================================================================

# --- DETECCIÓN DE ENTORNO (Debe ser antes de cargar librerías) ---
[[ $EUID -ne 0 ]] && echo -e "Ejecuta como root." && exit 1

# Cargar librerías
LIB_DIR="$(dirname "$(readlink -f "$0")")/lib"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/detect.sh"
source "$LIB_DIR/power.sh"
source "$LIB_DIR/install.sh"
source "$LIB_DIR/ui.sh"

# --- INICIO ---
DEBUG_MODE=1
[[ "$1" == "--no-debug" ]] && DEBUG_MODE=0
REAL_USER=$(who am i | awk '{print $1}')
[[ -z "$REAL_USER" ]] && REAL_USER=$(logname 2>/dev/null)
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$REAL_HOME/.Xauthority}"

touch "$LOG_FILE" 2>/dev/null
log INFO "=== TUF Optimizer Modular iniciado (usuario: $REAL_USER) ==="

# Bucle Principal
while true; do
    get_summary
    echo " 1. CHECKLIST      — Diagnóstico"
    echo " 2. INSTALAR       — Instalar/Reparar"
    echo " 3. ULTRA AHORRO   — Batería máxima"
    echo " 4. GAMING         — Potencia máxima"
    echo " 5. PERSONALIZAR   — Ajustes individuales"
    echo " 6. DEBUG / LOG    — Ver registro"
    echo " 7. AYUDA"
    echo " 8. Salir"
    echo ""
    if [[ $DEBUG_MODE -eq 1 ]]; then
        read -rp " Selección: " opt
    else
        read -t 30 -rp " Selección: " opt
    fi
    [[ -z "$opt" ]] && continue

    case $opt in
        1) run_check ;;
        2) run_install ;;
        3) apply_mode "battery" ;;
        4) apply_mode "performance" ;;
        5) menu_personalizar ;;
        6) show_debug ;;
        7) show_help ;;
        8) log INFO "=== Cerrado ==="; exit 0 ;;
        *) echo "Opción no válida."; sleep 1 ;;
    esac
done
