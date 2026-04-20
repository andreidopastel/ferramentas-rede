#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE ---${NC}"

# Pergunta ao usuário qual o alvo do teste
echo -e "\nDeseja usar o alvo padrão (${AZ}8.8.8.8${NC})?"
read -p "Digite 'y' para SIM ou digite o IP/HOST desejado: " ALVO

if [ "$ALVO" == "y" ] || [ "$ALVO" == "Y" ]; then
    TARGET="8.8.8.8"
else
    TARGET=$ALVO
fi

echo -e "\n${V}Iniciando testes para: ${AZ}$TARGET${NC}"

# 1. Gateway Local (Roteador)
GW=$(ip route | grep default | awk '{print $3}')
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"
ping -c 5 $GW | grep "avg" || echo -e "${VM}Roteador inacessível!${NC}"

# 2. Perda de Pacotes e Jitter
echo -e "\n${A}[2] ESTABILIDADE E PERDA DE PACOTES${NC}"
PING_EXT=$(ping -c 10 $TARGET)
LOSS=$(echo "$PING_EXT" | grep -oP '\d+(?=% packet loss)')
AVG=$(echo "$PING_EXT" | grep "avg" | awk -F'/' '{print $5}')
MDEV=$(echo "$PING_EXT" | grep "avg" | awk -F'/' '{print $7}' | cut -d' ' -f1)

echo -e "Alvo: ${AZ}$TARGET${NC}"
echo -e "Perda de Pacotes: ${VM}${LOSS}%${NC}"
echo -e "Latência Média: ${AZ}${AVG}ms${NC}"
echo -e "Jitter (Instabilidade): ${AZ}${MDEV}ms${NC}"

# 3. Rastreio de Rota
echo -e "\n${A}[3] RASTREIO DE ROTA (GARGALOS)${NC}"
tracepath -n $TARGET | head -n 8

# 4. Velocidade de Banda
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
speedtest-cli --simple

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
