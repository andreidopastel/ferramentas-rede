#!/data/data/com.termux/files/usr/bin/bash

# Cores para o terminal
V='\033[0;32m'
A='\033[1;33m'
VM='\033[0;31m'
AZ='\033[0;34m'
NC='\033[0m'

clear
echo -e "${V}--- CANIVETE SUÍÇO DE REDE (LÓGICA DE RASTREIO) ---${NC}"

# 1. Seleção de Alvo
echo -e "\nQual o alvo do teste? (Padrão: 8.8.8.8)"
read -t 10 -p "IP ou 'y' para padrão: " RESP
TARGET=${RESP:-8.8.8.8}
[[ "$TARGET" == "y" || "$TARGET" == "Y" ]] && TARGET="8.8.8.8"

echo -e "\n${V}Iniciando Diagnóstico para: ${AZ}$TARGET${NC}"

# --- PASSO 1: RASTREIO DE ROTA (O BATEDOR) ---
# Este passo agora vem primeiro para descobrir quem é o seu roteador (Salto 1)
echo -e "\n${A}[1] RASTREIO DE ROTA (IDENTIFICANDO O CAMINHO)${NC}"
TRACE_DATA=$(tracepath -n "$TARGET" | head -n 10)
echo "$TRACE_DATA"

# Extrai o IP do primeiro salto (Gateway)
GW_DETECTADO=$(echo "$TRACE_DATA" | grep -E "^ 1:" | awk '{print $2}' | head -n 1)

# --- PASSO 2: TESTE DE REDE LOCAL (WI-FI) ---
# Usa o IP que o Rastreio acabou de encontrar
echo -e "\n${A}[2] TESTE DE REDE LOCAL (ESTABILIDADE DO ROTEADOR)${NC}"

# Se o tracepath não pegou o IP, tenta o comando do sistema como Plano B
if [[ -z "$GW_DETECTADO" || "$GW_DETECTADO" == "no" ]]; then
    GW_DETECTADO=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
fi

if [[ -n "$GW_DETECTADO" ]]; then
    echo -e "Testando Roteador Detectado: ${V}$GW_DETECTADO${NC}"
    ping -c 5 "$GW_DETECTADO" | tee resultado_gw.txt
    GW_AVG=$(grep "avg" resultado_gw.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
    
    if [[ -n "$GW_AVG" ]]; then
        if [[ "$GW_AVG" -lt 15 ]]; then 
            echo -e "Resumo Local: ${V}EXCELENTE ($GW_AVG ms)${NC}"
        else 
            echo -e "Resumo Local: ${A}OSCILANTE ($GW_AVG ms)${NC}"
        fi
    else
        echo -e "Resumo Local: ${VM}SEM RESPOSTA (O roteador $GW_DETECTADO bloqueia pings)${NC}"
    fi
else
    echo -e "Resumo Local: ${VM}ERRO: Gateway não identificado pelo Rastreio.${NC}"
fi

# --- PASSO 3: ESTABILIDADE E PERDA DE PACOTES (INTERNET) ---
echo -e "\n${A}[3] ESTABILIDADE E PERDA DE PACOTES (INTERNET)${NC}"
echo -e "Monitorando $TARGET em tempo real:"
echo "------------------------------------"
ping -c 10 "$TARGET" | tee resultado_ping.txt
echo "------------------------------------"

LOSS_VAL=$(grep -oP '\d+(?=% packet loss)' resultado_ping.txt || echo 0)
LAT_RAW=$(grep "avg" resultado_ping.txt | awk -F'/' '{print $5}' | cut -d'.' -f1)
LAT_VAL=${LAT_RAW:-0}

if [[ "$LOSS_VAL" -gt 0 ]]; then 
    echo -e "Resumo Internet: ${VM}INSTÁVEL (Perda de $LOSS_VAL%)${NC}"
elif [[ "$LAT_VAL" -lt 60 ]]; then 
    echo -e "Resumo Internet: ${V}BOM ($LAT_VAL ms)${NC}"
else 
    echo -e "Resumo Internet: ${A}MÉDIO ($LAT_VAL ms)${NC}"
fi

# --- PASSO 4: VELOCIDADE (SPEEDTEST) ---
echo -e "\n${A}[4] TESTE DE VELOCIDADE (SPEEDTEST)${NC}"
SPEED_OUT=$(speedtest-cli --simple 2>/dev/null)
if [[ -n "$SPEED_OUT" ]]; then
    echo "$SPEED_OUT"
    DOWN_RAW=$(echo "$SPEED_OUT" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
    if [[ "${DOWN_RAW:-0}" -gt 50 ]]; then 
        echo -e "Resumo Banda: ${V}ALTA VELOCIDADE${NC}"
    else 
        echo -e "Resumo Banda: ${A}VELOCIDADE MÉDIA/BAIXA${NC}"
    fi
else
    echo -e "Resumo Banda: ${VM}SPEEDTEST INDISPONÍVEL${NC}"
fi

echo -e "\n${V}--- DIAGNÓSTICO FINALIZADO ---${NC}"

# Limpeza
rm -f resultado_ping.txt resultado_gw.txt
