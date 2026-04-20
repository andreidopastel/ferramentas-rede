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
echo -n "Digite 'y' para SIM ou digite o IP/HOST: "
read RESP

if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ] || [ -z "$RESP" ]; then
    TARGET="8.8.8.8"
else
    TARGET=$RESP
fi

echo -e "\n${V}Iniciando testes para: ${AZ}$TARGET${NC}"

# 1. Gateway Local (Roteador)
# Corrigido: Se não achar o IP, ele não tenta dar ping no vazio
GW=$(ip route | grep default | awk '{print $3}' | head -n 1)
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"
if [ -z "$GW" ]; then
    echo -e "${VM}Erro: Gateway não encontrado (Verifique se o Wi-Fi está ligado).${NC}"
else
    ping -c 5 "$GW" | grep "avg" || echo -e "${VM}Roteador inacessível!${NC}"
fi

# 2. Perda de Pacotes e Jitter
echo -e "\n${A}[2] ESTABILIDADE E PERDA DE PACOTES${NC}"
# Corrigido: Usando aspas para garantir que o alvo seja lido
PING_EXT=$(ping -c 10 "$TARGET" 2>/dev/null)
if [ $? -eq 0 ]; then
    LOSS=$(echo "$PING_EXT" | grep -oP '\d+(?=% packet loss)')
    AVG=$(echo "$PING_EXT" | grep "avg" | awk -F'/' '{print $5}')
    MDEV=$(echo "$PING_EXT" | grep "avg" | awk -F'/' '{print $7}' | cut -d' ' -f1)

    echo -e "Alvo: ${AZ}$TARGET${NC}"
    echo -e "Perda de Pacotes: ${VM}${LOSS}%${NC}"
    echo -e "Latência Média: ${AZ}${AVG}ms${NC}"
    echo -e "Jitter (Instabilidade): ${AZ}${MDEV}ms${NC}"
else
    echo -e "${VM}Erro: Não foi possível alcançar o alvo $TARGET${NC}"
fi

# 3. Rastreio de Rota
echo -e "\n${A}[3] RASTREIO DE ROTA (GARGALOS)${NC}"
# Corrigido: Adicionado o alvo no comando tracepath
tracepath -n "$TARGET" | head -n 10

# 4. Velocidade de Banda
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
speedtest-cli --simple || echo -e "${VM}Speedtest falhou.${NC}"

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
