#!/bin/bash
# audit-ssh-certs.sh - Analyze and correlate SSH certificate logs
# This script helps audit SSH certificate issuance and usage

set -e

# Default configuration
VAULT_LOG_PATH="/var/log/vault/audit.log"
CERT_LOG_PATH="/var/log/vault/ssh-certs.log"
SSH_LOG_PATH="/var/log/auth.log"
OUTPUT_FORMAT="text"  # text or json
DAYS=7
USER=""
ENVIRONMENT=""

# Display help
function show_help {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -v, --vault-logs PATH    Path to Vault audit logs (default: $VAULT_LOG_PATH)"
    echo "  -c, --cert-logs PATH     Path to SSH certificate logs (default: $CERT_LOG_PATH)"
    echo "  -s, --ssh-logs PATH      Path to SSH auth logs (default: $SSH_LOG_PATH)"
    echo "  -d, --days DAYS          Number of days to analyze (default: $DAYS)"
    echo "  -u, --user USER          Filter by username"
    echo "  -e, --environment ENV    Filter by environment (prod, dev, staging)"
    echo "  -f, --format FORMAT      Output format: text or json (default: $OUTPUT_FORMAT)"
    echo "  -h, --help               Show this help message"
    echo
    echo "Example:"
    echo "  $0 -d 30 -u admin -e prod"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--vault-logs)
            VAULT_LOG_PATH="$2"
            shift 2
            ;;
        -c|--cert-logs)
            CERT_LOG_PATH="$2"
            shift 2
            ;;
        -s|--ssh-logs)
            SSH_LOG_PATH="$2"
            shift 2
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check if required tools are available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this script to work"
    echo "Install it with: sudo apt-get install jq"
    exit 1
fi

# Function to check if a file exists and is readable
check_file() {
    if [ ! -f "$1" ]; then
        echo "Warning: File $1 does not exist"
        return 1
    fi
    if [ ! -r "$1" ]; then
        echo "Warning: File $1 is not readable"
        return 1
    fi
    return 0
}

# Function to analyze Vault audit logs
analyze_vault_logs() {
    echo "=== Vault Audit Log Analysis ==="
    echo "Analyzing Vault audit logs for SSH certificate operations..."
    
    if ! check_file "$VAULT_LOG_PATH"; then
        echo "Skipping Vault audit log analysis"
        return
    fi
    
    # Filter logs by date, operation type, and user
    FILTER="."
    if [ -n "$USER" ]; then
        FILTER="$FILTER | select(.auth.metadata.username == \"$USER\")"
    fi
    
    # Extract SSH certificate signing operations
    cat "$VAULT_LOG_PATH" | grep "ssh-client-signer/sign" | \
    while read -r line; do
        echo "$line" | jq -r "$FILTER" 2>/dev/null | \
        jq -r '. | 
            "Time: \(.time) | User: \(.auth.metadata.username) | " + 
            "Operation: \(.type) | Path: \(.request.path) | " + 
            "Client IP: \(.request.remote_addr)"' 2>/dev/null
    done
}

# Function to analyze SSH certificate logs
analyze_cert_logs() {
    echo "=== SSH Certificate Issuance Log Analysis ==="
    
    if ! check_file "$CERT_LOG_PATH"; then
        echo "Skipping SSH certificate log analysis"
        return
    fi
    
    # Apply filters
    GREP_CMD="grep -a"
    if [ -n "$USER" ]; then
        GREP_CMD="$GREP_CMD -e \"User=$USER\""
    fi
    if [ -n "$ENVIRONMENT" ]; then
        GREP_CMD="$GREP_CMD -e \"Env=$ENVIRONMENT\""
    fi
    
    # Get logs from the last X days
    SINCE_DATE=$(date -d "$DAYS days ago" +"%Y-%m-%d")
    
    # Execute the command
    eval "$GREP_CMD \"$CERT_LOG_PATH\" | grep -a -A 0 \"$SINCE_DATE\""
}

# Function to analyze SSH auth logs
analyze_ssh_logs() {
    echo "=== SSH Authentication Log Analysis ==="
    
    if ! check_file "$SSH_LOG_PATH"; then
        echo "Skipping SSH authentication log analysis"
        return
    fi
    
    # Get logs from the last X days
    SINCE_DATE=$(date -d "$DAYS days ago" +"%Y-%m-%d")
    
    # Look for certificate authentication events
    grep -a "Accepted publickey" "$SSH_LOG_PATH" | \
    grep -a -A 0 "$SINCE_DATE" | \
    while read -r line; do
        # Extract timestamp, user, and source IP
        TIMESTAMP=$(echo "$line" | awk '{print $1,$2,$3}')
        SSH_USER=$(echo "$line" | awk '{print $9}')
        SOURCE_IP=$(echo "$line" | awk '{print $11}')
        
        # Apply filters
        if [ -n "$USER" ] && [ "$SSH_USER" != "$USER" ]; then
            continue
        fi
        
        echo "Time: $TIMESTAMP | User: $SSH_USER | Source IP: $SOURCE_IP"
    done
}

# Function to correlate certificate issuance with SSH logins
correlate_logs() {
    echo "=== Certificate Issuance and Usage Correlation ==="
    echo "Correlating certificate issuance with SSH logins..."
    
    # This is a simplified correlation - in a real environment, you'd want to
    # extract the certificate serial number or key ID and match it precisely
    
    if ! check_file "$CERT_LOG_PATH" || ! check_file "$SSH_LOG_PATH"; then
        echo "Skipping correlation analysis - missing required logs"
        return
    fi
    
    # Extract certificate issuances
    echo "Certificate issuances:"
    ISSUANCES=$(grep -a "Certificate issued" "$CERT_LOG_PATH")
    echo "$ISSUANCES" | head -n 10
    
    # Extract SSH logins
    echo "SSH logins:"
    LOGINS=$(grep -a "Accepted publickey" "$SSH_LOG_PATH")
    echo "$LOGINS" | head -n 10
    
    # Simple correlation based on timestamps and usernames
    # This is a placeholder for a more sophisticated correlation algorithm
    echo "Potential matches (certificate issued followed by SSH login):"
    
    # This is a simplified example - a real implementation would need more sophisticated matching
    echo "For a complete correlation, consider implementing a more advanced matching algorithm"
    echo "or using a dedicated log analysis tool like ELK stack."
}

# Main execution
echo "SSH Certificate Audit Report"
echo "============================"
echo "Date range: Last $DAYS days"
if [ -n "$USER" ]; then
    echo "Filtered by user: $USER"
fi
if [ -n "$ENVIRONMENT" ]; then
    echo "Filtered by environment: $ENVIRONMENT"
fi
echo

# Run analyses
analyze_vault_logs
echo
analyze_cert_logs
echo
analyze_ssh_logs
echo
correlate_logs

echo
echo "Audit complete. For more detailed analysis, consider using a dedicated log analysis platform."
