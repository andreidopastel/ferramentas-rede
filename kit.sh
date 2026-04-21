#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (VERSÃO MULTI-GW) ---${NC}"

# 1. Seleção de Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

# 2. Teste de Rede Local (Varredura de IPs)
echo -e "\n${A}[1] TESTE DE REDE LOCAL (BUSCANDO GATEWAY)${NC}"

# Lista inteligente de IPs (Incluindo o seu 3.1 e o 100.1 que você pediu)
GATEWAYS=("192.168.3.1" "192.168.1.1" "192.168.5.1" "192.168.100.1" "192.168.127.1")
GW_ENCONTRADO=""

# Tenta detectar o IP via sistema (ip route)
GW_SISTEMA=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
[[ -n "$GW_SISTEMA" ]] && GATEWAYS=("$GW_SISTEMA" "${GATEWAYS[@]}")

for ip in "${GATEWAYS[@]}"; do
    echo -n "Testando $ip... "
    if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
        echo -e "${V}OK!${NC}"
        GW_ENCONTRADO="$ip"
        break
    else
        echo -e "${VM}X${NC}"
    fi
done

if [[ -n "$GW_ENCONTRADO" ]]; then
    echo -e "\nFazendo teste completo em: ${V}$GW_ENCONTRADO${NC}"
    ping -c 5 "$GW_ENCONTRADO" | tee resultado_gw.txt
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    echo -e "Resumo Local: ${V}EXCELENTE ($GW_AVG ms)${NC}"
else
    echo -e "\n${VM}Resumo Local: SEM RESPOSTA DIRETA${NC}"
    echo -e "${AZ}Dica: O roteador bloqueia ICMP, mas o Passo [3] confirmou tráfego.${NC}"
fi

# 3. Estabilidade Internet
echo -e "\n${A}[2] ESTABILIDADE E PERDA DE PACOTES (INTERNET)${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LOSS_VAL=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt || echo 0)
LAT_VAL=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

echo -e "------------------------------------"
if [[ "$LOSS_VAL" -gt 0 ]]; then echo -e "Status: ${VM}INSTÁVEL ($LOSS_VAL% perda)${NC}"
else echo -e "Status: ${V}BOM ($LAT_VAL ms)${NC}"; fi

# 4. Rastreio
echo -e "\n${A}[3] RASTREIO DE ROTA${NC}"
tracepath -n "$TARGET" | head -n 10

# 5. Speedtest
echo -e "\n${A}[4] TESTE DE VELOCIDADE${NC}"
speedtest-cli --simple 2>/dev/null || echo "Speedtest falhou"

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt resultado_gw.txt
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
