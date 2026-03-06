#!/bin/bash
# lib/detect.sh — Detección de hardware, GPU y pantallas

# --- DETECCIÓN DE HARDWARE ---
CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)

# Herramientas presentes
HAS_ASUSCTL=0; HAS_SUPERGFX=0; HAS_AUTOCPUFREQ=0
HAS_BRIGHTNESS=0; HAS_SENSORS=0; HAS_UPOWER=0; HAS_POWERSTAT=0

check_tools() {
    command -v asusctl       &>/dev/null && HAS_ASUSCTL=1
    command -v supergfxctl   &>/dev/null && HAS_SUPERGFX=1
    command -v auto-cpufreq  &>/dev/null && HAS_AUTOCPUFREQ=1
    command -v brightnessctl &>/dev/null && HAS_BRIGHTNESS=1
    command -v sensors       &>/dev/null && HAS_SENSORS=1
    command -v upower        &>/dev/null && HAS_UPOWER=1
    command -v powerstat     &>/dev/null && HAS_POWERSTAT=1
    log INFO "Herramientas: asusctl=$HAS_ASUSCTL supergfx=$HAS_SUPERGFX autocpufreq=$HAS_AUTOCPUFREQ sensors=$HAS_SENSORS"
}

detect_gpu() {
    DETECTED_GPUS=()
    while read -r line; do
        DETECTED_GPUS+=("$line")
    done < <(lspci | grep -i 'vga\|3d\|display' | sed 's/.*: //')
    
    if command -v supergfxctl &>/dev/null; then
        local raw_mode
        raw_mode=$(supergfxctl -g 2>/dev/null)
        case "$raw_mode" in
            "Integrated") GPU_MODE="Intel" ;;
            "Hybrid")     GPU_MODE="Both (Intel + Nvidia)" ;;
            "Dedicated"|"Discrete"|"AsusMuxDgpu")  GPU_MODE="Nvidia" ;;
            "Vfio")       GPU_MODE="Nvidia (VFIO)" ;;
            *)            GPU_MODE="$raw_mode" ;;
        esac
    else
        GPU_MODE="N/A (sin supergfxctl)"
        [[ -d /sys/class/drm ]] && GPU_MODE="Detectada via DRM"
    fi
}

detect_display() {
    CONNECTED_DISPLAYS=()
    while read -r line; do
        local name res
        name=$(echo "$line" | awk '{print $1}')
        res=$(echo "$line" | grep -oP '\d+x\d+' | head -n1)
        if [[ -n "$name" && -n "$res" ]]; then
            CONNECTED_DISPLAYS+=("$name:$res")
        fi
    done < <(xrandr 2>/dev/null | grep " connected")
    
    log INFO "Pantallas detectadas: ${CONNECTED_DISPLAYS[*]}"
}
