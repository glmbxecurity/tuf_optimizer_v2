#!/bin/bash
# lib/utils.sh — Utilidades, colores y logs

# --- COLORES ---
RED='\e[31m'; GRN='\e[32m'; YLW='\e[33m'; BLU='\e[34m'; CYN='\e[36m'; NC='\e[0m'; BOLD='\e[1m'

# --- ARCHIVO DE LOG ---
LOG_FILE="/var/log/tuf-optimizer.log"
DEBUG_MODE=0  # Se cambia en el inicio o via menú

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
