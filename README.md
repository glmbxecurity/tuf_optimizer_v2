# ⚡ TUF Optimizer v2.0

> Gestor de energía interactivo para portátiles ASUS TUF / ROG — con soporte parcial para cualquier portátil Linux.

![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-13%2B-A81D33?style=flat-square&logo=debian&logoColor=white)
![License](https://img.shields.io/badge/Licencia-MIT-blue?style=flat-square)
![Root](https://img.shields.io/badge/Requiere-root%20%2F%20sudo-critical?style=flat-square)

---

## ¿Qué es TUF Optimizer?

TUF Optimizer es un script Bash interactivo diseñado para gestionar de forma centralizada todos los parámetros de rendimiento y consumo energético de un portátil Linux. Nació para los modelos ASUS TUF Gaming y ROG, pero incluye soporte degradado para cualquier portátil con Linux que no disponga de las herramientas ASUS específicas.

El objetivo es sencillo: desde un solo menú, con un solo comando, puedes pasar del modo de máximo ahorro de batería al modo gaming, ver el estado real del sistema, diagnosticar problemas de configuración e instalar las herramientas necesarias — todo con persistencia real entre reinicios.

![image](optimizer.png)
---

## ✨ Características principales

- **Modo Ultra Ahorro** — minimiza el consumo: GPU integrada, 60 Hz, brillo bajo, límite de carga al 80%, gobernador `powersave`
- **Modo Gaming** — máximo rendimiento: GPU híbrida, Hz máximo, turbo activo, gobernador `performance`
- **Checklist de diagnóstico** — solo lectura, detecta herramientas faltantes, parámetros de kernel incorrectos y configuraciones ausentes sin modificar nada
- **Instalador separado** — instala y repara con confirmación individual en cada paso
- **Persistencia real** — los cambios sobreviven al reinicio mediante servicios `systemd`, `auto-cpufreq.conf` y parámetros GRUB
- **Resumen del sistema en tiempo real** — batería (%, W/h, vatios de consumo, tiempo restante), temperaturas de CPU/GPU/NVMe, gobernador activo, Hz y modo de gráfica
- **Sistema de log** — todas las acciones se registran en `/var/log/tuf-optimizer.log`
- **Modo debug** — activable desde el menú o con `--debug`, muestra feedback en tiempo real de cada operación
- **Compatibilidad amplia** — funciona en hardware sin `asusctl` ni `supergfxctl`, adaptando las funciones disponibles al hardware detectado

---

## 📋 Menú principal

```
================================================================
     TUF OPTIMIZER v2.0  |  06/03/2026 14:32
================================================================
 CPU:      AMD Ryzen 7 6800H with Radeon Graphics
 GPU:      NVIDIA GeForce RTX 3050 Mobile
 Modo GPU: Hybrid
 Perfil:   Balanced
 Pantalla: eDP-1  |  Hz: 144.00
 Gobernador CPU: powersave
 Batería: 78%  Estado: Discharging
 Energía restante: 45.3 Wh
 Consumo actual:   12.4 W
 Tiempo restante hasta descarga: 3,5 horas
----------------------------------------------------------------
 Temperaturas:
   CPU:  +42.0°C  +41.0°C  +40.0°C  +43.0°C
   GPU:  +38.0°C
================================================================
 1. CHECKLIST      — Diagnóstico (solo lectura)
 2. INSTALAR       — Instalar herramientas y reparar
 3. ULTRA AHORRO   — Batería máxima
 4. GAMING         — Potencia máxima
 5. PERSONALIZAR   — Ajustes individuales
 6. DEBUG / LOG    — Ver registro del script
 7. AYUDA
 8. Salir
```

---

## 🔧 Ajustes individuales disponibles

Desde la opción **Personalizar** puedes cambiar cada parámetro de forma independiente:

| Parámetro | Opciones |
|---|---|
| Perfil energía | Quiet / Balanced / Performance |
| Modo gráfica | Integrated / Hybrid |
| Tasa de refresco | Lista de Hz disponibles detectada en tiempo real |
| Brillo de pantalla | 0–100% |
| Límite de carga | 40–100% |
| Modo de suspensión | s2idle / deep (S3) |
| LED teclado | ON (blanco) / OFF |
| Gobernador CPU | powersave / performance / schedutil |

---

## 💾 Persistencia entre reinicios

Cada tipo de ajuste tiene su mecanismo de persistencia:

| Ajuste | Mecanismo |
|---|---|
| Perfil ASUS / límite batería / modo GPU / LEDs | Daemon de `asusctl` y `supergfxctl` (persisten solos) |
| Brillo y tasa de refresco | Servicio `systemd` instalado por el script (`tuf-optimizer-restore.service`) |
| Gobernador CPU / turbo | `/etc/auto-cpufreq.conf` con secciones `[battery]` y `[charger]` |
| Deep sleep (S3) | Parámetro `mem_sleep_default=deep` añadido a GRUB |
| `nvidia-drm.modeset=1` | Parámetro añadido a GRUB |

Al aplicar un modo (Ahorro o Gaming), el script pregunta si deseas hacer los cambios permanentes antes de escribir nada.

---

## 🖥️ Compatibilidad

### Compatibilidad total (todas las funciones)

| Modelo | Notas |
|---|---|
| ASUS TUF Gaming F15 / F17 | Modelo de referencia del desarrollo |
| ASUS TUF Gaming A15 / A17 | Compatible |
| ASUS ROG Zephyrus G14 / G15 / G16 | Compatible |
| ASUS ROG Strix G15 / G17 | Compatible |
| ASUS ProArt Studiobook (con dGPU) | Compatible |

Requiere `asusctl` y `supergfxctl` del repositorio [asus-linux.org](https://asus-linux.org).

### Compatibilidad parcial (sin herramientas ASUS)

Cualquier portátil Linux con GPU integrada funciona con las siguientes características:

- ✅ Resumen de sistema (batería, temperaturas, gobernador, Hz)
- ✅ Control del gobernador CPU (powersave / performance / schedutil)
- ✅ Control de brillo con `brightnessctl`
- ✅ Control de tasa de refresco con `xrandr`
- ✅ Deep sleep via GRUB
- ✅ Diagnóstico y checklist
- ❌ Perfiles ASUS (Quiet / Balanced / Performance)
- ❌ Conmutación de GPU integrada/híbrida
- ❌ Control de LEDs del teclado
- ❌ Límite de carga de batería

### No compatible

- Portátiles con Windows (obviamente)
- Portátiles sin entorno gráfico con Xorg (el control de Hz requiere `xrandr`)

---

## 📦 Dependencias

### Herramientas base (disponibles en apt)

| Paquete | Uso |
|---|---|
| `lm-sensors` | Temperaturas de CPU, GPU y NVMe |
| `upower` | Estado detallado de batería (W/h, vatios, tiempo) |
| `powerstat` | Consumo energético avanzado |
| `brightnessctl` | Control de brillo de pantalla |
| `x11-xserver-utils` | `xrandr` para control de Hz |
| `auto-cpufreq` | Gestión automática del gobernador CPU |
| `amd64-microcode` / `intel-microcode` | Actualizaciones de microcódigo (según CPU) |

### Herramientas ASUS (repositorio externo)

| Paquete | Uso |
|---|---|
| `asusctl` | Perfiles, límite de batería, LEDs |
| `supergfxctl` | Conmutación GPU integrada/híbrida |

El script puede añadir el repositorio de forma automática si lo confirmas durante la instalación.

---

## 🚀 Instalación y uso

### 1. Clonar el repositorio

```bash
git clone https://github.com/TU_USUARIO/tuf-optimizer.git
cd tuf-optimizer
```

### 2. Dar permisos de ejecución

```bash
chmod +x tuf-optimizer.sh
```

### 3. Ejecutar

```bash
sudo ./tuf-optimizer.sh
```

### Modo debug (muestra feedback de cada operación en pantalla)

```bash
sudo ./tuf-optimizer.sh --debug
```

> **Nota:** El script requiere permisos de root porque necesita acceder a parámetros del kernel, modificar el GRUB, instalar paquetes y gestionar servicios systemd.

---

## 📁 Archivos generados por el script

| Ruta | Descripción |
|---|---|
| `/var/log/tuf-optimizer.log` | Log de todas las operaciones |
| `/etc/auto-cpufreq.conf` | Configuración de gobernador CPU por batería/cargador |
| `/etc/systemd/system/tuf-optimizer-restore.service` | Servicio de restauración de brillo y Hz al arranque |

---

## 🐛 Solución de problemas

**`xrandr` no detecta la pantalla correctamente**
Asegúrate de ejecutar el script en una sesión gráfica activa con `DISPLAY=:0` disponible. Si usas Wayland, `xrandr` puede no funcionar; considera cambiar a Xorg.

**La GPU aparece como "No detectada"**
Instala `pciutils` (`apt install pciutils`) para que `lspci` esté disponible.

**El modo deep sleep no funciona tras reiniciar**
Verifica que el parámetro `mem_sleep_default=deep` esté en `/etc/default/grub` y que hayas ejecutado `update-grub`. Algunos BIOS/UEFI no soportan S3.

**`asusctl` no está disponible en apt**
Usa la opción **Instalar** del menú para añadir el repositorio de `asus-linux.org` automáticamente.

**Temperaturas no aparecen en el resumen**
Instala `lm-sensors` y ejecuta `sudo sensors-detect --auto` (disponible desde la opción Instalar del menú).

---

## 📄 Licencia

MIT License — libre para usar, modificar y distribuir con atribución.

---

## 🙏 Créditos

- Script base generado con [Gemini](https://gemini.google.com), revisado, reescrito y ampliado con soporte de [Claude](https://claude.ai)
- [asus-linux.org](https://asus-linux.org) — proyecto comunitario para soporte de hardware ASUS en Linux
- [auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) — gestión automática de frecuencia CPU
