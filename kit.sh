#!/data/data/com.termux/files/usr/bin/bash

# --- CONFIGURAÇÃO DE CORES ---
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

# [1] RASTREIO DE ROTA INTELIGENTE (PARA NO ALVO)
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
> rota.txt
tracepath -n "$TARGET" 2>/dev/null | while read -r line; do
    if [[ "$line" != *"no reply"* ]]; then
        echo "$line" | tee -a rota.txt
    fi
    if [[ "$line" == *"$TARGET"* ]]; then
        echo -e "${V}Destino atingido.${NC}"
        pkill -P $$ tracepath 2>/dev/null
        break
    fi
done

# [2] TESTE DE REDE LOCAL (DETECÇÃO DINÂMICA)
echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"

# Tentativa 1: Pega do salto 1 do arquivo rota.txt
GW_DETECTADO=$(grep -m 1 "1: " rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

# Tentativa 2: Se falhar, descobre o IP do próprio celular e assume final .1 (Fallback Inteligente)
if [[ -z "$GW_DETECTADO" ]]; then
    MEU_IP=$(ip addr show wlan0 | grep -w inet | awk '{print $2}' | cut -d/ -f1)
    if [[ -n "$MEU_IP" ]]; then
        GW_DETECTADO=$(echo "$MEU_IP" | cut -d. -f1-3).1
    fi
fi

# Se tudo falhar, usa um comando de vizinhos
[[ -z "$GW_DETECTADO" ]] && GW_DETECTADO=$(ip neigh show | grep "router" | awk '{print $1}' | head -n 1)

echo -e "Roteador Local Detectado: ${V}$GW_DETECTADO${NC}"

# Pinga o IP detectado
ping -c 3 "$GW_DETECTADO" > resultado_gw.txt 2>&1
if [ $? -eq 0 ]; then
    cat resultado_gw.txt | grep "time="
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    echo -e "Latência Média Local: ${V}${GW_AVG:-0} ms${NC}"
else
    echo -e "${VM}Erro ao pingar roteador ($GW_DETECTADO).${NC}"
fi

# [3] ESTABILIDADE DA INTERNET
echo -e "\n${A}[3] ESTABILIDADE DA INTERNET${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LAT_AVG=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Latência Média Google: ${V}${LAT_AVG:-0} ms${NC}"

# [4] TESTE DE VELOCIDADE
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
if command -v speedtest-cli &> /dev/null; then
    speedtest-cli --simple
else
    echo -e "${VM}Speedtest-cli não instalado.${NC}"
fi

# [5] INFORMAÇÕES TÉCNICAS WI-FI (COM CANAL)
echo -e "\n${A}[5] INFORMAÇÕES TÉCNICAS WI-FI${NC}"
WIFI_JSON=$(timeout 3 termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI_JSON" && "$WIFI_JSON" != "{}" ]]; then
    SSID=$(echo "$WIFI_JSON" | grep -oP '(?<="ssid": ")[^"]*' | head -n 1)
    FREQ=$(echo "$WIFI_JSON" | grep -oP '(?<="frequency_mhz": )[0-9]*' | head -n 1)
    RSSI=$(echo "$WIFI_JSON" | grep -oP '(?<="rssi": )[-\d]*' | head -n 1)
    
    echo -e "${AZ}SSID:${NC} ${SSID:-Desconhecido}"
    
    if [[ -n "$FREQ" ]]; then
        # Lógica de Banda e Canal
        if [ "$FREQ" -lt 3000 ]; then 
            BANDA="2.4GHz"
            CANAL=$(( (FREQ - 2412) / 5 + 1 ))
        else 
            BANDA="5GHz"
            CANAL=$(( (FREQ - 5170) / 5 + 34 ))
        fi
        echo -e "${AZ}Frequência:${NC} $FREQ MHz ${V}($BANDA)${NC}"
        echo -e "${AZ}Canal Atual:${NC} ${A}$CANAL${NC}"
    fi
    
    if [[ -n "$RSSI" ]]; then
        echo -ne "${AZ}Força do Sinal:${NC} ${RSSI} dBm "
        if [ "$RSSI" -ge -60 ]; then echo -e "${V}(Excelente)${NC}";
        elif [ "$RSSI" -ge -75 ]; then echo -e "${A}(Bom)${NC}";
        else echo -e "${VM}(Ruim)${NC}"; fi
    fi
else
    echo -e "${VM}Erro: API não respondeu. Ligue o GPS.${NC}"
fi

echo -e "\n${V}---- DIAGNÓSTICO FINALIZADO ----${NC}"

# Limpeza silenciosa
rm -f rota.txt resultado_gw.txt resultado_ping.txt
