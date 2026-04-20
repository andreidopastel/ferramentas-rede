#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (COM RESUMO) ---${NC}"

echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP

if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ] || [ -z "$RESP" ]; then
    TARGET="8.8.8.8"
else
    TARGET=$RESP
fi

echo -e "\n${V}Iniciando testes... aguarde.${NC}"

# 1. Estabilidade e Perda (Ping)
ping -c 10 "$TARGET" > resultado_ping.txt
LOSS=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt)
AVG=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
MDEV=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $7}' | cut -d'.' -f1)

# 2. Velocidade (Speedtest)
echo -e "${A}Medindo velocidade de banda...${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
DOWNLOAD=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)

clear
echo -e "${V}--- RESULTADO DO DIAGNÓSTICO ---${NC}"
echo -e "Alvo: $TARGET"
echo -e "--------------------------------"

# Lógica de Avaliação de Latência (Ping)
if [ "$AVG" -lt 50 ]; then STATUS_PING="${V}BOM (Baixa)${NC}";
elif [ "$AVG" -lt 150 ]; then STATUS_PING="${A}MÉDIO (Moderada)${NC}";
else STATUS_PING="${VM}RUIM (Alta)${NC}"; fi

# Lógica de Avaliação de Estabilidade (Jitter/MDEV)
if [ "$MDEV" -lt 10 ]; then STATUS_JITTER="${V}EXCELENTE${NC}";
elif [ "$MDEV" -lt 30 ]; then STATUS_JITTER="${A}OSCILANTE${NC}";
else STATUS_JITTER="${VM}INSTÁVEL${NC}"; fi

# Lógica de Perda de Pacotes
if [ "$LOSS" -eq 0 ]; then STATUS_LOSS="${V}NENHUMA${NC}";
else STATUS_LOSS="${VM}CRÍTICA ($LOSS%)${NC}"; fi

# Exibição do Resumo
echo -e "LATÊNCIA:   $AVG ms -> $STATUS_PING"
echo -e "JITTER:     $MDEV ms -> $STATUS_JITTER"
echo -e "PERDA:      $STATUS_LOSS"
echo -e "DOWNLOAD:   $DOWNLOAD Mbps"

echo -e "--------------------------------"
echo -n "VEREDITO FINAL: "

if [ "$LOSS" -gt 0 ]; then echo -e "${VM}CONEXÃO COM FALHAS (PERDA DE DADOS)${NC}";
elif [ "$AVG" -gt 150 ] || [ "$MDEV" -gt 30 ]; then echo -e "${A}CONEXÃO LENTA/INSTÁVEL (GARGALO)${NC}";
else echo -e "${V}CONEXÃO SAUDÁVEL${NC}"; fi

echo -e "--------------------------------"
rm resultado_ping.txt
