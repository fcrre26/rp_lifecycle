#!/bin/bash

# Rocket Pool 测试网完整生命周期管理脚本
# 支持反复注册节点和 mev-commit 测试

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║    Rocket Pool 测试网完整生命周期管理器         ║"
    echo "║           (支持反复注册 & mev-commit 测试)      ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 显示菜单
show_menu() {
    echo
    echo -e "${PURPLE}主要流程 (按顺序执行):${NC}"
    echo " 1. 安装 Rocket Pool 智能节点"
    echo " 2. 配置节点 (选择 Hoodi 测试网)"
    echo " 3. 钱包管理 (创建新钱包/恢复现有钱包)"
    echo " 4. 注册 Rocket Pool 节点"
    echo " 5. 创建 Minipool (质押 8 ETH)"
    echo " 6. 获取 BLS 公钥 (用于 mev-commit 注册)"
    echo
    echo -e "${YELLOW}状态监控:${NC}"
    echo " 7. 查看钱包状态和余额"
    echo " 8. 查看节点状态"
    echo " 9. 查看 Minipool 状态"
    echo "10. 检查区块链同步状态"
    echo
    echo -e "${BLUE}维护操作:${NC}"
    echo "11. 重启所有服务"
    echo "12. 查看服务日志"
    echo
    echo -e "${RED}环境重置 (关键功能):${NC}"
    echo "13. 安全退出并关闭 Minipool"
    echo "14. 完全重置测试网环境 (新钱包周期)"
    echo "15. 备份钱包助记词到安全文件"
    echo
    echo " 0. 退出脚本"
    echo
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

# 安装 Rocket Pool
install_rocketpool() {
    echo -e "${YELLOW}[1/15] 开始安装 Rocket Pool 智能节点...${NC}"
    echo -e "${CYAN}这将安装 Rocket Pool 节点软件和 Docker...${NC}"
    
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
    else
        echo -e "${RED}✗ 安装失败，请检查错误信息${NC}"
    fi
    press_any_key
}

# 配置节点
configure_node() {
    echo -e "${YELLOW}[2/15] 配置节点网络和客户端...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}请确保选择 Hoodi Testnet 作为网络${NC}"
    echo -e "${CYAN}推荐客户端组合: Geth (执行层) + Lighthouse (共识层)${NC}"
    
    rocketpool service config
    
    echo -e "${GREEN}✓ 节点配置完成！${NC}"
    press_any_key
}

# 钱包管理
manage_wallet() {
    echo -e "${YELLOW}[3/15] 钱包管理选项${NC}"
    echo
    echo "1. 创建全新的钱包 (开始新测试周期)"
    echo "2. 恢复现有钱包 (使用助记词)"
    echo "3. 检查当前钱包状态"
    echo
    read -p "请选择 [1-3]: " wallet_choice
    
    case $wallet_choice in
        1)
            echo -e "${YELLOW}创建全新钱包...${NC}"
            echo -e "${RED}重要：请务必备份生成的助记词！${NC}"
            read -p "准备好后按回车键继续..."
            
            rocketpool wallet init
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ 新钱包创建成功！${NC}"
                echo -e "${RED}请立即安全备份助记词！${NC}"
            else
                echo -e "${RED}✗ 钱包创建失败${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}恢复现有钱包...${NC}"
            echo -e "${CYAN}这将引导您通过助记词恢复钱包[citation:2]${NC}"
            read -p "准备好后按回车键继续..."
            
            rocketpool wallet recover
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ 钱包恢复成功！${NC}"
            else
                echo -e "${RED}✗ 钱包恢复失败${NC}"
            fi
            ;;
        3)
            echo -e "${YELLOW}当前钱包状态:${NC}"
            rocketpool wallet status
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
    press_any_key
}

# 注册节点
register_node() {
    echo -e "${YELLOW}[4/15] 注册节点到 Rocket Pool 网络...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}这将把您的节点注册到 Rocket Pool 协议${NC}"
    read -p "确认继续？(y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        rocketpool node register
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 节点注册成功！${NC}"
        else
            echo -e "${RED}✗ 节点注册失败${NC}"
        fi
    else
        echo -e "${YELLOW}注册已取消${NC}"
    fi
    press_any_key
}

# 创建 Minipool
create_minipool() {
    echo -e "${YELLOW}[5/15] 创建 Minipool (验证者)...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}这将质押 8 ETH 创建一个验证者${NC}"
    echo -e "${YELLOW}确保您的钱包有足够测试网 ETH${NC}"
    read -p "确认创建 Minipool？(y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        rocketpool node deposit
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Minipool 创建成功！${NC}"
            echo -e "${YELLOW}注意：验证者需要时间激活，请稍后检查状态${NC}"
        else
            echo -e "${RED}✗ Minipool 创建失败${NC}"
        fi
    else
        echo -e "${YELLOW}已取消${NC}"
    fi
    press_any_key
}

# 获取 BLS 公钥
get_bls_pubkey() {
    echo -e "${YELLOW}[6/15] 获取验证者 BLS 公钥...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    echo -e "${GREEN}这是注册 mev-commit 需要的信息:${NC}"
    echo
    echo -e "${CYAN}=== Minipool 状态和 BLS 公钥 ===${NC}"
    rocketpool minipool status
    echo
    echo -e "${GREEN}请复制上面的 'Validator pubkey' 用于 mev-commit 注册${NC}"
    echo
    echo -e "${YELLOW}下一步: 访问 Hoodi Etherscan 上的 RocketMinipoolRegistry 合约${NC}"
    echo -e "${BLUE}合约地址: 0xbe5a803a7b68f442eff1953c672a3499779680b0${NC}"
    echo -e "${YELLOW}使用 'registerValidator' 函数注册此公钥${NC}"
    
    press_any_key
}

# 检查钱包状态
check_wallet_status() {
    echo -e "${YELLOW}[7/15] 钱包状态检查...${NC}"
    rocketpool wallet status
    press_any_key
}

# 检查节点状态
check_node_status() {
    echo -e "${YELLOW}[8/15] 节点状态检查...${NC}"
    rocketpool node status
    press_any_key
}

# 检查 Minipool 状态
check_minipool_status() {
    echo -e "${YELLOW}[9/15] Minipool 状态检查...${NC}"
    echo -e "${CYAN}=== Minipool 状态 ===${NC}"
    rocketpool minipool status
    press_any_key
}

# 检查同步状态
check_sync_status() {
    echo -e "${YELLOW}[10/15] 区块链同步状态...${NC}"
    rocketpool node sync
    press_any_key
}

# 重启服务
restart_services() {
    echo -e "${YELLOW}[11/15] 重启 Rocket Pool 服务...${NC}"
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
    echo -e "${YELLOW}[12/15] 服务日志查看...${NC}"
    echo "1. 执行层客户端 (Geth/Nethermind)"
    echo "2. 共识层客户端 (Lighthouse/Prysm)" 
    echo "3. 验证者客户端"
    echo "4. Rocket Pool 服务"
    read -p "请选择 [1-4]: " log_choice
    
    case $log_choice in
        1) rocketpool service logs eth1 ;;
        2) rocketpool service logs eth2 ;;
        3) rocketpool service logs validator ;;
        4) rocketpool service logs rocketpool ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
    press_any_key
}

# 安全退出 Minipool
exit_minipool() {
    echo -e "${YELLOW}[13/15] 安全退出 Minipool...${NC}"
    echo -e "${RED}警告：这将开始退出验证者的过程！${NC}"
    read -p "确认要继续退出吗？(输入 'EXIT' 确认): " confirm
    
    if [ "$confirm" = "EXIT" ]; then
        rocketpool minipool exit
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 退出流程已启动！${NC}"
            echo -e "${YELLOW}注意：退出过程需要时间，请稍后检查状态${NC}"
        else
            echo -e "${RED}✗ 退出失败${NC}"
        fi
    else
        echo -e "${YELLOW}退出已取消${NC}"
    fi
    press_any_key
}

# 完全重置环境
reset_environment() {
    echo -e "${YELLOW}[14/15] 完全重置测试网环境...${NC}"
    echo -e "${RED}⚠️  警告：这将清理当前测试网环境！⚠️${NC}"
    echo -e "${RED}这将停止服务并删除链数据，让您可以开始新测试周期${NC}"
    echo
    echo -e "${YELLOW}重置后将需要:${NC}"
    echo "  • 创建或恢复钱包"
    echo "  • 重新注册节点" 
    echo "  • 重新创建 Minipool"
    echo
    read -p "确认要完全重置吗？(输入 'RESET' 确认): " confirm
    
    if [ "$confirm" = "RESET" ]; then
        echo -e "${YELLOW}停止服务...${NC}"
        rocketpool service stop
        
        echo -e "${YELLOW}清理区块链数据...${NC}"
        rocketpool service prune
        
        echo -e "${YELLOW}删除 Docker 容器...${NC}"
        rocketpool service terminate
        
        echo -e "${GREEN}✓ 环境重置完成！${NC}"
        echo -e "${CYAN}现在您可以开始新的测试周期：${NC}"
        echo -e "${CYAN}1. 管理钱包 → 2. 注册节点 → 3. 创建 Minipool${NC}"
    else
        echo -e "${YELLOW}重置已取消${NC}"
    fi
    press_any_key
}

# 备份钱包
backup_wallet() {
    echo -e "${YELLOW}[15/15] 备份钱包助记词...${NC}"
    echo -e "${RED}警告：确保在安全的环境中操作！${NC}"
    read -p "确认继续？(y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo -e "${YELLOW}正在生成备份文件...${NC}"
        rocketpool wallet status > rocketpool_wallet_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 钱包信息已备份到当前目录！${NC}"
            echo -e "${RED}请立即将此文件转移到安全的位置并删除服务器上的副本！${NC}"
        else
            echo -e "${RED}无法获取钱包信息，可能因为钱包未初始化${NC}"
        fi
    else
        echo -e "${YELLOW}备份已取消${NC}"
    fi
    press_any_key
}

# 主循环
main() {
    while true; do
        show_banner
        show_menu
        read -p "请选择操作 [0-15]: " choice
        
        case $choice in
            1) install_rocketpool ;;
            2) configure_node ;;
            3) manage_wallet ;;
            4) register_node ;;
            5) create_minipool ;;
            6) get_bls_pubkey ;;
            7) check_wallet_status ;;
            8) check_node_status ;;
            9) check_minipool_status ;;
            10) check_sync_status ;;
            11) restart_services ;;
            12) view_logs ;;
            13) exit_minipool ;;
            14) reset_environment ;;
            15) backup_wallet ;;
            0) 
                echo -e "${GREEN}感谢使用 Rocket Pool 测试网管理器！再见！${NC}"
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
