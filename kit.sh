#!/data/data/com.termux/files/usr/bin/bash

# Cores para o visual profissional
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE ---${NC}"

# 1. Seleção de Alvo
echo -ne "\nAlvo do teste? (Padrão: 8.8.8.8) ou 'y' para padrão: "
read -t 10 RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" ]] && TARGET="8.8.8.8"

# --- PASSO 1: RASTREIO DE ROTA ---
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
tracepath -n "$TARGET" | head -n 10 | tee rota.txt
# Pega o primeiro IP que responder após o localhost
GW_DETECTADO=$(grep -E "^ 1:|^ 2:" rota.txt | grep -v "127.0.0.1" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)

# --- PASSO 2: TESTE DE REDE LOCAL ---
echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"
if [[ -z "$GW_DETECTADO" ]]; then
    GW_DETECTADO=$(ip route | grep default | awk '{print $3}')
fi
echo -e "Roteador Alvo: ${V}$GW_DETECTADO${NC}"
ping -c 5 "$GW_DETECTADO" | tee resultado_gw.txt
GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Resumo Local: ${V}${GW_AVG:-0} ms${NC}"

# --- PASSO 3: ESTABILIDADE E PERDA (INTERNET) ---
echo -e "\n${A}[3] ESTABILIDADE E PERDA DE PACOTES${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LAT_AVG=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Status: ${V}${LAT_AVG:-0} ms${NC}"

# --- PASSO 4: TESTE DE VELOCIDADE ---
echo -e "\n${A}[4] TESTE DE VELOCIDADE${NC}"
speedtest-cli --simple 2>/dev/null || echo -e "${VM}Speedtest Offline${NC}"

# --- PASSO 5: INFO TÉCNICA DO WI-FI (VIA DUMPSYS) ---
echo -e "\n${A}[5] INFO DO CANAL E CONEXÃO${NC}"
# Tenta pegar SSID e Frequência do sistema sem precisar de API externa
WIFI_DATA=$(dumpsys connectivity | grep -i "WIFI" | grep -i "networkExtraInfo" | head -n 1)
FREQ_DATA=$(dumpsys wifi | grep "mFrequency" | head -n 1 | awk '{print $1}' | tr -d 'mFrequency=')

if [[ -n "$WIFI_DATA" ]]; then
    echo -e "${AZ}Rede Atual:${NC} $(echo $WIFI_DATA | awk -F'extra: ' '{print $2}')"
fi

if [[ -n "$FREQ_DATA" ]]; then
    echo -ne "${AZ}Frequência:${NC} $FREQ_DATA MHz "
    if [ "$FREQ_DATA" -lt 3000 ]; then
        echo -e "${VM}(Canal 2.4GHz - Sujeito a Interferência)${NC}"
    else
        echo -e "${V}(Canal 5GHz - Alta Performance)${NC}"
    fi
else
    echo -e "${VM}Dica: Ligue o GPS para liberar dados de frequência no Android.${NC}"
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f rota.txt resultado_gw.txt resultado_ping.txt
