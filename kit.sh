#!/data/data/com.termux/files/usr/bin/bash

# Definição de Cores para o terminal
V='\033[0;32m'   # Verde
A='\033[1;33m'   # Amarelo
VM='\033[0;31m'  # Vermelho
AZ='\033[0;34m'  # Azul
NC='\033[0m'     # Sem cor

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (MDNet Edition) ---${NC}"

# Seleção de Alvo
echo -ne "\nAlvo do teste? Padrão 8.8.8.8: "
read -t 10 RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || -z "$TARGET" ]] && TARGET="8.8.8.8"

echo -e "\n${A}[1] RASTREIO DE ROTA (MÁX 10 SALTOS)${NC}"
# Limpa o tracepath para mostrar apenas o que interessa
tracepath -n -m 10 "$TARGET" 2>/dev/null | grep -v "no reply" | grep -v "Too many hops" | uniq | tee rota.txt

# Detecta o Gateway (Roteador) dinamicamente pelo primeiro salto do trace
GW_DETECTADO=$(grep -E "^ 1:" rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)

echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"
# Fallbacks caso o trace falhe em detectar o GW
[[ -z "$GW_DETECTADO" ]] && GW_DETECTADO=$(ip route show | grep default | awk '{print $3}' | head -n 1)
[[ -z "$GW_DETECTADO" ]] && GW_DETECTADO="192.168.3.1"

echo -e "Roteador Local: ${V}$GW_DETECTADO${NC}"

ping -c 5 "$GW_DETECTADO" > resultado_gw.txt 2>&1
if [ $? -eq 0 ]; then
    cat resultado_gw.txt
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
# Comando oficial da Termux:API
WIFI_JSON=$(termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI_JSON" && "$WIFI_JSON" != "{}" ]]; then
    SSID=$(echo "$WIFI_JSON" | grep -oP '(?<="ssid": ")[^"]*' | head -n 1)
    FREQ=$(echo "$WIFI_JSON" | grep -oP '(?<="frequency_mhz": )[0-9]*' | head -n 1)
    RSSI=$(echo "$WIFI_JSON" | grep -oP '(?<="rssi": )[-\d]*' | head -n 1)
    
    echo -e "${AZ}SSID Atual:${NC} ${SSID:-Desconhecido}"
    
    if [[ -n "$FREQ" ]]; then
        echo -ne "${AZ}Frequência:${NC} $FREQ MHz "
        if [ "$FREQ" -lt 3000 ]; then 
            echo -e "${VM}(2.4GHz)${NC}"
        else 
            echo -e "${V}(5GHz)${NC}"
        fi
    fi
    
    if [[ -n "$RSSI" ]]; then
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
