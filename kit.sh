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

# 2. Teste de Rede Local (Gateway Multi-IP)
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"

# Lista de IPs comuns de gateways conforme solicitado
GATEWAYS=("192.168.127.1" "192.168.1.1" "192.168.3.1" "192.168.5.1" "192.168.100.1")
GW_ENCONTRADO=""

# Tenta pegar o IP real pelo sistema primeiro
GW_SISTEMA=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
[[ -n "$GW_SISTEMA" ]] && GATEWAYS=("$GW_SISTEMA" "${GATEWAYS[@]}")

echo -e "Buscando roteador ativo na lista..."

for ip in "${GATEWAYS[@]}"; do
    # Tenta um ping rápido de 1 segundo em cada IP da lista
    if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
        GW_ENCONTRADO="$ip"
        break
    fi
done

if [[ -n "$GW_ENCONTRADO" ]]; then
    echo -e "Roteador encontrado: ${V}$GW_ENCONTRADO${NC}"
    ping -c 5 "$GW_ENCONTRADO" | tee resultado_gw.txt
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    
    if [[ "$GW_AVG" -lt 15 ]]; then 
        echo -e "Resumo Local: ${V}EXCELENTE ($GW_AVG ms)${NC}"
    else 
        echo -e "Resumo Local: ${A}OSCILANTE ($GW_AVG ms)${NC}"
    fi
else
    echo -e "Resumo Local: ${VM}SEM RESPOSTA DIRETA${NC}"
    echo -e "${AZ}Dica: O roteador bloqueia ping, mas o Passo [3] mostrará o tráfego.${NC}"
fi

# 3. Estabilidade e Perda de Pacotes (LIVE PING)
echo -e "\n${A}[2] ESTABILIDADE E PERDA DE PACOTES (INTERNET)${NC}"
echo -e "Monitorando $TARGET em tempo real:"
echo "------------------------------------"
ping -c 10 "$TARGET" | tee resultado_ping.txt
echo "------------------------------------"

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

# 4. Rastreio de Rota
echo -e "\n${A}[3] RASTREIO DE ROTA (HOP BY HOP)${NC}"
tracepath -n "$TARGET" | head -n 10

# 5. Velocidade
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
if [[ -n "$SPEED_OUT" ]]; then
    echo "$SPEED_OUT"
    DOWN_RAW=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
    DOWN_VAL=${DOWN_RAW:-0}
    
    if [[ "$DOWN_VAL" -gt 50 ]]; then echo -e "Resumo Banda: ${V}ALTA VELOCIDADE${NC}"
    elif [[ "$DOWN_VAL" -gt 15 ]]; then echo -e "Resumo Banda: ${A}VELOCIDADE MÉDIA${NC}"
    else echo -e "Resumo Banda: ${VM}VELOCIDADE BAIXA${NC}"; fi
else
    echo -e "Resumo Banda: ${VM}SPEEDTEST INDISPONÍVEL${NC}"
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt resultado_gw.txt
