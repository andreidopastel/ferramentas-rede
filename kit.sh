#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (PROFISSIONAL + SCAN) ---${NC}"

# Requisito para o Passo 5
if ! command -v termux-wifi-scaninfo &> /dev/null; then
    echo -e "${A}Dica: Instale o 'termux-api' na Play Store e use 'pkg install termux-api' para o Passo 5 completo.${NC}"
fi

# 1. Seleção de Alvo
echo -ne "\nAlvo (Padrão: 8.8.8.8): "
read -t 10 RESP
TARGET=${RESP:-8.8.8.8}

# --- PASSO 1: RASTREIO ---
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
tracepath -n "$TARGET" | head -n 10 | tee rota.txt
GW_DETECTADO=$(grep -E "^ 1:" rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)

# --- PASSO 2: TESTE LOCAL ---
echo -e "\n${A}[2] TESTE LOCAL (WI-FI)${NC}"
[[ -z "$GW_DETECTADO" ]] && GW_DETECTADO=$(ip route | grep default | awk '{print $3}')
ping -c 5 "$GW_DETECTADO" | tee resultado_gw.txt
GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Latência Local: ${V}${GW_AVG:-0} ms${NC}"

# --- PASSO 3: ESTABILIDADE INTERNET ---
echo -e "\n${A}[3] ESTABILIDADE INTERNET${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LAT_VAL=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Status: ${V}${LAT_VAL:-0} ms${NC}"

# --- PASSO 4: VELOCIDADE ---
echo -e "\n${A}[4] VELOCIDADE${NC}"
speedtest-cli --simple 2>/dev/null || echo "Speedtest Offline"

# --- PASSO 5: ANÁLISE DE CANAIS (NOVIDADE) ---
echo -e "\n${A}[5] ANÁLISE DE CANAIS WI-FI AO REDOR${NC}"
if command -v termux-wifi-scaninfo &> /dev/null; then
    # Tenta listar os canais e o RSSI (sinal) das redes próximas
    termux-wifi-scaninfo | grep -E "frequency|rssi|ssid" | sed 's/"//g' | sed 's/,//g'
else
    # Plano B: Informação da conexão atual
    echo -e "${AZ}Informação da sua conexão atual:${NC}"
    termux-wifi-connectioninfo 2>/dev/null || ip -o -4 addr show
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f rota.txt resultado_gw.txt resultado_ping.txt
