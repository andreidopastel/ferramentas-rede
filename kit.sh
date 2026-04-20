#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (LIVE PING) ---${NC}"

# Pergunta Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

echo -e "\n${V}Iniciando testes...${NC}"

# 1. Gateway Local
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"
GW=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
[[ -z "$GW" ]] && GW="192.168.127.1"

echo -e "Pingando Roteador ($GW):"
# O comando 'tee' faz o ping aparecer na tela E salvar no arquivo ao mesmo tempo
ping -c 5 "$GW" | tee resultado_gw.txt
GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

if [[ -n "$GW_AVG" ]]; then
    if [[ "$GW_AVG" -lt 15 ]]; then echo -e "Resumo: ${V}EXCELENTE ($GW_AVG ms)${NC}"
    else echo -e "Resumo: ${A}OSCILANTE ($GW_AVG ms)${NC}"; fi
else
    echo -e "Resumo: ${VM}FALHA NO GATEWAY${NC}"
fi

# 2. Estabilidade Externa (Ping a Ping)
echo -e "\n${A}[2] ESTABILIDADE EXTERNA (INTERNET)${NC}"
echo -e "Pingando $TARGET (10 pacotes):"
# Aqui você verá cada linha do ping conforme ela acontece
ping -c 10 "$TARGET" | tee resultado_ping.txt

LOSS_VAL=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt || echo 0)
LAT_RAW=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
LAT_VAL=${LAT_RAW:-0}

echo -e "\n--- Resumo do Teste [2] ---"
if [[ "$LOSS_VAL" -gt 0 ]]; then echo -e "Status: ${VM}PERDA DE PACOTES ($LOSS_VAL%)${NC}"
elif [[ "$LAT_VAL" -lt 60 ]]; then echo -e "Status: ${V}BOM ($LAT_VAL ms)${NC}"
else echo -e "Status: ${A}MÉDIO ($LAT_VAL ms)${NC}"; fi

# 3. Rastreio e 4. Velocidade (Mantidos para o diagnóstico completo)
echo -e "\n${A}[3] RASTREIO DE ROTA${NC}"
tracepath -n "$TARGET" | head -n 8

echo -e "\n${A}[4] VELOCIDADE (SPEEDTEST)${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
if [[ -n "$SPEED_OUT" ]]; then
    echo "$SPEED_OUT"
    DOWN_VAL=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
    if [[ "${DOWN_VAL:-0}" -gt 15 ]]; then echo -e "Resumo: ${V}VELOCIDADE OK${NC}"
    else echo -e "Resumo: ${VM}VELOCIDADE BAIXA${NC}"; fi
else
    echo -e "Resumo: ${VM}SPEEDTEST INDISPONÍVEL${NC}"
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt resultado_gw.txt
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
