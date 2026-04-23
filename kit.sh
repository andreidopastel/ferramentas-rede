#!/data/data/com.termux/files/usr/bin/bash

# --- CONFIGURAÇÃO DE CORES ---
V='\033[0;32m'   # Verde
A='\033[1;33m'   # Amarelo
VM='\033[0;31m'  # Vermelho
AZ='\033[0;34m'  # Azul
NC='\033[0m'     # Sem cor

clear
echo -e "${V}---- FERRAMENTA DE REDE ----${NC}"

# --- ALVO ---
echo -ne "\nAlvo do teste? Padrão 8.8.8.8: "
read -t 10 RESP
TARGET=${RESP:-8.8.8.8}

# --- [1] ROTA ---
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

# --- [2] REDE LOCAL ---
echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"

GW_DETECTADO=$(grep -m 1 "1: " rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

if [[ -z "$GW_DETECTADO" ]]; then
    MEU_IP=$(ip addr show wlan0 2>/dev/null | grep -w inet | awk '{print $2}' | cut -d/ -f1)
    [[ -n "$MEU_IP" ]] && GW_DETECTADO=$(echo "$MEU_IP" | cut -d. -f1-3).1
fi

[[ -z "$GW_DETECTADO" ]] && GW_DETECTADO=$(ip neigh show | awk '{print $1}' | head -n 1)

echo -e "Roteador Local Detectado: ${V}$GW_DETECTADO${NC}"

ping -c 3 "$GW_DETECTADO" > resultado_gw.txt 2>&1

if [ $? -eq 0 ]; then
    cat resultado_gw.txt | grep "time="
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    echo -e "Latência Média Local: ${V}${GW_AVG:-0} ms${NC}"
else
    echo -e "${VM}Erro ao pingar roteador.${NC}"
fi

# --- [3] INTERNET ---
echo -e "\n${A}[3] ESTABILIDADE DA INTERNET${NC}"

ping -c 10 "$TARGET" | tee resultado_ping.txt

LAT_AVG=$(grep "rtt" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

echo -e "Latência Média Google: ${V}${LAT_AVG:-0} ms${NC}"

# --- [4] SPEEDTEST ---
echo -e "\n${A}[4] TESTE DE VELOCIDADE${NC}"

if command -v speedtest-cli &> /dev/null; then
    speedtest-cli --simple
else
    echo -e "${VM}speedtest-cli não instalado.${NC}"
fi

# --- [5] WIFI INFO ---
echo -e "\n${A}[5] INFORMAÇÕES WI-FI${NC}"

WIFI_JSON=$(timeout 3 termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI_JSON" && "$WIFI_JSON" != "{}" ]]; then
    SSID=$(echo "$WIFI_JSON" | grep -oP '(?<="ssid": ")[^"]*')
    FREQ=$(echo "$WIFI_JSON" | grep -oP '(?<="frequency_mhz": )[0-9]*')
    RSSI=$(echo "$WIFI_JSON" | grep -oP '(?<="rssi": )[-0-9]*')

    echo -e "${AZ}SSID:${NC} $SSID"

    if [[ -n "$FREQ" ]]; then
        if [ "$FREQ" -lt 3000 ]; then
            BANDA="2.4GHz"
            CANAL=$(( (FREQ - 2412) / 5 + 1 ))
        else
            BANDA="5GHz"
            CANAL=$(( (FREQ - 5170) / 5 + 34 ))
        fi

        echo -e "${AZ}Frequência:${NC} $FREQ MHz ($BANDA)"
        echo -e "${AZ}Canal:${NC} $CANAL"
    fi

    if [[ -n "$RSSI" ]]; then
        echo -ne "${AZ}Sinal:${NC} $RSSI dBm "

        if [ "$RSSI" -ge -60 ]; then
            echo -e "${V}(Excelente)${NC}"
        elif [ "$RSSI" -ge -75 ]; then
            echo -e "${A}(Bom)${NC}"
        else
            echo -e "${VM}(Ruim)${NC}"
        fi
    fi
else
    echo -e "${VM}Erro: ative GPS/localização.${NC}"
fi

# --- [6] SCAN WI-FI ---
echo -e "\n${A}[6] SCAN DE CANAIS WI-FI${NC}"

SCAN_JSON=$(timeout 5 termux-wifi-scaninfo 2>/dev/null)

if [[ -n "$SCAN_JSON" && "$SCAN_JSON" != "[]" ]]; then
    echo -e "${AZ}Redes encontradas:${NC}\n"

    echo "$SCAN_JSON" | grep -oP '{[^}]*}' | while read -r rede; do
        SSID=$(echo "$rede" | grep -oP '(?<="ssid":")[^"]*')
        FREQ=$(echo "$rede" | grep -oP '(?<="frequency_mhz":)[0-9]*')
        RSSI=$(echo "$rede" | grep -oP '(?<="rssi":)-?[0-9]*')

        if [[ -n "$FREQ" ]]; then
            if [ "$FREQ" -lt 3000 ]; then
                CANAL=$(( (FREQ - 2412) / 5 + 1 ))
            else
                CANAL=$(( (FREQ - 5170) / 5 + 34 ))
            fi
        fi

        echo -e "${V}SSID:${NC} ${SSID:-Oculto}"
        echo -e "Canal: ${A}${CANAL:-?}${NC} | Freq: $FREQ MHz | Sinal: $RSSI dBm"
        echo "-----------------------------"
    done
else
    echo -e "${VM}Nenhuma rede detectada (GPS/permissão).${NC}"
fi

# --- FINAL ---
echo -e "\n${V}---- DIAGNÓSTICO FINALIZADO ----${NC}"

rm -f rota.txt resultado_gw.txt resultado_ping.txt
