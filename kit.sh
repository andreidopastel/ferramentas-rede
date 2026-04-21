#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (ORDEM DINÂMICA) ---${NC}"

# 1. Seleção de Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

echo -e "\n${V}Iniciando Diagnóstico para: ${AZ}$TARGET${NC}"

# --- PASSO 1: RASTREIO DE ROTA (PARA IDENTIFICAR O IP DO ROTEADOR) ---
echo -e "\n${A}[1] RASTREIO DE ROTA (IDENTIFICANDO CAMINHO)${NC}"
# Executa o tracepath e salva em variável para não precisar rodar duas vezes
TRACE_DATA=$(tracepath -n "$TARGET" | head -n 10)
echo "$TRACE_DATA"

# Extrai o IP do salto 1 (o roteador real)
GW_DETECTADO=$(echo "$TRACE_DATA" | grep -E "^ 1:" | awk '{print $2}' | head -n 1)

# --- PASSO 2: TESTE DE REDE LOCAL (USANDO O IP DESCOBERTO NO PASSO 1) ---
echo -e "\n${A}[2] TESTE DE REDE LOCAL (WI-FI)${NC}"

if [[ -z "$GW_DETECTADO" || "$GW_DETECTADO" == "no" ]]; then
    # Plano B caso o tracepath falhe em mostrar o IP
    GW_DETECTADO=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
fi

if [[ -n "$GW_DETECTADO" ]]; then
    echo -e "Pingando Roteador detectado: ${V}$GW_DETECTADO${NC}"
    ping -c 5 "$GW_DETECTADO" | tee resultado_gw.txt
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    
    if [[ -n "$GW_AVG" ]]; then
        if [[ "$GW_AVG" -lt 15 ]]; then echo -e "Resumo Local: ${V}EXCELENTE ($GW_AVG ms)${NC}"
        else echo -e "Resumo Local: ${A}OSCILANTE ($GW_AVG ms)${NC}"; fi
    else
        echo -e "Resumo Local: ${VM}SEM RESPOSTA (Roteador bloqueia ICMP/Ping)${NC}"
    fi
else
    echo -e "Resumo Local: ${VM}NÃO FOI POSSÍVEL DETECTAR O GATEWAY${NC}"
fi

# --- PASSO 3: ESTABILIDADE EXTERNA ---
echo -e "\n${A}[3] ESTABILIDADE E PERDA DE PACOTES (INTERNET)${NC}"
echo -e "Monitorando $TARGET em tempo real:"
echo "------------------------------------"
ping -c 10 "$TARGET" | tee resultado_ping.txt
echo "------------------------------------"

LOSS_VAL=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt || echo 0)
LAT_VAL=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

if [[ "$LOSS_VAL" -gt 0 ]]; then echo -e "Resumo Internet: ${VM}INSTÁVEL ($LOSS_VAL% perda)${NC}"
else echo -e "Resumo Internet: ${V}BOM ($LAT_VAL ms)${NC}"; fi

# --- PASSO 4: VELOCIDADE ---
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
speedtest-cli --simple 2>/dev/null || echo -e "${VM}Speedtest offline${NC}"

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt resultado_gw.txt
