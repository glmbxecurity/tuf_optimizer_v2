#!/bin/bash
# ==============================================================================
#  TUF OPTIMIZER v2.0 — Gestor de energía para portátiles ASUS (y compatibles)
#  Autor: Revisado y mejorado desde script base de Gemini
#  Compatible: ASUS TUF / ROG con asusctl+supergfxctl | cualquier portátil Linux
# ==============================================================================

# --- COLORES ---
RED='\e[31m'; GRN='\e[32m'; YLW='\e[33m'; BLU='\e[34m'; CYN='\e[36m'; NC='\e[0m'; BOLD='\e[1m'

# --- ARCHIVO DE LOG ---
LOG_FILE="/var/log/tuf-optimizer.log"
DEBUG_MODE=0  # 0=off, 1=on (cambia con opción del menú o --debug)

log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
    if [[ $DEBUG_MODE -eq 1 ]]; then
        case $level in
            INFO)  echo -e "${BLU}[DBG INFO]${NC} $msg" ;;
            WARN)  echo -e "${YLW}[DBG WARN]${NC} $msg" ;;
            ERROR) echo -e "${RED}[DBG ERR ]${NC} $msg" ;;
            OK)    echo -e "${GRN}[DBG OK  ]${NC} $msg" ;;
        esac
    fi
}

run_cmd() {
    # Ejecuta un comando, loguea resultado. Uso: run_cmd "descripción" comando args...
    local desc="$1"; shift
    log INFO "Ejecutando: $*"
    local output
    output=$("$@" 2>&1)
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        log OK "$desc: OK"
    else
        log WARN "$desc: FALLÓ (rc=$rc) — $output"
    fi
    return $rc
}

# --- CHECKS DE ROOT Y ARGUMENTOS ---
[[ $EUID -ne 0 ]] && echo -e "${RED}[!] Ejecuta como root (sudo).${NC}" && exit 1
[[ "$1" == "--debug" ]] && DEBUG_MODE=1

# --- DETECCIÓN DE ENTORNO (DISPLAY para root) ---
REAL_USER=$(who am i | awk '{print $1}')
[[ -z "$REAL_USER" ]] && REAL_USER=$(logname 2>/dev/null)
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$REAL_HOME/.Xauthority}"
log INFO "Usuario real: $REAL_USER | HOME: $REAL_HOME | DISPLAY: $DISPLAY"

# --- DETECCIÓN DE HARDWARE ---
CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)

# GPU: intentamos varios métodos
detect_gpu() {
    if command -v supergfxctl &>/dev/null; then
        GPU_MODE=$(supergfxctl -g 2>/dev/null)
        GPU_NAME=$(lspci | grep -i 'vga\|3d\|display' | head -n1 | cut -d: -f3 | xargs)
    else
        # Sin supergfxctl: leemos lspci
        GPU_NAME=$(lspci | grep -i 'vga\|3d\|display' | head -n1 | cut -d: -f3 | xargs)
        GPU_MODE="N/A (sin supergfxctl)"
        # Intentar via DRM
        if ls /sys/class/drm/*/device/vendor &>/dev/null; then
            GPU_MODE="Integrada/detectada via DRM"
        fi
    fi
    [[ -z "$GPU_NAME" ]] && GPU_NAME="No detectada"
}

# Pantalla
detect_display() {
    DISPLAY_NAME=$(xrandr 2>/dev/null | grep " connected primary" | awk '{print $1}')
    [[ -z "$DISPLAY_NAME" ]] && DISPLAY_NAME=$(xrandr 2>/dev/null | grep " connected" | grep -i 'edp\|lvds' | head -n1 | awk '{print $1}')
    [[ -z "$DISPLAY_NAME" ]] && DISPLAY_NAME=$(xrandr 2>/dev/null | grep " connected" | head -n1 | awk '{print $1}')
    [[ -z "$DISPLAY_NAME" ]] && DISPLAY_NAME="No detectada"
    log INFO "Pantalla detectada: $DISPLAY_NAME"
}

# Herramientas ASUS presentes
HAS_ASUSCTL=0; HAS_SUPERGFX=0; HAS_AUTOCPUFREQ=0
HAS_BRIGHTNESS=0; HAS_SENSORS=0; HAS_UPOWER=0; HAS_POWERSTAT=0
command -v asusctl      &>/dev/null && HAS_ASUSCTL=1
command -v supergfxctl  &>/dev/null && HAS_SUPERGFX=1
command -v auto-cpufreq &>/dev/null && HAS_AUTOCPUFREQ=1
command -v brightnessctl &>/dev/null && HAS_BRIGHTNESS=1
command -v sensors      &>/dev/null && HAS_SENSORS=1
command -v upower       &>/dev/null && HAS_UPOWER=1
command -v powerstat    &>/dev/null && HAS_POWERSTAT=1
log INFO "Herramientas: asusctl=$HAS_ASUSCTL supergfx=$HAS_SUPERGFX autocpufreq=$HAS_AUTOCPUFREQ sensors=$HAS_SENSORS upower=$HAS_UPOWER powerstat=$HAS_POWERSTAT"

# ==============================================================================
# FUNCIÓN: RESUMEN DEL SISTEMA
# ==============================================================================
get_summary() {
    detect_display
    detect_gpu
    clear
    echo -e "${BOLD}================================================================${NC}"
    echo -e "${BOLD}     TUF OPTIMIZER v2.0  |  $(date '+%d/%m/%Y %H:%M')${NC}"
    echo -e "${BOLD}================================================================${NC}"

    # CPU
    echo -e " ${CYN}CPU:${NC}      $CPU_MODEL"

    # GPU
    echo -e " ${CYN}GPU:${NC}      $GPU_NAME"
    if [[ $HAS_SUPERGFX -eq 1 ]]; then
        echo -e " ${CYN}Modo GPU:${NC} ${YLW}$GPU_MODE${NC}"
    fi

    # Perfil ASUS (si disponible)
    if [[ $HAS_ASUSCTL -eq 1 ]]; then
        PROFILE=$(asusctl profile -p 2>/dev/null | awk '{print $NF}')
        echo -e " ${CYN}Perfil ASUS:${NC} ${YLW}${PROFILE:-N/A}${NC}"
        BATT_LIMIT=$(asusctl -c 2>/dev/null | grep -oP '\d+')
        echo -e " ${CYN}Límite batería:${NC} ${YLW}${BATT_LIMIT:+$BATT_LIMIT%}${BATT_LIMIT:-N/A}${NC}"
    fi

    # Pantalla y Hz
    if [[ "$DISPLAY_NAME" != "No detectada" ]]; then
        REFRESH=$(xrandr 2>/dev/null | grep -A1 "$DISPLAY_NAME" | grep '*' | awk '{print $1}')
        echo -e " ${CYN}Pantalla:${NC} $DISPLAY_NAME  ${CYN}|  Hz:${NC} ${YLW}${REFRESH:-N/A}${NC}"
    fi

    # Gobernador CPU
    GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    echo -e " ${CYN}Gobernador CPU:${NC} ${YLW}${GOV:-N/A}${NC}"

    # Suspensión
    SLEEP_MODE=$(cat /sys/power/mem_sleep 2>/dev/null | grep -oP '\[\K[^\]]+')
    echo -e " ${CYN}Suspensión:${NC} ${YLW}${SLEEP_MODE:-N/A}${NC}"

    echo -e "${BOLD}----------------------------------------------------------------${NC}"

    # --- BATERÍA (upower) ---
    if [[ $HAS_UPOWER -eq 1 ]]; then
        BATT_PATH=$(upower -e 2>/dev/null | grep -i battery | head -n1)
        if [[ -n "$BATT_PATH" ]]; then
            BATT_PCT=$(upower -i "$BATT_PATH" 2>/dev/null | grep -i 'percentage' | awk '{print $2}')
            BATT_STATE=$(upower -i "$BATT_PATH" 2>/dev/null | grep -i 'state' | awk '{print $2}')
            BATT_WH=$(upower -i "$BATT_PATH" 2>/dev/null | grep 'energy:' | grep -v rate | awk '{print $2, $3}')
            BATT_RATE=$(upower -i "$BATT_PATH" 2>/dev/null | grep 'energy-rate' | awk '{print $2, $3}')
            BATT_TIME=$(upower -i "$BATT_PATH" 2>/dev/null | grep 'time to' | sed 's/.*time to/Tiempo/' | xargs)
            echo -e " ${CYN}Batería:${NC} ${YLW}${BATT_PCT:-N/A}${NC}  Estado: ${YLW}${BATT_STATE:-N/A}${NC}"
            [[ -n "$BATT_WH" ]]   && echo -e " ${CYN}Energía restante:${NC} ${YLW}$BATT_WH${NC}"
            [[ -n "$BATT_RATE" ]] && echo -e " ${CYN}Consumo actual:${NC}   ${YLW}$BATT_RATE${NC}"
            [[ -n "$BATT_TIME" ]] && echo -e " ${CYN}$BATT_TIME${NC}"
        fi
    else
        # Fallback: /sys directamente
        BATT_SYS=$(ls /sys/class/power_supply/ 2>/dev/null | grep -i bat | head -n1)
        if [[ -n "$BATT_SYS" ]]; then
            B="/sys/class/power_supply/$BATT_SYS"
            PCT=$(cat "$B/capacity" 2>/dev/null)
            STATE=$(cat "$B/status" 2>/dev/null)
            echo -e " ${CYN}Batería:${NC} ${YLW}${PCT:+$PCT%}${PCT:-N/A}${NC}  Estado: ${YLW}${STATE:-N/A}${NC}"
        fi
    fi

    # --- TEMPERATURAS (sensors) ---
    if [[ $HAS_SENSORS -eq 1 ]]; then
        echo -e "${BOLD}----------------------------------------------------------------${NC}"
        echo -e " ${CYN}Temperaturas:${NC}"
        # CPU: core temps
        CPU_TEMP=$(sensors 2>/dev/null | grep -E 'Core|Tctl|Tdie|Package' | \
            awk '{for(i=1;i<=NF;i++) if($i~/^\+[0-9]/) printf "  %s ", $i}' | head -c 60)
        [[ -n "$CPU_TEMP" ]] && echo -e "   CPU:  ${YLW}$CPU_TEMP${NC}" || echo -e "   CPU:  ${YLW}N/A${NC}"
        # GPU temp
        GPU_TEMP=$(sensors 2>/dev/null | grep -A3 -i 'amdgpu\|nouveau\|nvidia' | \
            grep -i 'temp\|edge\|junction' | head -n1 | awk '{print $2}')
        [[ -n "$GPU_TEMP" ]] && echo -e "   GPU:  ${YLW}$GPU_TEMP${NC}"
        # NVMe/disco
        NVME_TEMP=$(sensors 2>/dev/null | grep -A5 'nvme\|acpitz' | grep 'Composite\|temp1' | head -n1 | awk '{print $2}')
        [[ -n "$NVME_TEMP" ]] && echo -e "   NVMe: ${YLW}$NVME_TEMP${NC}"
    else
        echo -e " ${CYN}Temp:${NC} ${YLW}(instala lm-sensors — ver Checklist)${NC}"
    fi

    echo -e "${BOLD}================================================================${NC}"

    # Advertencias visibles
    [[ $DEBUG_MODE -eq 1 ]] && echo -e " ${YLW}[DEBUG ACTIVO — log: $LOG_FILE]${NC}\n"
}

# ==============================================================================
# CHECKLIST: COMPROBAR (sin tocar nada)
# ==============================================================================
run_check() {
    clear
    echo -e "${BOLD}${BLU}================================================================${NC}"
    echo -e "${BOLD}${BLU}   CHECKLIST — DIAGNÓSTICO (solo lectura, no instala nada)${NC}"
    echo -e "${BOLD}${BLU}================================================================${NC}\n"

    local issues=0

    _chk() {
        # _chk "descripción" condición_booleana [consejo]
        local desc="$1"; local ok="$2"; local tip="${3:-}"
        if [[ "$ok" == "1" ]]; then
            echo -e " ${GRN}[✔]${NC} $desc"
            log OK "CHECK: $desc"
        else
            echo -e " ${RED}[✘]${NC} $desc"
            [[ -n "$tip" ]] && echo -e "      ${YLW}→ $tip${NC}"
            log WARN "CHECK FALLO: $desc"
            ((issues++))
        fi
    }

    echo -e "${BOLD}── Herramientas base ────────────────────────────────────────${NC}"
    _chk "lm-sensors instalado"    "$(command -v sensors    &>/dev/null && echo 1 || echo 0)" "apt install lm-sensors"
    _chk "upower instalado"        "$(command -v upower     &>/dev/null && echo 1 || echo 0)" "apt install upower"
    _chk "powerstat instalado"     "$(command -v powerstat  &>/dev/null && echo 1 || echo 0)" "apt install powerstat"
    _chk "brightnessctl instalado" "$(command -v brightnessctl &>/dev/null && echo 1 || echo 0)" "apt install brightnessctl"
    _chk "xrandr disponible"       "$(command -v xrandr     &>/dev/null && echo 1 || echo 0)" "apt install x11-xserver-utils"

    echo -e "\n${BOLD}── Herramientas ASUS (solo portátiles ASUS TUF/ROG) ─────────${NC}"
    _chk "asusctl instalado"       "$HAS_ASUSCTL"    "Requiere repositorio asus-linux.org (ver opción Instalar)"
    _chk "supergfxctl instalado"   "$HAS_SUPERGFX"   "Requiere repositorio asus-linux.org"
    _chk "auto-cpufreq instalado"  "$HAS_AUTOCPUFREQ" "apt install auto-cpufreq o desde GitHub"

    echo -e "\n${BOLD}── Parámetros del kernel ────────────────────────────────────${NC}"
    KERNEL_PARAMS=$(cat /proc/cmdline)
    if [[ $KERNEL_PARAMS == *"nvidia-drm.modeset=1"* ]]; then
        _chk "nvidia-drm.modeset=1 en GRUB" "1"
    else
        _chk "nvidia-drm.modeset=1 en GRUB" "0" "Necesario si usas NVIDIA; añádelo en /etc/default/grub"
    fi

    MEM_SLEEP=$(cat /sys/power/mem_sleep 2>/dev/null)
    if [[ "$MEM_SLEEP" == *"[deep]"* ]]; then
        _chk "Deep sleep (S3) activo" "1"
    else
        _chk "Deep sleep (S3) activo" "0" "Añade mem_sleep_default=deep a GRUB_CMDLINE_LINUX_DEFAULT"
    fi

    echo -e "\n${BOLD}── Repositorio ASUS ─────────────────────────────────────────${NC}"
    if grep -rq "lukasheis\|asus-linux\|asus-repo" /etc/apt/sources.list.d/ 2>/dev/null; then
        _chk "Repositorio asus-linux.org configurado" "1"
    else
        _chk "Repositorio asus-linux.org configurado" "0" "Ver opción 'Instalar herramientas' del menú"
    fi

    echo -e "\n${BOLD}── auto-cpufreq config ──────────────────────────────────────${NC}"
    if [[ -f /etc/auto-cpufreq.conf ]]; then
        _chk "/etc/auto-cpufreq.conf existe" "1"
    else
        _chk "/etc/auto-cpufreq.conf existe" "0" "El script puede crearlo (opción Instalar)"
    fi

    echo -e "\n${BOLD}================================================================${NC}"
    if [[ $issues -eq 0 ]]; then
        echo -e " ${GRN}${BOLD}Sistema completamente configurado. Sin problemas detectados.${NC}"
    else
        echo -e " ${YLW}${BOLD}$issues problema(s) detectado(s). Usa 'Instalar/Reparar' para resolverlos.${NC}"
    fi
    echo ""
    read -n1 -p "Presiona una tecla para volver..."
}

# ==============================================================================
# INSTALAR / REPARAR (pregunta antes de cada acción)
# ==============================================================================
run_install() {
    clear
    echo -e "${BOLD}${YLW}================================================================${NC}"
    echo -e "${BOLD}${YLW}   INSTALAR / REPARAR (pide confirmación en cada paso)${NC}"
    echo -e "${BOLD}${YLW}================================================================${NC}\n"

    _ask_install() {
        local pkg="$1"; local desc="$2"
        if ! dpkg -s "$pkg" &>/dev/null; then
            echo -e "${YLW}[?]${NC} $desc ($pkg) no está instalado."
            read -rp "    ¿Instalar ahora? (s/n): " resp
            if [[ $resp == "s" ]]; then
                apt-get install -y "$pkg" && log OK "Instalado: $pkg" || log ERROR "Fallo instalando: $pkg"
            fi
        else
            echo -e "${GRN}[✔]${NC} $desc ya instalado."
            log OK "Ya presente: $pkg"
        fi
    }

    echo -e "${BOLD}── Herramientas base ────────────────────────────────────────${NC}"
    _ask_install "lm-sensors"        "Temperaturas del sistema"
    _ask_install "upower"            "Info de batería (W, %)"
    _ask_install "powerstat"         "Consumo energético detallado"
    _ask_install "brightnessctl"     "Control de brillo de pantalla"
    _ask_install "x11-xserver-utils" "xrandr (control de pantalla/Hz)"

    # Microcódigo según fabricante
    echo -e "\n${BOLD}── Microcódigo CPU ──────────────────────────────────────────${NC}"
    if [[ $CPU_VENDOR == "AuthenticAMD" ]]; then
        _ask_install "amd64-microcode" "Microcódigo AMD"
    elif [[ $CPU_VENDOR == "GenuineIntel" ]]; then
        _ask_install "intel-microcode" "Microcódigo Intel"
    fi

    # Herramientas ASUS
    echo -e "\n${BOLD}── Herramientas ASUS (solo portátiles ASUS TUF/ROG) ─────────${NC}"
    echo -e "${CYN}Nota: requieren el repositorio de asus-linux.org${NC}"
    if ! grep -rq "lukasheis\|asus-linux" /etc/apt/sources.list.d/ 2>/dev/null; then
        read -rp "¿Añadir repositorio asus-linux.org? (s/n): " resp
        if [[ $resp == "s" ]]; then
            curl -fsSL https://download.opensuse.org/repositories/home:/lukasheis/Debian_Testing/Release.key \
                | gpg --dearmor | tee /etc/apt/trusted.gpg.d/home_lukasheis.gpg > /dev/null
            echo 'deb http://download.opensuse.org/repositories/home:/lukasheis/Debian_Testing/ /' \
                | tee /etc/apt/sources.list.d/home_lukasheis.list
            apt-get update
            log OK "Repositorio asus-linux añadido"
        fi
    else
        echo -e "${GRN}[✔]${NC} Repositorio asus-linux ya configurado."
    fi
    _ask_install "asusctl"     "Control de perfiles/batería ASUS"
    _ask_install "supergfxctl" "Conmutación de GPU (Integrada/Híbrida)"

    # auto-cpufreq
    echo -e "\n${BOLD}── auto-cpufreq ─────────────────────────────────────────────${NC}"
    if ! command -v auto-cpufreq &>/dev/null; then
        read -rp "¿Instalar auto-cpufreq? (s/n): " resp
        if [[ $resp == "s" ]]; then
            if apt-get install -y auto-cpufreq 2>/dev/null; then
                log OK "auto-cpufreq instalado via apt"
            else
                echo -e "${YLW}No disponible en apt, intentando via snap...${NC}"
                snap install auto-cpufreq && log OK "auto-cpufreq via snap" || log ERROR "Fallo instalando auto-cpufreq"
            fi
        fi
    else
        echo -e "${GRN}[✔]${NC} auto-cpufreq ya instalado."
    fi

    # Crear /etc/auto-cpufreq.conf si no existe
    if command -v auto-cpufreq &>/dev/null && [[ ! -f /etc/auto-cpufreq.conf ]]; then
        read -rp "¿Crear /etc/auto-cpufreq.conf con ajustes recomendados? (s/n): " resp
        if [[ $resp == "s" ]]; then
            create_autocpufreq_conf
        fi
    fi

    # Parámetros GRUB
    echo -e "\n${BOLD}── Parámetros del kernel (GRUB) ─────────────────────────────${NC}"
    GRUB_LINE=$(grep 'GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub | head -n1)
    CHANGED_GRUB=0

    if [[ ! $GRUB_LINE == *"nvidia-drm.modeset=1"* ]]; then
        read -rp "¿Añadir nvidia-drm.modeset=1 a GRUB? (necesario para NVIDIA) (s/n): " resp
        if [[ $resp == "s" ]]; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
            CHANGED_GRUB=1; log OK "nvidia-drm.modeset=1 añadido a GRUB"
        fi
    else
        echo -e "${GRN}[✔]${NC} nvidia-drm.modeset=1 ya presente."
    fi

    if [[ ! $GRUB_LINE == *"mem_sleep_default=deep"* ]]; then
        read -rp "¿Añadir mem_sleep_default=deep a GRUB? (deep sleep, ahorra batería en suspensión) (s/n): " resp
        if [[ $resp == "s" ]]; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="mem_sleep_default=deep /' /etc/default/grub
            CHANGED_GRUB=1; log OK "mem_sleep_default=deep añadido a GRUB"
        fi
    else
        echo -e "${GRN}[✔]${NC} mem_sleep_default=deep ya presente."
    fi

    if [[ $CHANGED_GRUB -eq 1 ]]; then
        update-grub && log OK "GRUB actualizado" || log ERROR "Fallo actualizando GRUB"
        echo -e "${YLW}[!] REINICIA el sistema para que los parámetros del kernel tengan efecto.${NC}"
    fi

    # sensors-detect
    if command -v sensors-detect &>/dev/null; then
        read -rp "¿Ejecutar sensors-detect para activar módulos de temperatura? (s/n): " resp
        [[ $resp == "s" ]] && sensors-detect --auto && log OK "sensors-detect completado"
    fi

    echo ""
    read -n1 -p "Instalación finalizada. Presiona una tecla..."
}

# ==============================================================================
# PERSISTENCIA: crear /etc/auto-cpufreq.conf
# ==============================================================================
create_autocpufreq_conf() {
    cat > /etc/auto-cpufreq.conf << 'EOF'
# auto-cpufreq configuration — generado por TUF Optimizer
# Documentación: https://github.com/AdnanHodzic/auto-cpufreq

[battery]
governor = powersave
energy_performance_preference = power
scaling_min_freq = 400000
scaling_max_freq = 1800000
turbo = never

[charger]
governor = performance
energy_performance_preference = performance
scaling_min_freq = 800000
scaling_max_freq = 4800000
turbo = auto
EOF
    log OK "/etc/auto-cpufreq.conf creado"
    echo -e "${GRN}[✔]${NC} /etc/auto-cpufreq.conf creado con ajustes recomendados."
}

# ==============================================================================
# PERSISTENCIA: instalar systemd service para brillo y Hz
# ==============================================================================
install_persist_service() {
    local mode="$1"   # "battery" o "performance"
    local hz="$2"
    local brightness="$3"

    cat > /etc/systemd/system/tuf-optimizer-restore.service << EOF
[Unit]
Description=TUF Optimizer — restaurar ajustes de pantalla
After=graphical.target

[Service]
Type=oneshot
User=$REAL_USER
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$REAL_HOME/.Xauthority"
ExecStart=/bin/bash -c 'xrandr --output $DISPLAY_NAME --rate $hz 2>/dev/null; brightnessctl s ${brightness}% 2>/dev/null'
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF
    systemctl daemon-reload
    systemctl enable tuf-optimizer-restore.service &>/dev/null
    log OK "Servicio tuf-optimizer-restore.service instalado (Hz=$hz, brillo=$brightness%)"
}

# ==============================================================================
# APLICAR MODO — función central reutilizada por Ahorro y Gaming
# ==============================================================================
apply_mode() {
    local mode="$1"
    local errors=0

    if [[ $mode == "battery" ]]; then
        echo -e "\n${BLU}Activando Modo Ultra Ahorro...${NC}"
        PROFILE="Quiet"; GPU_TARGET="integrated"; HZ="60.00"; BRIGHT="40"; BATT_LIM="80"; GOV_TARGET="powersave"
    else
        echo -e "\n${BLU}Activando Modo Gaming...${NC}"
        PROFILE="Performance"; GPU_TARGET="hybrid"; HZ="144.00"; BRIGHT="80"; BATT_LIM="100"; GOV_TARGET="performance"
    fi

    # Perfil ASUS
    if [[ $HAS_ASUSCTL -eq 1 ]]; then
        run_cmd "Perfil ASUS $PROFILE" asusctl profile -p "$PROFILE" || ((errors++))
        run_cmd "Límite batería $BATT_LIM%" asusctl -c "$BATT_LIM" || ((errors++))
        if [[ $mode == "battery" ]]; then
            # Sintaxis moderna asusctl para LEDs
            run_cmd "LED apagado" asusctl aura off 2>/dev/null || \
                run_cmd "LED apagado (legacy)" asusctl led-mode off 2>/dev/null || true
        else
            run_cmd "LED blanco" asusctl aura static --colour FFFFFF 2>/dev/null || \
                run_cmd "LED blanco (legacy)" asusctl led-mode static -c FFFFFF 2>/dev/null || true
        fi
    fi

    # GPU
    if [[ $HAS_SUPERGFX -eq 1 ]]; then
        run_cmd "GPU modo $GPU_TARGET" supergfxctl -m "$GPU_TARGET" || ((errors++))
    fi

    # auto-cpufreq
    if [[ $HAS_AUTOCPUFREQ -eq 1 ]]; then
        # auto-cpufreq no tiene --mode como flag; se controla via config + daemon
        if [[ $mode == "battery" ]]; then
            run_cmd "auto-cpufreq force powersave" auto-cpufreq --force=powersave 2>/dev/null || \
                run_cmd "gobernador powersave manual" bash -c \
                    "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > \$f; done"
        else
            run_cmd "auto-cpufreq force performance" auto-cpufreq --force=performance 2>/dev/null || \
                run_cmd "gobernador performance manual" bash -c \
                    "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > \$f; done"
        fi
    else
        # Sin auto-cpufreq: gobernador directo
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "$GOV_TARGET" > "$f" 2>/dev/null
        done
        log INFO "Gobernador CPU puesto a $GOV_TARGET manualmente"
    fi

    # Brillo
    if [[ $HAS_BRIGHTNESS -eq 1 ]]; then
        run_cmd "Brillo ${BRIGHT}%" brightnessctl s "${BRIGHT}%" || ((errors++))
    fi

    # Hz
    if [[ "$DISPLAY_NAME" != "No detectada" ]]; then
        # Verificar que el modo existe antes de aplicar
        if xrandr 2>/dev/null | grep -q "$HZ"; then
            run_cmd "Tasa refresco ${HZ}Hz" xrandr --output "$DISPLAY_NAME" --rate "$HZ" || ((errors++))
        else
            AVAILABLE_HZ=$(xrandr 2>/dev/null | grep -A10 "$DISPLAY_NAME" | grep -oP '\d+\.\d+' | sort -rn | head -n1)
            log WARN "${HZ}Hz no disponible en $DISPLAY_NAME, usando ${AVAILABLE_HZ}Hz"
            xrandr --output "$DISPLAY_NAME" --rate "$AVAILABLE_HZ" 2>/dev/null
        fi
    fi

    # --- PERSISTENCIA ---
    echo -e "\n${CYN}¿Hacer estos ajustes permanentes (se restauran al reiniciar)?${NC}"
    read -rp "  (s/n): " persist
    if [[ $persist == "s" ]]; then
        # auto-cpufreq: asegurar config correcta
        if [[ $HAS_AUTOCPUFREQ -eq 1 ]]; then
            [[ ! -f /etc/auto-cpufreq.conf ]] && create_autocpufreq_conf
            run_cmd "auto-cpufreq daemon habilitado" systemctl enable --now auto-cpufreq
        fi
        # Brillo y Hz via servicio systemd
        if [[ "$DISPLAY_NAME" != "No detectada" ]]; then
            install_persist_service "$mode" "$HZ" "$BRIGHT"
            echo -e "${GRN}[✔]${NC} Servicio systemd instalado para brillo y Hz."
        fi
        # Deep sleep permanente en GRUB (solo modo ahorro)
        if [[ $mode == "battery" ]]; then
            GRUB_LINE=$(grep 'GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub)
            if [[ ! $GRUB_LINE == *"mem_sleep_default=deep"* ]]; then
                read -rp "¿Añadir mem_sleep_default=deep al GRUB? (requiere reinicio) (s/n): " resp
                if [[ $resp == "s" ]]; then
                    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="mem_sleep_default=deep /' /etc/default/grub
                    update-grub && log OK "mem_sleep_default=deep añadido"
                fi
            fi
        fi
        echo -e "${GRN}[✔]${NC} Persistencia configurada."
    fi

    echo ""
    if [[ $errors -eq 0 ]]; then
        echo -e "${GRN}${BOLD}✔ Modo ${mode} aplicado sin errores.${NC}"
    else
        echo -e "${YLW}${BOLD}⚠ Modo ${mode} aplicado con $errors advertencia(s). Revisa el log: $LOG_FILE${NC}"
    fi
    sleep 2
}

# ==============================================================================
# MENÚ DE PERSONALIZACIÓN
# ==============================================================================
menu_personalizar() {
    while true; do
        clear
        echo -e "${BOLD}================================================================${NC}"
        echo -e "${BOLD}           CONFIGURACIÓN INDIVIDUAL DE PARÁMETROS${NC}"
        echo -e "${BOLD}================================================================${NC}"
        echo " 1. Perfil energía    (Quiet / Balanced / Performance)"
        echo " 2. Modo gráfica      (Integrated / Hybrid)"
        echo " 3. Tasa de refresco  (60Hz / Máximo disponible)"
        echo " 4. Brillo de pantalla"
        echo " 5. Límite de carga   (80% / 100%)"
        echo " 6. Modo de suspensión (s2idle / deep)"
        echo " 7. LED teclado       (ON / OFF)"
        echo " 8. Gobernador CPU    (powersave / performance / schedutil)"
        echo " 9. Volver"
        read -rp "Selecciona: " subopt

        case $subopt in
            1)
                if [[ $HAS_ASUSCTL -eq 0 ]]; then echo -e "${YLW}asusctl no disponible.${NC}"; sleep 1; continue; fi
                echo "1:Quiet  2:Balanced  3:Performance"
                read -rp "> " p
                case $p in
                    1) run_cmd "Perfil Quiet"       asusctl profile -p Quiet ;;
                    2) run_cmd "Perfil Balanced"     asusctl profile -p Balanced ;;
                    3) run_cmd "Perfil Performance"  asusctl profile -p Performance ;;
                esac ;;
            2)
                if [[ $HAS_SUPERGFX -eq 0 ]]; then echo -e "${YLW}supergfxctl no disponible.${NC}"; sleep 1; continue; fi
                echo "1:Integrated  2:Hybrid"
                read -rp "> " g
                [[ $g == "1" ]] && run_cmd "GPU Integrated" supergfxctl -m integrated
                [[ $g == "2" ]] && run_cmd "GPU Hybrid"     supergfxctl -m hybrid ;;
            3)
                [[ "$DISPLAY_NAME" == "No detectada" ]] && echo -e "${YLW}Pantalla no detectada.${NC}" && sleep 1 && continue
                echo "Hz disponibles en $DISPLAY_NAME:"
                xrandr 2>/dev/null | grep -A20 "$DISPLAY_NAME" | grep -oP '\d+\.\d+' | sort -rn | uniq | head -10 | nl
                read -rp "Introduce el Hz deseado (ej: 60.00): " hz
                run_cmd "Hz $hz" xrandr --output "$DISPLAY_NAME" --rate "$hz" ;;
            4)
                if [[ $HAS_BRIGHTNESS -eq 0 ]]; then echo -e "${YLW}brightnessctl no disponible.${NC}"; sleep 1; continue; fi
                read -rp "Brillo (0-100): " br
                run_cmd "Brillo ${br}%" brightnessctl s "${br}%" ;;
            5)
                if [[ $HAS_ASUSCTL -eq 0 ]]; then echo -e "${YLW}asusctl no disponible.${NC}"; sleep 1; continue; fi
                read -rp "Límite (40-100): " lim
                run_cmd "Límite batería $lim%" asusctl -c "$lim" ;;
            6)
                echo "1: s2idle (compatible)  2: deep (S3, más ahorro)"
                read -rp "> " s
                if [[ $s == "1" ]]; then
                    echo "s2idle" > /sys/power/mem_sleep && log OK "Suspensión: s2idle"
                elif [[ $s == "2" ]]; then
                    if grep -q "deep" /sys/power/mem_sleep 2>/dev/null; then
                        echo "deep" > /sys/power/mem_sleep && log OK "Suspensión: deep"
                    else
                        echo -e "${YLW}deep no soportado en tu kernel/hardware sin parámetro GRUB.${NC}"
                        log WARN "deep sleep no disponible"
                    fi
                fi ;;
            7)
                if [[ $HAS_ASUSCTL -eq 0 ]]; then echo -e "${YLW}asusctl no disponible.${NC}"; sleep 1; continue; fi
                echo "1: ON (blanco)  2: OFF"
                read -rp "> " l
                if [[ $l == "1" ]]; then
                    run_cmd "LED ON" asusctl aura static --colour FFFFFF 2>/dev/null || \
                        run_cmd "LED ON legacy" asusctl led-mode static -c FFFFFF 2>/dev/null
                elif [[ $l == "2" ]]; then
                    run_cmd "LED OFF" asusctl aura off 2>/dev/null || \
                        run_cmd "LED OFF legacy" asusctl led-mode off 2>/dev/null
                fi ;;
            8)
                echo "1: powersave  2: performance  3: schedutil (recomendado en AMD)"
                read -rp "> " gov
                case $gov in
                    1) GOV="powersave" ;;
                    2) GOV="performance" ;;
                    3) GOV="schedutil" ;;
                    *) echo "Opción no válida"; sleep 1; continue ;;
                esac
                for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo "$GOV" > "$f" 2>/dev/null
                done
                log OK "Gobernador CPU: $GOV"
                echo -e "${GRN}Gobernador puesto a $GOV${NC}" ;;
            9) break ;;
        esac
        echo -e "${GRN}Ajuste aplicado.${NC}"; sleep 1
    done
}

# ==============================================================================
# VISOR DE LOG / DEBUG
# ==============================================================================
show_debug() {
    clear
    echo -e "${BOLD}================================================================${NC}"
    echo -e "${BOLD}               VISOR DE LOG / DEBUG${NC}"
    echo -e "${BOLD}================================================================${NC}"
    echo -e " Log: ${CYN}$LOG_FILE${NC}"
    echo -e " Debug en pantalla: ${YLW}$([ $DEBUG_MODE -eq 1 ] && echo 'ACTIVADO' || echo 'DESACTIVADO')${NC}"
    echo ""
    echo "1. Ver últimas 40 líneas del log"
    echo "2. Ver log completo (paginado)"
    echo "3. $([ $DEBUG_MODE -eq 1 ] && echo 'Desactivar' || echo 'Activar') debug en pantalla"
    echo "4. Limpiar log"
    echo "5. Volver"
    read -rp "Selecciona: " dopt
    case $dopt in
        1) echo ""; tail -40 "$LOG_FILE" 2>/dev/null || echo "(log vacío)"; echo ""; read -n1 -p "Tecla para volver..." ;;
        2) less "$LOG_FILE" 2>/dev/null || echo "(log vacío)"; read -n1 -p "Tecla para volver..." ;;
        3) [[ $DEBUG_MODE -eq 1 ]] && DEBUG_MODE=0 || DEBUG_MODE=1
           echo -e "${GRN}Debug $([ $DEBUG_MODE -eq 1 ] && echo 'activado' || echo 'desactivado').${NC}"; sleep 1 ;;
        4) > "$LOG_FILE"; echo -e "${GRN}Log limpiado.${NC}"; sleep 1 ;;
    esac
}

# ==============================================================================
# AYUDA
# ==============================================================================
show_help() {
    clear
    echo -e "${BOLD}================================================================${NC}"
    echo -e "${BOLD}                 GUÍA DE AYUDA — TUF OPTIMIZER${NC}"
    echo -e "${BOLD}================================================================${NC}"
    cat << 'EOF'

 CHECKLIST:    Solo diagnostica, no toca nada. Muestra qué falta.

 INSTALAR:     Instala herramientas con confirmación una a una.
               También repara GRUB y crea /etc/auto-cpufreq.conf.

 ULTRA AHORRO: Perfil Quiet + GPU integrada + 60Hz + brillo bajo
               + límite batería 80% + gobernador powersave.
               Pregunta si hacerlo permanente.

 GAMING:       Perfil Performance + GPU híbrida + Hz máximo
               + brillo alto + turbo activado.
               Pregunta si hacerlo permanente.

 PERSONALIZAR: Cambia cada parámetro por separado.

 DEBUG/LOG:    Ver qué ha hecho el script y si algo falló.
               Activa mensajes en tiempo real.

 PERSISTENCIA: Los cambios de asusctl/supergfxctl persisten solos
               via sus daemons. El brillo y Hz se guardan via un
               servicio systemd que crea el script.
               auto-cpufreq persiste via /etc/auto-cpufreq.conf.

 COMPATIBILIDAD:
   - ASUS TUF F15/F17, A15/A17    → compatibilidad total
   - ASUS ROG Zephyrus G14/G15    → compatibilidad total
   - ASUS ROG Strix G15/G17       → compatibilidad total
   - Otros portátiles Linux        → funciona sin asusctl/supergfx
     (gobernador CPU, brillo, Hz, batería básica, temperaturas)
   - VivoBook/ZenBook sin dGPU    → funciona parcialmente

EOF
    read -n1 -p "Presiona una tecla para volver..."
}

# ==============================================================================
# BUCLE PRINCIPAL
# ==============================================================================
touch "$LOG_FILE" 2>/dev/null
log INFO "=== TUF Optimizer iniciado (usuario: $REAL_USER) ==="

while true; do
    get_summary
    echo " 1. CHECKLIST      — Diagnóstico (solo lectura)"
    echo " 2. INSTALAR       — Instalar herramientas y reparar"
    echo " 3. ULTRA AHORRO   — Batería máxima"
    echo " 4. GAMING         — Potencia máxima"
    echo " 5. PERSONALIZAR   — Ajustes individuales"
    echo " 6. DEBUG / LOG    — Ver registro del script"
    echo " 7. AYUDA"
    echo " 8. Salir"
    echo ""
    read -rp " Selección: " opt

    case $opt in
        1) run_check ;;
        2) run_install ;;
        3) apply_mode "battery" ;;
        4) apply_mode "performance" ;;
        5) menu_personalizar ;;
        6) show_debug ;;
        7) show_help ;;
        8) log INFO "=== TUF Optimizer cerrado ==="; exit 0 ;;
        *) echo -e "${YLW}Opción no válida.${NC}"; sleep 1 ;;
    esac
done
