# SSH Certificate Authority Flow Diagrams

## Network Architecture Diagram

```mermaid
flowchart TB
    subgraph "AWS Cloud"
        subgraph "VPC"
            subgraph "Public Subnets"
                JB1[Jumpbox - Dev]
                JB2[Jumpbox - Staging]
                JB3[Jumpbox - Prod]
                IGW[Internet Gateway]
            end
            
            subgraph "Private Subnets"
                VS[Vault Server]
                NAT[NAT Gateway]
            end
            
            JB1 --- IGW
            JB2 --- IGW
            JB3 --- IGW
            IGW --- Internet((Internet))
            
            VS --- NAT
            NAT --- IGW
        end
    end
    
    User((User)) --- Internet
    User --- JB1
    User --- JB2
    User --- JB3
    
    JB1 -.- VS
    JB2 -.- VS
    JB3 -.- VS
    
    classDef publicSubnet fill:#99ccff,stroke:#333,stroke-width:1px
    classDef privateSubnet fill:#ffcc99,stroke:#333,stroke-width:1px
    classDef gateway fill:#ccff99,stroke:#333,stroke-width:1px
    classDef server fill:#ff9999,stroke:#333,stroke-width:1px
    classDef user fill:#cc99ff,stroke:#333,stroke-width:1px
    
    class JB1,JB2,JB3 publicSubnet
    class VS privateSubnet
    class IGW,NAT gateway
    class User user
```

## SSH Certificate Authentication Flow

```mermaid
sequenceDiagram
    participant User
    participant Vault as Vault Server
    participant Jumpbox
    
    Note over User,Jumpbox: Initial Setup (One-time)
    User->>Vault: Generate SSH key pair
    Vault->>Vault: Generate CA key pair
    Vault->>Jumpbox: Install CA public key
    
    Note over User,Jumpbox: Authentication Flow
    User->>Vault: Authenticate (username/password)
    Vault->>User: Return authentication token
    User->>Vault: Request certificate signing<br>(Send public key + token)
    Vault->>Vault: Verify permissions
    Vault->>Vault: Sign public key with CA private key
    Vault->>User: Return signed certificate
    User->>Jumpbox: SSH with private key + certificate
    Jumpbox->>Jumpbox: Verify certificate signature<br>using CA public key
    Jumpbox->>Jumpbox: Verify certificate not expired
    Jumpbox->>Jumpbox: Verify authorized principals
    Jumpbox->>User: Grant access
```

## Certificate Lifecycle

```mermaid
stateDiagram-v2
    [*] --> KeyGeneration: User generates SSH key pair
    KeyGeneration --> CertificateRequest: User authenticates to Vault
    CertificateRequest --> CertificateIssued: Vault signs public key
    CertificateIssued --> CertificateActive: User receives certificate
    CertificateActive --> CertificateExpired: TTL expires (24h default)
    CertificateExpired --> CertificateRequest: User requests new certificate
    CertificateActive --> CertificateRevoked: Admin revokes access
    CertificateRevoked --> [*]
    CertificateExpired --> [*]
```

## Component Relationships

```mermaid
flowchart TD
    subgraph "Vault Server"
        CA[SSH CA Key Pair]
        Auth[Authentication Methods]
        Policies[Access Policies]
        Roles[SSH Signing Roles]
        Audit[Audit Logs]
    end
    
    subgraph "Jumpbox"
        TrustedCA[Trusted CA Public Key]
        SSHD[SSH Daemon]
        Principals[Authorized Principals]
    end
    
    subgraph "User Workstation"
        KeyPair[SSH Key Pair]
        Cert[Signed Certificate]
        Client[SSH Client]
        Helper[vault-ssh-helper.sh]
    end
    
    Auth --> Policies
    Policies --> Roles
    CA --> Roles
    Roles --> Cert
    
    KeyPair --> Helper
    Helper --> Auth
    Helper --> Cert
    
    Cert --> Client
    KeyPair --> Client
    Client --> SSHD
    
    TrustedCA --> SSHD
    Principals --> SSHD
    
    SSHD --> Audit
    
    classDef vault fill:#ff9999,stroke:#333,stroke-width:1px
    classDef jumpbox fill:#99ccff,stroke:#333,stroke-width:1px
    classDef user fill:#ccff99,stroke:#333,stroke-width:1px
    
    class CA,Auth,Policies,Roles,Audit vault
    class TrustedCA,SSHD,Principals jumpbox
    class KeyPair,Cert,Client,Helper user
```

## Terraform Resource Relationships

```mermaid
flowchart LR
    subgraph "Terraform Modules"
        Main[main.tf]
        VPC[VPC Module]
        Vault[Vault Module]
        Jumpbox[Jumpbox Module]
    end
    
    Main --> VPC
    Main --> Vault
    Main --> Jumpbox
    
    VPC --> Vault
    VPC --> Jumpbox
    Vault --> Jumpbox
    
    subgraph "AWS Resources"
        VPCRes[VPC Resources]
        EC2Vault[Vault EC2 Instance]
        EC2Jump[Jumpbox EC2 Instances]
        SG[Security Groups]
        IAM[IAM Roles]
    end
    
    VPC --> VPCRes
    Vault --> EC2Vault
    Vault --> SG
    Vault --> IAM
    Jumpbox --> EC2Jump
    Jumpbox --> SG
    Jumpbox --> IAM
    
    classDef terraform fill:#99ccff,stroke:#333,stroke-width:1px
    classDef aws fill:#ff9999,stroke:#333,stroke-width:1px
    
    class Main,VPC,Vault,Jumpbox terraform
    class VPCRes,EC2Vault,EC2Jump,SG,IAM aws
```

## Comparison with Traditional SSH Key Management

```mermaid
flowchart TD
    subgraph "Traditional SSH Key Management"
        AK[Authorized Keys Files]
        KD[Key Distribution Scripts]
        CR[Cron Jobs]
        
        AK --> KD
        KD --> CR
        CR --> Servers1[Servers]
    end
    
    subgraph "Certificate-Based SSH Authentication"
        CA[Certificate Authority]
        CP[CA Public Key]
        CT[Certificates]
        
        CA --> CP
        CA --> CT
        CP --> Servers2[Servers]
        CT --> Users[Users]
    end
    
    classDef traditional fill:#ffcc99,stroke:#333,stroke-width:1px
    classDef certbased fill:#99ccff,stroke:#333,stroke-width:1px
    
    class AK,KD,CR,Servers1 traditional
    class CA,CP,CT,Servers2,Users certbased
```
