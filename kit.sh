#!/data/data/com.termux/files/usr/bin/bash

# ---------------- CORES ----------------
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}---- FERRAMENTA DE REDE ----${NC}"

# ---------------- ALVO ----------------
echo -ne "\nAlvo do teste? Padrão 8.8.8.8: "
read -t 10 RESP
TARGET=${RESP:-8.8.8.8}

# =====================================================
# [1] ROTA
# =====================================================
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
> rota.txt

tracepath -n "$TARGET" 2>/dev/null | while read -r line; do
    [[ "$line" != *"no reply"* ]] && echo "$line" | tee -a rota.txt

    if [[ "$line" == *"$TARGET"* ]]; then
        echo -e "${V}Destino atingido.${NC}"
        pkill -P $$ tracepath 2>/dev/null
        break
    fi
done

# =====================================================
# [2] REDE LOCAL
# =====================================================
echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"

GW_DETECTADO=$(grep -m 1 "1: " rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

if [[ -z "$GW_DETECTADO" ]]; then
    MEU_IP=$(ip addr show wlan0 2>/dev/null | grep -w inet | awk '{print $2}' | cut -d/ -f1)
    [[ -n "$MEU_IP" ]] && GW_DETECTADO=$(echo "$MEU_IP" | cut -d. -f1-3).1
fi

[[ -z "$GW_DETECTADO" ]] && GW_DETECTADO=$(ip neigh show | awk '{print $1}' | head -n 1)

echo -e "Roteador: ${V}$GW_DETECTADO${NC}"

ping -c 3 "$GW_DETECTADO" > gw.txt 2>&1

if [[ $? -eq 0 ]]; then
    cat gw.txt | grep "time="
    GW_AVG=$(grep "rtt" gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    echo -e "Latência local: ${V}${GW_AVG:-0} ms${NC}"
else
    echo -e "${VM}Erro no ping do roteador.${NC}"
fi

# =====================================================
# [3] INTERNET
# =====================================================
echo -e "\n${A}[3] ESTABILIDADE DA INTERNET${NC}"

ping -c 10 "$TARGET" | tee ping.txt

LAT_AVG=$(grep "rtt" ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

echo -e "Latência média: ${V}${LAT_AVG:-0} ms${NC}"

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
# [5] WIFI ATUAL
# =====================================================
echo -e "\n${A}[5] WI-FI ATUAL${NC}"

WIFI=$(termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI" && "$WIFI" != "{}" ]]; then

    SSID=$(echo "$WIFI" | grep -oP '"ssid":\s*"\K[^"]+')
    FREQ=$(echo "$WIFI" | grep -oP '"frequency_mhz":\s*\K[0-9]+')
    RSSI=$(echo "$WIFI" | grep -oP '"rssi":\s*\K-?[0-9]+')

    echo -e "${AZ}SSID:${NC} $SSID"

    if [[ -n "$FREQ" ]]; then
        if [ "$FREQ" -lt 3000 ]; then
            BANDA="2.4GHz"
            CANAL=$(( (FREQ - 2412) / 5 + 1 ))
        else
            BANDA="5GHz"
            CANAL=$(( (FREQ - 5170) / 5 + 34 ))
        fi

        echo -e "Frequência: $FREQ MHz ($BANDA)"
        echo -e "Canal: $CANAL"
    fi

    if [[ -n "$RSSI" ]]; then
        if [ "$RSSI" -ge -60 ]; then QUAL="Excelente"
        elif [ "$RSSI" -ge -75 ]; then QUAL="Bom"
        else QUAL="Ruim"; fi

        echo -e "Sinal: $RSSI dBm ($QUAL)"
    fi
else
    echo -e "${VM}Ative localização (GPS).${NC}"
fi

# =====================================================
# [6] SCAN WI-FI (VERSÃO ESTÁVEL)
# =====================================================
echo -e "\n${A}[6] SCAN DE CANAIS WI-FI${NC}"

# força refresh do Android
termux-wifi-scaninfo >/dev/null 2>&1
sleep 4

SCAN=$(termux-wifi-scaninfo 2>/dev/null)

# retry automático se vier vazio
if [[ "$SCAN" == "[]" || -z "$SCAN" ]]; then
    sleep 3
    SCAN=$(termux-wifi-scaninfo 2>/dev/null)
fi

if [[ "$SCAN" != "[]" && -n "$SCAN" ]]; then

    echo "$SCAN" | grep -Eo '"ssid":"[^"]*"|"frequency_mhz":[0-9]+|"rssi":[-0-9]+' | \
    awk '
    /ssid/ {gsub(/.*:/,""); ssid=$0}
    /frequency_mhz/ {gsub(/.*:/,""); freq=$0}
    /rssi/ {gsub(/.*:/,""); rssi=$0}

    ssid && freq && rssi {
        if (freq < 3000)
            canal=int((freq-2412)/5)+1;
        else
            canal=int((freq-5170)/5)+34;

        print "SSID: " ssid;
        print "Canal: " canal " | Freq: " freq " MHz | Sinal: " rssi " dBm";
        print "-----------------------------";

        ssid=""; freq=""; rssi=""
    }'
else
    echo -e "${VM}Scan indisponível (Android bloqueou ou não atualizou ainda).${NC}"
fi

# =====================================================
# FINAL
# =====================================================
echo -e "\n${V}---- DIAGNÓSTICO FINALIZADO ----${NC}"

rm -f rota.txt gw.txt ping.txt
