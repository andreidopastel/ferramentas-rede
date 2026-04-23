#!/data/data/com.termux/files/usr/bin/bash

# ================= CORES =================
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}==== FERRAMENTA DE REDE PRO MAX ====${NC}"

# ================= ALVO =================
echo -ne "\nAlvo (padrão 8.8.8.8): "
read -t 10 TARGET
TARGET=${TARGET:-8.8.8.8}

# =====================================================
# [1] ROTA
# =====================================================
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
tracepath -n "$TARGET" 2>/dev/null | head -n 12

# =====================================================
# [2] REDE LOCAL
# =====================================================
echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"

GW=$(ip route | awk '/default/ {print $3}' | head -n1)

echo -e "Gateway: ${V}$GW${NC}"

PING_GW=$(ping -c 3 "$GW" 2>/dev/null)
echo "$PING_GW" | grep time=

GW_AVG=$(echo "$PING_GW" | awk -F'/' '/rtt/ {print $5}')
echo -e "Latência local: ${V}${GW_AVG:-0} ms${NC}"

# =====================================================
# [3] INTERNET
# =====================================================
echo -e "\n${A}[3] ESTABILIDADE DA INTERNET${NC}"

PING_NET=$(ping -c 10 "$TARGET" 2>/dev/null)

echo "$PING_NET" | grep time= | head -n 5
LAT=$(echo "$PING_NET" | awk -F'/' '/rtt/ {print $5}')

echo -e "Latência média: ${V}${LAT:-0} ms${NC}"

# =====================================================
# [4] SPEEDTEST
# =====================================================
echo -e "\n${A}[4] VELOCIDADE${NC}"

if command -v speedtest-cli &>/dev/null; then
    speedtest-cli --simple
else
    echo -e "${VM}Instale: pkg install speedtest-cli${NC}"
fi

# =====================================================
# [5] WI-FI ATUAL
# =====================================================
echo -e "\n${A}[5] WI-FI ATUAL${NC}"

WIFI=$(termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI" && "$WIFI" != "{}" ]]; then

    SSID=$(echo "$WIFI" | jq -r '.ssid')
    FREQ=$(echo "$WIFI" | jq -r '.frequency_mhz')
    RSSI=$(echo "$WIFI" | jq -r '.rssi')

    echo -e "${AZ}SSID:${NC} $SSID"

    if [[ -n "$FREQ" && "$FREQ" != "null" ]]; then
        if [ "$FREQ" -lt 3000 ]; then
            BANDA="2.4GHz"
            CANAL=$(( (FREQ - 2412) / 5 + 1 ))
        else
            BANDA="5GHz"
            CANAL=$(( (FREQ - 5170) / 5 + 34 ))
        fi

        echo -e "Frequência: $FREQ MHz ($BANDA)"
        echo -e "Canal atual: ${A}$CANAL${NC}"
    fi

    if [[ -n "$RSSI" ]]; then
        if [ "$RSSI" -ge -60 ]; then QUAL="Excelente"
        elif [ "$RSSI" -ge -75 ]; then QUAL="Bom"
        else QUAL="Ruim"; fi

        echo -e "Sinal: $RSSI dBm (${V}$QUAL${NC})"
    fi
else
    echo -e "${VM}Ative localização (GPS)${NC}"
fi

# =====================================================
# [6] SCAN + ANALISADOR PRO MAX
# =====================================================
echo -e "\n${A}[6] ANALISADOR WI-FI PRO MAX${NC}"

# força atualização do Android
termux-wifi-scaninfo >/dev/null 2>&1
sleep 3

SCAN=$(termux-wifi-scaninfo 2>/dev/null)

# retry automático
if [[ "$SCAN" == "[]" || -z "$SCAN" ]]; then
    sleep 3
    SCAN=$(termux-wifi-scaninfo 2>/dev/null)
fi

if [[ "$SCAN" == "[]" || -z "$SCAN" ]]; then
    echo -e "${VM}Nenhuma rede detectada (GPS desligado ou bloqueio Android)${NC}"
    exit
fi

declare -A CH24
declare -A CH5

echo ""

echo "$SCAN" | jq -c '.[]' | while read rede; do

    SSID=$(echo "$rede" | jq -r '.ssid')
    FREQ=$(echo "$rede" | jq -r '.frequency_mhz')
    RSSI=$(echo "$rede" | jq -r '.rssi')

    if [[ "$FREQ" -lt 3000 ]]; then
        CANAL=$(( (FREQ - 2412) / 5 + 1 ))
        BANDA="2.4GHz"
        CH24[$CANAL]=$(( ${CH24[$CANAL]:-0} + (-1 * RSSI) ))
    else
        CANAL=$(( (FREQ - 5000) / 5 ))
        BANDA="5GHz"
        CH5[$CANAL]=$(( ${CH5[$CANAL]:-0} + (-1 * RSSI) ))
    fi

    echo -e "${V}SSID:${NC} ${SSID:-Oculto}"
    echo -e "Banda: $BANDA"
    echo -e "Canal: ${A}$CANAL${NC}"
    echo -e "Sinal: $RSSI dBm"
    echo "-------------------------"
done

# ================= MELHOR CANAL =================

BEST24=1
VAL24=99999

for i in {1..11}; do
    VAL=${CH24[$i]:-0}
    if (( VAL < VAL24 )); then
        VAL24=$VAL
        BEST24=$i
    fi
done

BEST5=36
VAL5=99999

for i in 36 40 44 48 149 153 157 161; do
    VAL=${CH5[$i]:-0}
    if (( VAL < VAL5 )); then
        VAL5=$VAL
        BEST5=$i
    fi
done

echo -e "\n${A}=== RECOMENDAÇÃO FINAL ===${NC}"
echo -e "Melhor canal 2.4GHz: ${V}$BEST24${NC}"
echo -e "Melhor canal 5GHz: ${V}$BEST5${NC}"

echo -e "\n${V}==== PRO MAX FINALIZADO ====${NC}"
