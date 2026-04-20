#!/data/data/com.termux/files/usr/bin/bash

# Cores para o terminal
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE ---${NC}"

# Seleção de Alvo
echo -n "Alvo (padrão 8.8.8.8) ou digite o IP: "
read RESP
TARGET=${RESP:-8.8.8.8}

echo -e "\n${V}Iniciando Testes em Tempo Real...${NC}"
echo -e "------------------------------------"

# 1. Teste de Rede Local (Gateway)
echo -e "${A}[1] TESTANDO CONEXÃO LOCAL (WI-FI/ROTEADOR)${NC}"
GW=$(ip route | grep default | awk '{print $3}' | head -n 1)
if [ -n "$GW" ]; then
    ping -c 4 "$GW"
    GW_RESULT="OK"
else
    echo -e "${VM}Gateway não detectado!${NC}"
    GW_RESULT="FALHA"
fi

# 2. Teste de Estabilidade e Perda (Internet)
echo -e "\n${A}[2] TESTANDO ESTABILIDADE E PERDA (INTERNET)${NC}"
PING_OUT=$(ping -c 10 "$TARGET")
echo "$PING_OUT"

# Extração de dados para o relatório
LOSS=$(echo "$PING_OUT" | grep -oP '\d+(?=% packet loss)')
AVG=$(echo "$PING_OUT" | grep "avg" | awk -F'/' '{print $5}' | cut -d'.' -f1)
MDEV=$(echo "$PING_OUT" | grep "avg" | awk -F'/' '{print $7}' | cut -d'.' -f1)

# 3. Teste de Velocidade
echo -e "\n${A}[3] MEDINDO VELOCIDADE DE BANDA (AGUARDE...)${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
echo "$SPEED_OUT"
DOWNLOAD=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)

# --- GERAÇÃO DO RELATÓRIO FINAL ---
echo -e "\n\n${V}====================================${NC}"
echo -e "${V}       RELATÓRIO DE QUALIDADE       ${NC}"
echo -e "${V}====================================${NC}"

# Avaliação da Latência
if [ -z "$AVG" ]; then STATUS_LAT="${VM}DESCONECTADO${NC}";
elif [ "$AVG" -lt 50 ]; then STATUS_LAT="${V}BOM (Baixa)${NC}";
elif [ "$AVG" -lt 150 ]; then STATUS_LAT="${A}MÉDIO (Moderada)${NC}";
else STATUS_LAT="${VM}RUIM (Alta)${NC}"; fi

# Avaliação do Jitter (Instabilidade)
if [ -z "$MDEV" ]; then STATUS_JIT="${VM}---${NC}";
elif [ "$MDEV" -lt 15 ]; then STATUS_JIT="${V}ESTÁVEL${NC}";
elif [ "$MDEV" -lt 35 ]; then STATUS_JIT="${A}OSCILANTE${NC}";
else STATUS_JIT="${VM}INSTÁVEL (Ruim)${NC}"; fi

# Avaliação de Perda
if [ "$LOSS" -eq 0 ]; then STATUS_LOSS="${V}NENHUMA (Perfeito)${NC}";
else STATUS_LOSS="${VM}COM FALHAS ($LOSS%)${NC}"; fi

echo -e "CONEXÃO LOCAL:  $GW_RESULT"
echo -e "LATÊNCIA PING:  $AVG ms -> $STATUS_LAT"
echo -e "INSTABILIDADE:  $MDEV ms -> $STATUS_JIT"
echo -e "PERDA DADOS:    $STATUS_LOSS"
echo -e "VELOCIDADE:     ${DOWNLOAD:-0} Mbps"
echo -e "------------------------------------"

# VEREDITO FINAL
if [ "$LOSS" -gt 0 ]; then
    echo -e "VEREDITO: ${VM}CONEXÃO COM PERDA DE SINAL${NC}"
elif [ "$AVG" -gt 150 ]; then
    echo -e "VEREDITO: ${A}CONEXÃO LENTA (LATÊNCIA ALTA)${NC}"
else
    echo -e "VEREDITO: ${V}CONEXÃO DENTRO DOS PADRÕES${NC}"
fi
echo -e "===================================="
