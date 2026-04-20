#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE ---${NC}"

# Pergunta com tempo de espera (se não responder em 10s, usa o padrão)
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
    echo -e "${VM}Gateway não identificado via comando 'ip route'.${NC}"
else
    echo -e "Testando Roteador: $GW"
    ping -c 4 "$GW" | grep "avg" || echo -e "${VM}Sem resposta do roteador.${NC}"
fi

# 2. Estabilidade (Ping)
echo -e "\n${A}[2] ESTABILIDADE E PERDA DE PACOTES${NC}"
ping -c 6 "$TARGET" > resultado_ping.txt
LOSS=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt)
AVG=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}')

if [ -z "$LOSS" ]; then
    echo -e "${VM}Erro ao alcançar o alvo $TARGET${NC}"
else
    echo -e "Perda de Pacotes: ${VM}${LOSS}%${NC}"
    echo -e "Latência Média: ${AZ}${AVG}ms${NC}"
fi

# 3. Rastreio (Tracepath)
echo -e "\n${A}[3] RASTREIO DE ROTA (GARGALOS)${NC}"
tracepath -n "$TARGET" | head -n 8

# 4. Velocidade
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
speedtest-cli --simple || echo -e "${VM}Speedtest indisponível.${NC}"

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm resultado_ping.txt
