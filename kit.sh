#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#              FERRAMENTA DE DIAGNÓSTICO DE REDE
#              Termux / Android
# ============================================================

# --- CONFIGURAÇÃO DE CORES ---
V='\033[0;32m'       # Verde
A='\033[1;33m'       # Amarelo
VM='\033[0;31m'      # Vermelho
AZ='\033[0;34m'      # Azul
CY='\033[0;36m'      # Ciano
BR='\033[1;37m'      # Branco forte
NC='\033[0m'         # Sem cor

# --- ARQUIVOS TEMPORÁRIOS ---
ROTA_FILE="./rota.txt"
GW_FILE="./resultado_gw.txt"
PING_FILE="./resultado_ping.txt"

# ============================================================
# FUNÇÕES
# ============================================================

pausa() {
    sleep 1
}

comando_existe() {
    command -v "$1" >/dev/null 2>&1
}

limpar_arquivos() {
    rm -f "$ROTA_FILE" "$GW_FILE" "$PING_FILE"
}

calcular_canal() {
    local freq="$1"

    if [[ -z "$freq" || "$freq" == "null" ]]; then
        echo "?"
        return
    fi

    # 2.4 GHz
    case "$freq" in
        2412) echo 1 ;;
        2417) echo 2 ;;
        2422) echo 3 ;;
        2427) echo 4 ;;
        2432) echo 5 ;;
        2437) echo 6 ;;
        2442) echo 7 ;;
        2447) echo 8 ;;
        2452) echo 9 ;;
        2457) echo 10 ;;
        2462) echo 11 ;;
        2467) echo 12 ;;
        2472) echo 13 ;;
        2484) echo 14 ;;

        # 5 GHz
        5180) echo 36 ;;
        5200) echo 40 ;;
        5220) echo 44 ;;
        5240) echo 48 ;;
        5260) echo 52 ;;
        5280) echo 56 ;;
        5300) echo 60 ;;
        5320) echo 64 ;;
        5500) echo 100 ;;
        5520) echo 104 ;;
        5540) echo 108 ;;
        5560) echo 112 ;;
        5580) echo 116 ;;
        5600) echo 120 ;;
        5620) echo 124 ;;
        5640) echo 128 ;;
        5660) echo 132 ;;
        5680) echo 136 ;;
        5700) echo 140 ;;
        5720) echo 144 ;;
        5745) echo 149 ;;
        5765) echo 153 ;;
        5785) echo 157 ;;
        5805) echo 161 ;;
        5825) echo 165 ;;
        5845) echo 169 ;;

        *)
            # Fórmula aproximada para frequências não listadas
            if (( freq < 3000 )); then
                echo $(( (freq - 2407) / 5 ))
            else
                echo "?"
            fi
            ;;
    esac
}

avaliar_rssi() {
    local rssi="$1"

    if [[ -z "$rssi" || "$rssi" == "null" ]]; then
        echo "Desconhecido"
        return
    fi

    if (( rssi >= -60 )); then
        echo "Excelente"
    elif (( rssi >= -67 )); then
        echo "Bom"
    elif (( rssi >= -75 )); then
        echo "Regular"
    else
        echo "Ruim"
    fi
}

# ============================================================
# INÍCIO
# ============================================================

clear

echo -e "${V}==================================================${NC}"
echo -e "${V}             FERRAMENTA DE REDE                  ${NC}"
echo -e "${V}==================================================${NC}"

# ============================================================
# SELEÇÃO DO ALVO
# ============================================================

echo
echo -ne "${BR}Alvo do teste? [143.0.36.20]: ${NC}"

read -r -t 10 RESP

TARGET="${RESP:-143.0.36.20}"

# Se o usuário digitar y por engano
if [[ "$TARGET" == "y" || "$TARGET" == "Y" ]]; then
    TARGET="143.0.36.20"
fi

echo
echo -e "${AZ}Destino selecionado:${NC} ${V}$TARGET${NC}"

limpar_arquivos

# ============================================================
# [1] RASTREIO DE ROTA
# ============================================================

echo
echo -e "${A}[1] RASTREIO DE ROTA${NC}"
echo -e "${CY}Destino:${NC} $TARGET"
echo

ROTA_OK=0

# ------------------------------------------------------------
# TRACEPATH
# ------------------------------------------------------------

if comando_existe tracepath; then

    echo -e "${AZ}Utilizando tracepath...${NC}"
    echo

    tracepath -n "$TARGET" 2>&1 | tee "$ROTA_FILE"

    TRACE_EXIT=${PIPESTATUS[0]}

    echo

    if (( TRACE_EXIT == 0 )); then
        ROTA_OK=1
        echo -e "${V}Tracepath concluído.${NC}"
    else
        echo -e "${A}Tracepath terminou com código $TRACE_EXIT.${NC}"
    fi

# ------------------------------------------------------------
# TRACEROUTE COMO ALTERNATIVA
# ------------------------------------------------------------

elif comando_existe traceroute; then

    echo -e "${AZ}tracepath não encontrado.${NC}"
    echo -e "${AZ}Utilizando traceroute como alternativa...${NC}"
    echo

    traceroute -n "$TARGET" 2>&1 | tee "$ROTA_FILE"

    TRACE_EXIT=${PIPESTATUS[0]}

    echo

    if (( TRACE_EXIT == 0 )); then
        ROTA_OK=1
        echo -e "${V}Traceroute concluído.${NC}"
    else
        echo -e "${A}Traceroute terminou com código $TRACE_EXIT.${NC}"
    fi

else

    echo -e "${VM}ERRO: nenhum programa de rastreio de rota encontrado.${NC}"
    echo
    echo -e "${A}Instale o iproute2:${NC}"
    echo
    echo "pkg update"
    echo "pkg install iproute2"
    echo
    echo -e "${A}Depois execute novamente o kit.${NC}"

fi

# ------------------------------------------------------------
# VERIFICAÇÃO DA ROTA
# ------------------------------------------------------------

if [[ -s "$ROTA_FILE" ]]; then

    echo
    echo -e "${AZ}Resumo dos saltos encontrados:${NC}"

    grep -E '^[[:space:]]*[0-9]+:|^[[:space:]]*[0-9]+\?' "$ROTA_FILE" \
        | head -n 30

    if grep -q "$TARGET" "$ROTA_FILE"; then
        echo
        echo -e "${V}✓ Destino atingido: $TARGET${NC}"
    else
        echo
        echo -e "${A}⚠ O destino não apareceu explicitamente na saída.${NC}"
        echo -e "${A}Isso não significa necessariamente que a Internet esteja com problema.${NC}"
    fi

else

    echo
    echo -e "${VM}Nenhuma rota foi registrada.${NC}"

fi

# ============================================================
# [2] TESTE DE REDE LOCAL
# ============================================================

echo
echo -e "${A}[2] TESTE DE REDE LOCAL${NC}"

# ------------------------------------------------------------
# DETECÇÃO CORRETA DO GATEWAY
# ------------------------------------------------------------

GW_DETECTADO=""

# Primeiro tenta pela rota padrão
if comando_existe ip; then
    GW_DETECTADO=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
fi

# Segundo método: route
if [[ -z "$GW_DETECTADO" ]] && comando_existe route; then
    GW_DETECTADO=$(route -n 2>/dev/null | awk '$1 == "0.0.0.0" {print $2; exit}')
fi

# Terceiro método: gateway Android
if [[ -z "$GW_DETECTADO" ]] && comando_existe getprop; then
    GW_DETECTADO=$(getprop dhcp.wlan0.gateway 2>/dev/null)
fi

echo -e "${CY}Roteador Local Detectado:${NC} ${V}${GW_DETECTADO:-Não detectado}${NC}"

if [[ -n "$GW_DETECTADO" ]]; then

    echo
    echo -e "${AZ}Testando gateway...${NC}"

    if ping -c 5 -W 2 "$GW_DETECTADO" > "$GW_FILE" 2>&1; then

        grep "time=" "$GW_FILE"

        GW_STATS=$(grep -E 'rtt|round-trip' "$GW_FILE")

        if [[ -n "$GW_STATS" ]]; then

            GW_MIN=$(echo "$GW_STATS" | awk -F'=' '{print $2}' | awk -F'/' '{print $1}')
            GW_AVG=$(echo "$GW_STATS" | awk -F'=' '{print $2}' | awk -F'/' '{print $2}')
            GW_MAX=$(echo "$GW_STATS" | awk -F'=' '{print $2}' | awk -F'/' '{print $3}')

            echo
            echo -e "${V}Latência local:${NC}"
            echo -e "Mínima: ${V}${GW_MIN} ms${NC}"
            echo -e "Média:  ${V}${GW_AVG} ms${NC}"
            echo -e "Máxima: ${V}${GW_MAX} ms${NC}"
        fi

        GW_LOSS=$(grep -oE '[0-9]+% packet loss' "$GW_FILE" | head -n1)

        echo -e "Perda:  ${V}${GW_LOSS:-0%}${NC}"

    else

        echo -e "${VM}ERRO: não foi possível pingar o gateway.${NC}"

    fi

else

    echo -e "${VM}Não foi possível detectar o gateway local.${NC}"

fi

# ============================================================
# [3] ESTABILIDADE DA INTERNET
# ============================================================

echo
echo -e "${A}[3] ESTABILIDADE DA INTERNET${NC}"
echo -e "${CY}Destino:${NC} $TARGET"
echo

if ping -c 10 -W 3 "$TARGET" 2>&1 | tee "$PING_FILE"; then
    PING_OK=1
else
    PING_OK=0
fi

echo

PING_STATS=$(grep -E 'rtt|round-trip' "$PING_FILE")

if [[ -n "$PING_STATS" ]]; then

    LAT_MIN=$(echo "$PING_STATS" | awk -F'=' '{print $2}' | awk -F'/' '{print $1}')
    LAT_AVG=$(echo "$PING_STATS" | awk -F'=' '{print $2}' | awk -F'/' '{print $2}')
    LAT_MAX=$(echo "$PING_STATS" | awk -F'=' '{print $2}' | awk -F'/' '{print $3}')
    LAT_MDEV=$(echo "$PING_STATS" | awk -F'=' '{print $2}' | awk -F'/' '{print $4}')

    echo -e "${AZ}Estatísticas:${NC}"
    echo -e "Mínima: ${V}${LAT_MIN} ms${NC}"
    echo -e "Média:  ${V}${LAT_AVG} ms${NC}"
    echo -e "Máxima: ${V}${LAT_MAX} ms${NC}"
    echo -e "Jitter/MDEV: ${V}${LAT_MDEV} ms${NC}"

fi

LOSS=$(grep -oE '[0-9]+% packet loss' "$PING_FILE" | head -n1)

echo -e "Perda de pacotes: ${V}${LOSS:-0%}${NC}"

# ============================================================
# [4] TESTE DE VELOCIDADE
# ============================================================

echo
echo -e "${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"

if comando_existe speedtest-cli; then

    speedtest-cli --simple

elif comando_existe speedtest; then

    speedtest

else

    echo -e "${VM}Speedtest não instalado.${NC}"
    echo
    echo -e "${A}Para instalar:${NC}"
    echo "pkg install python"
    echo "pip install speedtest-cli"

fi

# ============================================================
# [5] INFORMAÇÕES TÉCNICAS WI-FI
# ============================================================

echo
echo -e "${A}[5] INFORMAÇÕES TÉCNICAS WI-FI${NC}"

if comando_existe termux-wifi-connectioninfo; then

    WIFI_JSON=$(timeout 5 termux-wifi-connectioninfo 2>/dev/null)

    if [[ -n "$WIFI_JSON" && "$WIFI_JSON" != "{}" ]]; then

        if comando_existe jq; then

            SSID=$(echo "$WIFI_JSON" | jq -r '.ssid // empty')
            FREQ=$(echo "$WIFI_JSON" | jq -r '.frequency_mhz // empty')
            RSSI=$(echo "$WIFI_JSON" | jq -r '.rssi // empty')
            LINK_SPEED=$(echo "$WIFI_JSON" | jq -r '.link_speed_mbps // empty')
            RX_SPEED=$(echo "$WIFI_JSON" | jq -r '.rx_link_speed_mbps // empty')
            TX_SPEED=$(echo "$WIFI_JSON" | jq -r '.tx_link_speed_mbps // empty')

        else

            SSID=$(echo "$WIFI_JSON" | grep -oP '(?<="ssid": ")[^"]*' | head -n1)
            FREQ=$(echo "$WIFI_JSON" | grep -oP '(?<="frequency_mhz": )[0-9]+' | head -n1)
            RSSI=$(echo "$WIFI_JSON" | grep -oP '(?<="rssi": )-?[0-9]+' | head -n1)
            LINK_SPEED=""
            RX_SPEED=""
            TX_SPEED=""

        fi

        echo -e "${AZ}SSID:${NC} ${SSID:-Desconhecido}"

        if [[ -n "$FREQ" ]]; then

            CANAL=$(calcular_canal "$FREQ")

            if (( FREQ < 3000 )); then
                BANDA="2.4 GHz"
            else
                BANDA="5 GHz"
            fi

            echo -e "${AZ}Frequência:${NC} ${FREQ} MHz"
            echo -e "${AZ}Banda:${NC} ${V}${BANDA}${NC}"
            echo -e "${AZ}Canal:${NC} ${A}${CANAL}${NC}"

        fi

        if [[ -n "$RSSI" ]]; then

            QUALIDADE=$(avaliar_rssi "$RSSI")

            echo -ne "${AZ}Sinal:${NC} ${RSSI} dBm "

            case "$QUALIDADE" in
                Excelente)
                    echo -e "${V}(Excelente)${NC}"
                    ;;
                Bom)
                    echo -e "${V}(Bom)${NC}"
                    ;;
                Regular)
                    echo -e "${A}(Regular)${NC}"
                    ;;
                Ruim)
                    echo -e "${VM}(Ruim)${NC}"
                    ;;
            esac

        fi

        if [[ -n "$LINK_SPEED" ]]; then
            echo -e "${AZ}Link Speed:${NC} ${LINK_SPEED} Mbps"
        fi

        if [[ -n "$RX_SPEED" ]]; then
            echo -e "${AZ}RX:${NC} ${RX_SPEED} Mbps"
        fi

        if [[ -n "$TX_SPEED" ]]; then
            echo -e "${AZ}TX:${NC} ${TX_SPEED} Mbps"
        fi

    else

        echo -e "${VM}Não foi possível obter informações do Wi-Fi.${NC}"
        echo -e "${A}Verifique a permissão de localização/GPS do Android.${NC}"

    fi

else

    echo -e "${VM}termux-api não está instalado.${NC}"
    echo
    echo "pkg install termux-api"

fi

# ============================================================
# [6] SCAN DE CANAIS WI-FI
# ============================================================

echo
echo -e "${A}[6] SCAN DE CANAIS WI-FI${NC}"

if ! comando_existe termux-wifi-scaninfo; then

    echo -e "${VM}termux-wifi-scaninfo não encontrado.${NC}"
    echo
    echo "Instale o Termux:API e execute:"
    echo "pkg install termux-api"

else

    SCAN=$(termux-wifi-scaninfo 2>/dev/null)

    # Segunda tentativa
    if [[ -z "$SCAN" || "$SCAN" == "[]" ]]; then
        echo -e "${A}Primeiro scan vazio. Tentando novamente...${NC}"
        sleep 5
        SCAN=$(termux-wifi-scaninfo 2>/dev/null)
    fi

    if [[ -z "$SCAN" || "$SCAN" == "[]" ]]; then

        echo -e "${VM}Nenhuma rede detectada.${NC}"
        echo
        echo -e "${A}Possíveis causas:${NC}"
        echo "- GPS/localização desligada"
        echo "- Permissão de localização negada"
        echo "- Termux:API não instalado"
        echo "- Android bloqueou o scan"
        echo "- Scan Wi-Fi ainda não atualizado"

    elif ! comando_existe jq; then

        echo -e "${VM}jq não está instalado.${NC}"
        echo
        echo "Instale com:"
        echo "pkg install jq"

    else

        echo -e "${AZ}Redes encontradas:${NC}"
        echo

        # ====================================================
        # LISTAGEM DAS REDES
        # ====================================================

        while read -r rede; do

            SSID=$(echo "$rede" | jq -r '.ssid // empty')
            FREQ=$(echo "$rede" | jq -r '.frequency_mhz // empty')
            RSSI=$(echo "$rede" | jq -r '.rssi // empty')

            CANAL=$(calcular_canal "$FREQ")

            if [[ -n "$FREQ" && "$FREQ" != "null" ]]; then

                if (( FREQ < 3000 )); then
                    BANDA="2.4 GHz"
                else
                    BANDA="5 GHz"
                fi

            else

                BANDA="Desconhecida"

            fi

            echo -e "${V}SSID:${NC} ${SSID:-Oculto}"
            echo -e "Banda: $BANDA"
            echo -e "Canal: ${A}${CANAL}${NC}"
            echo -e "Frequência: ${FREQ:-?} MHz"
            echo -e "Sinal: ${RSSI:-?} dBm"
            echo "-----------------------------"

        done < <(echo "$SCAN" | jq -c '.[]')

        # ====================================================
        # ANÁLISE DOS CANAIS
        # ====================================================

        echo
        echo -e "${A}=== ANÁLISE DE CANAIS ===${NC}"
        echo

        declare -A canais24
        declare -A canais5

        # Inicialização
        for c in 1 6 11; do
            canais24[$c]=0
        done

        for c in 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165; do
            canais5[$c]=0
        done

        # ----------------------------------------------------
        # SOMA DOS PESOS
        # ----------------------------------------------------

        while read -r rede; do

            FREQ=$(echo "$rede" | jq -r '.frequency_mhz // 0')
            RSSI=$(echo "$rede" | jq -r '.rssi // 0')

            if [[ "$FREQ" -eq 0 ]]; then
                continue
            fi

            CANAL=$(calcular_canal "$FREQ")

            if [[ "$CANAL" == "?" ]]; then
                continue
            fi

            # RSSI negativo:
            # -30 = sinal forte
            # -80 = sinal fraco
            #
            # Transformamos em peso positivo.
            PESO=$((100 + RSSI))

            # Nunca permitir peso negativo
            if (( PESO < 0 )); then
                PESO=0
            fi

            # ------------------------------
            # 2.4 GHz
            # ------------------------------

            if (( FREQ < 3000 )); then

                for c in 1 6 11; do

                    if (( CANAL >= c - 2 && CANAL <= c + 2 )); then
                        canais24[$c]=$(( canais24[$c] + PESO ))
                    fi

                done

            # ------------------------------
            # 5 GHz
            # ------------------------------

            else

                if [[ -n "${canais5[$CANAL]+x}" ]]; then
                    canais5[$CANAL]=$(( canais5[$CANAL] + PESO ))
                fi

            fi

        done < <(echo "$SCAN" | jq -c '.[]')

        # ====================================================
        # MELHOR CANAL 2.4 GHz
        # ====================================================

        melhor24=1
        menor24=999999

        for c in 1 6 11; do

            VALOR=${canais24[$c]:-0}

            echo -e "Canal ${A}$c${NC}: interferência = $VALOR"

            if (( VALOR < menor24 )); then
                menor24=$VALOR
                melhor24=$c
            fi

        done

        echo

        # ====================================================
        # MELHOR CANAL 5 GHz
        # ====================================================

        melhor5=36
        menor5=999999

        for c in 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165; do

            VALOR=${canais5[$c]:-0}

            echo -e "Canal ${A}$c${NC}: interferência = $VALOR"

            if (( VALOR < menor5 )); then
                menor5=$VALOR
                melhor5=$c
            fi

        done

        # ====================================================
        # RECOMENDAÇÃO
        # ====================================================

        echo
        echo -e "${V}============================================${NC}"
        echo -e "${V}           RECOMENDAÇÃO FINAL               ${NC}"
        echo -e "${V}============================================${NC}"

        echo -e "Melhor canal 2.4 GHz: ${A}$melhor24${NC}"
        echo -e "Melhor canal 5 GHz:   ${A}$melhor5${NC}"

    fi
fi

# ============================================================
# DIAGNÓSTICO AUTOMÁTICO
# ============================================================

echo
echo -e "${V}============================================${NC}"
echo -e "${V}          DIAGNÓSTICO FINAL                 ${NC}"
echo -e "${V}============================================${NC}"

# Gateway
if [[ -n "$GW_DETECTADO" ]]; then
    echo -e "${V}✓ Gateway detectado:${NC} $GW_DETECTADO"
else
    echo -e "${VM}✗ Gateway não detectado${NC}"
fi

# Internet
if [[ "$PING_OK" == "1" ]]; then
    echo -e "${V}✓ Internet responde:${NC} $TARGET"
else
    echo -e "${VM}✗ Destino não respondeu:${NC} $TARGET"
fi

# Wi-Fi
if [[ -n "$RSSI" ]]; then

    if (( RSSI >= -67 )); then
        echo -e "${V}✓ Sinal Wi-Fi adequado:${NC} $RSSI dBm"
    elif (( RSSI >= -75 )); then
        echo -e "${A}⚠ Sinal Wi-Fi moderado:${NC} $RSSI dBm"
    else
        echo -e "${VM}✗ Sinal Wi-Fi fraco:${NC} $RSSI dBm"
    fi

fi

# Perda
if [[ "$LOSS" == "0% packet loss" ]]; then
    echo -e "${V}✓ Sem perda de pacotes no teste.${NC}"
elif [[ -n "$LOSS" ]]; then
    echo -e "${VM}✗ Perda detectada: $LOSS${NC}"
fi

echo
echo -e "${V}---- DIAGNÓSTICO FINALIZADO ----${NC}"

# ============================================================
# LIMPEZA
# ============================================================

rm -f "$ROTA_FILE" "$GW_FILE" "$PING_FILE"
