#!/bin/bash

# --- CONFIGURAÇÃO DE CORES ---
VM='\033[0;31m'
V='\033[0;32m'
AZ='\033[0;34m'
A='\033[1;33m'
NC='\033[0m'

TARGET="8.8.8.8"

# Título em Verde conforme solicitado
echo -e "${V}---- FERRAMENTA DE REDE ----${NC}"

# [1] RASTREIO DE ROTA INTELIGENTE (PARA NO DESTINO)
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
# Usando um loop para interromper assim que o alvo for atingido
tracepath -n "$TARGET" | while read -r line; do
    echo "$line"
    # Se a linha contiver o IP de destino, interrompe o processo
    if [[ "$line" == *"$TARGET"* ]]; then
        echo -e "${V}Destino atingido.${NC}"
        pkill -P $$ tracepath 2>/dev/null
        break
    fi
done

# [2] TESTE DE REDE LOCAL (GATEWAY)
echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"
GATEWAY=$(ip route | grep default | awk '{print $3}')
if [ -n "$GATEWAY" ]; then
    echo -e "${AZ}Roteador Local:${NC} $GATEWAY"
    ping -c 3 "$GATEWAY" | grep "time=" || echo -e "${VM}Erro ao pingar roteador.${NC}"
else
    echo -e "${VM}Erro: Gateway não encontrado.${NC}"
fi

# [3] TESTE DE VELOCIDADE (SPEEDTEST)
echo -e "\n${A}[3] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
if command -v speedtest-cli &> /dev/null; then
    speedtest-cli --simple
else
    echo -e "${VM}Instale o speedtest-cli (pip install speedtest-cli)${NC}"
fi

# [4] INFORMAÇÕES TÉCNICAS WI-FI (CANAL E BANDA)
echo -e "\n${A}[4] INFORMAÇÕES TÉCNICAS WI-FI${NC}"
WIFI_JSON=$(timeout 3 termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI_JSON" && "$WIFI_JSON" != "{}" ]]; then
    SSID=$(echo "$WIFI_JSON" | grep -oP '(?<="ssid": ")[^"]*' | head -n 1)
    FREQ=$(echo "$WIFI_JSON" | grep -oP '(?<="frequency_mhz": )[0-9]*' | head -n 1)
    RSSI=$(echo "$WIFI_JSON" | grep -oP '(?<="rssi": )[-\d]*' | head -n 1)
    
    # Cálculo de Canais para 2.4GHz e 5GHz
    if [ "$FREQ" -ge 2412 ] && [ "$FREQ" -le 2484 ]; then
        CANAL=$(( (FREQ - 2412) / 5 + 1 ))
        BANDA="2.4GHz"
    elif [ "$FREQ" -ge 5170 ] && [ "$FREQ" -le 5825 ]; then
        # Cálculo básico para canais de 5GHz
        CANAL=$(( (FREQ - 5170) / 5 + 34 ))
        BANDA="5GHz"
    else
        CANAL="N/A"
        BANDA="Desconhecida"
    fi

    echo -e "${AZ}SSID:${NC} $SSID"
    echo -e "${AZ}Banda:${NC} ${V}$BANDA${NC}"
    echo -e "${AZ}Canal:${NC} ${A}$CANAL${NC} (Freq: $FREQ MHz)"
    echo -e "${AZ}Sinal:${NC} ${RSSI} dBm"

    # Alerta de sinal para o técnico
    if [ "$RSSI" -le -75 ]; then 
        echo -e "${VM}CUIDADO: Sinal fraco detectado!${NC}"
    fi
else
    echo -e "${VM}Erro: Ligue o GPS e verifique o Termux:API.${NC}"
fi

echo -e "\n${V}---- DIAGNÓSTICO FINALIZADO ----${NC}"
