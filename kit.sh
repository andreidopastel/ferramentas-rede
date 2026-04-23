#!/data/data/com.termux/files/usr/bin/bash

# ---------------- CORES ----------------
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}---- FERRAMENTA DE REDE PRO MAX ----${NC}"

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

GW=$(grep -m1 "1:" rota.txt | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')

if [[ -z "$GW" ]]; then
    IP=$(ip addr show wlan0 2>/dev/null | grep -w inet | awk '{print $2}' | cut -d/ -f1)
    [[ -n "$IP" ]] && GW=$(echo "$IP" | cut -d. -f1-3).1
fi

echo -e "Roteador: ${V}$GW${NC}"

ping -c 3 "$GW" > gw.txt 2>/dev/null

if [[ $? -eq 0 ]]; then
    AVG=$(grep "rtt" gw.txt | awk -F'/' '{print $5}')
    echo -e "Latência local: ${V}${AVG:-0} ms${NC}"
else
    echo -e "${VM}Erro no ping do roteador${NC}"
fi

# =====================================================
# [3] INTERNET
# =====================================================
echo -e "\n${A}[3] ESTABILIDADE DA INTERNET${NC}"

ping -c 10 "$TARGET" | tee ping.txt

AVG=$(grep "rtt" ping.txt | awk -F'/' '{print $5}')

echo -e "Latência média: ${V}${AVG:-0} ms${NC}"

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

SSID=$(echo "$WIFI" | grep -oP '"ssid":\s*"\K[^"]+')
FREQ=$(echo "$WIFI" | grep -oP '"frequency_mhz":\s*\K[0-9]+')
RSSI=$(echo "$WIFI" | grep -oP '"rssi":\s*\K-?[0-9]+')

echo -e "${AZ}SSID:${NC} $SSID"

if [[ -n "$FREQ" ]]; then
    if [ "$FREQ" -ge 2412 ] && [ "$FREQ" -le 2484 ]; then
        BAND="2.4GHz"
        CH=$(( (FREQ - 2412) / 5 + 1 ))
    elif [ "$FREQ" -ge 5170 ] && [ "$FREQ" -le 5825 ]; then
        BAND="5GHz"
        CH=$(( (FREQ - 5170) / 5 + 34 ))
    else
        BAND="?"
        CH="?"
    fi

    echo -e "Frequência: $FREQ MHz ($BAND)"
    echo -e "Canal: $CH"
fi

if [[ -n "$RSSI" ]]; then
    [[ "$RSSI" -ge -60 ]] && Q="Excelente"
    [[ "$RSSI" -lt -60 && "$RSSI" -ge -75 ]] && Q="Bom"
    [[ "$RSSI" -lt -75 ]] && Q="Ruim"

    echo -e "Sinal: $RSSI dBm ($Q)"
fi

# =====================================================
# [6] SCAN WI-FI + ANÁLISE DE CANAL
# =====================================================
echo -e "\n${A}[6] ANALISADOR WI-FI PRO MAX${NC}"

SCAN=""
for i in 1 2 3; do
    SCAN=$(termux-wifi-scaninfo 2>/dev/null)
    [[ "$SCAN" != "[]" && -n "$SCAN" ]] && break
    sleep 3
done

if [[ "$SCAN" == "[]" || -z "$SCAN" ]]; then
    echo -e "${VM}Scan bloqueado pelo Android${NC}"
else

echo "$SCAN" | awk '
{
    if ($0 ~ /ssid/) {
        gsub(/.*"ssid":"/,"")
        gsub(/".*/,"")
        ssid=$0
    }
    if ($0 ~ /frequency_mhz/) {
        gsub(/.*:/,"")
        freq=$0
    }
    if ($0 ~ /rssi/) {
        gsub(/.*:/,"")
        rssi=$0

        if (freq >= 2412 && freq <= 2484)
            ch=int((freq-2412)/5)+1
        else if (freq >= 5170 && freq <= 5825)
            ch=int((freq-5170)/5)+34
        else
            ch="?"

        print "SSID: " ssid
        print "Banda: " (freq<3000?"2.4GHz":"5GHz")
        print "Canal: " ch
        print "Sinal: " rssi " dBm"
        print "----------------"

        ssid=""; freq=""; rssi=""
    }
}
'

echo -e "\n=== RECOMENDAÇÃO FINAL ==="

echo "$SCAN" | awk '
{
    if ($0 ~ /frequency_mhz/) {
        gsub(/.*:/,"")
        f=$0

        if (f>=2412 && f<=2484) c=int((f-2412)/5)+1
        else if (f>=5170 && f<=5825) c=int((f-5170)/5)+34
        else c=-1

        if (c>0) count[c]++
    }
}
END{
    min=999
    best=1
    for (i in count) {
        if (count[i] < min) {
            min=count[i]
            best=i
        }
    }

    print "Melhor canal sugerido:", best
}
'
fi

# =====================================================
# FINAL
# =====================================================
echo -e "\n${V}---- PRO MAX FINALIZADO ----${NC}"

rm -f rota.txt gw.txt ping.txt
