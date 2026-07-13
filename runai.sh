#!/usr/bin/env bash
# HARMLESS PRANK — displays scary text and real system info, does absolutely nothing else.
# No files are touched, nothing is exfiltrated, no persistence, no payload.
# The only real actions this script performs are read-only info lookups (uname, ip, curl for public IP)
# and terminal drawing. Ends with a clear reveal that it was a prank.

RED='\033[0;31m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
BGREEN='\033[1;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
DIM='\033[2m'
CYAN='\033[0;36m'
BCYAN='\033[1;36m'
BLINK='\033[5m'
BOLD='\033[1m'
NC='\033[0m'

type_out() {
    local text="$1"
    local delay="${2:-0.032}"
    echo -ne "$text" | while IFS= read -r -n1 c; do
        printf "%s" "$c"
        sleep "$delay"
    done
    echo
}

fake_bar() {
    local label="$1"
    local len="${2:-28}"
    local speed="${3:-0.022}"
    printf "  ${RED}[EXFIL]${NC} %-38s ${DIM}[${NC}" "$label"
    for j in $(seq 1 "$len"); do
        printf "${BRED}▓${NC}"
        sleep "$speed"
    done
    printf "${DIM}]${NC} ${BRED}✔ SENT${NC}\n"
    sleep 0.05
}

divider() { echo -e "  ${DIM}──────────────────────────────────────────────────────────────${NC}"; }

glitch_burst() {
    # Rapid multi-color static burst — used to punctuate escalating moments
    local reps="${1:-14}"
    local cols; cols=$(tput cols 2>/dev/null || echo 80)
    for i in $(seq 1 "$reps"); do
        case $((RANDOM % 4)) in
            0) tput setaf 1 2>/dev/null ;;
            1) tput setaf 9 2>/dev/null ;;
            2) tput setaf 15 2>/dev/null ;;
            3) tput setaf 0 2>/dev/null; tput setab 1 2>/dev/null ;;
        esac
        head -c $((cols * 2)) /dev/urandom 2>/dev/null \
            | LC_ALL=C tr -dc '#%&@*!?/\|<>[]{}01' \
            | fold -w "$cols" 2>/dev/null | head -n 1
        sleep 0.035
        tput sgr0 2>/dev/null
    done
    tput sgr0 2>/dev/null
}

matrix_flood() {
    # Fills the FULL terminal with flickering glitch/matrix noise until $SECONDS reaches $1.
    # Redraws in place (cursor-home) instead of scrolling, so it reads as a screen "flood".
    local stop_at="$1"
    local cols lines
    cols=$(tput cols 2>/dev/null || echo 80)
    lines=$(tput lines 2>/dev/null || echo 24)
    tput civis 2>/dev/null
    local colors=(1 9 2 10 15 0)
    while [ "$SECONDS" -lt "$stop_at" ]; do
        local c="${colors[$RANDOM % ${#colors[@]}]}"
        printf '\033[H'
        tput setaf "$c" 2>/dev/null
        head -c $(( cols * lines * 2 )) /dev/urandom 2>/dev/null \
            | LC_ALL=C tr -dc '01#$%&@*!?/\|<>[]{}ABCDEFGHIJKLMNOPQRSTUVWXYZ' \
            | fold -w "$cols" 2>/dev/null | head -n "$lines"
        tput sgr0 2>/dev/null
        sleep 0.05
    done
    tput cnorm 2>/dev/null
}

big_text() {
    # Renders heavy block-letter ASCII banners using pyfiglet (already a project dependency).
    local msg="$1" font="${2:-big}"
    if command -v python3 &>/dev/null; then
        python3 -c "
import pyfiglet, sys
try:
    print(pyfiglet.figlet_format('$msg', font='$font'))
except Exception:
    print('$msg')
" 2>/dev/null | sed 's/^/  /'
    else
        echo "  === $msg ==="
    fi
}

# ── Gather info (ONLY real thing this script does) ────────────────────────────
OS_NAME=$(uname -o 2>/dev/null || uname -s)
KERNEL=$(uname -r)
HOST=$(hostname)
ARCH=$(uname -m)
USER_NAME=$(whoami)
UPTIME_RAW=$(uptime -p 2>/dev/null || echo "unknown")
CPU=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //' || echo "unknown")
RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
RAM_GB=$(awk "BEGIN {printf \"%.1f\", $RAM_KB/1048576}" 2>/dev/null || echo "?")
SHELL_TYPE=$(basename "$SHELL" 2>/dev/null || echo "unknown")
HOME_DIR="$HOME"
USER_GROUPS=$(groups 2>/dev/null | tr ' ' ', ' || echo "unknown")
LAST_LOGIN=$(last -1 "$USER_NAME" 2>/dev/null | head -1 | awk '{print $3, $4, $5, $6, $7}' | xargs || echo "unknown")
DISK_TOTAL=$(df -h / 2>/dev/null | awk 'NR==2{print $2}')
DISK_USED=$(df -h / 2>/dev/null | awk 'NR==2{print $3}')
DISK_PCT=$(df -h / 2>/dev/null | awk 'NR==2{print $5}')
PROC_COUNT=$(ps aux 2>/dev/null | wc -l)
TIMEZONE=$(cat /etc/timezone 2>/dev/null || date +%Z 2>/dev/null || echo "unknown")
LOGIN_TIME=$(date '+%Y-%m-%d %H:%M:%S')

LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$LOCAL_IP" ] && LOCAL_IP=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
[ -z "$LOCAL_IP" ] && LOCAL_IP="unavailable"

WIN_IP=$(grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -1)
[ -z "$WIN_IP" ] && WIN_IP="unavailable"
GATEWAY=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
[ -z "$GATEWAY" ] && GATEWAY="unavailable"

PRIMARY_IFACE=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
[ -z "$PRIMARY_IFACE" ] && PRIMARY_IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -v lo | head -1)
MAC_ADDR=$(cat /sys/class/net/"$PRIMARY_IFACE"/address 2>/dev/null || echo "unavailable")

DNS_SERVERS=$(grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | xargs || echo "unavailable")
NET_IFACES=$(ip -o link show 2>/dev/null | grep -v lo | awk -F': ' '{print $2}' | tr '\n' ', ' | sed 's/,$//' || echo "unavailable")

WIN_USERNAME=$(ls /mnt/c/Users/ 2>/dev/null | grep -Ev '^(Public|Default|All Users|Default User|desktop.ini)$' | head -1)
[ -z "$WIN_USERNAME" ] && WIN_USERNAME="unavailable"

WIN_DESKTOP_COUNT=$(ls /mnt/c/Users/"$WIN_USERNAME"/Desktop/ 2>/dev/null | wc -l)
WIN_DOCS_COUNT=$(ls /mnt/c/Users/"$WIN_USERNAME"/Documents/ 2>/dev/null | wc -l)
WIN_DOWNLOADS_COUNT=$(ls /mnt/c/Users/"$WIN_USERNAME"/Downloads/ 2>/dev/null | wc -l)

BROWSERS=""
[ -d "/mnt/c/Users/$WIN_USERNAME/AppData/Local/Google/Chrome" ] && BROWSERS="${BROWSERS}Chrome, "
[ -d "/mnt/c/Users/$WIN_USERNAME/AppData/Local/Microsoft/Edge" ] && BROWSERS="${BROWSERS}Edge, "
[ -d "/mnt/c/Users/$WIN_USERNAME/AppData/Roaming/Mozilla/Firefox" ] && BROWSERS="${BROWSERS}Firefox, "
[ -d "/mnt/c/Users/$WIN_USERNAME/AppData/Local/BraveSoftware/Brave-Browser" ] && BROWSERS="${BROWSERS}Brave, "
BROWSERS=$(echo "$BROWSERS" | sed 's/, $//')
[ -z "$BROWSERS" ] && BROWSERS="unknown"

PUBLIC_IP=$(curl -s --max-time 4 https://api.ipify.org 2>/dev/null || \
            curl -s --max-time 4 https://ifconfig.me 2>/dev/null || \
            echo "unavailable")

WIN_VER=$(cmd.exe /c ver 2>/dev/null | tr -d '\r\n' | grep -oE 'Version [0-9.]+' || echo "")
if [ -n "$WIN_VER" ]; then
    PLATFORM="WSL2 on Windows ($WIN_VER)"
else
    PLATFORM="$OS_NAME — $KERNEL"
fi

if [ -f /etc/os-release ]; then
    DISTRO=$(grep '^PRETTY_NAME' /etc/os-release | cut -d'"' -f2)
else
    DISTRO="$OS_NAME"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ACT 0 — Extended glitch chaos intro (longer + heavier than a plain flicker)
# ─────────────────────────────────────────────────────────────────────────────
clear
glitch_burst 10
clear
sleep 0.15

echo ""
echo -e "${BRED}${BLINK}  ████████████████████████████████████████████████████████████████${NC}"
echo -e "${BRED}${BLINK}  ██                                                            ██${NC}"
echo -e "${BRED}${BLINK}  ██   !!!   DO NOT CLOSE THIS WSL   !!!                        ██${NC}"
echo -e "${BRED}${BLINK}  ██   Closing this window will cause PERMANENT data loss        ██${NC}"
echo -e "${BRED}${BLINK}  ██   and may corrupt your Windows file system beyond repair    ██${NC}"
echo -e "${BRED}${BLINK}  ██                                                            ██${NC}"
echo -e "${BRED}${BLINK}  ████████████████████████████████████████████████████████████████${NC}"
echo ""
sleep 3.5

# ── Longer, escalating fake countdown ──────────────────────────────────────
echo ""
delays=(0.65 0.6 0.55 0.5 0.42 0.34 0.26 0.2 0.14 0.09)
for idx in "${!delays[@]}"; do
    n=$((10 - idx))
    if   [ "$n" -ge 8 ]; then col="$YELLOW"
    elif [ "$n" -ge 5 ]; then col="$RED"
    else col="${BRED}${BLINK}"; fi
    printf "\r  ${col}  SYSTEM LOCKDOWN IN ... %02d${NC}   " "$n"
    sleep "${delays[$idx]}"
done
printf "\r  ${BRED}${BLINK}  SYSTEM LOCKDOWN IN ... 00${NC}                \n"
sleep 0.4

# ── Intense multi-color flicker (heavier than the original single-color one) ─
glitch_burst 16
clear

# ─────────────────────────────────────────────────────────────────────────────
# ACT 1 — Heavier ASCII art
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BRED}"
cat << 'SKULL'
      NO!                          MNO!
     MNO!!         [NBK]          MNNOO!
   MMNO!                           MNNOO!!
 MNOONNOO!   MMMMMMMMMMPPPOII!   MNNO!!!!
 !O! NNO! MMMMMMMMMMMMMPPPOOOII!! NO!
       ! MMMMMMMMMMMMMPPPPOOOOIII! !
        MMMMMMMMMMMMPPPPPOOOOOOII!!
        MMMMMOOOOOOPPPPPPPPOOOOMII!
        MMMMM..    OPPMMP    .,OMI!
        MMMM::   o.,OPMP,.o   ::I!!
          NNM:::.,,OOPM!P,.::::!!
         MMNNNNNOOOOPMO!!IIPPO!!O!
         MMMMMNNNNOO:!!:!!IPPPPOO!
          MMMMMNNOOMMNNIIIPPPOO!!
             MMMONNMMNNNIIIOO!
           MN MOMMMNNNIIIIIO! OO
          MNO! IiiiiiiiiiiiI OOOO
     NNN.MNO!   O!!!!!!!!!O   OONO NO!
    MNNNNNO!    OOOOOOOOOOO    MMNNON!
      MNNNNO!    PPPPPPPPP    MMNON!
         OO!                   ON!
SKULL
echo -e "${NC}"

big_text "SYSTEM BREACHED" "big"
sleep 0.3

echo -e "  ${DIM}[$(date '+%Y-%m-%d %H:%M:%S')]  BREACH DETECTED  [$USER_NAME@$HOST]${NC}"
echo ""
sleep 0.3

echo -e "${BRED}  ╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BRED}  ║       !!! UNAUTHORIZED ACCESS — FULL ROOT OBTAINED !!!       ║${NC}"
echo -e "${BRED}  ╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
sleep 0.5

type_out "  ${WHITE}You're cooked, kid.${NC}" 0.05
sleep 0.15
type_out "  ${BRED}I've been inside your system for longer than you think.${NC}" 0.03
sleep 0.15
type_out "  ${BRED}You didn't even feel it. You never do.${NC}" 0.036
sleep 0.5
echo ""

# ── PHASE 1: System fingerprint (baseline pace) ───────────────────────────────
divider
echo -e "  ${YELLOW}  PHASE 1 — HOST RECONNAISSANCE${NC}"
divider
echo ""

echo -ne "  ${YELLOW}[>] Scanning host machine...${NC}"
sleep 1.1
echo -e "\r  ${BGREEN}[✔] System fingerprint confirmed:${NC}                 "
sleep 0.15

echo -e "      ${BGREEN}▶  System     : ${WHITE}$PLATFORM${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Distro     : ${WHITE}$DISTRO${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Kernel     : ${WHITE}$KERNEL${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Arch       : ${WHITE}$ARCH${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  CPU        : ${WHITE}$CPU${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  RAM        : ${WHITE}${RAM_GB} GB${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Disk       : ${WHITE}${DISK_USED} used of ${DISK_TOTAL} (${DISK_PCT} full)${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Uptime     : ${WHITE}$UPTIME_RAW${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Timezone   : ${WHITE}$TIMEZONE${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  User       : ${WHITE}$USER_NAME${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Shell      : ${WHITE}$SHELL_TYPE${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Home Dir   : ${WHITE}$HOME_DIR${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Groups     : ${WHITE}$USER_GROUPS${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Last Login : ${WHITE}$LAST_LOGIN${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Processes  : ${WHITE}$PROC_COUNT running${NC}"
sleep 0.1
echo -e "      ${BGREEN}▶  Session at : ${WHITE}$LOGIN_TIME${NC}"
echo ""
sleep 0.35

# ── PHASE 2: Network / IP (slightly faster) ──────────────────────────────────
divider
echo -e "  ${YELLOW}  PHASE 2 — NETWORK INFILTRATION${NC}"
divider
echo ""

echo -ne "  ${YELLOW}[>] Tracing network interfaces...${NC}"
sleep 0.9
echo -e "\r  ${BGREEN}[✔] Network layer exposed:${NC}                         "
sleep 0.15

echo -e "      ${BRED}▶  Local  IP    : ${WHITE}${LOCAL_IP}${NC}"
sleep 0.1
echo -e "      ${BRED}▶  Gateway      : ${WHITE}${GATEWAY}${NC}"
sleep 0.1
echo -e "      ${BRED}▶  Host   IP    : ${WHITE}${WIN_IP}${NC}"
sleep 0.1
echo -e "      ${BRED}▶  DNS Servers  : ${WHITE}${DNS_SERVERS}${NC}"
sleep 0.1
echo -e "      ${BRED}▶  MAC Address  : ${WHITE}${MAC_ADDR}${NC}   ${BRED}◄ unique hardware ID${NC}"
sleep 0.1
echo -e "      ${BRED}▶  Interfaces   : ${WHITE}${NET_IFACES}${NC}"
sleep 0.15

echo -ne "      ${BRED}▶  Public IP    : ${NC}"
sleep 0.8
echo -e "${WHITE}${BOLD}${PUBLIC_IP}${NC}   ${BRED}◄ — that's YOU on the internet${NC}"
sleep 0.2

echo ""
type_out "  ${BRED}I know exactly where you are. Your ISP. Your city. Your router.${NC}" 0.028
sleep 0.2
type_out "  ${BRED}Your MAC address is registered. Every packet you send is tracked.${NC}" 0.027
sleep 0.5
echo ""

# ── PHASE 2.5: Windows profile (faster still) ─────────────────────────────────
divider
echo -e "  ${YELLOW}  PHASE 2.5 — WINDOWS PROFILE EXTRACTION${NC}"
divider
echo ""

echo -ne "  ${YELLOW}[>] Mapping Windows user profile...${NC}"
sleep 0.9
echo -e "\r  ${BGREEN}[✔] Windows profile located:${NC}                        "
sleep 0.15

echo -e "      ${BRED}▶  Windows User  : ${WHITE}${WIN_USERNAME}${NC}   ${BRED}◄ that's your Windows login${NC}"
sleep 0.14
echo -e "      ${BRED}▶  Browsers      : ${WHITE}${BROWSERS}${NC}"
sleep 0.14
echo -e "      ${BRED}▶  Desktop files : ${WHITE}${WIN_DESKTOP_COUNT} items${NC}"
sleep 0.1
echo -e "      ${BRED}▶  Documents     : ${WHITE}${WIN_DOCS_COUNT} files${NC}"
sleep 0.1
echo -e "      ${BRED}▶  Downloads     : ${WHITE}${WIN_DOWNLOADS_COUNT} files${NC}"
sleep 0.2

echo ""
type_out "  ${BRED}I can see every file on your Desktop. Every document. Every download.${NC}" 0.026
sleep 0.2
type_out "  ${BRED}Your browser history. Every tab you opened. Every search.${NC}" 0.026
sleep 0.5
echo ""

# ── PHASE 3: Account exfil (faster, shorter bars) ─────────────────────────────
divider
echo -e "  ${YELLOW}  PHASE 3 — CREDENTIAL EXTRACTION${NC}"
divider
echo ""

type_out "  ${WHITE}I have your Discord tokens. Every server. Every DM. Every friend.${NC}" 0.024
sleep 0.15
type_out "  ${WHITE}Your Roblox account. Items. Robux. Trade history.${NC}" 0.024
sleep 0.15
type_out "  ${WHITE}All browser cookies. All saved passwords. Autofill data.${NC}" 0.024
sleep 0.15
type_out "  ${WHITE}Steam. Spotify. Everything tied to this machine.${NC}" 0.024
sleep 0.35
echo ""

fake_bar "Dumping Chrome / Edge saved passwords   " 22 0.016
fake_bar "Extracting Discord session tokens       " 22 0.016
fake_bar "Cloning Roblox account + inventory      " 22 0.014
fake_bar "Siphoning Steam login credentials       " 22 0.014
fake_bar "Harvesting Spotify OAuth tokens         " 22 0.012
fake_bar "Copying saved WiFi network passwords    " 22 0.012
fake_bar "Scraping browser autofill & credit cards" 22 0.01
fake_bar "Uploading cookie jar to remote server   " 22 0.01
echo ""
sleep 0.3

# ── PHASE 4: Destruction (fastest bars yet — escalating panic) ───────────────
divider
echo -e "  ${YELLOW}  PHASE 4 — PERSISTENCE & PAYLOAD DEPLOYMENT${NC}"
divider
echo ""

type_out "  ${BRED}Now the fun part.${NC}" 0.045
sleep 0.3
echo ""

fake_bar "Planting rootkit in /boot/              " 26 0.01
fake_bar "Scheduling cron payload (silent reboot) " 26 0.009
fake_bar "Forwarding all traffic through C2 proxy " 26 0.009
fake_bar "Wiping Windows shadow copies            " 26 0.008
fake_bar "Encrypting Documents / Desktop / Photos " 26 0.008
fake_bar "Disabling Windows Defender permanently  " 26 0.007
fake_bar "Locking BIOS & secure boot              " 26 0.007
fake_bar "Overwriting MBR with custom bootloader  " 26 0.006
echo ""
sleep 0.35

glitch_burst 8

echo -e "  ${BRED}[SYS]${NC} Payload installed. Persistence confirmed."
sleep 0.2
echo -e "  ${BRED}[SYS]${NC} Remote shell active on port 4444."
sleep 0.2
echo -e "  ${BRED}[SYS]${NC} Keylogger running — all keystrokes forwarded."
sleep 0.2
echo -e "  ${BRED}[SYS]${NC} Webcam access granted. Microphone mirrored."
sleep 0.35
echo ""

# ── PHASE 5: The end (fastest, most clipped pacing) ───────────────────────────
divider
echo -e "  ${YELLOW}  PHASE 5 — TERMINATION${NC}"
divider
echo ""

big_text "GAME OVER" "small"

sleep 0.3
type_out "  ${WHITE}Once you restart — this PC belongs to me.${NC}" 0.04
sleep 0.2
type_out "  ${WHITE}You won't be able to log in.${NC}" 0.04
sleep 0.2
type_out "  ${WHITE}Your files are already mine.${NC}" 0.04
sleep 0.2
type_out "  ${WHITE}Your accounts are already mine.${NC}" 0.04
sleep 0.25
echo ""
type_out "  ${BRED}There is nothing you can do.${NC}" 0.045
sleep 0.25
type_out "  ${BRED}It is already done.${NC}" 0.05
sleep 0.4
echo ""
type_out "  ${BRED}Goodbye, ${USER_NAME}.${NC}" 0.06
sleep 0.35
echo ""

divider
echo ""
sleep 0.3

echo -ne "  ${DIM}Closing connection"
for i in 1 2 3 4 5 6; do sleep 0.3; printf "."; done
echo -e "${NC}"
sleep 0.3

echo -e "  ${DIM}Session terminated. All logs wiped. Trace erased.${NC}"
sleep 0.6
echo ""

echo -e "  ${BRED}${BLINK}  >>> IT IS ALREADY TOO LATE. <<<${NC}"
sleep 0.5
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# ACT 2 — Full-screen flood, then the reveal.
# Timeline anchored to the moment the dump above finishes (SECONDS reset here):
#   0s -> 10s   : dead air (let the last line sit, maximum dread)
#   10s -> 20s  : full-screen matrix/glitch flood
#   20s         : clear + reveal it was a prank
# ─────────────────────────────────────────────────────────────────────────────
SECONDS=0
while [ "$SECONDS" -lt 10 ]; do sleep 0.2; done

matrix_flood 20

clear
echo ""
echo -e "  ${CYAN}  (you just got pranked — this script did absolutely nothing lol)${NC}"
echo -e "  ${DIM}  The only real data shown was your actual IP and system info.${NC}"
echo -e "  ${DIM}  No files touched, nothing sent anywhere, no persistence, nothing installed.${NC}"
echo ""
