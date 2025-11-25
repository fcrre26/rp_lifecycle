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
    
    echo -e "${CYAN}在 Devnet 5 测试网络注册节点...${NC}"
    
    # 检查同步状态
    echo -e "${YELLOW}检查区块链同步状态...${NC}"
    local sync_output=$(run_rocketpool node sync 2>&1)
    if echo "$sync_output" | grep -q "syncing"; then
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
    fi
    
    echo
    local register_output=$(run_rocketpool node register 2>&1)
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
    
    echo -e "${CYAN}在 Devnet 5 测试网络创建 Minipool...${NC}"
    echo -e "${YELLOW}注意: 需要测试网 ETH${NC}"
    
    # 检查同步状态
    echo -e "${YELLOW}检查区块链同步状态...${NC}"
    local sync_output=$(run_rocketpool node sync 2>&1)
    if echo "$sync_output" | grep -q "syncing"; then
        echo -e "${YELLOW}⚠️  警告：区块链仍在同步中${NC}"
        echo -e "${CYAN}建议：等待同步完成后再创建 Minipool${NC}"
        echo -e "${CYAN}可以使用选项 13 检查同步状态${NC}"
        echo
        read -p "是否继续尝试创建？(y/n): " continue_deposit
        if [ "$continue_deposit" != "y" ] && [ "$continue_deposit" != "Y" ]; then
            echo -e "${YELLOW}已取消创建${NC}"
            press_any_key
            return
        fi
    fi
    
    echo
    local deposit_output=$(run_rocketpool node deposit 2>&1)
    local deposit_status=$?
    
    # 检查输出中是否包含错误
    if echo "$deposit_output" | grep -qi "error\|not ready\|syncing"; then
        echo -e "${RED}✗ Minipool 创建失败${NC}"
        echo
        echo -e "${YELLOW}错误信息：${NC}"
        echo "$deposit_output" | grep -i "error\|not ready\|syncing" | head -3
        echo
        echo -e "${CYAN}可能的原因：${NC}"
        echo -e "${YELLOW}• 共识层客户端仍在同步中（需要 100% 同步完成）${NC}"
        echo -e "${YELLOW}• 执行层客户端未就绪${NC}"
        echo -e "${YELLOW}• 钱包余额不足（需要测试网 ETH）${NC}"
        echo -e "${YELLOW}• 节点未注册${NC}"
        echo
        echo -e "${GREEN}建议操作：${NC}"
        echo -e "${CYAN}1. 使用选项 13 检查区块链同步状态${NC}"
        echo -e "${CYAN}2. 等待同步完成（共识层需要 100% 同步）${NC}"
        echo -e "${CYAN}3. 使用选项 11 检查钱包余额${NC}"
        echo -e "${CYAN}4. 确保节点已注册（选项 5）${NC}"
        echo -e "${CYAN}5. 使用选项 14 重启服务后重试${NC}"
    elif [ $deposit_status -eq 0 ]; then
        echo -e "${GREEN}✓ Minipool 创建成功！${NC}"
        echo -e "${YELLOW}注意：验证者需要时间激活，请稍后检查状态${NC}"
    else
        echo -e "${RED}✗ Minipool 创建失败${NC}"
        echo "$deposit_output"
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
    
    run_rocketpool wallet status
    press_any_key
}

# 查看 Minipool 状态和 BLS 公钥
check_minipool_and_bls() {
    echo -e "${YELLOW}[12] Minipool 状态和 BLS 公钥...${NC}"
    
    if ! check_root_user; then
        press_any_key
        return
    fi
    
    echo -e "${CYAN}=== Minipool 状态 ===${NC}"
    run_rocketpool minipool status
    echo
    echo -e "${GREEN}=== BLS 公钥 (用于 mev-commit 注册) ===${NC}"
    run_rocketpool minipool status | grep -A 1 "Validator pubkey"
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
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
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
        read -p "请选择操作 [0-18]: " choice
        
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
