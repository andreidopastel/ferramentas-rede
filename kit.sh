#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (COM RESUMOS) ---${NC}"

# Pergunta com tempo de espera
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP

if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ] || [ -z "$RESP" ]; then
    TARGET="8.8.8.8"
else
    TARGET=$RESP
fi

echo -e "\n${V}Iniciando testes para: ${AZ}$TARGET${NC}"

# 1. Gateway Local
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"
GW=$(ip route | grep default | awk '{print $3}' | head -n 1)
if [ -z "$GW" ]; then
    echo -e "${VM}Resumo: Gateway não identificado.${NC}"
else
    echo -e "Testando Roteador: $GW"
    GW_PING=$(ping -c 4 "$GW" | grep "avg" | awk -F'/' '{print $5}' | cut -d'.' -f1)
    if [ -z "$GW_PING" ]; then
        echo -e "Resumo: ${VM}SEM RESPOSTA (Cabo ou Wi-Fi desconectado)${NC}"
    elif [ "$GW_PING" -lt 10 ]; then
        echo -e "Resumo: ${V}EXCELENTE ($GW_PING ms)${NC}"
    else
        echo -e "Resumo: ${A}ALTO ($GW_PING ms) - Possível interferência no Wi-Fi${NC}"
    fi
fi

# 2. Estabilidade (Ping)
echo -e "\n${A}[2] ESTABILIDADE E PERDA DE PACOTES${NC}"
ping -c 6 "$TARGET" > resultado_ping.txt
LOSS=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt)
AVG_FULL=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}')
AVG=$(echo "$AVG_FULL" | cut -d'.' -f1)

if [ -z "$LOSS" ]; then
    echo -e "Resumo: ${VM}ERRO DE CONEXÃO EXTERNA${NC}"
else
    echo -e "Perda: $LOSS% | Latência: ${AVG_FULL}ms"
    # Lógica de Resumo do Ping
    if [ "$LOSS" -gt 0 ]; then echo -e "Resumo: ${VM}RUIM (Perda de dados)${NC}"
    elif [ "$AVG" -lt 50 ]; then echo -e "Resumo: ${V}BOM (Conexão Rápida)${NC}"
    elif [ "$AVG" -lt 150 ]; then echo -e "Resumo: ${A}MÉDIO (Latência Moderada)${NC}"
    else echo -e "Resumo: ${VM}RUIM (Muito Lento)${NC}"; fi
fi

# 3. Rastreio (Tracepath)
echo -e "\n${A}[3] RASTREIO DE ROTA (GARGALOS)${NC}"
tracepath -n "$TARGET" | head -n 8
echo -e "Resumo: ${AZ}Verifique se os primeiros saltos estão abaixo de 50ms.${NC}"

# 4. Velocidade
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
if [ -z "$SPEED_OUT" ]; then
    echo -e "Resumo: ${VM}Speedtest falhou.${NC}"
else
    echo "$SPEED_OUT"
    DOWN=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
    # Lógica de Resumo de Banda
    if [ "$DOWN" -gt 50 ]; then echo -e "Resumo: ${V}ALTA VELOCIDADE${NC}"
    elif [ "$DOWN" -gt 15 ]; then echo -e "Resumo: ${A}VELOCIDADE MÉDIA${NC}"
    else echo -e "Resumo: ${VM}VELOCIDADE BAIXA${NC}"; fi
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt
