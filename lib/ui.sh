#!/bin/bash
# lib/ui.sh — Interfaz de usuario, resúmenes y menús

get_summary() {
    detect_display; detect_gpu; check_tools; clear
    echo -e "${BOLD}================================================================${NC}"
    echo -e " ${BOLD}TUF OPTIMIZER v2.0  |  $(date '+%d/%m/%Y %H:%M')${NC}"
    echo -e "${BOLD}================================================================${NC}"
    
    # CPU & GPUs
    echo -e " ${CYN}CPU:${NC}      $CPU_MODEL"
    local g_idx=1
    for gpu in "${DETECTED_GPUS[@]}"; do
        echo -e " ${CYN}GPU $g_idx:${NC}    $gpu"
        ((g_idx++))
    done
    echo -e " ${CYN}Modo GPU:${NC} ${YLW}$GPU_MODE${NC}"
    
    # Perfiles, Batería & Gobernador
    local PROFILE="N/A"; local BATT_LIM="N/A"
    if [[ $HAS_ASUSCTL -eq 1 ]]; then
        PROFILE=$(asusctl profile -p 2>/dev/null | tail -n1 | awk '{print $NF}')
        BATT_LIM=$(cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null)
    fi
    local GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    echo -e " ${CYN}Perfil:${NC}      ${YLW}${PROFILE:-N/A}${NC}  |  ${CYN}Límite Bat:${NC} ${YLW}${BATT_LIM:-100}%${NC}"
    echo -e " ${CYN}Gobernador:${NC}  ${YLW}${GOV:-N/A}${NC}"

    # Teclado & Sueño
    local KBD_B="OFF"; local SLEEP="OFF"
    if [[ $HAS_ASUSCTL -eq 1 ]]; then
        # Detectar brillo actual: 0=OFF, >0=ON
        local k_val=$(asusctl -s 2>/dev/null | grep "Keyboard Brightness" | awk '{print $NF}')
        [[ "$k_val" != "Off" && "$k_val" != "0" && -n "$k_val" ]] && KBD_B="ON"
        
        asusctl led-pow-1 --help 2>&1 | grep -q "sleep" && SLEEP="Opt Available"
    fi
    echo -e " ${CYN}Teclado LED:${NC} ${YLW}${KBD_B}${NC}  |  ${CYN}Modo Sueño:${NC}  ${YLW}${SLEEP}${NC}"
    
    # Pantallas
    local i=1
    for disp in "${CONNECTED_DISPLAYS[@]}"; do
        local n=$(echo "$disp" | cut -d: -f1)
        local hz=$(xrandr 2>/dev/null | sed -n "/^$n connected/,/^[^ ]/p" | grep '\*' | awk '{for(i=1;i<=NF;i++) if($i~/\*/) {print $i; break}}' | sed 's/[^0-9.]//g')
        echo -e " ${CYN}Pantalla $i:${NC}  ${YLW}${n}${NC}  |  ${CYN}Hz:${NC} ${YLW}${hz:-60.00}${NC}"
        ((i++))
    done

    # Brillo
    if [[ $HAS_BRIGHTNESS -eq 1 ]]; then
        local cur=$(brightnessctl g); local max=$(brightnessctl m)
        echo -e " ${CYN}Brillo:${NC}      ${YLW}$(( 100 * cur / max ))%${NC}"
    fi
    
    echo -e "${BOLD}----------------------------------------------------------------${NC}"
    
    # Batería (upower)
    if [[ $HAS_UPOWER -eq 1 ]]; then
        local BATT_PATH=$(upower -e | grep battery | head -n1)
        if [[ -n "$BATT_PATH" ]]; then
            local PCT=$(upower -i "$BATT_PATH" | grep percentage | awk '{print $2}')
            local CAP=$(upower -i "$BATT_PATH" | grep capacity | awk '{print $2}' | sed 's/[,.].*//')
            local STATE=$(upower -i "$BATT_PATH" | grep state | awk '{print $2}' | sed 's/fully-charged/Cargada/; s/discharging/Descargando/; s/charging/Cargando/')
            local RATE=$(upower -i "$BATT_PATH" | grep energy-rate | awk '{print $2}' | sed 's/[,.].*//')
            local UNIT=$(upower -i "$BATT_PATH" | grep energy-rate | awk '{print $3}')
            local CUR_WH=$(upower -i "$BATT_PATH" | grep "energy:" | awk '{print $2" "$3}')
            local FULL_WH=$(upower -i "$BATT_PATH" | grep "energy-full:" | awk '{print $2" "$3}')
            local DES_WH=$(upower -i "$BATT_PATH" | grep "energy-full-design:" | awk '{print $2" "$3}')

            echo -e " ${CYN}Batería:${NC}  ${YLW}$PCT${NC} ($STATE) ${CYN}Salud:${NC} ${YLW}${CAP:-100}%${NC} | ${CYN}Consumo:${NC} ${YLW}${RATE:-0} ${UNIT:-W}${NC}"
            echo -e " ${CYN}Detalle:${NC}  Actual: ${YLW}${CUR_WH:-N/A}${NC}  Full: ${YLW}${FULL_WH:-N/A}${NC}  Diseño: ${YLW}${DES_WH:-N/A}${NC}"
        fi
    fi

    # Temperaturas
    if [[ $HAS_SENSORS -eq 1 ]]; then
        local CPU_T=$(sensors 2>/dev/null | grep -E 'Package|Tctl' | head -n1 | awk '{print $4}' | grep -oP '\+\d+\.\d+°C')
        local GPU_T=$(sensors 2>/dev/null | grep -i 'edge\|temp1' | tail -n1 | awk '{print $2}' | grep -oP '\+\d+\.\d+°C')
        
        # Fans (RPM)
        local ASUS_HWMON
        ASUS_HWMON=$(grep -l "asus" /sys/class/hwmon/hwmon*/name | head -n1 | xargs dirname 2>/dev/null)
        if [[ -d "$ASUS_HWMON" ]]; then
            local CPU_RPM=$(cat "$ASUS_HWMON/fan1_input" 2>/dev/null || echo 0)
            local GPU_RPM=$(cat "$ASUS_HWMON/fan2_input" 2>/dev/null || echo 0)
        else
            local CPU_RPM="N/A"; local GPU_RPM="N/A"
        fi

        echo -e " ${CYN}Temps:${NC}    CPU: ${YLW}${CPU_T:-N/A}${NC}  GPU: ${YLW}${GPU_T:-N/A}${NC}"
        echo -e " ${CYN}Fans:${NC}     CPU: ${YLW}${CPU_RPM} RPM${NC}  GPU: ${YLW}${GPU_RPM} RPM${NC}"
    fi

    echo -e "${BOLD}================================================================${NC}"
}

menu_personalizar() {
    while true; do
        clear
        echo -e "${BOLD}================================================================${NC}"
        echo -e "           ${BOLD}AJUSTES INDIVIDUALES${NC}"
        echo -e "${BOLD}================================================================${NC}"
        echo " 1. Perfil energía (Quiet-Silent/Balanced/Performance)"
        echo " 2. Modo gráfica   (Integrated/Hybrid)"
        echo " 3. Límite carga   (20-100%)"
        echo " 4. Brillo pantalla"
        echo " 5. Refresco (Hz)  - Granular por pantalla"
        echo " 6. Teclado LED    - Brillo (Off/Low/Med/High)"
        echo " 7. Gobernador CPU - (powersave/performance)"
        echo " 8. Modo Sueño LED - (Toggle animations)"
        echo " 9. Volver"
        read -rp " Selección: " o
        case $o in
            1) [[ $HAS_ASUSCTL -eq 1 ]] && asusctl profile -n ;;
            2) [[ $HAS_SUPERGFX -eq 1 ]] && { 
                local current_m=$(supergfxctl -g)
                if [[ "$current_m" == "Integrated" ]]; then
                    supergfxctl -m Hybrid && log INFO "Cambiado a modo Hybrid"
                else
                    supergfxctl -m Integrated && log INFO "Cambiado a modo Integrated"
                fi
            } ;;
            3) [[ $HAS_ASUSCTL -eq 1 ]] && read -rp "Límite (20-100): " l && asusctl -c "$l" ;;
            4) [[ $HAS_BRIGHTNESS -eq 1 ]] && read -rp "Brillo %: " b && brightnessctl s "$b%" ;;
            5) menu_hz_granular ;;
            6) [[ $HAS_ASUSCTL -eq 1 ]] && menu_led_keyboard ;;
            7) menu_governor_granular ;;
            8) [[ $HAS_ASUSCTL -eq 1 ]] && menu_sleep_granular ;;
            9) break ;;
        esac
    done
}

menu_hz_granular() {
    clear
    echo "--- Selecciona Pantalla ---"
    local idx=1
    for disp in "${CONNECTED_DISPLAYS[@]}"; do
        echo " $idx. $(echo "$disp" | cut -d: -f1)"
        ((idx++))
    done
    read -rp " Selección: " sidx
    local target=$(echo "${CONNECTED_DISPLAYS[$((sidx-1))]}" | cut -d: -f1)
    local res=$(echo "${CONNECTED_DISPLAYS[$((sidx-1))]}" | cut -d: -f2)
    [[ -z "$target" ]] && return

    echo "--- Selecciona Refresh Rate para $target ---"
    local rates=($(xrandr 2>/dev/null | sed -n "/^$target connected/,/^[^ ]/p" | grep -A10 "$res" | head -n11 | grep -oP '\d+\.\d+' | sort -un))
    local ridx=1
    for r in "${rates[@]}"; do
        echo " $ridx. $r Hz"
        ((ridx++))
    done
    read -rp " Selección: " sridx
    local rate=${rates[$((sridx-1))]}
    [[ -n "$rate" ]] && run_cmd "Ajuste Hz $target" xrandr --output "$target" --mode "$res" --rate "$rate"
}

menu_led_keyboard() {
    echo "--- Brillo Teclado ---"
    echo " 1. Off | 2. Low | 3. Med | 4. High"
    read -rp " Selección: " l
    case $l in
        1) asusctl -k off ;;
        2) asusctl -k low ;;
        3) asusctl -k med ;;
        4) asusctl -k high ;;
    esac
}

menu_governor_granular() {
    echo "--- Gobernador CPU ---"
    local govs=($(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors))
    local idx=1
    for g in "${govs[@]}"; do
        echo " $idx. $g"
        ((idx++))
    done
    read -rp " Selección: " gidx
    local gov=${govs[$((gidx-1))]}
    if [[ -n "$gov" ]]; then
        bash -c "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo $gov > \$f; done" 2>/dev/null
        log INFO "Gobernador cambiado a $gov"
    fi
}

menu_sleep_granular() {
    echo "--- Modo Sueño (LED Animations) ---"
    echo " 1. Activar Animaciones (Sleep/Boot)"
    echo " 2. Desactivar Animaciones"
    read -rp " Selección: " s
    case $s in
        1) asusctl led-pow-1 -s true -b true ;;
        2) asusctl led-pow-1 -s false -b false ;;
    esac
}

show_debug() {
    clear; echo -e "${BOLD}   VISOR DE LOG (últimas 40 líneas)${NC}"; echo "----------------------------------------------------------------"
    tail -40 "$LOG_FILE" 2>/dev/null || echo "Log vacío."
    echo "----------------------------------------------------------------"
    read -n1 -p "Pulsa una tecla para volver..."
}

show_help() {
    clear
    echo -e "${BOLD}AYUDA — TUF OPTIMIZER v2.0${NC}"
    echo -e "${BOLD}================================================================${NC}"
    echo -e "${CYN}HERRAMIENTAS Y DEPENDENCIAS:${NC}"
    echo " • asusctl:       Perfiles de energía y límite de carga."
    echo " • supergfxctl:   Gestión de GPU (Nvidia/Intel)."
    echo " • auto-cpufreq:  Optimización del procesador y gobernadores."
    echo " • brightnessctl: Control de brillo y luz del teclado."
    echo " • upower/sensors: Estado de batería, temps y ventiladores."
    echo " • xrandr:        Ajuste de Hz de la pantalla."
    echo ""
    echo -e "${CYN}MODOS DE ENERGÍA:${NC}"
    echo -e " ${YLW}1. ULTRA AHORRO (Batería):${NC}"
    echo "    - Perfil Silencioso (Silent/Quiet), GPU Integrada, 30% brillo."
    echo "    - Refresco al mínimo (60Hz), límite batería 80%."
    echo "    - CPU en modo ahorro, teclado y animaciones LED apagados."
    echo ""
    echo -e " ${YLW}2. GAMING (Rendimiento):${NC}"
    echo "    - Perfil Rendimiento, GPU Híbrida, 100% brillo."
    echo "    - Refresco al máximo (144Hz+), límite batería 100%."
    echo "    - CPU en máximo rendimiento, teclado LED al máximo."
    echo ""
    echo -e "${BOLD}================================================================${NC}"
    read -n1 -p "Pulsa una tecla para volver..."
}
