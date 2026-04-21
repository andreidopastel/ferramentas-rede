#!/data/data/com.termux/files/usr/bin/bash

V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE ---${NC}"

echo -ne "\nAlvo do teste? Padrão 8.8.8.8: "
read -t 10 RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || -z "$TARGET" ]] && TARGET="8.8.8.8"

echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
# Forçamos o uso de IP numérico para evitar erros de DNS no rastreio
tracepath -n -m 20 "$TARGET" 2>/dev/null | tee rota.txt
GW_DETECTADO=$(grep -E "^ 1:" rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)

echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"
if [[ -z "$GW_DETECTADO" ]]; then
    GW_DETECTADO=$(ip route show | grep default | awk '{print $3}' | head -n 1)
fi

if [[ -z "$GW_DETECTADO" ]]; then
    GW_DETECTADO=$(getprop net.dns1 | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
fi

if [[ -z "$GW_DETECTADO" ]]; then
    GW_DETECTADO="192.168.3.1"
fi

echo -e "Roteador Alvo: ${V}$GW_DETECTADO${NC}"

ping -c 5 "$GW_DETECTADO" > resultado_gw.txt 2>&1
if [ $? -eq 0 ]; then
    cat resultado_gw.txt
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    echo -e "Resumo Local: ${V}${GW_AVG:-0} ms${NC}"
else
    echo -e "${VM}Erro no ping local${NC}"
fi

echo -e "\n${A}[3] ESTABILIDADE INTERNET${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LAT_AVG=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Status: ${V}${LAT_AVG:-0} ms${NC}"

echo -e "\n${A}[4] TESTE DE VELOCIDADE${NC}"
speedtest-cli --simple 2>/dev/null || echo -e "${VM}Speedtest Offline${NC}"

echo -e "\n${A}[5] INFO TÉCNICA WI-FI${NC}"
WIFI_INFO=$(dumpsys connectivity | grep -i "networkExtraInfo" | head -n 1 | awk -F'extra: ' '{print $2}' | tr -d '"')
# Busca frequência de forma mais agressiva para contornar bloqueios
FREQ_VAL=$(dumpsys wifi | grep -E "mFrequency|freq|mWifiInfo" | grep -oE "[25][0-9]{3}" | head -n 1)

if [[ -n "$WIFI_INFO" ]]; then
    echo -e "${AZ}Rede Atual:${NC} $WIFI_INFO"
fi

if [[ -n "$FREQ_VAL" ]]; then
    echo -ne "${AZ}Frequência:${NC} $FREQ_VAL MHz "
    if [ "$FREQ_VAL" -lt 3000 ]; then
        echo -e "${VM}2.4GHz${NC}"
    else
        echo -e "${V}5GHz${NC}"
    fi
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f rota.txt resultado_gw.txt resultado_ping.txt
