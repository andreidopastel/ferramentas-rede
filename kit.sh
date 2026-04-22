#!/bin/bash

# --- CONFIGURAÇÃO DE CORES ---
VM='\033[0;31m'
V='\033[0;32m'
AZ='\033[0;34m'
A='\033[1;33m'
NC='\033[0m'

TARGET="8.8.8.8"

echo -e "${A}--- CANIVETE SUÍÇO DE REDE (MDNet Edition) ---${NC}"

# [1] RASTREIO DE ROTA (ROTA COMPLETA)
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
# Sem o limite de 10 saltos para ver a rota inteira até o destino
tracepath -n "$TARGET"

# [2] TESTE DE REDE LOCAL
echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"
GATEWAY=$(ip route | grep default | awk '{print $3}')
if [ -n "$GATEWAY" ]; then
    echo -e "${AZ}Roteador Local:${NC} $GATEWAY"
    ping -c 3 "$GATEWAY" | grep "time=" || echo -e "${VM}Erro ao pingar roteador. Verifique o Wi-Fi.${NC}"
else
    echo -e "${VM}Erro: Gateway não encontrado.${NC}"
fi

# [3] ESTABILIDADE DA INTERNET
echo -e "\n${A}[3] ESTABILIDADE DA INTERNET (PING)${NC}"
ping -c 10 "$TARGET" | grep -E "packets|avg"

# [4] TESTE DE VELOCIDADE
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
if command -v speedtest-cli &> /dev/null; then
    speedtest-cli --simple
else
    echo -e "${VM}Speedtest-cli não instalado. Rode: pip install speedtest-cli${NC}"
fi

# [5] INFORMAÇÕES TÉCNICAS WI-FI (COM CANAL E BANDA)
echo -e "\n${A}[5] INFORMAÇÕES TÉCNICAS WI-FI${NC}"
# Timeout de 3s para não travar o script se o GPS estiver desligado
WIFI_JSON=$(timeout 3 termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI_JSON" && "$WIFI_JSON" != "{}" ]]; then
    SSID=$(echo "$WIFI_JSON" | grep -oP '(?<="ssid": ")[^"]*' | head -n 1)
    FREQ=$(echo "$WIFI_JSON" | grep -oP '(?<="frequency_mhz": )[0-9]*' | head -n 1)
    RSSI=$(echo "$WIFI_JSON" | grep -oP '(?<="rssi": )[-\d]*' | head -n 1)
    IP_WIFI=$(echo "$WIFI_JSON" | grep -oP '(?<="ip": ")[^"]*' | head -n 1)

    # Lógica para cálculo de Canal
    if [ "$FREQ" -ge 2412 ] && [ "$FREQ" -le 2484 ]; then
        CANAL=$(( (FREQ - 2412) / 5 + 1 ))
        BANDA="2.4GHz"
    elif [ "$FREQ" -ge 5170 ] && [ "$FREQ" -le 5825 ]; then
        CANAL=$(( (FREQ - 5170) / 5 + 34 )) # Cálculo aproximado para 5G
        BANDA="5GHz"
    else
        CANAL="N/A"
        BANDA="Desconhecida"
    fi

    echo -e "${AZ}SSID:${NC} $SSID"
    echo -e "${AZ}IP Dispositivo:${NC} $IP_WIFI"
    echo -e "${AZ}Frequência:${NC} $FREQ MHz (${V}$BANDA${NC})"
    echo -e "${AZ}Canal Atual:${NC} ${A}$CANAL${NC}"
    echo -e "${AZ}Sinal (RSSI):${NC} ${RSSI} dBm"
    
    # Diagnóstico rápido de sinal
    if [ "$RSSI" -le -80 ]; then echo -e "${VM}ALERTA: Sinal muito fraco!${NC}"; fi
else
    echo -e "${VM}Erro: Falha na API. Verifique GPS e Permissões do Termux:API.${NC}"
fi

echo -e "\n${A}--- DIAGNÓSTICO FINALIZADO ---${NC}"
        echo -ne "${AZ}Força do Sinal:${NC} ${RSSI} dBm "
        if [ "$RSSI" -ge -50 ]; then echo -e "${V}(Excelente)${NC}";
        elif [ "$RSSI" -ge -70 ]; then echo -e "${A}(Bom)${NC}";
        else echo -e "${VM}(Ruim/Instável)${NC}"; fi
    fi
else
    echo -e "${VM}Erro: Não foi possível obter dados do Wi-Fi.${NC}"
    echo -e "Certifique-se de que o GPS está ligado e o Termux:API tem permissão de Localização."
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"

# Limpeza de ficheiros temporários
rm -f rota.txt resultado_gw.txt resultado_ping.txt
