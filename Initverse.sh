#!/bin/bash

# Цвета для вывода в терминале
BLUE='\033[0;34m'         # Нормальный синий
LIGHTBLUE='\033[1;34m'    # Светло-синий
CYAN='\033[0;36m'         # Голубой
LIGHTCYAN='\033[1;36m'    # Светло-голубой
NC='\033[0m'              # Сброс цвета

# Конфигурация
WALLET_ADDRESS=""                             # Адрес кошелька (оставьте пустым для ввода)
WORKER_NAME="default_worker"                  # Имя воркера по умолчанию
MINING_SOFTWARE_URL="https://github.com/Project-InitVerse/ini-miner/releases/download/v1.0.0/iniminer-linux-x64"  # URL для скачивания майнерa
CPU_CORES=$(nproc)                            # Количество ядер процессора
RESTART_INTERVAL=3600                         # Интервал автоперезапуска в секундах (1 час)

# Доступные майнинговые пулы
declare -A MINING_POOLS=(
    ["YatesPool"]="pool-a.yatespool.com:31588"
    ["BackupPool"]="pool-b.yatespool.com:32488"
)

# Функция для отображения баннера
show_banner() {
    clear
    echo -e "${LIGHTBLUE}╔════════════════════════════════╗${NC}"
    echo -e "${LIGHTBLUE}║             Nod3r              ║${NC}"
    echo -e "${LIGHTBLUE}╚════════════════════════════════╝${NC}"
    echo
}

# Функция для проверки корректности адреса кошелька
validate_wallet() {
    if [[ ! $1 =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${BLUE}Неверный адрес кошелька!${NC}"
        return 1
    fi
    return 0
}

# Функция для запуска майнинга с автоперезапуском
run_mining() {
    local mining_cmd="$1"
    while true; do
        echo -e "${BLUE}Запуск процесса майнинга...${NC}"
        echo -e "${CYAN}Команда майнинга: $mining_cmd${NC}"
        
        # Расчёт и отображение времени следующего перезапуска
        local next_restart=$(date -d "+1 hour" +"%H:%M:%S")
        echo -e "${LIGHTCYAN}Следующий автоперезапуск запланирован на: $next_restart${NC}"
        
        # Запуск команды майнинга
        eval "$mining_cmd"
        
        echo -e "${LIGHTCYAN}Процесс майнинга завершён. Перезапуск через 10 секунд...${NC}"
        sleep 10
        
        # Завершение оставшихся процессов майнера
        pkill -f iniminer-linux-x64
    done
}

# Функция для настройки майнинга
setup_mining() {
    # Получение адреса кошелька
    while [ -z "$WALLET_ADDRESS" ] || ! validate_wallet "$WALLET_ADDRESS"; do
        echo -e "${LIGHTCYAN}Введите адрес вашего кошелька (0x...):${NC}"
        read WALLET_ADDRESS
    done

    # Получение имени воркера
    echo -e "${LIGHTCYAN}Введите имя воркера (по умолчанию: $WORKER_NAME):${NC}"
    read input_worker
    WORKER_NAME=${input_worker:-$WORKER_NAME}

    # Выбор майнингового пула
    echo -e "${LIGHTCYAN}Доступные майнинговые пулы:${NC}"
    local i=1
    for pool_name in "${!MINING_POOLS[@]}"; do
        echo -e "$i) $pool_name (${MINING_POOLS[$pool_name]})"
        ((i++))
    done

    local pool_choice
    read -p "Выберите пул (1-${#MINING_POOLS[@]}): " pool_choice
    local pool_address=$(echo "${MINING_POOLS[@]}" | cut -d' ' -f$pool_choice)

    # Настройка использования ядер процессора
    echo -e "${LIGHTCYAN}Доступно ядер процессора: $CPU_CORES${NC}"
    read -p "Сколько ядер использовать? (1-$CPU_CORES): " cores_to_use
    cores_to_use=${cores_to_use:-1}

    # Настройка интервала автоперезапуска
    echo -e "${LIGHTCYAN}Текущий интервал автоперезапуска: ${RESTART_INTERVAL} секунд (1 час)${NC}"
    read -p "Введите новый интервал в секундах (нажмите Enter для сохранения текущего): " new_interval
    if [[ -n "$new_interval" ]] && [[ "$new_interval" =~ ^[0-9]+$ ]]; then
        RESTART_INTERVAL=$new_interval
    fi

    # Создание директории и настройка майнера
    mkdir -p ini-miner && cd ini-miner
    echo -e "${LIGHTCYAN}Скачивание майнингового программного обеспечения...${NC}"
    wget "$MINING_SOFTWARE_URL" -O iniminer-linux-x64
    chmod +x iniminer-linux-x64

    # Формирование команды для майнинга
    local mining_cmd="./iniminer-linux-x64 --pool stratum+tcp://${WALLET_ADDRESS}.${WORKER_NAME}@${pool_address}"
    for ((i=0; i<cores_to_use; i++)); do
        mining_cmd+=" --cpu-devices $i"
    done

    # Запуск майнинга с автоперезапуском
    echo -e "${LIGHTCYAN}Запуск майнинга с автоперезапуском каждые ${RESTART_INTERVAL} секунд${NC}"
    echo -e "${LIGHTCYAN}Нажмите Ctrl+C дважды для полного остановки майнинга${NC}"
    run_mining "$mining_cmd"
}

# Функция для проверки системных характеристик
check_system() {
    echo -e "${LIGHTBLUE}Информация о системе:${NC}"
    echo -e "Ядер процессора: ${CYAN}$CPU_CORES${NC}"
    echo -e "Оперативная память: ${CYAN}$(free -h | awk '/^Mem:/{print $2}')${NC}"
    echo -e "Свободное место на диске: ${CYAN}$(df -h / | awk 'NR==2 {print $4}')${NC}"
    echo -e "Интервал автоперезапуска: ${CYAN}${RESTART_INTERVAL} секунд${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Главное меню
while true; do
    show_banner
    echo -e "${LIGHTBLUE}1) Запустить майнинг${NC}"
    echo -e "${LIGHTBLUE}2) Проверить систему${NC}"
    echo -e "${LIGHTBLUE}3) Выход${NC}"
    echo
    read -p "Выберите опцию (1-3): " choice

    case $choice in
        1) setup_mining ;;
        2) check_system ;;
        3) echo -e "${BLUE}Давай, до встречи! Следите за обновлениями на GitHub: @Brrrskuy ${NC}"; exit 0 ;;
        *) echo -e "${CYAN}Неверная опция${NC}"; sleep 1 ;;
    esac
done
