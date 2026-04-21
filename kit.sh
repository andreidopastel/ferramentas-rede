#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (LÓGICA DINÂMICA) ---${NC}"

# 1. Seleção de Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

echo -e "\n${V}Iniciando Diagnóstico para: ${AZ}$TARGET${NC}"

# --- PASSO A: RASTREIO INICIAL (O Batedor) ---
echo -e "\n${A}[*] IDENTIFICANDO ROTA E GATEWAY...${NC}"
# Pega o primeiro IP que aparece no tracepath (Salto 1)
GW_DETECTADO=$(tracepath -n -max 3 "$TARGET" | grep -E "^ 1:" | awk '{print $2}' | head -n 1)

if [[ -z "$GW_DETECTADO" || "$GW_DETECTADO" == "no" ]]; then
    # Se o tracepath falhar no primeiro salto, tenta o método reserva do sistema
    GW_DETECTADO=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
fi

# --- PASSO 1: TESTE DE REDE LOCAL (Usando o IP detectado) ---
echo -e "\n${A}[1] TESTE DE REDE LOCAL (WI-FI)${NC}"
if [[ -n "$GW_DETECTADO" ]]; then
    echo -e "Roteador detectado: ${V}$GW_DETECTADO${NC}"
    ping -c 5 "$GW_DETECTADO" | tee resultado_gw.txt
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    
    if [[ -n "$GW_AVG" ]]; then
        if [[ "$GW_AVG" -lt 15 ]]; then echo -e "Resumo Local: ${V}EXCELENTE ($GW_AVG ms)${NC}"
        else echo -e "Resumo Local: ${A}OSCILANTE ($GW_AVG ms)${NC}"; fi
    else
        echo -e "Resumo Local: ${VM}SEM RESPOSTA (Roteador bloqueia ICMP)${NC}"
    fi
else
    echo -e "Resumo Local: ${VM}GATEWAY NÃO IDENTIFICADO${NC}"
fi

# --- PASSO 2: ESTABILIDADE EXTERNA ---
echo -e "\n${A}[2] ESTABILIDADE E PERDA DE PACOTES (INTERNET)${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LOSS_VAL=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt || echo 0)
LAT_VAL=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

if [[ "$LOSS_VAL" -gt 0 ]]; then echo -e "Resumo Internet: ${VM}INSTÁVEL ($LOSS_VAL% perda)${NC}"
else echo -e "Resumo Internet: ${V}BOM ($LAT_VAL ms)${NC}"; fi

# --- PASSO 3: EXIBIÇÃO DA ROTA COMPLETA ---
echo -e "\n${A}[3] RASTREIO DE ROTA COMPLETO${NC}"
tracepath -n "$TARGET" | head -n 10

# --- PASSO 4: VELOCIDADE ---
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
speedtest-cli --simple 2>/dev/null || echo -e "${VM}Speedtest offline${NC}"

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt resultado_gw.txt
    echo -e "Resumo Internet: ${V}BOM ($LAT_VAL ms)${NC}"
else 
    echo -e "Resumo Internet: ${A}MÉDIO ($LAT_VAL ms)${NC}"
fi

# 4. Rastreio de Rota
echo -e "\n${A}[3] RASTREIO DE ROTA (HOP BY HOP)${NC}"
tracepath -n "$TARGET" | head -n 10

# 5. Velocidade
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
if [[ -n "$SPEED_OUT" ]]; then
    echo "$SPEED_OUT"
    DOWN_RAW=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
    DOWN_VAL=${DOWN_RAW:-0}
    
    if [[ "$DOWN_VAL" -gt 50 ]]; then echo -e "Resumo Banda: ${V}ALTA VELOCIDADE${NC}"
    elif [[ "$DOWN_VAL" -gt 15 ]]; then echo -e "Resumo Banda: ${A}VELOCIDADE MÉDIA${NC}"
    else echo -e "Resumo Banda: ${VM}VELOCIDADE BAIXA${NC}"; fi
else
    echo -e "Resumo Banda: ${VM}SPEEDTEST INDISPONÍVEL${NC}"
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt resultado_gw.txt
