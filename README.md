# ⚡ TUF Optimizer v2.0

Gestor de energía interactivo para portátiles ASUS TUF y ROG. Optimiza el rendimiento, el consumo de batería y la configuración multi-monitor de forma centralizada.

## 🚀 ¿Qué es y qué hace?
TUF Optimizer es un script Bash que permite alternar entre perfiles de energía, modos de GPU y tasas de refresco con un solo menú. Diseñado para ASUS, pero con soporte básico para cualquier portátil Linux.

## 🛠️ Herramientas necesarias
- **ASUS Control**: `asusctl`, `supergfxctl` (perfiles, GPU, batería).
- **Energía**: `auto-cpufreq` (gobernador CPU).
- **Pantalla**: `xrandr`, `brightnessctl`.
- **Diagnóstico**: `lm-sensors`, `upower`.

## 🖥️ Equipos compatibles
- **ASUS TUF / ROG**: Soporte total (F15, A15, Zephyrus, Strix, etc).
- **Otros portátiles**: Soporte parcial (gobernador CPU, brillo, Hz, batería básica).

## 🌙 Modos principales
- **🔋 ULTRA AHORRO**: Perfil Silencioso, GPU integrada, 60Hz, brillo bajo y límite de batería (80%).
- **🎮 GAMING**: Perfil Rendimiento, elección entre GPU Híbrida o Dedicada, Hz máximo en todas las pantallas y turbo activo.
- **🖥️ MULTI-MONITOR**: Detección dinámica de todas las pantallas conectadas y aplicación de refresco independiente por monitor.

## 📥 Instalación rápida
1. **Clonar**: `git clone https://github.com/glmbxecurity/tuf_optimizer_v2.git`
2. **Permisos**: `chmod +x ASUS_TUF_OPTIMIZER_V2.sh`
3. **Ejecutar**: `sudo ./ASUS_TUF_OPTIMIZER_V2.sh`
   - El script inicia en **modo debug** por defecto para mostrar el progreso de los comandos.
   - Para ejecutar sin logs en pantalla: `sudo ./ASUS_TUF_OPTIMIZER_V2.sh --no-debug`

> [!NOTE]
> Usa la opción **2. INSTALAR** del menú para configurar automáticamente las dependencias y el repositorio de ASUS.
