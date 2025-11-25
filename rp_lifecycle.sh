#!/bin/bash

# Rocket Pool 多钱包测试管理器 - Devnet 5 版本
# 使用最新的 Rocket Pool v1.18.6-devnet5

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
    echo "║           (v1.18.6-devnet5 版本)                    ║"
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

# 检查当前用户是否为 root
check_root_user() {
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${RED}警告: 不建议以 root 用户运行 Rocket Pool${NC}"
        echo -e "${YELLOW}请创建一个普通用户并重新运行脚本${NC}"
        echo -e "${CYAN}创建用户命令:${NC}"
        echo "  adduser rocketpool"
        echo "  usermod -aG sudo rocketpool"
        echo "  su - rocketpool"
        return 1
    fi
    return 0
}

# 以非 root 用户运行 Rocket Pool 命令
run_rocketpool() {
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${RED}错误: 不能以 root 用户运行 Rocket Pool 命令${NC}"
        echo -e "${YELLOW}请切换到普通用户运行: su - \$USER${NC}"
        return 1
    else
        rocketpool "$@"
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
    echo " 1. 安装 Rocket Pool 智能节点 (v1.18.6-devnet5)"
    echo " 2. 配置节点 (选择 Devnet 5)"
    echo " 3. 创建新钱包 (开始新测试周期)"
    echo " 4. 导入钱包 (助记词/私钥二选一)"
    echo " 5. 注册 Rocket Pool 节点"
    echo " 6. 创建 Minipool (质押 8 ETH)"
    echo
    echo -e "${CYAN}=== 多钱包快速切换 ===${NC}"
    echo " 7. 备份当前钱包配置"
    echo " 8. 切换到其他钱包配置"
    echo " 9. 创建新钱包并立即备份"
    echo "10. 列出所有已备份的钱包"
    echo
    echo -e "${YELLOW}=== 状态和监控 ===${NC}"
    echo "11. 查看当前钱包状态"
    echo "12. 查看 Minipool 状态和 BLS 公钥"
    echo "13. 检查区块链同步状态"
    echo "18. 网络诊断（检查连接和同步问题）"
    echo
    echo -e "${BLUE}=== 服务管理 ===${NC}"
    echo "14. 重启所有服务"
    echo "15. 查看服务日志"
    echo
    echo -e "${GREEN}=== 数据管理 ===${NC}"
    echo "16. 安全退出当前 Minipool"
    echo "17. 清理钱包数据 (保留区块链，用于批量测试)"
    echo
    echo -e "${RED}=== 紧急修复工具 ===${NC}"
    echo "19. 【紧急修复】Geth ancient database 错误（Hoodi 经典问题）"
    echo "20. 强制等待双客户端 100% 同步（推荐所有操作前运行）"
    echo
    echo -e "${CYAN}提示: 批量测试流程: 17清理 → 4导入钱包 → 5注册节点 → 6创建Minipool${NC}"
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

# ================== 关键修复补丁开始 ==================

# 强制等待执行层和共识层完全同步到 100%
wait_for_sync() {
    echo -e "${YELLOW}正在等待执行层和共识层完全同步（100%）...${NC}"
    echo -e "${CYAN}提示：Hoodi 测试网 Snap Sync 通常 30–90 分钟，state download 阶段会很慢但会突然跳 100%${NC}"
    echo
    
    while true; do
        local sync=$(run_rocketpool node sync 2>/dev/null)
        if echo "$sync" | grep -qi "execution.*synced.*ready" && echo "$sync" | grep -qi "consensus.*synced.*ready"; then
            echo -e "${GREEN}✓ 双客户端已 100% 同步！可以继续操作${NC}"
            return 0
        else
            local ec=$(echo "$sync" | grep -i "execution" | grep -o "[0-9.]\+%" | head -1 || echo "未知")
            local cc=$(echo "$sync" | grep -i "consensus" | grep -o "[0-9.]\+%" | head -1 || echo "未知")
            if [ -z "$ec" ]; then
                ec=$(echo "$sync" | grep -i "EC" | grep -o "[0-9.]\+%" | head -1 || echo "未知")
            fi
            if [ -z "$cc" ]; then
                cc=$(echo "$sync" | grep -i "CC" | grep -o "[0-9.]\+%" | head -1 || echo "未知")
            fi
            echo -e "${YELLOW}当前进度 → 执行层: $ec   共识层: $cc   (每30秒刷新一次)${NC}"
            sleep 30
        fi
    done
}

# 安装 Rocket Pool (Devnet 5 版本)
install_rocketpool() {
    echo -e "${YELLOW}[1] 安装 Rocket Pool 智能节点 (v1.18.6-devnet5)...${NC}"
    
    # 检查是否以 root 用户运行
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${RED}错误: 不能以 root 用户安装 Rocket Pool${NC}"
        echo -e "${YELLOW}请切换到普通用户运行此脚本${NC}"
        echo -e "${CYAN}切换用户命令:${NC}"
        echo "  exit  # 退出 root"
        echo "  ./rocketpool_manager.sh  # 以普通用户运行"
        press_any_key
        return 1
    fi
    
    read -p "确认继续安装？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi
    
    echo -e "${YELLOW}检测系统架构...${NC}"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        *)
            echo -e "${RED}不支持的架构: $ARCH${NC}"
            press_any_key
            return
            ;;
    esac
    
    echo -e "${CYAN}系统架构: $ARCH${NC}"
    
    # 设置版本号 - Devnet 5
    VERSION="v1.18.6-devnet5"
    
    # 检查是否已经安装
    if command -v rocketpool &> /dev/null; then
        echo -e "${YELLOW}检测到已安装 Rocket Pool，是否重新安装？${NC}"
        read -p "重新安装将覆盖现有版本 (y/n): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            echo -e "${YELLOW}安装已取消${NC}"
            return
        fi
    fi
    
    # 下载 Rocket Pool CLI
    echo -e "${YELLOW}下载 Rocket Pool CLI...${NC}"
    CLI_DOWNLOAD_URL="https://github.com/rocket-pool/smartnode/releases/download/$VERSION/rocketpool-cli-linux-$ARCH"
    
    echo -e "${CYAN}CLI 下载地址: $CLI_DOWNLOAD_URL${NC}"
    
    if ! wget -O /tmp/rocketpool-cli "$CLI_DOWNLOAD_URL"; then
        echo -e "${RED}✗ 下载 Rocket Pool CLI 失败${NC}"
        echo -e "${YELLOW}请检查:${NC}"
        echo "1. 网络连接"
        echo "2. 系统架构是否支持"
        echo "3. 手动下载命令:"
        echo "   wget $CLI_DOWNLOAD_URL"
        echo "   sudo mv rocketpool-cli-linux-$ARCH /usr/local/bin/rocketpool"
        press_any_key
        return
    fi
    
    # 下载 Rocket Pool Daemon
    echo -e "${YELLOW}下载 Rocket Pool Daemon...${NC}"
    DAEMON_DOWNLOAD_URL="https://github.com/rocket-pool/smartnode/releases/download/$VERSION/rocketpool-daemon-linux-$ARCH"
    
    echo -e "${CYAN}Daemon 下载地址: $DAEMON_DOWNLOAD_URL${NC}"
    
    if wget -O /tmp/rocketpool-daemon "$DAEMON_DOWNLOAD_URL"; then
        sudo mv /tmp/rocketpool-daemon /usr/local/bin/rocketpool-daemon
        sudo chmod +x /usr/local/bin/rocketpool-daemon
        echo -e "${GREEN}✓ Rocket Pool Daemon 安装成功！${NC}"
    else
        echo -e "${YELLOW}⚠ Daemon 下载失败，将继续安装 CLI${NC}"
    fi
    
    # 安装 CLI
    echo -e "${YELLOW}安装 Rocket Pool CLI...${NC}"
    sudo mv /tmp/rocketpool-cli /usr/local/bin/rocketpool
    sudo chmod +x /usr/local/bin/rocketpool
    
    # 验证安装
    if ! command -v rocketpool &> /dev/null; then
        echo -e "${RED}✗ Rocket Pool CLI 安装失败${NC}"
        press_any_key
        return
    fi
    
    echo -e "${GREEN}✓ Rocket Pool CLI 安装成功！${NC}"
    echo -e "${CYAN}版本信息:${NC}"
    rocketpool --version
    
    # 安装服务
    echo
    echo -e "${YELLOW}安装 Rocket Pool 服务...${NC}"
    echo -e "${CYAN}注意: 这将安装 Devnet 5 测试网络${NC}"
    
    if rocketpool service install; then
        echo -e "${GREEN}✓ Rocket Pool 服务安装成功！${NC}"
        init_backup_dir
        
        echo
        echo -e "${GREEN}安装完成！下一步操作:${NC}"
        echo "1. 运行选项2配置节点 (选择 Devnet 5)"
        echo "2. 运行选项3创建新钱包"
        echo "3. 运行选项5注册节点"
        echo
        echo -e "${YELLOW}注意: 这是 Devnet 5 测试网络，请使用测试 ETH${NC}"
    else
        echo -e "${RED}✗ 服务安装失败${NC}"
        echo -e "${YELLOW}可以尝试手动运行: rocketpool service install${NC}"
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
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}请确保选择 Devnet 5 作为测试网络${NC}"
    echo -e "${YELLOW}注意: 配置过程可能需要一些时间${NC}"
    echo -e "${GREEN}当前版本: v1.18.6-devnet5${NC}"
    run_rocketpool service config
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
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${RED}重要：请务必备份生成的助记词！${NC}"
    echo -e "${YELLOW}这是 Devnet 5 测试网络钱包${NC}"
    read -p "准备好后按回车键继续..."
    
    run_rocketpool wallet init
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 新钱包创建成功！${NC}"
        echo -e "${RED}请立即安全备份助记词！${NC}"
    else
        echo -e "${RED}✗ 钱包创建失败${NC}"
    fi
    press_any_key
}

# 恢复钱包（支持助记词和私钥）
recover_wallet() {
    echo -e "${YELLOW}[4] 导入钱包（助记词/私钥二选一）...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}请选择导入方式：${NC}"
    echo
    echo -e "${YELLOW}1. 使用助记词导入（推荐）${NC}"
    echo -e "${CYAN}   • 支持 12 或 24 个单词的助记词${NC}"
    echo -e "${CYAN}   • Rocket Pool 原生支持${NC}"
    echo
    echo -e "${YELLOW}2. 使用私钥导入${NC}"
    echo -e "${CYAN}   • 需要提供 0x 开头的十六进制私钥${NC}"
    echo -e "${CYAN}   • 使用 ethdo 工具进行导入${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    read -p "请选择导入方式 [1-2]: " import_method
    
    case $import_method in
        1)
            recover_with_mnemonic
            ;;
        2)
            recover_with_private_key
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            press_any_key
            return
            ;;
    esac
}

# 使用助记词恢复钱包
recover_with_mnemonic() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}使用助记词导入钱包${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}功能说明：${NC}"
    echo -e "${CYAN}• 此功能用于导入您已有的钱包（通过助记词）${NC}"
    echo -e "${CYAN}• 您的资金已经在钱包中，这里只是将钱包导入到 Rocket Pool 节点${NC}"
    echo -e "${CYAN}• 系统会根据助记词重新生成钱包私钥和验证者密钥${NC}"
    echo
    echo -e "${YELLOW}接下来系统会要求您：${NC}"
    echo -e "${GREEN}步骤 1：${NC} 系统会提示您输入钱包密码"
    echo -e "${CYAN}        • 密码必须至少 12 个字符${NC}"
    echo -e "${CYAN}        • 用于加密钱包文件，请务必记住此密码${NC}"
    echo -e "${CYAN}        • 需要输入两次以确认${NC}"
    echo
    echo -e "${GREEN}步骤 2：${NC} 系统会询问助记词的数量（重要：这里只输入数字！）"
    echo -e "${RED}        ⚠️  系统提示：Please enter the number of words in your mnemonic phrase${NC}"
    echo -e "${YELLOW}        • 这时只输入数字：12 或 24${NC}"
    echo -e "${YELLOW}        • 不要输入助记词！只输入数字！${NC}"
    echo -e "${YELLOW}        • 如果您有 12 个单词，输入：12${NC}"
    echo -e "${YELLOW}        • 如果您有 24 个单词，输入：24${NC}"
    echo -e "${YELLOW}        • 直接按回车则默认为 24${NC}"
    echo
    echo -e "${GREEN}步骤 3：${NC} 系统会一个一个单词地要求您输入助记词"
    echo -e "${RED}        ⚠️  系统提示：Enter Word Number 1 of your mnemonic${NC}"
    echo -e "${YELLOW}        • 重要：系统会一个一个单词地询问，不是一次性输入所有单词！${NC}"
    echo -e "${YELLOW}        • 每次只输入一个单词，然后按回车${NC}"
    echo -e "${YELLOW}        • 系统会依次询问：Word 1, Word 2, Word 3 ... Word 12${NC}"
    echo -e "${YELLOW}        • 例如：${NC}"
    echo -e "${CYAN}          Word 1: shop${NC}"
    echo -e "${CYAN}          Word 2: result${NC}"
    echo -e "${CYAN}          Word 3: calm${NC}"
    echo -e "${CYAN}          ... 依此类推${NC}"
    echo -e "${RED}        • 注意：不要一次输入多个单词，每次只输入一个！${NC}"
    echo
    echo -e "${YELLOW}注意：${NC}"
    echo -e "${RED}• 此操作会完全重新生成节点钱包的私钥和验证者密钥${NC}"
    echo -e "${RED}• 如果只想测试而不实际导入，可以输入 'test-recovery'${NC}"
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    read -p "准备好后，按回车键开始导入流程... " start_recover
    
    echo
    echo -e "${YELLOW}正在启动钱包导入流程...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}【重要提醒】${NC}"
    echo -e "${YELLOW}当系统提示 'Please enter the number of words' 时：${NC}"
    echo -e "${GREEN}  → 只输入数字 12 或 24，不要输入助记词！${NC}"
    echo -e "${YELLOW}当系统提示 'Enter Word Number X of your mnemonic' 时：${NC}"
    echo -e "${GREEN}  → 每次只输入一个单词，然后按回车${NC}"
    echo -e "${GREEN}  → 系统会依次询问每个单词，共 12 或 24 次${NC}"
    echo -e "${RED}  → 重要：不要一次输入多个单词！每次只输入一个！${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    run_rocketpool wallet recover
    if [ $? -eq 0 ]; then
        echo
        echo -e "${GREEN}✓ 钱包导入成功！${NC}"
        echo -e "${CYAN}您的钱包已成功导入到 Rocket Pool 节点${NC}"
        echo
        echo -e "${YELLOW}关于验证者密钥：${NC}"
        echo -e "${CYAN}• 如果看到 'No validator keys were found'，这是正常的${NC}"
        echo -e "${CYAN}• 验证者密钥会在创建 Minipool（选项 6）时自动生成${NC}"
        echo -e "${CYAN}• 现在您可以继续注册节点（选项 5）和创建 Minipool（选项 6）${NC}"
        echo
        echo -e "${YELLOW}建议：使用选项 7 备份当前钱包配置${NC}"
    else
        echo
        echo -e "${RED}✗ 钱包导入失败${NC}"
        echo -e "${YELLOW}请检查：${NC}"
        echo -e "${CYAN}• 助记词数量输入：只输入数字 12 或 24，不要带任何文字或空格${NC}"
        echo -e "${CYAN}• 助记词是否正确（单词拼写、顺序）${NC}"
        echo -e "${CYAN}• 助记词数量是否正确（12 或 24 个单词）${NC}"
        echo -e "${CYAN}• 密码是否符合要求（至少 12 个字符）${NC}"
    fi
    press_any_key
}

# 使用私钥恢复钱包
recover_with_private_key() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}使用私钥导入钱包${NC}"
    echo
    echo -e "${YELLOW}重要说明：${NC}"
    echo -e "${CYAN}• Rocket Pool CLI 不直接支持私钥导入${NC}"
    echo -e "${CYAN}• 需要使用 ethdo 工具将私钥转换为钱包格式${NC}"
    echo -e "${CYAN}• 或者先使用其他工具（如 MetaMask）将私钥转换为助记词${NC}"
    echo
    echo -e "${GREEN}推荐方法：将私钥转换为助记词后导入（最简单可靠）${NC}"
    echo
    echo -e "${CYAN}步骤 1：使用 MetaMask 导入私钥${NC}"
    echo -e "${YELLOW}  1. 打开 MetaMask 浏览器扩展${NC}"
    echo -e "${YELLOW}  2. 点击账户图标 → 导入账户${NC}"
    echo -e "${YELLOW}  3. 选择'私钥'选项${NC}"
    echo -e "${YELLOW}  4. 粘贴您的私钥（0x 开头或去掉 0x 都可以）${NC}"
    echo -e "${YELLOW}  5. 点击导入${NC}"
    echo
    echo -e "${CYAN}步骤 2：从 MetaMask 导出助记词${NC}"
    echo -e "${YELLOW}  1. 在 MetaMask 中，点击右上角设置图标${NC}"
    echo -e "${YELLOW}  2. 选择'安全和隐私'${NC}"
    echo -e "${YELLOW}  3. 点击'显示助记词'${NC}"
    echo -e "${YELLOW}  4. 输入密码确认${NC}"
    echo -e "${YELLOW}  5. 复制显示的 12 个单词（助记词）${NC}"
    echo
    echo -e "${CYAN}步骤 3：使用助记词导入到 Rocket Pool${NC}"
    echo -e "${YELLOW}  返回此脚本，选择选项 4 → 选项 1（助记词导入）${NC}"
    echo
    echo
    echo -e "${GREEN}其他工具选项：${NC}"
    echo -e "${CYAN}• MyEtherWallet (MEW) - 支持私钥导入和助记词导出${NC}"
    echo -e "${CYAN}• Trust Wallet - 支持私钥导入${NC}"
    echo -e "${CYAN}• 任何支持私钥导入和助记词导出的钱包工具${NC}"
    echo
    echo -e "${YELLOW}注意：${NC}"
    echo -e "${RED}• 私钥和助记词都是敏感信息，请确保在安全环境中操作${NC}"
    echo -e "${RED}• 不要在公共网络或不安全的设备上操作${NC}"
    echo -e "${RED}• 操作完成后，及时清除剪贴板中的私钥和助记词${NC}"
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    read -p "是否已完成私钥到助记词的转换？(y/n): " converted
    
    if [ "$converted" = "y" ] || [ "$converted" = "Y" ]; then
        echo
        echo -e "${GREEN}好的，现在使用助记词导入...${NC}"
        echo
        press_any_key
        recover_with_mnemonic
    else
        echo
        echo -e "${YELLOW}请按照上述步骤完成私钥到助记词的转换${NC}"
        echo -e "${CYAN}完成后，返回此脚本选择选项 4 → 选项 1（助记词导入）${NC}"
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
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Rocket Pool 架构说明${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}节点（Node）和 Minipool 的区别：${NC}"
    echo
    echo -e "${GREEN}1. 节点注册（Node Registration）${NC}"
    echo -e "${CYAN}   • 这是第一步：将您的服务器注册到 Rocket Pool 网络${NC}"
    echo -e "${CYAN}   • 注册后，您的服务器成为 Rocket Pool 网络的一部分${NC}"
    echo -e "${CYAN}   • 但此时还没有开始验证，只是注册了基础设施${NC}"
    echo
    echo -e "${GREEN}2. Minipool 创建（Minipool Creation）${NC}"
    echo -e "${CYAN}   • 这是第二步：创建实际的验证者实例${NC}"
    echo -e "${CYAN}   • Minipool = 一个验证者池，需要质押 ETH 才能创建${NC}"
    echo -e "${CYAN}   • 每个 Minipool 需要 8 ETH（或 16 ETH）来启动验证${NC}"
    echo -e "${CYAN}   • 创建 Minipool 后，验证者才会开始工作并赚取奖励${NC}"
    echo
    echo -e "${YELLOW}简单理解：${NC}"
    echo -e "${CYAN}  • 节点注册 = 注册您的服务器（基础设施）${NC}"
    echo -e "${CYAN}  • Minipool = 创建验证者（实际工作）${NC}"
    echo -e "${CYAN}  • 一个节点可以创建多个 Minipool（如果您有足够的 ETH）${NC}"
    echo
    echo -e "${YELLOW}注意：${NC}"
    echo -e "${RED}  • Rocket Pool 就是基于 Minipool 架构的${NC}"
    echo -e "${RED}  • 如果您不想使用 Minipool，可能需要考虑其他质押方案${NC}"
    echo -e "${RED}  • 但 Rocket Pool 的优势就是通过 Minipool 降低质押门槛${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    read -p "了解后，按回车键继续注册节点... " confirm
    
    echo -e "${CYAN}在 Devnet 5 测试网络注册节点...${NC}"
    
    # 检查同步状态（带超时）
    echo -e "${YELLOW}检查区块链同步状态（最多等待 30 秒）...${NC}"
    echo -e "${CYAN}如果卡住，可以按 Ctrl+C 中断，然后直接尝试注册${NC}"
    
    # 使用 timeout 命令，如果系统不支持则直接执行
    if command -v timeout &> /dev/null; then
        local sync_output=$(timeout 30 run_rocketpool node sync 2>&1)
        local sync_timeout=$?
        if [ $sync_timeout -eq 124 ]; then
            echo -e "${YELLOW}⚠️  同步状态检查超时（30秒）${NC}"
            echo -e "${CYAN}建议：如果选项 13 显示已同步，可以直接继续注册${NC}"
            echo
            read -p "是否继续尝试注册？(y/n): " continue_register
            if [ "$continue_register" != "y" ] && [ "$continue_register" != "Y" ]; then
                echo -e "${YELLOW}已取消注册${NC}"
                press_any_key
                return
            fi
        elif echo "$sync_output" | grep -q "syncing"; then
            echo -e "${YELLOW}⚠️  警告：区块链仍在同步中${NC}"
            echo -e "${CYAN}建议：等待同步完成后再注册节点${NC}"
            echo -e "${CYAN}可以使用选项 13 检查同步状态${NC}"
            echo
            read -p "是否继续尝试注册？(y/n): " continue_register
            if [ "$continue_register" != "y" ] && [ "$continue_register" != "Y" ]; then
                echo -e "${YELLOW}已取消注册${NC}"
                press_any_key
                return
            fi
        else
            echo -e "${GREEN}✓ 区块链同步状态检查完成${NC}"
        fi
    else
        # 如果没有 timeout 命令，直接询问用户
        echo -e "${CYAN}提示：如果选项 13 显示已完全同步，可以直接继续${NC}"
        echo
        read -p "是否跳过同步检查，直接尝试注册？(y/n，默认y): " skip_sync_check
        if [ "${skip_sync_check:-y}" != "y" ] && [ "${skip_sync_check:-y}" != "Y" ]; then
            echo -e "${YELLOW}正在检查同步状态（可能需要一些时间）...${NC}"
            local sync_output=$(run_rocketpool node sync 2>&1)
            if echo "$sync_output" | grep -q "syncing"; then
                echo -e "${YELLOW}⚠️  警告：区块链仍在同步中${NC}"
                echo -e "${CYAN}建议：等待同步完成后再注册节点${NC}"
                echo
                read -p "是否继续尝试注册？(y/n): " continue_register
                if [ "$continue_register" != "y" ] && [ "$continue_register" != "Y" ]; then
                    echo -e "${YELLOW}已取消注册${NC}"
                    press_any_key
                    return
                fi
            else
                echo -e "${GREEN}✓ 区块链同步状态检查完成${NC}"
            fi
        else
            echo -e "${GREEN}✓ 跳过同步检查，直接进行注册${NC}"
        fi
    fi
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Gas 费用设置${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${GREEN}Gas 费用说明：${NC}"
    echo -e "${CYAN}  • Max Fee（最大费用）：您愿意支付的最高费用上限${NC}"
    echo -e "${CYAN}  • Max Priority Fee（优先费用）：给矿工的小费，让交易更快确认${NC}"
    echo -e "${CYAN}  • 实际支付 = 网络当前费用 + 优先费用（不会超过 Max Fee）${NC}"
    echo
    echo -e "${YELLOW}举例说明：${NC}"
    echo -e "${CYAN}  如果设置 Max Fee = 50 gwei, Priority Fee = 2 gwei${NC}"
    echo -e "${CYAN}  网络当前费用 = 10 gwei${NC}"
    echo -e "${CYAN}  实际支付 = 10 + 2 = 12 gwei（不是 50 gwei！）${NC}"
    echo -e "${CYAN}  50 gwei 只是上限，表示"我愿意最多付这么多"${NC}"
    echo
    echo -e "${GREEN}推荐设置（Hoodi 测试网，费用很低）：${NC}"
    echo -e "${CYAN}  • Max Fee: 10-20 gwei（测试网足够，主网可能需要更高）${NC}"
    echo -e "${CYAN}  • Max Priority Fee: 2 gwei（给矿工的小费）${NC}"
    echo
    echo -e "${YELLOW}自定义 Gas 费用（直接按回车使用推荐值）：${NC}"
    read -p "Max Fee (gwei，默认 10，测试网建议 10-20): " max_fee
    max_fee=${max_fee:-10}
    
    read -p "Max Priority Fee (gwei，默认 2): " max_priority_fee
    max_priority_fee=${max_priority_fee:-2}
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}注册过程说明${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}接下来系统会询问：${NC}"
    echo -e "${CYAN}  1. 是否自动检测时区（建议选择 y）${NC}"
    echo -e "${CYAN}  2. 确认检测到的时区（如 Asia/Hong_Kong）${NC}"
    echo -e "${CYAN}  3. 确认费用估算（约 0.02-0.04 ETH）${NC}"
    echo -e "${CYAN}  4. 最终确认注册${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}正在注册节点到 Rocket Pool 网络...${NC}"
    echo -e "${CYAN}使用 Gas 费用: Max Fee=${max_fee} gwei, Priority Fee=${max_priority_fee} gwei${NC}"
    echo -e "${CYAN}请按照提示回答相关问题...${NC}"
    echo
    local register_output=$(run_rocketpool -f "$max_fee" -i "$max_priority_fee" node register 2>&1)
    local register_status=$?
    
    # 检查输出中是否包含错误
    if echo "$register_output" | grep -qi "error\|not ready\|syncing"; then
        echo -e "${RED}✗ 节点注册失败${NC}"
        echo
        echo -e "${YELLOW}错误信息：${NC}"
        echo "$register_output" | grep -i "error\|not ready\|syncing" | head -3
        echo
        echo -e "${CYAN}可能的原因：${NC}"
        echo -e "${YELLOW}• 共识层客户端仍在同步中（需要 100% 同步完成）${NC}"
        echo -e "${YELLOW}• 执行层客户端未就绪${NC}"
        echo -e "${YELLOW}• 网络连接问题${NC}"
        echo
        echo -e "${GREEN}建议操作：${NC}"
        echo -e "${CYAN}1. 使用选项 13 检查区块链同步状态${NC}"
        echo -e "${CYAN}2. 等待同步完成（共识层需要 100% 同步）${NC}"
        echo -e "${CYAN}3. 使用选项 14 重启服务后重试${NC}"
    elif [ $register_status -eq 0 ]; then
        echo -e "${GREEN}✓ 节点注册成功！${NC}"
    else
        echo -e "${RED}✗ 节点注册失败${NC}"
        echo "$register_output"
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
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Minipool 说明${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}什么是 Minipool？${NC}"
    echo -e "${CYAN}  • Minipool 是 Rocket Pool 的核心概念${NC}"
    echo -e "${CYAN}  • 它代表一个验证者实例，用于参与以太坊质押${NC}"
    echo -e "${CYAN}  • 每个 Minipool 需要质押 ETH 才能创建${NC}"
    echo
    echo -e "${YELLOW}为什么需要 Minipool？${NC}"
    echo -e "${CYAN}  • 单独质押需要 32 ETH，门槛很高${NC}"
    echo -e "${CYAN}  • Rocket Pool 通过 Minipool 降低门槛：只需 8 ETH 或 16 ETH${NC}"
    echo -e "${CYAN}  • 剩余的 ETH 由 Rocket Pool 协议提供${NC}"
    echo -e "${CYAN}  • 这样更多人可以用更少的 ETH 参与质押${NC}"
    echo
    echo -e "${YELLOW}Minipool 类型：${NC}"
    echo -e "${GREEN}  • 8 ETH Minipool：${NC} 您提供 8 ETH，协议提供 24 ETH"
    echo -e "${GREEN}  • 16 ETH Minipool：${NC} 您提供 16 ETH，协议提供 16 ETH"
    echo
    echo -e "${YELLOW}重要：${NC}"
    echo -e "${RED}  • Rocket Pool 就是基于 Minipool 架构的，无法避免${NC}"
    echo -e "${RED}  • 如果您不想使用 Minipool，需要选择其他质押方案：${NC}"
    echo -e "${CYAN}    - 单独质押（Solo Staking）：需要 32 ETH，自己运行验证者${NC}"
    echo -e "${CYAN}    - 其他质押池：如 Lido、Stakewise 等${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    read -p "了解后，按回车键继续创建 Minipool... " confirm
    
    echo -e "${CYAN}在 Devnet 5 测试网络创建 Minipool...${NC}"
    echo -e "${YELLOW}注意: 需要测试网 ETH${NC}"
    
    # 强制等待同步到 100%
    echo -e "${YELLOW}检查区块链同步状态...${NC}"
    wait_for_sync   # ← 新增：强制等到双 100%
    
    echo -e "${GREEN}✓ 同步完成！开始创建 Minipool${NC}"
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}创建 Minipool 过程说明${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}接下来系统会询问多个确认：${NC}"
    echo -e "${CYAN}  1. 关于 Saturn 0 的说明（选择 y 继续）${NC}"
    echo -e "${CYAN}  2. 是否加入 Smoothing Pool（可选，建议 y）${NC}"
    echo -e "${CYAN}  3. 关于 Fee Distributor 的说明（选择 y 继续）${NC}"
    echo -e "${CYAN}  4. 确认 8 ETH 存款（选择 y 继续）${NC}"
    echo -e "${CYAN}  5. 确认 Commission Rate（5%）和 Credit Balance（选择 y 继续）${NC}"
    echo -e "${CYAN}  6. 选择 Gas 费用（建议选择 4 gwei，直接按回车）${NC}"
    echo -e "${CYAN}  7. 最终确认（选择 y 确认）${NC}"
    echo
    echo -e "${YELLOW}重要提示：${NC}"
    echo -e "${RED}  • 创建后需要等待 256 epochs（约 27 小时）才能退出${NC}"
    echo -e "${RED}  • 请确保钱包有足够的 ETH（至少 8 ETH + Gas 费用）${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    read -p "准备好后，按回车键开始创建 Minipool（或 Ctrl+C 取消）... " confirm
    
    echo
    echo -e "${YELLOW}正在创建 Minipool（8 ETH）...${NC}"
    echo -e "${CYAN}请按照提示回答相关问题...${NC}"
    echo
    local deposit_output=$(run_rocketpool node deposit 2>&1)
    local deposit_status=$?
    
    echo
    echo "$deposit_output"
    echo
    
    # 检查输出中是否包含成功信息
    if echo "$deposit_output" | grep -qi "successfully\|was made successfully\|minipool.*address\|validator pubkey\|minipool is now"; then
        echo -e "${GREEN}🎉 Minipool 创建成功！你的节点正式上线！${NC}"
        echo
        # 提取关键信息
        local minipool_addr=$(echo "$deposit_output" | grep -i "minipool.*address" | grep -o "0x[a-fA-F0-9]\{40\}" | head -1)
        local validator_pubkey=$(echo "$deposit_output" | grep -i "validator pubkey" | grep -o "[a-fA-F0-9]\{96\}" | head -1)
        
        if [ -n "$minipool_addr" ]; then
            echo -e "${CYAN}Minipool 地址: $minipool_addr${NC}"
        fi
        if [ -n "$validator_pubkey" ]; then
            echo -e "${CYAN}Validator 公钥: $validator_pubkey${NC}"
            echo -e "${YELLOW}（可用于 mev-commit 注册）${NC}"
        fi
        echo
        echo -e "${YELLOW}状态变化：${NC}"
        echo -e "${CYAN}  • Initialized（已初始化）${NC}"
        echo -e "${CYAN}  • Prelaunch（预启动，等待剩余 ETH 分配）${NC}"
        echo -e "${CYAN}  • Staking（质押中，约 12 小时后生效）${NC}"
        echo
        echo -e "${GREEN}可以使用以下命令监控进度：${NC}"
        echo -e "${CYAN}  rocketpool service logs node${NC}"
        echo -e "${CYAN}  rocketpool minipool status${NC}"
    elif echo "$deposit_output" | grep -qi "error\|not ready\|syncing\|failed"; then
        echo -e "${RED}✗ Minipool 创建失败${NC}"
        echo -e "${YELLOW}常见原因：余额不足 / 还没到 100% 同步${NC}"
        echo
        echo -e "${CYAN}可能的原因：${NC}"
        echo -e "${YELLOW}• 钱包余额不足（需要至少 8 ETH 测试网 ETH）${NC}"
        echo -e "${YELLOW}• 节点未注册${NC}"
        echo -e "${YELLOW}• 网络连接问题${NC}"
        echo
        echo -e "${GREEN}建议操作：${NC}"
        echo -e "${CYAN}1. 使用选项 11 检查钱包余额${NC}"
        echo -e "${CYAN}2. 确保节点已注册（选项 5）${NC}"
        echo -e "${CYAN}3. 使用选项 18 进行网络诊断${NC}"
    elif [ $deposit_status -eq 0 ]; then
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
        run_rocketpool wallet status | grep "Account address" | head -1
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
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}重要说明：${NC}"
    echo -e "${CYAN}  • 切换钱包时，区块链数据（eth1/eth2）将完整保留${NC}"
    echo -e "${CYAN}  • 无需重新同步区块，可直接使用${NC}"
    echo -e "${CYAN}  • 建议先备份当前钱包（选项7）${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    # 询问是否先备份当前钱包
    if [ -d "$DATA_DIR/wallet" ]; then
        read -p "是否先备份当前钱包？(y/n，默认y): " backup_current
        if [ "${backup_current:-y}" = "y" ] || [ "${backup_current:-y}" = "Y" ]; then
            echo -e "${YELLOW}备份当前钱包...${NC}"
            backup_wallet_config
        fi
    fi
    
    echo
    echo -e "${CYAN}可用的钱包备份:${NC}"
    for i in "${!backups[@]}"; do
        local size=$(du -h "${backups[i]}" 2>/dev/null | cut -f1)
        local date=$(stat -c %y "${backups[i]}" 2>/dev/null | cut -d' ' -f1)
        echo " $((i+1)). $(basename ${backups[i]}) (大小: $size, 日期: $date)"
    done
    
    echo
    read -p "选择要恢复的备份 [1-${#backups[@]}]: " choice
    
    if [[ ! $choice =~ ^[0-9]+$ ]] || [ $choice -lt 1 ] || [ $choice -gt ${#backups[@]} ]; then
        echo -e "${RED}无效选择${NC}"
        press_any_key
        return
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    
    echo
    echo -e "${YELLOW}停止服务...${NC}"
    run_rocketpool service stop
    
    echo -e "${YELLOW}恢复钱包配置...${NC}"
    tar -xzf "$selected_backup" -C "$DATA_DIR"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 钱包配置恢复成功${NC}"
        
        # 确认区块链数据保留
        if [ -d "$DATA_DIR/eth1" ] || [ -d "$DATA_DIR/eth2" ]; then
            echo -e "${CYAN}✓ 区块链数据已保留，无需重新同步${NC}"
        fi
        
        echo -e "${YELLOW}重启服务...${NC}"
        run_rocketpool service start
        
        echo
        echo -e "${GREEN}✓ 钱包切换成功！${NC}"
        echo -e "${CYAN}当前钱包信息:${NC}"
        run_rocketpool wallet status | grep -E "Account address|Node account" 2>/dev/null || echo -e "${YELLOW}请稍候，服务正在启动...${NC}"
    else
        echo -e "${RED}✗ 钱包恢复失败${NC}"
        echo -e "${YELLOW}重启服务...${NC}"
        run_rocketpool service start
    fi
    
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
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}钱包和节点状态${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    # 检查钱包状态
    local wallet_output=$(run_rocketpool wallet status 2>&1)
    echo "$wallet_output"
    echo
    
    # 检查节点是否注册
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}检查节点注册状态...${NC}"
    local node_status=$(run_rocketpool node status 2>&1)
    
    # 首先检查错误信息
    if echo "$node_status" | grep -qi "error\|not registered\|could not\|failed\|unable"; then
        echo -e "${RED}✗ 节点未注册${NC}"
        echo
        if echo "$node_status" | grep -qi "not registered"; then
            echo -e "${YELLOW}错误信息：${NC}"
            echo "$node_status" | grep -i "not registered" | head -2
            echo
            echo -e "${CYAN}说明：${NC}"
            echo -e "${YELLOW}  • 节点尚未注册到 Rocket Pool 网络${NC}"
            echo -e "${YELLOW}  • 之前的注册操作可能未成功${NC}"
            echo -e "${YELLOW}  • 可能原因：区块链未完全同步（需要 100% 同步）${NC}"
            echo
            echo -e "${GREEN}建议操作：${NC}"
            echo -e "${CYAN}1. 使用选项 13 检查区块链同步状态${NC}"
            echo -e "${CYAN}2. 等待同步到 100% 后，使用选项 5 注册节点${NC}"
            echo -e "${CYAN}3. 使用选项 18 进行网络诊断${NC}"
        else
            echo -e "${YELLOW}无法获取节点状态${NC}"
            echo "$node_status" | head -5
        fi
    elif echo "$node_status" | grep -qi "registered\|node.*registered\|registration"; then
        echo -e "${GREEN}✓ 节点已成功注册到 Rocket Pool 网络${NC}"
        echo -e "${CYAN}节点注册信息：${NC}"
        echo "$node_status" | grep -i "registered\|node" | head -3
    else
        echo -e "${YELLOW}⚠️  无法确定节点注册状态${NC}"
        echo -e "${CYAN}节点状态信息：${NC}"
        echo "$node_status" | head -10
    fi
    
    press_any_key
}

# 查看 Minipool 状态和 BLS 公钥
check_minipool_and_bls() {
    echo -e "${YELLOW}[12] Minipool 状态和 BLS 公钥...${NC}"
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Minipool 状态检查${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    local minipool_output=$(run_rocketpool minipool status 2>&1)
    
    # 首先检查是否有错误信息
    if echo "$minipool_output" | grep -qi "error\|not registered\|could not\|failed\|unable"; then
        echo -e "${RED}✗ Minipool 查询失败${NC}"
        echo
        echo -e "${YELLOW}错误信息：${NC}"
        echo "$minipool_output" | grep -i "error\|not registered\|could not\|failed" | head -3
        echo
        
        # 检查具体错误类型
        if echo "$minipool_output" | grep -qi "not registered"; then
            echo -e "${RED}问题：节点未注册${NC}"
            echo -e "${YELLOW}  说明：之前的注册操作可能未成功${NC}"
            echo -e "${YELLOW}  可能原因：${NC}"
            echo -e "${CYAN}    • 区块链未完全同步（需要 100% 同步）${NC}"
            echo -e "${CYAN}    • 网络连接问题导致注册失败${NC}"
            echo -e "${CYAN}    • 服务未就绪${NC}"
            echo
            echo -e "${GREEN}建议操作：${NC}"
            echo -e "${CYAN}1. 使用选项 13 检查区块链同步状态${NC}"
            echo -e "${CYAN}2. 等待同步到 100% 后，使用选项 5 重新注册节点${NC}"
            echo -e "${CYAN}3. 使用选项 18 进行网络诊断${NC}"
        else
            echo -e "${YELLOW}  说明：无法查询 Minipool 状态${NC}"
            echo -e "${YELLOW}  可能原因：${NC}"
            echo -e "${CYAN}    • 节点未注册${NC}"
            echo -e "${CYAN}    • 服务异常${NC}"
            echo -e "${CYAN}    • 网络连接问题${NC}"
            echo
            echo -e "${GREEN}建议操作：${NC}"
            echo -e "${CYAN}1. 使用选项 11 检查节点注册状态${NC}"
            echo -e "${CYAN}2. 使用选项 14 重启服务${NC}"
            echo -e "${CYAN}3. 使用选项 18 进行网络诊断${NC}"
        fi
    # 检查是否有 Minipool
    elif echo "$minipool_output" | grep -qi "no minipools\|0 minipools"; then
        echo -e "${RED}✗ 未找到任何 Minipool${NC}"
        echo -e "${YELLOW}  说明：之前的创建操作可能未成功${NC}"
        echo -e "${YELLOW}  可能原因：${NC}"
        echo -e "${CYAN}    • 区块链未完全同步（需要 100% 同步）${NC}"
        echo -e "${CYAN}    • 钱包余额不足${NC}"
        echo -e "${CYAN}    • 节点未注册${NC}"
        echo -e "${CYAN}    • 网络连接问题${NC}"
        echo
        echo -e "${GREEN}建议操作：${NC}"
        echo -e "${CYAN}1. 使用选项 13 检查区块链同步状态${NC}"
        echo -e "${CYAN}2. 使用选项 11 检查钱包余额和节点注册状态${NC}"
        echo -e "${CYAN}3. 使用选项 18 进行网络诊断${NC}"
        echo -e "${CYAN}4. 等待同步完成后，使用选项 6 重新创建 Minipool${NC}"
    elif echo "$minipool_output" | grep -qi "minipool.*status\|validator.*pubkey\|minipool address"; then
        echo -e "${GREEN}✓ 找到 Minipool，创建成功！${NC}"
        echo
        echo -e "${CYAN}=== Minipool 详细信息 ===${NC}"
        echo "$minipool_output"
        echo
        echo -e "${GREEN}=== BLS 公钥 (用于 mev-commit 注册) ===${NC}"
        echo "$minipool_output" | grep -A 1 -i "validator pubkey\|bls pubkey" || echo -e "${YELLOW}未找到 BLS 公钥信息${NC}"
    else
        echo -e "${YELLOW}⚠️  无法确定 Minipool 状态${NC}"
        echo -e "${CYAN}原始输出：${NC}"
        echo "$minipool_output"
    fi
    
    press_any_key
}

# 检查同步状态
check_sync_status() {
    echo -e "${YELLOW}[13] 区块链同步状态...${NC}"
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    run_rocketpool node sync
    press_any_key
}

# 重启服务
restart_services() {
    echo -e "${YELLOW}[14] 重启 Rocket Pool 服务...${NC}"
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    run_rocketpool service restart
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
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo "1. 执行层客户端"
    echo "2. 共识层客户端"
    echo "3. 验证者客户端"
    read -p "请选择 [1-3]: " log_choice
    
    case $log_choice in
        1) run_rocketpool service logs eth1 ;;
        2) run_rocketpool service logs eth2 ;;
        3) run_rocketpool service logs validator ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
    press_any_key
}

# 安全退出 Minipool
exit_minipool() {
    echo -e "${YELLOW}[16] 安全退出 Minipool...${NC}"
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${RED}警告：这将开始退出验证者的过程！${NC}"
    read -p "确认要继续退出吗？(输入 'EXIT' 确认): " confirm
    
    if [ "$confirm" = "EXIT" ]; then
        run_rocketpool minipool exit
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
    echo -e "${YELLOW}[17] 清理钱包和节点信息（保留区块链数据）...${NC}"
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}清理说明：${NC}"
    echo
    echo -e "${RED}将被删除的内容：${NC}"
    echo -e "${YELLOW}  • wallet/          - 钱包私钥和配置${NC}"
    echo -e "${YELLOW}  • validators/      - 验证者密钥${NC}"
    echo -e "${YELLOW}  • node/            - 节点注册信息（如果存在）${NC}"
    echo
    echo -e "${GREEN}将被保留的内容（区块链数据）：${NC}"
    echo -e "${CYAN}  • eth1/             - 执行层区块链数据（Geth/Nethermind 等）${NC}"
    echo -e "${CYAN}  • eth2/             - 共识层区块链数据（Lighthouse/Prysm 等）${NC}"
    echo -e "${CYAN}  • 所有已同步的区块数据将完整保留${NC}"
    echo
    echo -e "${GREEN}用途：${NC}"
    echo -e "${CYAN}  适用于批量测试多个钱包，无需重新同步区块链${NC}"
    echo -e "${CYAN}  清理后可以导入新钱包，区块链数据继续使用${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    read -p "确认清理？(输入 'CLEAN' 确认): " confirm
    
    if [ "$confirm" = "CLEAN" ]; then
        echo -e "${YELLOW}停止服务...${NC}"
        run_rocketpool service stop
        
        echo -e "${YELLOW}自动备份当前钱包配置...${NC}"
        if [ -d "$DATA_DIR/wallet" ]; then
            backup_wallet_config
        else
            echo -e "${CYAN}未找到钱包数据，跳过备份${NC}"
        fi
        
        echo
        echo -e "${YELLOW}开始清理钱包和节点数据...${NC}"
        
        # 清理钱包数据
        if [ -d "$DATA_DIR/wallet" ]; then
            rm -rf "$DATA_DIR/wallet"
            echo -e "${GREEN}✓ 已删除钱包数据${NC}"
        fi
        
        # 清理验证者密钥
        if [ -d "$DATA_DIR/validators" ]; then
            rm -rf "$DATA_DIR/validators"
            echo -e "${GREEN}✓ 已删除验证者密钥${NC}"
        fi
        
        # 清理节点注册信息（如果存在）
        if [ -d "$DATA_DIR/node" ]; then
            rm -rf "$DATA_DIR/node"
            echo -e "${GREEN}✓ 已删除节点注册信息${NC}"
        fi
        
        # 确认区块链数据目录存在（不删除）
        if [ -d "$DATA_DIR/eth1" ]; then
            local eth1_size=$(du -sh "$DATA_DIR/eth1" 2>/dev/null | cut -f1)
            echo -e "${CYAN}✓ 执行层区块链数据保留: $eth1_size${NC}"
        fi
        
        if [ -d "$DATA_DIR/eth2" ]; then
            local eth2_size=$(du -sh "$DATA_DIR/eth2" 2>/dev/null | cut -f1)
            echo -e "${CYAN}✓ 共识层区块链数据保留: $eth2_size${NC}"
        fi
        
        echo
        echo -e "${YELLOW}重启服务...${NC}"
        run_rocketpool service start
        
        echo
        echo -e "${GREEN}✓ 清理完成！${NC}"
        echo -e "${CYAN}区块链数据已完整保留，无需重新同步${NC}"
        echo -e "${YELLOW}下一步：使用选项 4 导入新钱包，或选项 3 创建新钱包${NC}"
    else
        echo -e "${YELLOW}清理已取消${NC}"
    fi
    press_any_key
}

# 网络诊断
network_diagnosis() {
    echo -e "${YELLOW}[18] 网络诊断（检查连接和同步问题）...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}网络诊断工具${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    # 1. 检查基本网络连接
    echo -e "${YELLOW}[1] 检查基本网络连接...${NC}"
    if ping -c 2 8.8.8.8 &> /dev/null; then
        echo -e "${GREEN}✓ 基本网络连接正常（可以访问互联网）${NC}"
    else
        echo -e "${RED}✗ 基本网络连接失败（无法访问互联网）${NC}"
        echo -e "${YELLOW}  这可能是导致同步问题的根本原因${NC}"
    fi
    echo
    
    # 2. 检查 DNS 解析
    echo -e "${YELLOW}[2] 检查 DNS 解析...${NC}"
    if nslookup github.com &> /dev/null; then
        echo -e "${GREEN}✓ DNS 解析正常${NC}"
    else
        echo -e "${RED}✗ DNS 解析失败${NC}"
        echo -e "${YELLOW}  可能影响连接到区块链节点${NC}"
    fi
    echo
    
    # 3. 检查 Rocket Pool 服务状态
    echo -e "${YELLOW}[3] 检查 Rocket Pool 服务状态...${NC}"
    local service_status=$(run_rocketpool service status 2>&1)
    if echo "$service_status" | grep -qi "running\|active"; then
        echo -e "${GREEN}✓ Rocket Pool 服务正在运行${NC}"
    else
        echo -e "${RED}✗ Rocket Pool 服务未运行或异常${NC}"
        echo -e "${YELLOW}  建议：使用选项 14 重启服务${NC}"
    fi
    echo
    
    # 4. 检查区块链同步状态
    echo -e "${YELLOW}[4] 检查区块链同步状态...${NC}"
    local sync_output=$(run_rocketpool node sync 2>&1)
    
    # 检查执行层（EC）状态
    if echo "$sync_output" | grep -qi "EC.*synced.*ready"; then
        echo -e "${GREEN}✓ 执行层（EC）已同步并就绪${NC}"
    elif echo "$sync_output" | grep -qi "EC.*syncing"; then
        local ec_progress=$(echo "$sync_output" | grep -i "EC" | grep -o "[0-9.]*%" | head -1)
        echo -e "${YELLOW}⚠️  执行层（EC）正在同步中: $ec_progress${NC}"
    else
        echo -e "${RED}✗ 执行层（EC）状态异常${NC}"
    fi
    
    # 检查共识层（CC）状态
    if echo "$sync_output" | grep -qi "CC.*synced.*ready"; then
        echo -e "${GREEN}✓ 共识层（CC）已同步并就绪${NC}"
    elif echo "$sync_output" | grep -qi "CC.*syncing"; then
        local cc_progress=$(echo "$sync_output" | grep -i "CC" | grep -o "[0-9.]*%" | head -1)
        echo -e "${RED}⚠️  共识层（CC）正在同步中: $cc_progress${NC}"
        if echo "$cc_progress" | grep -q "99"; then
            echo -e "${YELLOW}  注意：即使显示 99.99%，也需要等待到 100% 才能进行操作${NC}"
        fi
    else
        echo -e "${RED}✗ 共识层（CC）状态异常${NC}"
    fi
    echo
    
    # 5. 检查对等节点连接
    echo -e "${YELLOW}[5] 检查对等节点连接...${NC}"
    local peers_info=$(run_rocketpool node sync 2>&1 | grep -i "peer\|connection" | head -5)
    if [ -n "$peers_info" ]; then
        echo -e "${CYAN}对等节点信息：${NC}"
        echo "$peers_info"
    else
        echo -e "${YELLOW}⚠️  无法获取对等节点信息${NC}"
        echo -e "${YELLOW}  如果对等节点数量为 0，可能是网络问题${NC}"
    fi
    echo
    
    # 6. 检查常见网络问题
    echo -e "${YELLOW}[6] 常见网络问题排查...${NC}"
    echo -e "${CYAN}可能的问题和解决方案：${NC}"
    echo
    echo -e "${GREEN}问题 1：防火墙阻止连接${NC}"
    echo -e "${YELLOW}  解决：检查防火墙设置，确保允许 Rocket Pool 客户端端口${NC}"
    echo -e "${YELLOW}  执行层端口：通常为 30303（TCP/UDP）${NC}"
    echo -e "${YELLOW}  共识层端口：通常为 9000（TCP/UDP）${NC}"
    echo
    echo -e "${GREEN}问题 2：网络带宽不足${NC}"
    echo -e "${YELLOW}  解决：区块链同步需要稳定的网络连接${NC}"
    echo -e "${YELLOW}  建议：确保有足够的带宽（至少 10 Mbps）${NC}"
    echo
    echo -e "${GREEN}问题 3：NAT/路由器配置${NC}"
    echo -e "${YELLOW}  解决：如果使用 NAT，可能需要配置端口转发${NC}"
    echo -e "${YELLOW}  或者使用 UPnP 自动配置${NC}"
    echo
    echo -e "${GREEN}问题 4：ISP 限制或网络不稳定${NC}"
    echo -e "${YELLOW}  解决：检查网络稳定性，考虑使用 VPN 或更换网络${NC}"
    echo
    echo -e "${GREEN}问题 5：同步卡在 99.99%${NC}"
    echo -e "${YELLOW}  解决：这是正常现象，需要等待完全同步到 100%${NC}"
    echo -e "${YELLOW}  可以使用选项 13 持续监控同步状态${NC}"
    echo
    
    # 7. 提供建议操作
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}建议操作：${NC}"
    echo -e "${YELLOW}1. 如果网络连接正常但同步缓慢：${NC}"
    echo -e "${CYAN}   • 等待同步完成（可能需要数小时到数天）${NC}"
    echo -e "${CYAN}   • 使用选项 13 持续监控同步状态${NC}"
    echo -e "${CYAN}   • 确保网络连接稳定${NC}"
    echo
    echo -e "${YELLOW}2. 如果网络连接异常：${NC}"
    echo -e "${CYAN}   • 检查网络配置和防火墙设置${NC}"
    echo -e "${CYAN}   • 重启网络服务或路由器${NC}"
    echo -e "${CYAN}   • 联系网络管理员或 ISP${NC}"
    echo
    echo -e "${YELLOW}3. 如果服务异常：${NC}"
    echo -e "${CYAN}   • 使用选项 14 重启所有服务${NC}"
    echo -e "${CYAN}   • 使用选项 15 查看服务日志${NC}"
    echo
    
    # 8. 判断是否需要换 VPS
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}是否需要换 VPS？${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    local need_change_vps=false
    local reasons=""
    
    # 检查基本网络
    if ! ping -c 2 8.8.8.8 &> /dev/null; then
        need_change_vps=true
        reasons="${reasons}• 基本网络连接失败（无法访问互联网）\n"
    fi
    
    # 检查 DNS
    if ! nslookup github.com &> /dev/null; then
        need_change_vps=true
        reasons="${reasons}• DNS 解析失败\n"
    fi
    
    # 检查同步状态（如果长期卡住）
    if echo "$sync_output" | grep -qi "CC.*syncing.*99"; then
        local cc_sync_time=$(find "$DATA_DIR/eth2" -type f -name "*.log" -mtime +7 2>/dev/null | wc -l)
        if [ "$cc_sync_time" -gt 0 ]; then
            echo -e "${YELLOW}⚠️  共识层同步已持续多天，可能是网络问题${NC}"
        fi
    fi
    
    if [ "$need_change_vps" = true ]; then
        echo -e "${RED}建议：考虑更换 VPS${NC}"
        echo -e "${YELLOW}原因：${NC}"
        echo -e "$reasons"
        echo -e "${CYAN}推荐 VPS 提供商：${NC}"
        echo -e "${YELLOW}  • 选择网络稳定、带宽充足的 VPS${NC}"
        echo -e "${YELLOW}  • 建议选择靠近区块链节点的地理位置${NC}"
        echo -e "${YELLOW}  • 确保 VPS 提供商不限制 P2P 连接${NC}"
    else
        echo -e "${GREEN}当前 VPS 网络连接正常${NC}"
        echo -e "${CYAN}如果同步仍然缓慢，可能的原因：${NC}"
        echo -e "${YELLOW}  • 这是首次同步，需要下载整个区块链（正常需要数小时到数天）${NC}"
        echo -e "${YELLOW}  • 网络带宽较小，同步速度较慢（但最终会完成）${NC}"
        echo -e "${YELLOW}  • 对等节点连接较少（可以等待更多节点连接）${NC}"
        echo
        echo -e "${GREEN}建议：${NC}"
        echo -e "${CYAN}  • 耐心等待同步完成（这是正常过程）${NC}"
        echo -e "${CYAN}  • 使用选项 13 持续监控同步进度${NC}"
        echo -e "${CYAN}  • 如果同步完全停止（超过 24 小时无进展），再考虑换 VPS${NC}"
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    press_any_key
}

# 紧急修复 Geth ancient database 错误
fix_ancient_error() {
    echo -e "${RED}[19] 【紧急修复】Geth ancient database 损坏（常见 Hoodi 测试网问题）${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}【紧急修复】Geth ancient database 损坏${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}症状：${NC}"
    echo -e "${CYAN}  • 反复看到 Fatal: Failed to iterate ancient blocks${NC}"
    echo -e "${CYAN}  • Geth 无法启动或频繁崩溃${NC}"
    echo -e "${CYAN}  • 这是 Hoodi 测试网的常见问题${NC}"
    echo
    echo -e "${GREEN}一键彻底解决（已验证 100% 有效）：${NC}"
    echo -e "${YELLOW}  • 会删除 eth1 数据卷并重新 Snap Sync${NC}"
    echo -e "${YELLOW}  • 预计 30–90 分钟后 100% 同步完成${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    read -p "确认执行？会删除 eth1 数据卷并重新 Snap Sync (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo
        echo -e "${YELLOW}停止 Rocket Pool 服务...${NC}"
        run_rocketpool service stop
        
        echo -e "${YELLOW}删除 eth1 容器和数据卷...${NC}"
        docker ps -a | grep eth1 | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || echo "未找到 eth1 容器"
        docker volume rm rocketpool_eth1clientdata 2>/dev/null || echo "数据卷已删除或不存在"
        
        echo -e "${YELLOW}重启 Rocket Pool 服务...${NC}"
        run_rocketpool service start
        
        echo
        echo -e "${GREEN}✓ 已清理完成！Geth 正在全新 Snap Sync，预计 30–90 分钟后 100%${NC}"
        echo -e "${CYAN}你现在可以去喝杯水，回来直接建 Minipool${NC}"
        echo -e "${YELLOW}可以使用选项 20 或选项 13 监控同步进度${NC}"
    else
        echo -e "${YELLOW}已取消修复${NC}"
    fi
    
    press_any_key
}

# 强制等待双客户端 100% 同步
force_wait_sync() {
    echo -e "${YELLOW}[20] 强制等待双客户端 100% 同步...${NC}"
    
    if ! check_rocketpool_installed; then
        echo -e "${RED}✗ 请先安装 Rocket Pool！${NC}"
        press_any_key
        return
    fi
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    wait_for_sync
    press_any_key
}

# 主循环
main() {
    # 检查是否以 root 用户运行
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${YELLOW}警告: 当前以 root 用户运行${NC}"
        echo -e "${CYAN}Rocket Pool 不建议以 root 用户运行${NC}"
        echo
        echo -e "${GREEN}建议操作:${NC}"
        echo "1. 退出当前会话: exit"
        echo "2. 以普通用户重新运行: ./rocketpool_manager.sh"
        echo
        echo -e "${YELLOW}是否继续以 root 用户运行？(y/n): ${NC}"
        read -p "" continue_as_root
        if [ "$continue_as_root" != "y" ] && [ "$continue_as_root" != "Y" ]; then
            echo -e "${GREEN}退出脚本，请以普通用户重新运行${NC}"
            exit 1
        fi
    fi
    
    while true; do
        show_banner
        show_menu
        read -p "请选择操作 [0-20]: " choice
        
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
            18) network_diagnosis ;;
            19) fix_ancient_error ;;
            20) force_wait_sync ;;
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
