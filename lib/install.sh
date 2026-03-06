#!/bin/bash
# lib/install.sh — Diagnóstico, instalación y persistencia

run_check() {
    clear
    echo -e "${BOLD}${BLU}   CHECKLIST — DIAGNÓSTICO (solo lectura)${NC}\n"
    local issues=0
    _chk() {
        if [[ "$2" == "1" ]]; then echo -e " ${GRN}[✔]${NC} $1"
        else echo -e " ${RED}[✘]${NC} $1"; [[ -n "$3" ]] && echo -e "      ${YLW}→ $3${NC}"; ((issues++)); fi
    }
    _chk "sensors" "$(command -v sensors &>/dev/null && echo 1 || echo 0)" "apt install lm-sensors"
    _chk "upower" "$(command -v upower &>/dev/null && echo 1 || echo 0)" "apt install upower"
    _chk "asusctl" "$HAS_ASUSCTL" "Ver opción Instalar"
    _chk "supergfxctl" "$HAS_SUPERGFX" "Ver opción Instalar"
    
    [[ $issues -eq 0 ]] && echo -e "\n${GRN}${BOLD}Sistema OK.${NC}" || echo -e "\n${YLW}${BOLD}$issues problemas encontrados.${NC}"
    read -n1 -p "Presiona una tecla..."
}

run_install() {
    clear
    echo -e "${BOLD}${YLW}   INSTALAR / REPARAR${NC}\n"
    _ask() {
        if ! dpkg -s "$1" &>/dev/null; then
            read -rp "[?] ¿Instalar $2 ($1)? (s/n): " r
            [[ $r == "s" ]] && apt-get install -y "$1" && return 0 || return 1
        fi
        return 0
    }
    _ask "lm-sensors" "Sensores"; _ask "upower" "Batería"; _ask "brightnessctl" "Brillo"
    
    if [[ $HAS_ASUSCTL -eq 0 ]]; then
        read -rp "[?] ¿Instalar asusctl/supergfxctl (Rust)? (s/n): " r
        [[ $r == "s" ]] && install_asus_tools_source_rust
    fi
    read -n1 -p "Finalizado. Presiona una tecla..."
}

install_persist_service() {
    local mode="$1"; local brightness="$2"; local cmds=""
    for disp in "${CONNECTED_DISPLAYS[@]}"; do
        local n=$(echo "$disp" | cut -d: -f1); local r=$(echo "$disp" | cut -d: -f2)
        local hz=$(get_target_hz "$n" "$mode")
        cmds+="xrandr --output $n --mode $r --rate ${hz:-60.00} 2>/dev/null; "
    done
    cat > /etc/systemd/system/tuf-optimizer-restore.service << EOF
[Unit]
Description=TUF Optimizer — restaurar ajustes de pantalla
After=graphical.target
[Service]
Type=oneshot
User=$REAL_USER
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$REAL_HOME/.Xauthority"
ExecStart=/bin/bash -c '$cmds brightnessctl s ${brightness}% 2>/dev/null'
RemainAfterExit=yes
[Install]
WantedBy=graphical.target
EOF
    systemctl daemon-reload && systemctl enable tuf-optimizer-restore.service &>/dev/null
}

install_asus_tools_source_rust() {
    echo -e "${CYN}Instalando Rust y dependencias...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    apt-get install -y gcc pkg-config libasound2-dev cmake build-essential libudev-dev libseat-dev libinput-dev libxkbcommon-dev libgbm-dev
    local dir="/tmp/asus_build_$(date +%s)"
    mkdir -p "$dir" && cd "$dir"
    git clone https://gitlab.com/asus-linux/asusctl.git && cd asusctl && make install && cd ..
    git clone https://gitlab.com/asus-linux/supergfxctl.git && cd supergfxctl && make install
    systemctl enable asusd supergfxd --now
    usermod -aG users "$REAL_USER"
}

create_autocpufreq_conf() {
    cat > /etc/auto-cpufreq.conf << EOF
[battery]
governor = powersave
turbo = never
[charger]
governor = performance
turbo = auto
EOF
}
