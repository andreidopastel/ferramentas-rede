#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (TESTE DE DISTÂNCIA) ---${NC}"

# Pergunta com tempo de espera
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[ "$TARGET" == "y" ] || [ "$TARGET" == "Y" ] && TARGET="8.8.8.8"

echo -e "\n${V}Iniciando testes...${NC}"

# 1. Gateway Local (Tratamento para Android 10+)
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"

# Tenta achar o gateway sem gerar erro na tela
GW=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)

# Se falhar, tenta o DNS interno (comum em Android)
if [ -z "$GW" ]; then
    GW=$(getprop net.dns1 2>/dev/null | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)
fi

if [ -z "$GW" ]; then
    echo -e "${A}Aviso: Não foi possível detectar o Gateway automaticamente.${NC}"
    echo -n "Digite o IP do roteador (ex: 192.168.1.1) ou Enter para pular: "
    read -t 5 GW_MANUAL
    GW=$GW_MANUAL
fi

if [ -n "$GW" ]; then
    echo -e "Alvo Local: $GW (Distância: ~15m)"
    GW_PING_RAW=$(ping -c 5 "$GW" | grep "avg")
    GW_AVG=$(echo "$GW_PING_RAW" | awk -F'/' '{print $5}' | cut -d'.' -f1)
    
    if [ -z "$GW_AVG" ]; then
        echo -e "Resumo: ${VM}SEM RESPOSTA (Sinal muito fraco ou bloqueado)${NC}"
    elif [ "$GW_AVG" -lt 10 ]; then
        echo -e "Resumo: ${V}EXCELENTE ($GW_AVG ms) - Mesmo a 15m o sinal está limpo${NC}"
    elif [ "$GW_AVG" -lt 30 ]; then
        echo -e "Resumo: ${A}ALERTA ($GW_AVG ms) - Distância/Paredes afetando a resposta${NC}"
    else
        echo -e "Resumo: ${VM}RUIM ($GW_AVG ms) - Instabilidade alta no Wi-Fi${NC}"
    fi
else
    echo -e "Resumo: ${AZ}PULADO${NC}"
fi

# 2. Estabilidade Externa
echo -e "\n${A}[2] ESTABILIDADE EXTERNA (INTERNET)${NC}"
ping -c 6 "$TARGET" > resultado_ping.txt
LOSS=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt)
AVG=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

echo -e "Perda: $LOSS% | Latência: ${AVG}ms"
if [ "$LOSS" -gt 0 ]; then echo -e "Resumo: ${VM}PERDA DE PACOTES (Sinal Wi-Fi instável)${NC}"
elif [ "$AVG" -lt 60 ]; then echo -e "Resumo: ${V}BOM${NC}"
else echo -e "Resumo: ${A}MÉDIO${NC}"; fi

# 3. Rastreio
echo -e "\n${A}[3] RASTREIO DE ROTA${NC}"
tracepath -n "$TARGET" | head -n 8

# 4. Velocidade
echo -e "\n${A}[4] VELOCIDADE${NC}"
speedtest-cli --simple 2>/dev/null || echo "Erro no speedtest"

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt
    echo "$SPEED_OUT"
    DOWN=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
    # Lógica de Resumo de Banda
    if [ "$DOWN" -gt 50 ]; then echo -e "Resumo: ${V}ALTA VELOCIDADE${NC}"
    elif [ "$DOWN" -gt 15 ]; then echo -e "Resumo: ${A}VELOCIDADE MÉDIA${NC}"
    else echo -e "Resumo: ${VM}VELOCIDADE BAIXA${NC}"; fi
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt
