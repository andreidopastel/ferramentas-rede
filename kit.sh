#!/data/data/com.termux/files/usr/bin/bash

# Cores
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (VERSÃO BLINDADA) ---${NC}"

# 1. Seleção de Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

# --- PASSO 1: RASTREIO DE ROTA (IDENTIFICAÇÃO) ---
echo -e "\n${A}[1] RASTREIO DE ROTA (BUSCANDO O ROTEADOR)${NC}"
# Rodamos o rastreio e salvamos o log
tracepath -n "$TARGET" | head -n 10 | tee log_rota.txt

# EXTRAÇÃO INTELIGENTE DO IP:
# Procuramos por qualquer linha que tenha o formato de IP e não seja o 127.0.0.1 (localhost)
GW_DETECTADO=$(grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" log_rota.txt | grep -v "127.0.0.1" | head -n 1)

# PLANO B: Se o rastreio falhou, tenta o comando de vizinhos da rede (ARP)
if [[ -z "$GW_DETECTADO" ]]; then
    GW_DETECTADO=$(ip neigh show | grep -E "REACHABLE|STALE" | awk '{print $1}' | head -n 1)
fi

# PLANO C: Se tudo falhar, usa os IPs mais prováveis
if [[ -z "$GW_DETECTADO" ]]; then
    for ip in "192.168.3.1" "192.168.1.1" "192.168.100.1" "192.168.0.1"; do
        if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
            GW_DETECTADO="$ip"
            break
        fi
    done
fi

# --- PASSO 2: TESTE DE REDE LOCAL ---
echo -e "\n${A}[2] TESTE DE REDE LOCAL (ESTABILIDADE)${NC}"

if [[ -n "$GW_DETECTADO" ]]; then
    echo -e "Roteador Alvo: ${V}$GW_DETECTADO${NC}"
    ping -c 5 "$GW_DETECTADO" | tee resultado_gw.txt
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    
    if [[ -n "$GW_AVG" ]]; then
        echo -e "Resumo Local: ${V}EXCELENTE ($GW_AVG ms)${NC}"
    else
        echo -e "Resumo Local: ${VM}SEM RESPOSTA (O IP bloqueia pings)${NC}"
    fi
else
    echo -e "Resumo Local: ${VM}ERRO: Gateway não encontrado.${NC}"
fi

# --- PASSO 3: ESTABILIDADE INTERNET ---
echo -e "\n${A}[3] ESTABILIDADE E PERDA DE PACOTES (INTERNET)${NC}"
ping -c 10 "$TARGET" | tee resultado_ping.txt
LOSS_VAL=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt || echo 0)
LAT_VAL=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)

echo "------------------------------------"
if [[ "$LOSS_VAL" -gt 0 ]]; then echo -e "Status: ${VM}INSTÁVEL ($LOSS_VAL% perda)${NC}"
else echo -e "Status: ${V}BOM ($LAT_VAL ms)${NC}"; fi

# --- PASSO 4: VELOCIDADE ---
echo -e "\n${A}[4] TESTE DE VELOCIDADE${NC}"
speedtest-cli --simple 2>/dev/null || echo "Speedtest falhou"

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"
rm -f resultado_ping.txt resultado_gw.txt log_rota.txt
