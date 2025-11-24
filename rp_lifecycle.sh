#!/bin/bash

# Rocket Pool 多钱包测试管理器 - 保留区块链数据版本
# 支持快速切换钱包，避免重复同步

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_DIR="$HOME/.rocketpool"
DATA_DIR="$CONFIG_DIR/data"
BACKUP_DIR="$HOME/rocketpool_backups"

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║        Rocket Pool 多钱包测试管理器                   ║"
    echo "║      (保留区块链数据 + 快速钱包切换)                   ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查 Rocket Pool 是否安装
check_rocketpool_installed() {
    if command -v rocketpool &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 等待用户确认
press_any_key() {
    echo
    read -n 1 -s -r -p "按任意键继续..."
}

# 显示主菜单
show_menu() {
    echo
    echo -e "${PURPLE}=== 钱包和节点管理 ===${NC}"
    echo " 1. 安装 Rocket Pool 智能节点"
    echo " 2. 配置节点 (选择 Hoodi 测试网)"
    echo " 3. 创建新钱包 (开始新测试周期)"
    echo " 4. 通过助记词恢复钱包"
    echo " 5. 注册 Rocket Pool 节点"
    echo " 6. 创建 Minipool (质押 8 ETH)"
    echo
    echo -e "${CYAN}=== 多钱包快速切换 ===${NC}"
    echo " 7. 🔄 备份当前钱包配置"
    echo " 8. 🔄 切换到其他钱包配置"
    echo " 9. 🔄 创建新钱包并立即备份"
    echo "10. 📋 列出所有已备份的钱包"
    echo
    echo -e "${YELLOW}=== 状态和监控 ===${NC}"
    echo "11. 查看当前钱包状态"
    echo "12. 查看 Minipool 状态和 BLS 公钥"
    echo "13. 检查区块链同步状态"
    echo
    echo -e "${BLUE}=== 服务管理 ===${NC}"
    echo "14. 重启所有服务"
    echo "15. 查看服务日志"
    echo
    echo -e "${GREEN}=== 数据管理 ===${NC}"
    echo "16. 安全退出当前 Minipool"
    echo "17. 清理钱包数据 (不删除区块链)"
    echo
    echo " 0. 退出脚本"
    echo
}

# 初始化备份目录
init_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${GREEN}创建备份目录: $BACKUP_DIR${NC}"
    fi
}

# 安装 Rocket Pool
install_rocketpool() {
    echo -e "${YELLOW}[1] 安装 Rocket Pool 智能节点...${NC}"
    
    read -p "确认继续安装？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi
    
    curl -L https://install.rocketpool.net/uo -o install.sh
    chmod +x install.sh
    sudo bash install.sh
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Rocket Pool 安装成功！${NC}"
        init_backup_dir
    else
        echo -e "${RED}✗ 安装失败，请检查错误信息${NC}"
    fi
    press_any_key
}

# 配置节点
configure_node() {
    echo -e "${YELLOW}[2] 配置节点网络和客户端...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}请确保选择 Hoodi Testnet 作为网络${NC}"
    rocketpool service config
    echo -e "${GREEN}✓ 节点配置完成！${NC}"
    press_any_key
}

# 创建新钱包
create_new_wallet() {
    echo -e "${YELLOW}[3] 创建全新钱包...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    echo -e "${RED}重要：请务必备份生成的助记词！${NC}"
    read -p "准备好后按回车键继续..."
    
    rocketpool wallet init
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 新钱包创建成功！${NC}"
        echo -e "${RED}请立即安全备份助记词！${NC}"
    else
        echo -e "${RED}✗ 钱包创建失败${NC}"
    fi
    press_any_key
}

# 恢复钱包
recover_wallet() {
    echo -e "${YELLOW}[4] 通过助记词恢复钱包...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    rocketpool wallet recover
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 钱包恢复成功！${NC}"
    else
        echo -e "${RED}✗ 钱包恢复失败${NC}"
    fi
    press_any_key
}

# 注册节点
register_node() {
    echo -e "${YELLOW}[5] 注册节点到 Rocket Pool 网络...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    rocketpool node register
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 节点注册成功！${NC}"
    else
        echo -e "${RED}✗ 节点注册失败${NC}"
    fi
    press_any_key
}

# 创建 Minipool
create_minipool() {
    echo -e "${YELLOW}[6] 创建 Minipool (验证者)...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    rocketpool node deposit
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Minipool 创建成功！${NC}"
        echo -e "${YELLOW}注意：验证者需要时间激活，请稍后检查状态${NC}"
    else
        echo -e "${RED}✗ Minipool 创建失败${NC}"
    fi
    press_any_key
}

# 备份当前钱包配置
backup_wallet_config() {
    echo -e "${YELLOW}[7] 备份当前钱包配置...${NC}"
    init_backup_dir
    
    if [ ! -d "$DATA_DIR/wallet" ]; then
        echo -e "${RED}✗ 未找到钱包数据，请先创建或恢复钱包${NC}"
        press_any_key
        return
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/wallet_backup_$timestamp.tar.gz"
    
    # 备份钱包和验证者数据
    tar -czf "$backup_file" -C "$DATA_DIR" wallet validators 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 钱包配置备份成功: $(basename $backup_file)${NC}"
        
        # 显示钱包地址用于记录
        echo -e "${CYAN}当前钱包地址:${NC}"
        rocketpool wallet status | grep "Account address" | head -1
    else
        echo -e "${RED}✗ 备份失败${NC}"
    fi
    press_any_key
}

# 切换到其他钱包配置
switch_wallet_config() {
    echo -e "${YELLOW}[8] 切换到其他钱包配置...${NC}"
    init_backup_dir
    
    # 列出可用的备份
    local backups=($(ls $BACKUP_DIR/wallet_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}✗ 未找到任何钱包备份${NC}"
        echo -e "${YELLOW}请先使用选项7备份当前钱包${NC}"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}可用的钱包备份:${NC}"
    for i in "${!backups[@]}"; do
        echo " $((i+1)). $(basename ${backups[i]})"
    done
    
    echo
    read -p "选择要恢复的备份 [1-${#backups[@]}]: " choice
    
    if [[ ! $choice =~ ^[0-9]+$ ]] || [ $choice -lt 1 ] || [ $choice -gt ${#backups[@]} ]; then
        echo -e "${RED}无效选择${NC}"
        press_any_key
        return
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    
    echo -e "${YELLOW}停止服务...${NC}"
    rocketpool service stop
    
    echo -e "${YELLOW}恢复钱包配置...${NC}"
    tar -xzf "$selected_backup" -C "$DATA_DIR"
    
    echo -e "${YELLOW}重启服务...${NC}"
    rocketpool service start
    
    echo -e "${GREEN}✓ 钱包切换成功！${NC}"
    echo -e "${CYAN}当前钱包信息:${NC}"
    rocketpool wallet status | grep -E "Account address|Node account"
    press_any_key
}

# 创建新钱包并立即备份
create_and_backup_wallet() {
    echo -e "${YELLOW}[9] 创建新钱包并立即备份...${NC}"
    
    # 创建新钱包
    create_new_wallet
    
    # 备份新创建的钱包
    backup_wallet_config
}

# 列出所有已备份的钱包
list_backed_up_wallets() {
    echo -e "${YELLOW}[10] 已备份的钱包列表...${NC}"
    init_backup_dir
    
    local backups=($(ls $BACKUP_DIR/wallet_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${YELLOW}暂无钱包备份${NC}"
    else
        echo -e "${CYAN}找到 ${#backups[@]} 个钱包备份:${NC}"
        for backup in "${backups[@]}"; do
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" | cut -d' ' -f1)
            echo " • $(basename $backup) (大小: $size, 日期: $date)"
        done
    fi
    press_any_key
}

# 查看钱包状态
check_wallet_status() {
    echo -e "${YELLOW}[11] 当前钱包状态...${NC}"
    rocketpool wallet status
    press_any_key
}

# 查看 Minipool 状态和 BLS 公钥
check_minipool_and_bls() {
    echo -e "${YELLOW}[12] Minipool 状态和 BLS 公钥...${NC}"
    echo -e "${CYAN}=== Minipool 状态 ===${NC}"
    rocketpool minipool status
    echo
    echo -e "${GREEN}=== BLS 公钥 (用于 mev-commit 注册) ===${NC}"
    rocketpool minipool status | grep -A 1 "Validator pubkey"
    press_any_key
}

# 检查同步状态
check_sync_status() {
    echo -e "${YELLOW}[13] 区块链同步状态...${NC}"
    rocketpool node sync
    press_any_key
}

# 重启服务
restart_services() {
    echo -e "${YELLOW}[14] 重启 Rocket Pool 服务...${NC}"
    rocketpool service restart
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 服务重启成功！${NC}"
    else
        echo -e "${RED}✗ 服务重启失败${NC}"
    fi
    press_any_key
}

# 查看日志
view_logs() {
    echo -e "${YELLOW}[15] 服务日志查看...${NC}"
    echo "1. 执行层客户端"
    echo "2. 共识层客户端"
    echo "3. 验证者客户端"
    read -p "请选择 [1-3]: " log_choice
    
    case $log_choice in
        1) rocketpool service logs eth1 ;;
        2) rocketpool service logs eth2 ;;
        3) rocketpool service logs validator ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
    press_any_key
}

# 安全退出 Minipool
exit_minipool() {
    echo -e "${YELLOW}[16] 安全退出 Minipool...${NC}"
    echo -e "${RED}警告：这将开始退出验证者的过程！${NC}"
    read -p "确认要继续退出吗？(输入 'EXIT' 确认): " confirm
    
    if [ "$confirm" = "EXIT" ]; then
        rocketpool minipool exit
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 退出流程已启动！${NC}"
        else
            echo -e "${RED}✗ 退出失败${NC}"
        fi
    else
        echo -e "${YELLOW}退出已取消${NC}"
    fi
    press_any_key
}

# 清理钱包数据（保留区块链）
clean_wallet_data() {
    echo -e "${YELLOW}[17] 清理钱包数据（保留区块链）...${NC}"
    echo -e "${CYAN}这将删除当前钱包和验证者密钥，但保留区块链数据${NC}"
    read -p "确认清理？(输入 'CLEAN' 确认): " confirm
    
    if [ "$confirm" = "CLEAN" ]; then
        echo -e "${YELLOW}停止服务...${NC}"
        rocketpool service stop
        
        echo -e "${YELLOW}备份当前钱包...${NC}"
        backup_wallet_config
        
        echo -e "${YELLOW}清理钱包数据...${NC}"
        rm -rf "$DATA_DIR/wallet"
        rm -rf "$DATA_DIR/validators"
        
        echo -e "${YELLOW}重启服务...${NC}"
        rocketpool service start
        
        echo -e "${GREEN}✓ 钱包数据清理完成！${NC}"
        echo -e "${CYAN}现在可以创建或恢复新钱包了${NC}"
    else
        echo -e "${YELLOW}清理已取消${NC}"
    fi
    press_any_key
}

# 主循环
main() {
    while true; do
        show_banner
        show_menu
        read -p "请选择操作 [0-17]: " choice
        
        case $choice in
            1) install_rocketpool ;;
            2) configure_node ;;
            3) create_new_wallet ;;
            4) recover_wallet ;;
            5) register_node ;;
            6) create_minipool ;;
            7) backup_wallet_config ;;
            8) switch_wallet_config ;;
            9) create_and_backup_wallet ;;
            10) list_backed_up_wallets ;;
            11) check_wallet_status ;;
            12) check_minipool_and_bls ;;
            13) check_sync_status ;;
            14) restart_services ;;
            15) view_logs ;;
            16) exit_minipool ;;
            17) clean_wallet_data ;;
            0) 
                echo -e "${GREEN}感谢使用 Rocket Pool 多钱包测试管理器！再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入！${NC}"
                press_any_key
                ;;
        esac
    done
}

# 启动脚本
main
