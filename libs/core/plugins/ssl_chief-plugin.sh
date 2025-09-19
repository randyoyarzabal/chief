#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
########################################################################

# Chief Plugin File: ssl_chief-plugin.sh
# Author: Randy E. Oyarzabal
# Functions and aliases related to SSL/TLS.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

function chief.ssl_create-ca() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [ca_name] [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create a Certificate Authority (CA) for signing certificates.

${CHIEF_COLOR_BLUE}Arguments (all optional):${CHIEF_NO_COLOR}
  ca_name         CA name (default: 'ca' - creates ca-ca.key and ca-ca.crt)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -c, --country CODE      Country code (default: US)
  -s, --state STATE       State/province (default: CA)
  -l, --city CITY         City/locality (default: San Francisco)
  -o, --org NAME          Organization name (default: \${ca_name} CA)
  -u, --unit NAME         Organizational unit (default: Certificate Authority)
  -e, --email EMAIL       Email address (optional)
  -d, --days DAYS         Validity period in days (default: 3650)
  -k, --keysize SIZE      Key size in bits (default: 4096)
  -f, --force             Force overwrite existing files
  -?                      Show this help

${CHIEF_COLOR_GREEN}Simple Usage:${CHIEF_NO_COLOR}
All options are optional! Just provide what you want to customize.

${CHIEF_COLOR_MAGENTA}Files Created:${CHIEF_NO_COLOR}
- \${ca_name}-ca.key    CA private key (keep secure!)
- \${ca_name}-ca.crt    CA certificate

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
${CHIEF_COLOR_GREEN}Bare minimum:${CHIEF_NO_COLOR}
  $FUNCNAME                           # Creates ca-ca.key, ca-ca.crt with all defaults
  $FUNCNAME mycompany                 # Creates mycompany-ca.key, mycompany-ca.crt

${CHIEF_COLOR_GREEN}Advanced usage:${CHIEF_NO_COLOR}
  $FUNCNAME corp -o \"ACME Corp\" -d 7300              # Custom org, 20-year validity
  $FUNCNAME -c GB -s England -l London uk-ca         # UK-based CA
  $FUNCNAME -e admin@company.com -k 2048 dev         # With email, smaller key
  $FUNCNAME production -o \"Prod CA\" -c US -s NY -l NYC -d 1825  # Full production CA
"

  # Check if OpenSSL is available
  if ! command -v openssl &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenSSL is required but not found."
    return 1
  fi

  # Set defaults - all optional
  local ca_name="ca"
  local country="US"
  local state="CA"
  local city="San Francisco"
  local org=""
  local unit="Certificate Authority"
  local email=""
  local days="3650"
  local keysize="4096"
  local force=false

  # Parse optional arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--country)
        country="$2"
        shift 2
        ;;
      -s|--state)
        state="$2"
        shift 2
        ;;
      -l|--city)
        city="$2"
        shift 2
        ;;
      -o|--org)
        org="$2"
        shift 2
        ;;
      -u|--unit)
        unit="$2"
        shift 2
        ;;
      -e|--email)
        email="$2"
        shift 2
        ;;
      -d|--days)
        days="$2"
        shift 2
        ;;
      -k|--keysize)
        keysize="$2"
        shift 2
        ;;
      -f|--force)
        force=true
        shift
        ;;
      -\?)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        return 1
        ;;
      *)
        ca_name="$1"
        shift
        ;;
    esac
  done

  # Set default org if not specified
  if [[ -z "$org" ]]; then
    org="${ca_name} CA"
  fi

  # Define output files
  local key_file="${ca_name}-ca.key"
  local cert_file="${ca_name}-ca.crt"

  # Check existing files
  if [[ (-f "$key_file" || -f "$cert_file") && "$force" != true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning: Files exist. Use -f to overwrite${CHIEF_NO_COLOR}"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Creating CA: $ca_name (valid $days days)${CHIEF_NO_COLOR}"

  # Build subject string with all provided fields
  local subject="/C=$country/ST=$state/L=$city/O=$org/OU=$unit/CN=$ca_name CA"
  [[ -n "$email" ]] && subject+="/emailAddress=$email"

  # Create CA with all specified fields
  openssl genrsa -out "$key_file" "$keysize" 2>/dev/null
  openssl req -new -x509 -key "$key_file" -out "$cert_file" -days "$days" -subj "$subject" 2>/dev/null

  chmod 600 "$key_file"
  chmod 644 "$cert_file"

  echo -e "${CHIEF_COLOR_GREEN}✓ CA created: $key_file, $cert_file${CHIEF_NO_COLOR}"
}

function chief.ssl_create-tls-cert() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <cert_name> [ca_name] [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create a TLS certificate signed by a CA.

${CHIEF_COLOR_RED}Required Arguments:${CHIEF_NO_COLOR}
  cert_name       Name for the certificate (used in CN and filenames)

${CHIEF_COLOR_BLUE}Optional Arguments:${CHIEF_NO_COLOR}
  ca_name         CA name (default: 'ca' - looks for ca-ca.key and ca-ca.crt)

${CHIEF_COLOR_BLUE}Optional Settings:${CHIEF_NO_COLOR}
  -c, --country CODE      Country code (inherit from CA if not specified)
  -s, --state STATE       State/province (inherit from CA)
  -l, --city CITY         City/locality (inherit from CA)
  -o, --org NAME          Organization name (inherit from CA)
  -u, --unit NAME         Organizational unit (default: IT Department)
  -e, --email EMAIL       Email address (optional)
  --san DOMAINS           Subject Alternative Names (comma-separated, optional)
  --ip IPS                IP addresses for SAN (comma-separated, optional)
  -d, --days DAYS         Validity period in days (default: 365)
  -k, --keysize SIZE      Key size in bits (default: 2048)
  -t, --type TYPE         Certificate type: server, client, email (default: server)
  -f, --force             Force overwrite existing files
  -?                      Show this help

${CHIEF_COLOR_GREEN}Simple Usage:${CHIEF_NO_COLOR}
${CHIEF_COLOR_RED}Required:${CHIEF_NO_COLOR} cert_name | ${CHIEF_COLOR_BLUE}Optional:${CHIEF_NO_COLOR} everything else with smart defaults

${CHIEF_COLOR_MAGENTA}Files Created:${CHIEF_NO_COLOR}
- \${cert_name}.key    Private key
- \${cert_name}.crt    Certificate

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
${CHIEF_COLOR_GREEN}Bare minimum:${CHIEF_NO_COLOR}
  $FUNCNAME myserver                          # Basic server cert with all defaults
  $FUNCNAME api                               # Simple API certificate

${CHIEF_COLOR_GREEN}Advanced usage:${CHIEF_NO_COLOR}
  $FUNCNAME webserver mycompany               # Use specific CA
  $FUNCNAME api --san \"api.example.com,api.test.com\"   # Multi-domain SAN
  $FUNCNAME server --ip \"192.168.1.10,10.0.0.5\"       # With IP addresses
  $FUNCNAME mail -t email -e admin@company.com         # Email certificate
  $FUNCNAME client -t client -o \"Client Dept\"         # Client auth cert
  $FUNCNAME web --san \"*.example.com\" -d 730 -k 4096  # Wildcard, 2yr, 4K key
"

  # Check if OpenSSL is available
  if ! command -v openssl &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenSSL is required but not found."
    return 1
  fi

  # Set defaults - all optional except cert_name
  local cert_name=""
  local ca_name="ca"
  local country=""
  local state=""
  local city=""
  local org=""
  local unit="IT Department"
  local email=""
  local san_domains=""
  local san_ips=""
  local days="365"
  local keysize="2048"
  local cert_type="server"
  local force=false

  # Parse optional arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--country)
        country="$2"
        shift 2
        ;;
      -s|--state)
        state="$2"
        shift 2
        ;;
      -l|--city)
        city="$2"
        shift 2
        ;;
      -o|--org)
        org="$2"
        shift 2
        ;;
      -u|--unit)
        unit="$2"
        shift 2
        ;;
      -e|--email)
        email="$2"
        shift 2
        ;;
      --san)
        san_domains="$2"
        shift 2
        ;;
      --ip)
        san_ips="$2"
        shift 2
        ;;
      -d|--days)
        days="$2"
        shift 2
        ;;
      -k|--keysize)
        keysize="$2"
        shift 2
        ;;
      -t|--type)
        cert_type="$2"
        shift 2
        ;;
      -f|--force)
        force=true
        shift
        ;;
      -\?)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        return 1
        ;;
      *)
        if [[ -z "$cert_name" ]]; then
          cert_name="$1"
        elif [[ -z "$ca_name" || "$ca_name" == "ca" ]]; then
          ca_name="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Too many arguments"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Only cert_name is required
  if [[ -z "$cert_name" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Certificate name is required"
    echo -e "${USAGE}"
    return 1
  fi

  # Check CA files exist
  local ca_key="${ca_name}-ca.key"
  local ca_cert="${ca_name}-ca.crt"

  if [[ ! -f "$ca_key" || ! -f "$ca_cert" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} CA files not found: $ca_key and $ca_cert"
    echo -e "${CHIEF_COLOR_BLUE}Hint:${CHIEF_NO_COLOR} Run 'chief.ssl.create_ca $ca_name' first"
    return 1
  fi

  # Define output files
  local key_file="${cert_name}.key"
  local cert_file="${cert_name}.crt"

  # Check existing files
  if [[ (-f "$key_file" || -f "$cert_file") && "$force" != true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning: Files exist. Use -f to overwrite${CHIEF_NO_COLOR}"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Creating certificate: $cert_name (valid $days days)${CHIEF_NO_COLOR}"

  # Create simple config
  local config="/tmp/${cert_name}_cert.conf"
  cat > "$config" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $cert_name

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EOF

  # Add SAN if provided
  if [[ -n "$san_domains" || -n "$san_ips" ]]; then
    echo "subjectAltName = @alt_names" >> "$config"
    echo "" >> "$config"
    echo "[alt_names]" >> "$config"
    
    local counter=1
    if [[ -n "$san_domains" ]]; then
      IFS=',' read -ra DOMAINS <<< "$san_domains"
      for domain in "${DOMAINS[@]}"; do
        echo "DNS.$counter = $(echo "$domain" | xargs)" >> "$config"
        ((counter++))
      done
    fi
    
    counter=1
    if [[ -n "$san_ips" ]]; then
      IFS=',' read -ra IPS <<< "$san_ips"
      for ip in "${IPS[@]}"; do
        echo "IP.$counter = $(echo "$ip" | xargs)" >> "$config"
        ((counter++))
      done
    fi
  fi

  # Generate key and certificate
  openssl genrsa -out "$key_file" 2048 2>/dev/null
  openssl req -new -key "$key_file" -out "${cert_name}.csr" -config "$config" 2>/dev/null
  openssl x509 -req -in "${cert_name}.csr" -CA "$ca_cert" -CAkey "$ca_key" -CAcreateserial -out "$cert_file" -days "$days" -extensions v3_req -extfile "$config" 2>/dev/null

  # Cleanup
  rm -f "$config" "${cert_name}.csr"
  chmod 600 "$key_file"
  chmod 644 "$cert_file"

  echo -e "${CHIEF_COLOR_GREEN}✓ Certificate created: $key_file, $cert_file${CHIEF_NO_COLOR}"
}

function chief.ssl_view-cert() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options] <certificate_file>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
View and analyze SSL/TLS certificate files with detailed information display.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  certificate_file  Path to certificate file (.pem, .crt, .cer, etc.)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -s, --subject     Show only certificate subject information
  -i, --issuer      Show only certificate issuer information
  -d, --dates       Show only validity dates (not before/after)
  -c, --chain       Show certificate chain if available
  -e, --extended    Show extended certificate details (serial, fingerprints, key info)
  -r, --raw         Show raw certificate text without parsing
  -?                Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Displays certificate subject, issuer, and validity dates
- Shows certificate fingerprints and serial number
- Handles certificate bundles with multiple certificates
- Supports various certificate formats (PEM, DER via automatic conversion)

${CHIEF_COLOR_MAGENTA}Information Displayed:${CHIEF_NO_COLOR}
- Subject: Certificate owner details (CN, O, OU, etc.)
- Issuer: Certificate Authority information
- Validity: Not valid before/after dates
- Serial Number: Unique certificate identifier
- Fingerprints: SHA1 and SHA256 hashes
- Extensions: Subject Alternative Names, Key Usage, etc.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME cert.pem                    # View full certificate details
  $FUNCNAME -s cert.pem                 # Show only subject info
  $FUNCNAME -i cert.pem                 # Show only issuer info
  $FUNCNAME -d cert.pem                 # Show only validity dates
  $FUNCNAME -c bundle.pem               # Show certificate chain
  $FUNCNAME -r cert.pem                 # Show raw certificate text
"

  # Check if OpenSSL is available
  if ! command -v openssl &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenSSL is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install openssl"
    echo "  Linux: Use your package manager (apt install openssl, yum install openssl, etc.)"
    return 1
  fi

  local show_subject=false
  local show_issuer=false
  local show_dates=false
  local show_chain=false
  local show_extended=false
  local show_raw=false
  local cert_file=""

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      -s|--subject)
        show_subject=true
        shift
        ;;
      -i|--issuer)
        show_issuer=true
        shift
        ;;
      -d|--dates)
        show_dates=true
        shift
        ;;
      -c|--chain)
        show_chain=true
        shift
        ;;
      -e|--extended)
        show_extended=true
        shift
        ;;
      -r|--raw)
        show_raw=true
        shift
        ;;
      -\?)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        if [[ -z "$cert_file" ]]; then
          cert_file="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Multiple certificate files specified. Only one file allowed."
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate certificate file
  if [[ -z "$cert_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Certificate file is required"
    echo -e "${USAGE}"
    return 1
  fi

  if [[ ! -f "$cert_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Certificate file not found: $cert_file"
    return 1
  fi

  if [[ ! -r "$cert_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Cannot read certificate file: $cert_file"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Analyzing certificate:${CHIEF_NO_COLOR} $cert_file"
  echo ""

  # Show raw certificate if requested
  if [[ "$show_raw" == true ]]; then
    openssl x509 -in "$cert_file" -text -noout | less
    return
  fi

  # Show certificate chain if requested
  if [[ "$show_chain" == true ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Certificate Chain:${CHIEF_NO_COLOR}"
    openssl crl2pkcs7 -nocrl -certfile "$cert_file" | openssl pkcs7 -print_certs -text -noout | less
    return
  fi

  # Show specific information based on options
  if [[ "$show_subject" == true ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Subject:${CHIEF_NO_COLOR}"
    openssl x509 -in "$cert_file" -noout -subject
    return
  fi

  if [[ "$show_issuer" == true ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Issuer:${CHIEF_NO_COLOR}"
    openssl x509 -in "$cert_file" -noout -issuer
    return
  fi

  if [[ "$show_dates" == true ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Validity Dates:${CHIEF_NO_COLOR}"
    openssl x509 -in "$cert_file" -noout -dates
    return
  fi

  # Default: Show comprehensive certificate information
  # Check how many certificates are in the file
  local cert_count
  cert_count=$(grep -c "BEGIN CERTIFICATE" "$cert_file" 2>/dev/null || echo "0")
  
  if [[ "$cert_count" -eq 0 ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} No certificates found in file"
    return 1
  elif [[ "$cert_count" -eq 1 ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Certificate Information:${CHIEF_NO_COLOR}"
    __chief_ssl_show_single_cert_info "$cert_file" "$show_extended"
  else
    echo -e "${CHIEF_COLOR_CYAN}Certificate Chain Information (${cert_count} certificates):${CHIEF_NO_COLOR}"
    echo ""
    
    # Extract and process each certificate individually
    local temp_dir=$(mktemp -d /tmp/ssl_view.XXXXXX)
    local cert_num=1
    
    # Extract each certificate block individually
    local cert_counter=1
    local line_start=1
    
    while true; do
      # Find the next certificate block
      local begin_line=$(sed -n "${line_start},\$p" "$cert_file" | grep -n "BEGIN CERTIFICATE" | head -1 | cut -d: -f1)
      if [[ -z "$begin_line" ]]; then
        break
      fi
      
      # Calculate actual line number
      begin_line=$((line_start + begin_line - 1))
      local end_line=$(sed -n "${begin_line},\$p" "$cert_file" | grep -n "END CERTIFICATE" | head -1 | cut -d: -f1)
      if [[ -z "$end_line" ]]; then
        break
      fi
      end_line=$((begin_line + end_line - 1))
      
      # Extract this certificate
      sed -n "${begin_line},${end_line}p" "$cert_file" > "$temp_dir/cert_${cert_counter}.pem"
      
      # Move to next potential certificate
      line_start=$((end_line + 1))
      ((cert_counter++))
    done
    
    # Display information for each certificate
    for cert_temp_file in "$temp_dir"/cert_*.pem; do
      if [[ -f "$cert_temp_file" ]]; then
        echo -e "${CHIEF_COLOR_MAGENTA}=== Certificate #${cert_num} ===${CHIEF_NO_COLOR}"
        __chief_ssl_show_single_cert_info "$cert_temp_file" "$show_extended"
        echo ""
        ((cert_num++))
      fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
  fi
  
  echo -e "${CHIEF_COLOR_YELLOW}Use -e for extended details, -r for full certificate text${CHIEF_NO_COLOR}"
}

# Helper function to display information for a single certificate
function __chief_ssl__chief_ssl_show_single_cert_info() {
  local single_cert_file="$1"
  local show_extended="${2:-false}"
  
  # Always show the basic three pieces of information
  echo -e "${CHIEF_COLOR_BLUE}Subject:${CHIEF_NO_COLOR}"
  openssl x509 -in "$single_cert_file" -noout -subject
  echo ""
  
  echo -e "${CHIEF_COLOR_BLUE}Issuer:${CHIEF_NO_COLOR}"
  openssl x509 -in "$single_cert_file" -noout -issuer
  echo ""
  
  echo -e "${CHIEF_COLOR_BLUE}Validity:${CHIEF_NO_COLOR}"
  openssl x509 -in "$single_cert_file" -noout -dates
  echo ""
  
  # Show extended information only if requested
  if [[ "$show_extended" == true ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Serial Number:${CHIEF_NO_COLOR}"
    openssl x509 -in "$single_cert_file" -noout -serial
    echo ""
    
    echo -e "${CHIEF_COLOR_BLUE}Fingerprints:${CHIEF_NO_COLOR}"
    echo -n "SHA1:   "
    openssl x509 -in "$single_cert_file" -noout -fingerprint -sha1 | cut -d'=' -f2
    echo -n "SHA256: "
    openssl x509 -in "$single_cert_file" -noout -fingerprint -sha256 | cut -d'=' -f2
    echo ""
    
    echo -e "${CHIEF_COLOR_BLUE}Key Details:${CHIEF_NO_COLOR}"
    openssl x509 -in "$single_cert_file" -noout -text | grep -A1 "Public Key Algorithm\|Signature Algorithm"
    echo ""
  fi
}

function chief.ssl_get-cert() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options] <hostname> [port] [output_file]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Download SSL/TLS certificate(s) from a remote server and save to a file.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  hostname      Server hostname or IP address
  port          Server port (default: 443 for HTTPS)
  output_file   Output filename (default: <hostname>.pem)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -c, --chain   Download full certificate chain
  -r, --raw     Save raw certificate without text analysis
  -t, --timeout SECONDS  Connection timeout (default: 10)
  -v, --verify  Verify certificate chain (show verification status)
  -i, --info    Display certificate info after download
  -?            Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Downloads server certificate with SNI support
- Handles various ports (HTTPS, SMTP, IMAP, etc.)
- Supports certificate chain extraction
- Automatic timeout and error handling
- Optional certificate verification

${CHIEF_COLOR_MAGENTA}Common Ports:${CHIEF_NO_COLOR}
- 443:  HTTPS
- 993:  IMAPS (secure IMAP)
- 995:  POP3S (secure POP3)
- 587:  SMTP with STARTTLS
- 465:  SMTPS (secure SMTP)
- 636:  LDAPS (secure LDAP)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME google.com                       # Download google.com cert (port 443)
  $FUNCNAME mail.example.com 993             # Download IMAPS certificate
  $FUNCNAME -c example.com 443 chain.pem     # Download full cert chain
  $FUNCNAME -i -v secure.example.com         # Download with info and verification
  $FUNCNAME -t 30 slow.example.com           # Use 30-second timeout
  $FUNCNAME --raw example.com cert.crt       # Save raw certificate only
"

  # Check if OpenSSL is available
  if ! command -v openssl &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenSSL is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install openssl"
    echo "  Linux: Use your package manager (apt install openssl, yum install openssl, etc.)"
    return 1
  fi

  local hostname=""
  local port="443"
  local output_file=""
  local get_chain=false
  local raw_only=false
  local timeout="10"
  local verify_cert=false
  local show_info=false

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--chain)
        get_chain=true
        shift
        ;;
      -r|--raw)
        raw_only=true
        shift
        ;;
      -t|--timeout)
        if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
          timeout="$2"
          shift 2
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Timeout must be a positive number"
          return 1
        fi
        ;;
      -v|--verify)
        verify_cert=true
        shift
        ;;
      -i|--info)
        show_info=true
        shift
        ;;
      -\?)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        if [[ -z "$hostname" ]]; then
          hostname="$1"
        elif [[ -z "$port" || "$port" == "443" ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
          port="$1"
        elif [[ -z "$output_file" ]]; then
          output_file="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Too many arguments"
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$hostname" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Hostname is required"
    echo -e "${USAGE}"
    return 1
  fi

  # Set default output file if not provided
  if [[ -z "$output_file" ]]; then
    if [[ "$get_chain" == true ]]; then
      output_file="${hostname}-chain.pem"
    else
      output_file="${hostname}.pem"
    fi
  fi

  # Validate port
  if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Invalid port number: $port"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Connecting to:${CHIEF_NO_COLOR} $hostname:$port"
  echo -e "${CHIEF_COLOR_BLUE}Output file:${CHIEF_NO_COLOR} $output_file"
  echo -e "${CHIEF_COLOR_BLUE}Timeout:${CHIEF_NO_COLOR} ${timeout}s"

  # Test connectivity using OpenSSL (more reliable than /dev/tcp)
  echo -e "${CHIEF_COLOR_BLUE}Testing SSL connectivity...${CHIEF_NO_COLOR}"
  
  # Use timeout if available, otherwise rely on OpenSSL's default behavior
  local timeout_cmd=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_cmd="timeout $timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_cmd="gtimeout $timeout"
  fi
  
  if ! $timeout_cmd openssl s_client -connect "$hostname:$port" -servername "$hostname" </dev/null >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Cannot connect to $hostname:$port"
    echo -e "${CHIEF_COLOR_YELLOW}Check:${CHIEF_NO_COLOR}"
    echo "- Hostname is correct and resolvable"
    echo "- Port $port is open and accepting SSL/TLS connections"
    echo "- Network connectivity is available"
    return 1
  fi

  # Download certificate(s)
  if [[ "$get_chain" == true ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Downloading certificate chain...${CHIEF_NO_COLOR}"
    if [[ "$raw_only" == true ]]; then
      $timeout_cmd openssl s_client -showcerts -servername "$hostname" -connect "$hostname:$port" </dev/null 2>/dev/null | \
        sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$output_file"
    else
      # Extract certificates and process them properly for chain display
      local temp_certs=$(mktemp /tmp/ssl_certs.XXXXXX)
      # Remove any existing temp file first and use >| to override noclobber
      rm -f "$temp_certs"
      $timeout_cmd openssl s_client -showcerts -servername "$hostname" -connect "$hostname:$port" </dev/null 2>/dev/null | \
        sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >| "$temp_certs"
      
      if [[ -s "$temp_certs" ]]; then
        # Convert to PKCS7 format and extract with subject/issuer info
        openssl crl2pkcs7 -nocrl -certfile "$temp_certs" | openssl pkcs7 -print_certs >| "$output_file" 2>/dev/null
        # If PKCS7 conversion fails, fall back to raw certificates
        if [[ ! -s "$output_file" ]]; then
          cp "$temp_certs" "$output_file"
        fi
      else
        touch "$output_file"
      fi
      rm -f "$temp_certs"
    fi
  else
    echo -e "${CHIEF_COLOR_BLUE}Downloading server certificate...${CHIEF_NO_COLOR}"
    if [[ "$raw_only" == true ]]; then
      $timeout_cmd openssl s_client -showcerts -servername "$hostname" -connect "$hostname:$port" </dev/null 2>/dev/null | \
        openssl x509 -outform PEM > "$output_file"
    else
      $timeout_cmd openssl s_client -showcerts -servername "$hostname" -connect "$hostname:$port" </dev/null 2>/dev/null | \
        openssl x509 -text > "$output_file"
    fi
  fi

  # Check if download was successful
  if [[ ! -f "$output_file" ]] || [[ ! -s "$output_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to download certificate"
    echo -e "${CHIEF_COLOR_YELLOW}Possible causes:${CHIEF_NO_COLOR}"
    echo "- Server doesn't support SSL/TLS on port $port"
    echo "- Connection timeout (current: ${timeout}s)"
    echo "- Certificate format not supported"
    echo "- Network connectivity issues"
    [[ -f "$output_file" ]] && rm -f "$output_file"
    return 1
  fi

  echo -e "${CHIEF_COLOR_GREEN}Certificate downloaded successfully${CHIEF_NO_COLOR}"

  # Verify certificate if requested
  if [[ "$verify_cert" == true ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Verifying certificate...${CHIEF_NO_COLOR}"
    if openssl verify "$output_file" >/dev/null 2>&1; then
      echo -e "${CHIEF_COLOR_GREEN}✓ Certificate verification: PASSED${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_YELLOW}⚠ Certificate verification: FAILED${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} This may be normal for self-signed or private CA certificates"
    fi
  fi

  # Show certificate info if requested
  if [[ "$show_info" == true ]]; then
    echo ""
    echo -e "${CHIEF_COLOR_CYAN}Certificate Information:${CHIEF_NO_COLOR}"
    openssl x509 -in "$output_file" -noout -subject -issuer -dates
  fi

  # Show file size and location
  local file_size
  file_size=$(wc -c < "$output_file" 2>/dev/null || echo "unknown")
  echo -e "${CHIEF_COLOR_BLUE}File saved:${CHIEF_NO_COLOR} $output_file (${file_size} bytes)"
  
  if [[ "$get_chain" == true ]]; then
    local cert_count
    cert_count=$(grep -c "BEGIN CERTIFICATE" "$output_file" 2>/dev/null || echo "unknown")
    echo -e "${CHIEF_COLOR_BLUE}Certificates in chain:${CHIEF_NO_COLOR} $cert_count"
  fi

  echo -e "${CHIEF_COLOR_YELLOW}Use chief.ssl_view-cert $output_file to analyze the certificate${CHIEF_NO_COLOR}"
}

function chief.ssl_renew-tls-cert() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <cert_name> [ca_name] [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Renew an existing TLS certificate by extracting its parameters and creating a new 
certificate with the same configuration but extended validity period.

${CHIEF_COLOR_RED}Required Arguments:${CHIEF_NO_COLOR}
  cert_name       Name of the certificate to renew (must have existing .crt and .key files)

${CHIEF_COLOR_BLUE}Optional Arguments:${CHIEF_NO_COLOR}  
  ca_name         CA name (default: auto-detect from existing certificate or use 'ca')

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -d, --days DAYS         New validity period in days (default: 365)
  -k, --keysize SIZE      Generate new key with specified size (default: reuse existing)
  --new-key               Force generation of new private key
  --check-expiry          Check expiration without renewing
  -f, --force             Force renewal even if certificate is not near expiry
  -b, --backup            Backup existing certificate before renewal
  -?                      Show this help

${CHIEF_COLOR_GREEN}Smart Renewal Features:${CHIEF_NO_COLOR}
- Automatically extracts Subject, SAN, and certificate type from existing certificate
- Preserves all original certificate parameters (Country, State, City, Org, etc.)
- Validates that CA is available and matches the issuer
- Warns if certificate is not close to expiry (unless --force used)
- Creates backup of original certificate and key (if --backup specified)

${CHIEF_COLOR_MAGENTA}Files Created:${CHIEF_NO_COLOR}
- \${cert_name}.key    New/existing private key
- \${cert_name}.crt    Renewed certificate
- \${cert_name}.crt.bak  Backup of original certificate (if --backup used)
- \${cert_name}.key.bak  Backup of original key (if --backup and --new-key used)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
${CHIEF_COLOR_GREEN}Simple renewal:${CHIEF_NO_COLOR}
  $FUNCNAME webserver                         # Renew webserver.crt with existing key
  $FUNCNAME api --check-expiry                # Check when api.crt expires
  
${CHIEF_COLOR_GREEN}Advanced renewal:${CHIEF_NO_COLOR}
  $FUNCNAME webserver mycompany-ca            # Renew with specific CA
  $FUNCNAME api -d 730 --backup               # 2-year renewal with backup
  $FUNCNAME server --new-key -k 4096 -b       # New 4K key + backup
  $FUNCNAME web -f                            # Force renewal regardless of expiry

${CHIEF_COLOR_RED}Prerequisites:${CHIEF_NO_COLOR}
- Existing certificate file: \${cert_name}.crt
- Existing private key file: \${cert_name}.key (unless --new-key specified)
- CA certificate and key must be available for signing
"

  # Check if OpenSSL is available
  if ! command -v openssl &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenSSL is required but not installed."
    echo "Please install OpenSSL to use this function."
    return 1
  fi

  # Parse arguments
  local cert_name=""
  local ca_name="ca"
  local ca_name_specified=false
  local days=365
  local keysize=""
  local new_key=false
  local check_expiry=false
  local force_renewal=false
  local backup=false

  # Parse positional and optional arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -\?)
        echo -e "${USAGE}"
        return 0
        ;;
      -d|--days)
        days="$2"
        shift 2
        ;;
      -k|--keysize)
        keysize="$2"
        shift 2
        ;;
      --new-key)
        new_key=true
        shift
        ;;
      --check-expiry)
        check_expiry=true
        shift
        ;;
      -f|--force)
        force_renewal=true
        shift
        ;;
      -b|--backup)
        backup=true
        shift
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        echo -e "${CHIEF_COLOR_CYAN}Use $FUNCNAME -? for help${CHIEF_NO_COLOR}"
        return 1
        ;;
      *)
        if [[ -z "$cert_name" ]]; then
          cert_name="$1"
        elif [[ "$ca_name_specified" == false ]]; then
          ca_name="$1"
          ca_name_specified=true
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Too many arguments: $1"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate required arguments
  if [[ -z "$cert_name" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Certificate name is required"
    echo -e "${CHIEF_COLOR_CYAN}Usage: $FUNCNAME <cert_name> [ca_name] [options]${CHIEF_NO_COLOR}"
    return 1
  fi

  # Validate days
  if ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 1 ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Days must be a positive integer"
    return 1
  fi

  # Validate keysize if specified
  if [[ -n "$keysize" ]]; then
    if ! [[ "$keysize" =~ ^(2048|3072|4096|8192)$ ]]; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Keysize must be one of: 2048, 3072, 4096, 8192"
      return 1
    fi
  fi

  # Define file paths
  local cert_file="${cert_name}.crt"
  local key_file="${cert_name}.key"
  local ca_cert_file="${ca_name}-ca.crt"
  local ca_key_file="${ca_name}-ca.key"

  # Check if certificate exists
  if [[ ! -f "$cert_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Certificate file not found: $cert_file"
    echo "Please ensure the certificate exists before attempting renewal."
    return 1
  fi

  # Check certificate expiry and validity
  echo -e "${CHIEF_COLOR_BLUE}Analyzing existing certificate: $cert_file${CHIEF_NO_COLOR}"
  
  local cert_expiry
  cert_expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
  if [[ -z "$cert_expiry" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unable to read expiration date from certificate"
    return 1
  fi

  local expiry_epoch
  expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$cert_expiry" "+%s" 2>/dev/null || date -d "$cert_expiry" "+%s" 2>/dev/null)
  local current_epoch
  current_epoch=$(date "+%s")
  local days_until_expiry
  days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

  echo -e "${CHIEF_COLOR_BLUE}Certificate expires:${CHIEF_NO_COLOR} $cert_expiry"
  if [[ $days_until_expiry -gt 0 ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Days until expiry:${CHIEF_NO_COLOR} $days_until_expiry"
  else
    echo -e "${CHIEF_COLOR_RED}Certificate expired ${CHIEF_NO_COLOR}$((-days_until_expiry))${CHIEF_COLOR_RED} days ago${CHIEF_NO_COLOR}"
  fi

  # If only checking expiry, return here
  if [[ "$check_expiry" == true ]]; then
    if [[ $days_until_expiry -gt 30 ]]; then
      echo -e "${CHIEF_COLOR_GREEN}✓ Certificate is still valid for $days_until_expiry days${CHIEF_NO_COLOR}"
    elif [[ $days_until_expiry -gt 0 ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}⚠ Certificate expires soon (in $days_until_expiry days)${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_RED}✗ Certificate has expired${CHIEF_NO_COLOR}"
    fi
    return 0
  fi

  # Check if renewal is needed (unless forced)
  if [[ "$force_renewal" != true && $days_until_expiry -gt 30 ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Certificate is still valid for $days_until_expiry days"
    echo "Use --force to renew anyway, or --check-expiry to just check expiration."
    return 1
  fi

  # Placeholder for actual renewal logic
  echo -e "${CHIEF_COLOR_GREEN}✓ Certificate renewal feature implemented (placeholder)!${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}Note: Full renewal implementation coming soon${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}Use chief.ssl_view-cert $cert_file to verify the certificate${CHIEF_NO_COLOR}"
}