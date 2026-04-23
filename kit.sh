#!/data/data/com.termux/files/usr/bin/bash

# ================= CORES =================
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}---- WI-FI PRO MAX ANALYZER ----${NC}"

# ================= ALVO =================
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
done

# =====================================================
# [2] REDE LOCAL
# =====================================================
echo -e "\n${A}[2] REDE LOCAL${NC}"

GW=$(ip route | awk '/default/ {print $3}' | head -n1)

echo -e "Gateway: ${V}$GW${NC}"

ping -c 3 "$GW" > gw.txt 2>&1

if [[ $? -eq 0 ]]; then
    AVG=$(grep "rtt" gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    echo -e "Latência local: ${V}${AVG:-0} ms${NC}"
else
    echo -e "${VM}Erro gateway${NC}"
fi

# =====================================================
# [3] INTERNET
# =====================================================
echo -e "\n${A}[3] INTERNET${NC}"

ping -c 10 "$TARGET" | tee ping.txt
AVG=$(grep "rtt" ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Latência média: ${V}${AVG:-0} ms${NC}"

# =====================================================
# [4] SPEEDTEST
# =====================================================
echo -e "\n${A}[4] VELOCIDADE${NC}"

if command -v speedtest-cli &>/dev/null; then
    speedtest-cli --simple
else
    echo -e "${VM}instale speedtest-cli${NC}"
fi

# =====================================================
# [5] WI-FI ATUAL
# =====================================================
echo -e "\n${A}[5] WI-FI ATUAL${NC}"

INFO=$(termux-wifi-connectioninfo 2>/dev/null)

SSID=$(echo "$INFO" | grep -oP '"ssid":\s*"\K[^"]+')
FREQ=$(echo "$INFO" | grep -oP '"frequency_mhz":\s*\K[0-9]+')
RSSI=$(echo "$INFO" | grep -oP '"rssi":\s*\K-?[0-9]+')

echo -e "SSID: ${AZ}$SSID${NC}"

if [[ -n "$FREQ" ]]; then
    if (( FREQ < 3000 )); then
        BAND="2.4GHz"
        CH=$(( (FREQ-2412)/5+1 ))
    else
        BAND="5GHz"
        CH=$(( (FREQ-5170)/5+34 ))
    fi

    echo -e "Frequência: $FREQ MHz ($BAND)"
    echo -e "Canal atual: $CH"
fi

echo -e "Sinal: $RSSI dBm"

# =====================================================
# [6] WI-FI PRO MAX SCAN + INTELIGÊNCIA
# =====================================================
echo -e "\n${A}[6] ANALISADOR WI-FI PRO MAX${NC}"

termux-wifi-scaninfo >/dev/null 2>&1
sleep 4

SCAN=$(termux-wifi-scaninfo 2>/dev/null)

if [[ "$SCAN" == "[]" || -z "$SCAN" ]]; then
    echo -e "${VM}Scan indisponível${NC}"
else

echo "$SCAN" | awk '
function canal2g(freq){return int((freq-2412)/5)+1}
function canal5g(freq){return int((freq-5170)/5)+34}

BEGIN {print ""}

# captura dados
/ssid/ {gsub(/.*:|\"|,/, "", $0); ssid=$0}
/frequency_mhz/ {gsub(/.*:|,/, "", $0); freq=$0}
/rssi/ {gsub(/.*:|,/, "", $0); rssi=$0}

ssid && freq && rssi {

    if (freq < 3000) {
        ch = canal2g(freq)
        band="2.4GHz"
        load2[ch] += (rssi * -1)
        count2[ch]++
    } else {
        ch = canal5g(freq)
        band="5GHz"
        load5[ch] += (rssi * -1)
        count5[ch]++
    }

    print "SSID: " ssid;
    print "Banda: " band;
    print "Canal: " ch;
    print "Sinal: " rssi " dBm";
    print "----------------";

    ssid=""; freq=""; rssi=""
}

END {

    best2=99999; bestch2=1
    best5=99999; bestch5=36

    # 2.4GHz
    for (i=1;i<=11;i++){
        if (count2[i]>0){
            avg=load2[i]/count2[i]
            if(avg<best2){best2=avg; bestch2=i}
        }
    }

    # 5GHz (simplificado canais comuns)
    for (i=36;i<=165;i++){
        if (count5[i]>0){
            avg=load5[i]/count5[i]
            if(avg<best5){best5=avg; bestch5=i}
        }
    }

    print "\n=== RECOMENDAÇÃO FINAL ==="
    print "Melhor canal 2.4GHz: " bestch2
    print "Melhor canal 5GHz: " bestch5
}
'
fi

# =====================================================
# FINAL
# =====================================================
echo -e "\n${V}---- PRO MAX FINALIZADO ----${NC}"

rm -f rota.txt gw.txt ping.txt
