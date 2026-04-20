#!/data/data/com.termux/files/usr/bin/bash

# Cores para o terminal
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (VERSÃO COMPLETA) ---${NC}"

# 1. Seleção de Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

echo -e "\n${V}Iniciando Diagnóstico para: ${AZ}$TARGET${NC}"

# 2. Teste de Rede Local (Gateway)
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"
# Tenta pegar o IP do roteador sem mostrar erros de permissão
GW=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
[[ -z "$GW" ]] && GW="192.168.127.1" # Seu IP detectado anteriormente

echo -e "Pingando Roteador ($GW):"
ping -c 5 "$GW" | tee resultado_gw.txt
GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

if [[ -n "$GW_AVG" ]]; then
    if [[ "$GW_AVG" -lt 15 ]]; then 
        echo -e "Resumo Local: ${V}EXCELENTE ($GW_AVG ms)${NC}"
    else 
        echo -e "Resumo Local: ${A}OSCILANTE ($GW_AVG ms)${NC}"
    fi
else
    echo -e "Resumo Local: ${VM}SEM RESPOSTA (O roteador pode estar bloqueando pings)${NC}"
fi

# 3. Estabilidade e Perda de Pacotes (LIVE PING)
echo -e "\n${A}[2] ESTABILIDADE E PERDA DE PACOTES (INTERNET)${NC}"
echo -e "Monitorando $TARGET em tempo real:"
echo "------------------------------------"
ping -c 10 "$TARGET" | tee resultado_ping.txt
echo "------------------------------------"

# Extração segura de dados
LOSS_VAL=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt || echo 0)
LAT_RAW=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
LAT_VAL=${LAT_RAW:-0}

if [[ "$LOSS_VAL" -gt 0 ]]; then 
    echo -e "Resumo Internet: ${VM}INSTÁVEL (Perda de $LOSS_VAL%)${NC}"
elif [[ "$LAT_VAL" -lt 60 ]]; then 
    echo -e "Resumo Internet: ${V}BOM ($LAT_VAL ms)${NC}"
else 
    echo -e "Resumo Internet: ${A}MÉDIO ($LAT_VAL ms)${NC}"
fi

# 4. Rastreio de Rota (Gargalos)
echo -e "\n${A}[3] RASTREIO DE ROTA (HOP BY HOP)${NC}"
tracepath -n "$TARGET" | head -n 10
echo -e "${AZ}Dica: O primeiro salto é o seu roteador, o segundo é a sua operadora.${NC}"

# 5. Velocidade (Speedtest)
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
if [[ -n "$SPEED_OUT" ]]; then
    echo "$SPEED_OUT"
    DOWN_RAW=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
    DOWN_VAL=${DOWN_RAW:-0}
    
    if [[ "$DOWN_VAL" -gt 50 ]]; then 
        echo -e "Resumo Banda: ${V}ALTA VELOCIDADE${NC}"
    elif [[ "$DOWN_VAL" -gt 15 ]]; then 
        echo -e "Resumo Banda: ${A}VELOCIDADE MÉDIA${NC}"
    else 
        echo -e "Resumo Banda: ${VM}VELOCIDADE BAIXA${NC}"
    fi
else
    echo -e "Resumo Banda: ${VM}SPEEDTEST FALHOU (Verifique conexão)${NC}"
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"

# Limpeza de arquivos temporários
rm -f resultado_ping.txt resultado_gw.txt

