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
# [6] SCAN DE CANAIS WI-FI (VERSÃO DEFINITIVA)
echo -e "\n${A}[6] SCAN DE CANAIS WI-FI${NC}"

SCAN=$(termux-wifi-scaninfo 2>/dev/null)

if [[ -z "$SCAN" || "$SCAN" == "[]" ]]; then
    sleep 5
    SCAN=$(termux-wifi-scaninfo 2>/dev/null)
fi

if [[ -z "$SCAN" || "$SCAN" == "[]" ]]; then
    echo -e "${VM}Nenhuma rede detectada.${NC}"
    echo -e "${A}Dica:${NC} execute manualmente:"
    echo "termux-wifi-scaninfo"
    exit
fi

# valida
if [[ -z "$SCAN" || "$SCAN" == "[]" ]]; then
    echo -e "${VM}Nenhuma rede detectada.${NC}"
    echo -e "${A}Possíveis causas:${NC}"
    echo "- GPS desligado"
    echo "- Permissão de localização negada"
    echo "- Android não atualizou scan ainda"
else

    echo -e "${AZ}Redes encontradas:${NC}\n"

    # =========================
    # LISTAGEM DAS REDES
    # =========================
    echo "$SCAN" | jq -c '.[]' | while read -r rede; do

        SSID=$(echo "$rede" | jq -r '.ssid')
        FREQ=$(echo "$rede" | jq -r '.frequency_mhz')
        RSSI=$(echo "$rede" | jq -r '.rssi')

        if [[ "$FREQ" -lt 3000 ]]; then
            CANAL=$(( (FREQ - 2412) / 5 + 1 ))
            BANDA="2.4GHz"
        else
            CANAL=$(( (FREQ - 5170) / 5 + 34 ))
            BANDA="5GHz"
        fi

        echo -e "${V}SSID:${NC} ${SSID:-Oculto}"
        echo -e "Banda: $BANDA"
        echo -e "Canal: ${A}$CANAL${NC}"
        echo -e "Frequência: $FREQ MHz"
        echo -e "Sinal: $RSSI dBm"
        echo "-----------------------------"

    done

    # =========================
    # ANÁLISE DE CANAIS
    # =========================
    echo -e "\n${A}=== ANÁLISE DE CANAIS ===${NC}"

    declare -A canais24
    declare -A canais5

    for c in 1 6 11; do canais24[$c]=0; done
    for c in 36 40 44 48 149 153 157 161; do canais5[$c]=0; done

    echo "$SCAN" | jq -c '.[]' | while read -r rede; do

        FREQ=$(echo "$rede" | jq -r '.frequency_mhz')
        RSSI=$(echo "$rede" | jq -r '.rssi')

        if [[ "$FREQ" -lt 3000 ]]; then
            canal=$(( (FREQ - 2412) / 5 + 1 ))
            banda="2.4GHz"
        else
            canal=$(( (FREQ - 5170) / 5 + 34 ))
            banda="5GHz"
        fi

        peso=$((100 + RSSI))

        if [[ "$banda" == "2.4GHz" ]]; then
            for c in 1 6 11; do
                if (( canal >= c-2 && canal <= c+2 )); then
                    canais24[$c]=$(( ${canais24[$c]} + peso ))
                fi
            done
        else
            for c in 36 40 44 48 149 153 157 161; do
                if (( canal == c )); then
                    canais5[$c]=$(( ${canais5[$c]} + peso ))
                fi
            done
        fi

    done

    # =========================
    # ESCOLHA FINAL
    # =========================
    melhor24=1
    menor24=99999

    for c in 1 6 11; do
        if (( ${canais24[$c]} < menor24 )); then
            menor24=${canais24[$c]}
            melhor24=$c
        fi
    done

    melhor5=36
    menor5=99999

    for c in 36 40 44 48 149 153 157 161; do
        if (( ${canais5[$c]} < menor5 )); then
            menor5=${canais5[$c]}
            melhor5=$c
        fi
    done

    echo -e "\n${V}=== RECOMENDAÇÃO FINAL ===${NC}"
    echo -e "Melhor canal 2.4GHz: ${A}$melhor24${NC}"
    echo -e "Melhor canal 5GHz: ${A}$melhor5${NC}"

fi

# =====================================================
# [7] CHECKLIST TÉCNICO (INTERATIVO)
# =====================================================
echo -e "\n${A}[7] CHECKLIST TÉCNICO (ATENDIMENTO)${NC}"

# Função simples de pergunta
perguntar() {
    echo -ne "$1 (s/n): "
    read resp
    [[ "$resp" == "s" || "$resp" == "S" ]] && echo -e "${V}OK${NC}" || echo -e "${VM}Verificar${NC}"
}

echo -e "\n${AZ}Responda com base no local:${NC}\n"

# 01 - Sinal ONU
perguntar "01 - Sinal da ONU está dentro do padrão?"

# 02 - WiFi 2.4 e 5GHz
perguntar "02 - WiFi 2.4GHz e 5GHz estão ativos e fortes?"

# 03 - Canais (você já tem automático)
echo -e "03 - Canais Wi-Fi analisados automaticamente ✔"

# 04 - Latência (já automático)
echo -e "04 - Latência testada automaticamente ✔"

# 05 - Acesso remoto
perguntar "05 - Acesso remoto ativado e funcionando?"

# 06 - Dispositivos cliente
perguntar "06 - Dispositivos compatíveis com a velocidade?"
perguntar "   - Modo economia de bateria está DESATIVADO?"

# 07 - Cobertura WiFi
perguntar "07 - Sinal Wi-Fi está bom nos locais com problema?"

# 08 - Aplicações com problema
echo -ne "08 - Quais apps/sites apresentam lentidão? "
read APPS
echo -e "Registrado: ${A}$APPS${NC}"

# 09 - SN da ONU
echo -ne "09 - Informe o SN da ONU: "
read SN
echo -e "SN registrado: ${A}$SN${NC}"

echo -e "\n${V}Checklist finalizado.${NC}"

# =====================================================
# [8] GERAR RELATÓRIO WORD AUTOMÁTICO
# =====================================================
echo -e "\n${A}[8] GERANDO RELATÓRIO WORD...${NC}"

ARQ="relatorio_$(date +%Y%m%d_%H%M%S).docx"

python <<EOF
from docx import Document

doc = Document()
doc.add_heading('Relatório Técnico de Rede', 0)

doc.add_paragraph("Data: $(date)")
doc.add_paragraph("Alvo testado: $TARGET")

doc.add_paragraph("\n--- REDE ---")
doc.add_paragraph("Gateway: $GW_DETECTADO")
doc.add_paragraph("Latência local: ${GW_AVG} ms")
doc.add_paragraph("Latência internet: ${LAT_AVG} ms")

doc.add_paragraph("\n--- WI-FI ---")
doc.add_paragraph("SSID: ${SSID}")
doc.add_paragraph("Frequência: ${FREQ} MHz")
doc.add_paragraph("Canal atual: ${CANAL}")
doc.add_paragraph("Sinal: ${RSSI} dBm")

doc.add_paragraph("\n--- RECOMENDAÇÃO ---")
doc.add_paragraph("Melhor canal 2.4GHz: ${melhor24}")
doc.add_paragraph("Melhor canal 5GHz: ${melhor5}")

doc.add_paragraph("\n--- CLIENTE ---")
doc.add_paragraph("SN ONU: ${SN}")
doc.add_paragraph("PPPoE: ${PPP_USER}")
doc.add_paragraph("Plano: ${PLANO}")
doc.add_paragraph("Apps com problema: ${APPS}")

doc.save("$ARQ")
EOF

echo -e "${V}Relatório salvo:${NC} $ARQ"

echo -e "\n${V}---- DIAGNÓSTICO FINALIZADO ----${NC}"

# Limpeza
rm -f rota.txt resultado_gw.txt resultado_ping.txt
