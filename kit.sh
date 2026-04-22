#!/data/data/com.termux/files/usr/bin/bash

# --- CONFIGURAÇÃO DE CORES ---
V='\033[0;32m'   # Verde
A='\033[1;33m'   # Amarelo
VM='\033[0;31m'  # Vermelho
AZ='\033[0;34m'  # Azul
NC='\033[0m'     # Sem cor

clear
# Título em Verde
echo -e "${V}---- FERRAMENTA DE REDE ----${NC}"

# Seleção de Alvo
echo -ne "\nAlvo do teste? Padrão 8.8.8.8: "
read -t 10 RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || -z "$TARGET" ]] && TARGET="8.8.8.8"

# [1] RASTREIO DE ROTA INTELIGENTE (PARA NO DESTINO)
echo -e "\n${A}[1] RASTREIO DE ROTA${NC}"
> rota.txt
# Loop para garantir que pare ao encontrar o IP final
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

# [2] TESTE DE REDE LOCAL (CORREÇÃO DE FALHA)
echo -e "\n${A}[2] TESTE DE REDE LOCAL${NC}"
# Tenta extrair o IP do roteador do primeiro salto do arquivo gerado
GW_DETECTADO=$(grep -m 1 "1: " rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

# Se falhar (erro de permissão no trace), tenta via comando de vizinhos (mais seguro no Android)
if [[ -z "$GW_DETECTADO" ]]; then
    GW_DETECTADO=$(ip neighbor show | grep -m 1 "router" | awk '{print $1}')
fi

# Fallback final: Pega o IP do Wi-Fi e assume final .1
if [[ -z "$GW_DETECTADO" ]]; then
    IP_LOCAL=$(ip addr show wlan0 2>/dev/null | grep -w inet | awk '{print $2}' | cut -d/ -f1)
    GW_DETECTADO=$(echo "$IP_LOCAL" | cut -d. -f1-3).1
fi

echo -e "Roteador Local: ${V}$GW_DETECTADO${NC}"

# Ping silencioso para evitar erros de socket na tela
ping -c 3 "$GW_DETECTADO" > resultado_gw.txt 2>&1
if [ $? -eq 0 ]; then
    cat resultado_gw.txt | grep "time="
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    echo -e "Latência Média Local: ${V}${GW_AVG:-0} ms${NC}"
else
    echo -e "${VM}Erro ao pingar roteador.${NC}"
fi

# [3] ESTABILIDADE DA INTERNET
echo -e "\n${A}[3] ESTABILIDADE DA INTERNET${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LAT_AVG=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
echo -e "Latência Média Google: ${V}${LAT_AVG:-0} ms${NC}"

# [4] TESTE DE VELOCIDADE
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
speedtest-cli --simple 2>/dev/null || echo -e "${VM}Speedtest-cli não encontrado.${NC}"

# [5] INFORMAÇÕES TÉCNICAS WI-FI
echo -e "\n${A}[5] INFORMAÇÕES TÉCNICAS WI-FI${NC}"
WIFI_JSON=$(timeout 3 termux-wifi-connectioninfo 2>/dev/null)

if [[ -n "$WIFI_JSON" && "$WIFI_JSON" != "{}" ]]; then
    SSID=$(echo "$WIFI_JSON" | grep -oP '(?<="ssid": ")[^"]*' | head -n 1)
    FREQ=$(echo "$WIFI_JSON" | grep -oP '(?<="frequency_mhz": )[0-9]*' | head -n 1)
    RSSI=$(echo "$WIFI_JSON" | grep -oP '(?<="rssi": )[-\d]*' | head -n 1)
    
    echo -e "${AZ}SSID:${NC} ${SSID:-Desconhecido}"
    
    if [[ -n "$FREQ" ]]; then
        if [ "$FREQ" -lt 3000 ]; then 
            BANDA="2.4GHz"
            CANAL=$(( (FREQ - 2412) / 5 + 1 ))
        else 
            BANDA="5GHz"
            CANAL=$(( (FREQ - 5170) / 5 + 34 ))
        fi
        echo -e "${AZ}Frequência:${NC} $FREQ MHz ${V}($BANDA)${NC}"
        echo -e "${AZ}Canal:${NC} ${A}$CANAL${NC}"
    fi
    
    if [[ -n "$RSSI" ]]; then
        echo -ne "${AZ}Sinal:${NC} ${RSSI} dBm "
        if [ "$RSSI" -ge -60 ]; then echo -e "${V}(Excelente)${NC}";
        elif [ "$RSSI" -ge -75 ]; then echo -e "${A}(Bom)${NC}";
        else echo -e "${VM}(Ruim)${NC}"; fi
    fi
else
    echo -e "${VM}Erro: API não respondeu. Verifique GPS e Permissões.${NC}"
fi

echo -e "\n${V}---- DIAGNÓSTICO FINALIZADO ----${NC}"

# Limpeza
rm -f rota.txt resultado_gw.txt resultado_ping.txt
