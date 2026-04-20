#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (ESTÁVEL) ---${NC}"

# Pergunta Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

echo -e "\n${V}Iniciando testes...${NC}"

# 1. Gateway Local (Ajustado para seu IP: 192.168.127.1)
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"
GW=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
[[ -z "$GW" ]] && GW="192.168.127.1"

echo -e "Testando Roteador: $GW"
GW_PING_RAW=$(ping -c 5 "$GW" 2>/dev/null | grep "avg")

if [[ -n "$GW_PING_RAW" ]]; then
    GW_AVG=$(echo "$GW_PING_RAW" | awk -F'/' '{print $5}' | cut -d'.' -f1)
    if [[ "$GW_AVG" -lt 15 ]]; then
        echo -e "Resumo: ${V}EXCELENTE ($GW_AVG ms)${NC}"
    else
        echo -e "Resumo: ${A}LATÊNCIA LOCAL ALTA ($GW_AVG ms)${NC}"
    fi
else
    echo -e "Resumo: ${VM}ROTEADOR NÃO RESPONDEU${NC}"
fi

# 2. Estabilidade Externa
echo -e "\n${A}[2] ESTABILIDADE EXTERNA (INTERNET)${NC}"
ping -c 6 "$TARGET" > resultado_ping.txt
LOSS=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt)
AVG_VAL=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

# Garante que as variáveis não sejam vazias para não quebrar o código
LOSS_VAL=${LOSS:-0}
LAT_VAL=${AVG_VAL:-0}

echo -e "Perda: ${LOSS_VAL}% | Latência: ${LAT_VAL}ms"
if [[ "$LOSS_VAL" -gt 0 ]]; then 
    echo -e "Resumo: ${VM}PERDA DE PACOTES${NC}"
elif [[ "$LAT_VAL" -lt 60 ]]; then 
    echo -e "Resumo: ${V}BOM${NC}"
else 
    echo -e "Resumo: ${A}MÉDIO${NC}"
fi

# 3. Rastreio
echo -e "\n${A}[3] RASTREIO DE ROTA${NC}"
tracepath -n "$TARGET" | head -n 8

# 4. Velocidade
echo -e "\n${A}[4] VELOCIDADE${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
if [[ -n "$SPEED_OUT" ]]; then
    echo "$SPEED_OUT"
    DOWN_RAW=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
    DOWN_VAL=${DOWN_RAW:-0}
    
    if [[ "$DOWN_VAL" -gt 50 ]]; then 
        echo -e "Resumo: ${V}VELOCIDADE ALTA${NC}"
    elif [[ "$DOWN_VAL" -gt 15 ]]; then 
        echo -e "Resumo: ${A}VELOCIDADE MÉDIA${NC}"
    else 
        echo -e "Resumo: ${VM}VELOCIDADE BAIXA${NC}"
    fi
else
    echo -e "Resumo: ${VM}SPEEDTEST FALHOU OU ESTÁ LENTO${NC}"
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt
