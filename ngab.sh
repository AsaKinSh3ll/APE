#!/bin/bash
# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Auto Privilege Escalation Scanner v1.0           ║"
echo "║              For Educational Use Only                    ║"
echo "║            BY ASAKIN1337 || SINDIKAT77                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check command availability
check_command() {
    if command -v $1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to print section headers
print_section() {
    echo -e "\n${YELLOW}[+] $1${NC}"
    echo "=================================================="
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${GREEN}[✓] Already running as root!${NC}"
        return 0
    else
        echo -e "${RED}[✗] Not running as root${NC}"
        return 1
    fi
}

# System Information
print_section "System Information"
echo "Hostname: $(hostname 2>/dev/null)"
echo "Kernel: $(uname -a 2>/dev/null)"
echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
echo "User: $(whoami 2>/dev/null)"
echo "Groups: $(groups 2>/dev/null)"
echo "Shell: $SHELL"

# SUDO Rights Check
print_section "SUDO Privileges"
if check_command sudo; then
    echo -e "${BLUE}[*] Checking sudo permissions...${NC}"
    sudo -l 2>/dev/null || echo "No sudo permissions or password required"
    
    # Check for vulnerable sudo versions
    sudo_version=$(sudo --version 2>/dev/null | head -n1 | cut -d' ' -f3)
    if [ ! -z "$sudo_version" ]; then
        echo "Sudo version: $sudo_version"
        # Check for CVE-2021-3156 (Baron Samedit)
        if [[ "$sudo_version" == "1.8.31"* ]] || [[ "$sudo_version" < "1.8.31" ]]; then
            echo -e "${RED}[!] Potentially vulnerable to CVE-2021-3156 (Baron Samedit)${NC}"
        fi
    fi
else
    echo "sudo not available"
fi

# SUID/SGID Binaries
print_section "SUID/SGID Binaries"
echo -e "${BLUE}[*] Searching for SUID binaries...${NC}"
find / -type f -perm -4000 2>/dev/null | while read line; do
    echo -e "${YELLOW}[SUID]${NC} $line"
    # Check for known vulnerable SUID binaries
    case "$(basename $line)" in
        "pkexec"|"passwd"|"su"|"sudo"|"mount"|"umount"|"chsh"|"chfn"|"gpasswd"|"at"|"crontab")
            echo -e "${RED}[!] Potentially vulnerable SUID binary: $(basename $line)${NC}"
            ;;
    esac
done

echo -e "\n${BLUE}[*] Searching for SGID binaries...${NC}"
find / -type f -perm -2000 2>/dev/null | while read line; do
    echo -e "${YELLOW}[SGID]${NC} $line"
done

# Capabilities
print_section "File Capabilities"
if check_command getcap; then
    getcap -r / 2>/dev/null | while read line; do
        echo -e "${YELLOW}[CAP]${NC} $line"
        if [[ "$line" == *"cap_setuid"* ]] || [[ "$line" == *"cap_sys_admin"* ]]; then
            echo -e "${RED}[!] Dangerous capability detected${NC}"
        fi
    done
else
    find / -type f -exec getcap {} \; 2>/dev/null | while read line; do
        echo "$line"
    done
fi

# Writable Files/Directories
print_section "World-Writable Files/Directories"
echo -e "${BLUE}[*] Checking world-writable directories in /etc...${NC}"
find /etc -type d -perm -o+w 2>/dev/null | while read line; do
    echo -e "${YELLOW}[Writable Dir]${NC} $line"
done

echo -e "\n${BLUE}[*] Checking world-writable files in /etc...${NC}"
find /etc -type f -perm -o+w 2>/dev/null | while read line; do
    echo -e "${RED}[!] Writable config file: $line${NC}"
done

# Cron Jobs
print_section "Cron Jobs"
echo -e "${BLUE}[*] System crontab:${NC}"
cat /etc/crontab 2>/dev/null || echo "Cannot read /etc/crontab"

echo -e "\n${BLUE}[*] User crontabs:${NC}"
ls -la /var/spool/cron/ 2>/dev/null || echo "No user crontabs found"

echo -e "\n${BLUE}[*] Cron directories:${NC}"
ls -la /etc/cron* 2>/dev/null

# Check for writable cron scripts
echo -e "\n${BLUE}[*] Checking for writable cron scripts...${NC}"
find /etc/cron* -type f -writable 2>/dev/null | while read line; do
    echo -e "${RED}[!] Writable cron script: $line${NC}"
done

# PATH Abuse Check
print_section "PATH Variables"
echo "Current PATH: $PATH"
echo -e "\n${BLUE}[*] Checking for writable directories in PATH...${NC}"
IFS=':' read -ra path_dirs <<< "$PATH"
for dir in "${path_dirs[@]}"; do
    if [ -w "$dir" ]; then
        echo -e "${RED}[!] Writable directory in PATH: $dir${NC}"
    fi
done

# Running Processes
print_section "Running Processes"
echo -e "${BLUE}[*] Processes running as root:${NC}"
ps aux | grep "^root" 2>/dev/null | head -n20

# Check for interesting processes
echo -e "\n${BLUE}[*] Checking for interesting processes...${NC}"
ps aux 2>/dev/null | grep -E "(mysql|postgres|tomcat|jenkins|docker|kube)" | grep -v grep

# Network Information
print_section "Network Information"
echo -e "${BLUE}[*] Listening ports:${NC}"
netstat -tulpn 2>/dev/null | grep LISTEN || ss -tulpn 2>/dev/null | grep LISTEN

echo -e "\n${BLUE}[*] Network interfaces:${NC}"
ip addr 2>/dev/null || ifconfig 2>/dev/null

# Docker/LXC Check
print_section "Container Detection"
if [ -f /.dockerenv ]; then
    echo -e "${YELLOW}[*] Running inside Docker container${NC}"
fi

if [ -f /proc/1/environ ] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
    echo -e "${YELLOW}[*] Running inside LXC container${NC}"
fi

# Check for Docker group membership
if groups 2>/dev/null | grep -q docker; then
    echo -e "${RED}[!] User is in docker group - potential privilege escalation via Docker socket${NC}"
fi

# SSH Keys
print_section "SSH Keys"
echo -e "${BLUE}[*] Searching for SSH keys...${NC}"
find /home -name "id_rsa" -o -name "id_dsa" -o -name "*.pem" 2>/dev/null | while read line; do
    echo -e "${YELLOW}[SSH Key]${NC} $line"
done

find /root -name "id_rsa" -o -name "id_dsa" -o -name "*.pem" 2>/dev/null 2>/dev/null | while read line; do
    echo -e "${YELLOW}[SSH Key]${NC} $line"
done

# History Files
print_section "History Files"
echo -e "${BLUE}[*] Checking readable history files...${NC}"
for user_home in /home/*; do
    if [ -r "$user_home/.bash_history" ]; then
        echo -e "${YELLOW}[History]${NC} $user_home/.bash_history"
        tail -n5 "$user_home/.bash_history" 2>/dev/null | sed 's/^/  /'
    fi
done

# Password Files
print_section "Password Files"
echo -e "${BLUE}[*] Checking for readable password files...${NC}"
if [ -r /etc/passwd ]; then
    echo -e "${GREEN}[✓] Can read /etc/passwd${NC}"
    # Extract users with shells
    grep -E "/(bash|sh|zsh)" /etc/passwd 2>/dev/null | cut -d: -f1,7
fi

if [ -r /etc/shadow ]; then
    echo -e "${RED}[!] Can read /etc/shadow - potential for password cracking!${NC}"
fi

# Kernel Exploits Check
print_section "Kernel Exploit Suggestions"
kernel_version=$(uname -r)
echo "Kernel version: $kernel_version"

# Check for common vulnerable kernels
case $kernel_version in
    2.6.*|3.*|4.*)
        echo -e "${YELLOW}[*] Checking for known kernel exploits...${NC}"
        echo "  - CVE-2016-5195 (DirtyCow): kernel versions 2.6.22 < 4.8.3"
        echo "  - CVE-2017-1000112: Linux kernel < 4.13"
        echo "  - CVE-2021-3490 (eBPF): Linux kernel 5.7-rc1 < 5.13-rc4"
        ;;
esac

# Check for Linux Exploit Suggester
if [ -f "/usr/bin/linux-exploit-suggester.sh" ] || [ -f "/tmp/linux-exploit-suggester.sh" ]; then
    echo -e "\n${BLUE}[*] Running Linux Exploit Suggester...${NC}"
    /usr/bin/linux-exploit-suggester.sh 2>/dev/null || /tmp/linux-exploit-suggester.sh 2>/dev/null
else
    echo -e "${YELLOW}[*] Linux Exploit Suggester not found${NC}"
    echo "  To download: wget https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh -O /tmp/les.sh"
fi

# Automated Exploit Attempts (Optional - comment out for safety)
print_section "Automated Exploit Checks (Safe Mode)"

# Check for CVE-2021-4034 (PwnKit)
echo -e "${BLUE}[*] Checking for CVE-2021-4034 (PwnKit)...${NC}"
if [ -f "/usr/bin/pkexec" ]; then
    pkexec_version=$(pkexec --version 2>&1 | head -n1)
    if [[ "$pkexec_version" < "0.120" ]]; then
        echo -e "${RED}[!] pkexec version < 0.120 - vulnerable to PwnKit${NC}"
    fi
fi

# Check for CVE-2021-3156 (Baron Samedit)
echo -e "${BLUE}[*] Checking for CVE-2021-3156 (Baron Samedit)...${NC}"
if check_command sudoedit; then
    sudoedit -s / 2>&1 | grep -q "sudoedit:"
    if [ $? -eq 0 ]; then
        echo -e "${RED}[!] System may be vulnerable to Baron Samedit${NC}"
    fi
fi

# Summary
print_section "Summary of Findings"
echo -e "${RED}High Priority Findings:${NC}"
echo "1. Check all [SUID] binaries for known exploits"
echo "2. Review writable cron jobs and directories"
echo "3. Investigate sudo permissions"
echo "4. Check for kernel vulnerabilities matching your version"
echo "5. Review world-writable files in /etc"

echo -e "\n${GREEN}[*] Scan complete! Review findings above carefully.${NC}"
echo -e "${YELLOW}[!] Remember: Only exploit systems you own or have permission to test${NC}"
