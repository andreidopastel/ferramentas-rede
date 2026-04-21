#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (ORDEM DINÂMICA) ---${NC}"

# 1. Seleção de Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

echo -e "\n${V}Iniciando Diagnóstico para: ${AZ}$TARGET${NC}"

# --- PASSO 1: RASTREIO DE ROTA (O BATEDOR) ---
echo -e "\n${A}[1] RASTREIO DE ROTA (IDENTIFICANDO O CAMINHO)${NC}"
# Executa o tracepath e salva em um arquivo temporário para garantir a leitura
tracepath -n "$TARGET" | head -n 10 | tee rota.txt

# EXTRAÇÃO ULTRA-SEGURA DO IP DO ROTEADOR:
# Pega a linha que começa com " 1:", extrai o IP e ignora o localhost
GW_DETECTADO=$(grep -E "^ 1:" rota.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)

# Se o tracepath falhar em mostrar o IP, usa o comando de vizinhos (ARP) como plano B
if [[ -z "$GW_DETECTADO" ]]; then
    GW_DETECTADO=$(ip neigh show | grep -E "REACHABLE|STALE" | awk '{print $1}' | head -n 1)
fi

# --- PASSO 2: TESTE DE REDE LOCAL ---
echo -e "\n${A}[2] TESTE DE REDE LOCAL (WI-FI)${NC}"

if [[ -n "$GW_DETECTADO" ]]; then
    echo -e "Roteador Detectado: ${V}$GW_DETECTADO${NC}"
    ping -c 5 "$GW_DETECTADO" | tee resultado_gw.txt
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    
    if [[ -n "$GW_AVG" ]]; then
        echo -e "Resumo Local: ${V}EXCELENTE ($GW_AVG ms)${NC}"
    else
        echo -e "Resumo Local: ${VM}SEM RESPOSTA (O IP $GW_DETECTADO bloqueia pings)${NC}"
    fi
else
    echo -e "Resumo Local: ${VM}ERRO: Não foi possível identificar o IP do roteador.${NC}"
fi

# --- PASSO 3: ESTABILIDADE INTERNET ---
echo -e "\n${A}[3] ESTABILIDADE E PERDA DE PACOTES (INTERNET)${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LOSS_VAL=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt || echo 0)
LAT_VAL=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

echo "------------------------------------"
if [[ "$LOSS_VAL" -gt 0 ]]; then 
    echo -e "Status: ${VM}INSTÁVEL ($LOSS_VAL% perda)${NC}"
else 
    echo -e "Status: ${V}BOM ($LAT_VAL ms)${NC}"
fi

# --- PASSO 4: VELOCIDADE ---
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
speedtest-cli --simple 2>/dev/null || echo -e "${VM}Speedtest offline${NC}"

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt resultado_gw.txt rota.txt
