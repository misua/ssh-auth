# SSH Server configuration for enhanced logging
# Add this to /etc/ssh/sshd_config

# Enable verbose logging for SSH connections
LogLevel VERBOSE

# Log authentication methods
SyslogFacility AUTH
PrintLastLog yes

# Trust the Vault CA for user certificates
TrustedUserCAKeys /etc/ssh/trusted-user-ca-key.pub

# Enable certificate authentication
PubkeyAuthentication yes

# Configure detailed logging for certificate authentication
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
AuthorizedKeysFile .ssh/authorized_keys

# Log all accepted and rejected connections
LogLevel INFO

# Additional security settings
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Audit configuration
AcceptEnv LANG LC_*
PrintMotd no

# Enable audit logging for SSH sessions
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
