#!/bin/bash
# lib/power.sh — Modos de energía, perfiles y refresco de pantalla

get_target_hz() {
    local screen="$1"; local mode="$2"; local res="$3"
    local available_hz
    # Obtener Hz disponibles para la resolución específica
    # Intentamos capturar tanto rates decimales como enteros
    available_hz=$(xrandr 2>/dev/null | sed -n "/^$screen connected/,/^[^ ]/p" | grep -A10 "$res" | head -n11 | grep -oP '\d+(\.\d+)?(?=\*|\s)' | sort -un)
    
    if [[ -z "$available_hz" ]]; then
        # Fallback si falla el parsing
        [[ "$mode" == "battery" ]] && echo "60.00" || echo "144.00"
        return
    fi

    if [[ "$mode" == "battery" ]]; then
        # En modo batería, intentar 60.00 o 60, si no 59.94, si no el mínimo
        if echo "$available_hz" | grep -qE "^60(\.00)?$"; then
            echo "60.00"
        elif echo "$available_hz" | grep -qE "^59\.94$"; then
            echo "59.94"
        else
            local min=$(echo "$available_hz" | head -n1)
            [[ ! "$min" =~ \. ]] && echo "${min}.00" || echo "$min"
        fi
    else
        # En modo gaming, el máximo
        local max=$(echo "$available_hz" | tail -n1)
        [[ ! "$max" =~ \. ]] && echo "${max}.00" || echo "$max"
    fi
}

apply_mode() {
    local mode="$1"
    local errors=0

    if [[ $mode == "battery" ]]; then
        echo -e "\n${BLU}Activando Modo Ultra Ahorro...${NC}"
        PROFILE="Quiet"
        # Algunos modelos usan 'Silent' en vez de 'Quiet'
        asusctl profile -p | grep -qi "Silent" && PROFILE="Silent"
        
        GPU_TARGET="integrated"; BRIGHT="30"; BATT_LIM="80"; GOV_TARGET="powersave"
    else
        echo -e "\n${BLU}Activando Modo Gaming...${NC}"
        GPU_TARGET="hybrid"
        PROFILE="Performance"; BRIGHT="100"; BATT_LIM="100"; GOV_TARGET="performance"
    fi

    # Perfil ASUS
    if [[ $HAS_ASUSCTL -eq 1 ]]; then
        run_cmd "Perfil ASUS $PROFILE" asusctl profile -P "$PROFILE" || ((errors++))
        run_cmd "Límite batería $BATT_LIM%" asusctl -c "$BATT_LIM" || ((errors++))
        
        if [[ $mode == "battery" ]]; then
            run_cmd "Apagar LED Teclado" asusctl -k off 2>/dev/null
            run_cmd "Desactivar animaciones LED" asusctl led-pow-1 -s false -b false 2>/dev/null
        else
            run_cmd "Luz Teclado MAX" asusctl -k high 2>/dev/null
            run_cmd "Activar animaciones LED" asusctl led-pow-1 -s true -b true 2>/dev/null
        fi
    fi

    # GPU
    if [[ $HAS_SUPERGFX -eq 1 ]]; then
        local GFX_VAL
        case "$GPU_TARGET" in
            "integrated") GFX_VAL="Integrated" ;;
            *) GFX_VAL="Hybrid" ;;
        esac
        run_cmd "GPU modo $GFX_VAL" supergfxctl -m "$GFX_VAL" || ((errors++))
        # Pequeña pausa para que xrandr se asiente tras el cambio de GPU
        sleep 1
    fi

    # CPU Governor
    [[ $HAS_AUTOCPUFREQ -eq 1 ]] && run_cmd "auto-cpufreq force $GOV_TARGET" auto-cpufreq --force="$GOV_TARGET" 2>/dev/null
    bash -c "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo $GOV_TARGET > \$f; done" 2>/dev/null

    # Pantallas
    for disp in "${CONNECTED_DISPLAYS[@]}"; do
        local name=$(echo "$disp" | cut -d: -f1); local res=$(echo "$disp" | cut -d: -f2)
        local hz=$(get_target_hz "$name" "$mode" "$res")
        # Asegurar formato 60.00 si no tiene decimales
        [[ ! "$hz" =~ \. ]] && hz="${hz}.00"
        run_cmd "Refresco $name (${hz}Hz)" xrandr --output "$name" --mode "$res" --rate "$hz" || ((errors++))
    done

    # Brillo
    [[ $HAS_BRIGHTNESS -eq 1 ]] && run_cmd "Brillo ${BRIGHT}%" brightnessctl s "${BRIGHT}%" || ((errors++))

    # Persistencia
    echo -e "\n${CYN}¿Hacer estos ajustes permanentes? (s/n):${NC} " && read -rp "> " p
    if [[ $p == "s" ]]; then
        [[ $HAS_AUTOCPUFREQ -eq 1 ]] && systemctl enable --now auto-cpufreq &>/dev/null
        install_persist_service "$mode" "$BRIGHT"
        echo -e "${GRN}[✔] Persistencia configurada.${NC}"
    fi

    [[ $errors -eq 0 ]] && echo -e "${GRN}${BOLD}✔ Modo $mode aplicado.${NC}" && prompt_logout || \
                           echo -e "${YLW}${BOLD}⚠ Modo $mode con $errors avisos. Revisa log.${NC}"
    sleep 2
}

prompt_logout() {
    echo -e "\n${YLW}${BOLD}[!] ADVERTENCIA: Cerrar sesión para aplicar cambios al 100%.${NC}"
    read -rp "¿Cerrar sesión ahora? (s/n): " resp
    if [[ $resp == "s" ]]; then
        gnome-session-quit --logout --no-prompt 2>/dev/null || \
        loginctl terminate-user "$REAL_USER" 2>/dev/null || \
        pkill -u "$REAL_USER"
    fi
}
