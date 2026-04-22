#!/data/data/com.termux/files/usr/bin/bash

# Definição de Cores para o terminal
V='\033[0;32m'   # Verde
A='\033[1;33m'   # Amarelo
VM='\033[0;31m'  # Vermelho
AZ='\033[0;34m'  # Azul
NC='\033[0m'     # Sem cor

clear
# Título em Verde como solicitado
echo -e "${V}---- FERRAMENTA DE REDE ----${NC}"

# Seleção de Alvo
echo -ne "\nAlvo do teste? Padrão 8.8.8.8: "
read -t 10 RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || -z "$TARGET" ]] && TARGET="8.8.8.8"

# [1] RASTREIO DE ROTA INTELIGENTE (Para assim que encontra o alvo)
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
> rota.txt # Limpa o arquivo antes de começar
tracepath -n "$TARGET" 2>/dev/null | while read -r line; do
    # Remove "no reply" e linhas inúteis para o técnico
    if [[ "$line" != *"no reply"* && "$line" != *"Too many hops"* ]]; then
        echo "$line" | tee -a rota.txt
    fi
    # Se encontrar o IP do alvo, mata o processo e para
    if [[ "$line" == *"$TARGET"* ]]; then
        echo -e "${V}Destino atingido.${NC}"
        pkill -P $$ tracepath 2>/dev/null
        break
    fi
done

# Detecta o Gateway (Roteador) dinamicamente
GW_DETECTADO=$(grep -E "^ 1:" rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)

echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"
[[ -z "$GW_DETECTADO" ]] && GW_DETECTADO=$(ip route show | grep default | awk '{print $3}' | head -n 1)
[[ -z "$GW_DETECTADO" ]] && GW_DETECTADO="192.168.1.1"

echo -e "Roteador Local: ${V}$GW_DETECTADO${NC}"

ping -c 5 "$GW_DETECTADO" > resultado_gw.txt 2>&1
if [ $? -eq 0 ]; then
    cat resultado_gw.txt | grep "time="
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    echo -e "Latência Média Local: ${V}${GW_AVG:-0} ms${NC}"
else
    echo -e "${VM}Erro ao pingar roteador. Verifique a conexão Wi-Fi.${NC}"
fi

echo -e "\n${A}[3] ESTABILIDADE DA INTERNET${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LAT_AVG=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Latência Média Google: ${V}${LAT_AVG:-0} ms${NC}"

echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
speedtest-cli --simple 2>/dev/null || echo -e "${VM}Speedtest-cli não instalado ou sem internet.${NC}"

echo -e "\n${A}[5] INFORMAÇÕES TÉCNICAS WI-FI${NC}"
WIFI_JSON=$(timeout 3 termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI_JSON" && "$WIFI_JSON" != "{}" ]]; then
    SSID=$(echo "$WIFI_JSON" | grep -oP '(?<="ssid": ")[^"]*' | head -n 1)
    FREQ=$(echo "$WIFI_JSON" | grep -oP '(?<="frequency_mhz": )[0-9]*' | head -n 1)
    RSSI=$(echo "$WIFI_JSON" | grep -oP '(?<="rssi": )[-\d]*' | head -n 1)
    
    echo -e "${AZ}SSID Atual:${NC} ${SSID:-Desconhecido}"
    
    if [[ -n "$FREQ" ]]; then
        # Cálculo de Canais e Bandas
        if [ "$FREQ" -ge 2412 ] && [ "$FREQ" -le 2484 ]; then
            CANAL=$(( (FREQ - 2412) / 5 + 1 ))
            BANDA="2.4GHz"
        elif [ "$FREQ" -ge 5170 ] && [ "$FREQ" -le 5825 ]; then
            CANAL=$(( (FREQ - 5170) / 5 + 34 ))
            BANDA="5GHz"
        fi
        
        echo -e "${AZ}Frequência:${NC} $FREQ MHz ${V}($BANDA)${NC}"
        echo -e "${AZ}Canal Atual:${NC} ${A}$CANAL${NC}"
    fi
    
    if [[ -n "$RSSI" ]]; then
        echo -ne "${AZ}Força do Sinal:${NC} ${RSSI} dBm "
        if [ "$RSSI" -ge -50 ]; then echo -e "${V}(Excelente)${NC}";
        elif [ "$RSSI" -ge -70 ]; then echo -e "${A}(Bom)${NC}";
        else echo -e "${VM}(Ruim/Instável)${NC}"; fi
    fi
else
    echo -e "${VM}Erro: Não foi possível obter dados do Wi-Fi.${NC}"
fi

echo -e "\n${V}---- DIAGNÓSTICO FINALIZADO ----${NC}"

# Limpeza silenciosa
rm -f rota.txt resultado_gw.txt resultado_ping.txt
