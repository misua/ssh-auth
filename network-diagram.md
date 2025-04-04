# SSH Certificate Authority - Network Architecture and Flow

## Network Architecture

```
                                    +----------------+
                                    |                |
                                    |    Internet    |
                                    |                |
                                    +--------+-------+
                                             |
                                             |
                                    +--------v-------+
                                    |  Internet GW   |
                                    +--------+-------+
                                             |
            AWS VPC                          |
 +-------------------------------+  +--------+-------+
 |                               |  |                |
 |  Public Subnets               |  |   NAT Gateway  |
 |  +-------------+ +----------+ |  |                |
 |  | Jumpbox-Dev | | Jumpbox- | |  +--------+-------+
 |  |             | | Staging  | |           |
 |  +-------------+ +----------+ |           |
 |                               |           |
 |  +-------------+              |           |
 |  | Jumpbox-Prod|              |           |
 |  |             |              |           |
 |  +-------------+              |           |
 |                               |           |
 |  Private Subnets              |           |
 |  +-------------+              |           |
 |  | Vault Server|<-------------+-----------+
 |  | (SSH CA)    |              |
 |  +-------------+              |
 |                               |
 +-------------------------------+
```

## Authentication Flow

```
+-------+                  +-------------+                  +---------+
| User  |                  | Vault Server|                  | Jumpbox |
+-------+                  +-------------+                  +---------+
    |                             |                              |
    |                             |                              |
    |  Initial Setup (One-time)   |                              |
    |                             |                              |
    | Generate SSH key pair       |                              |
    |---------------------------->|                              |
    |                             |                              |
    |                             | Generate CA key pair         |
    |                             |------------------------+     |
    |                             |                        |     |
    |                             |<-----------------------+     |
    |                             |                              |
    |                             | Install CA public key        |
    |                             |----------------------------->|
    |                             |                              |
    |                             |                              |
    |  Authentication Flow        |                              |
    |                             |                              |
    | Authenticate (username/pwd) |                              |
    |---------------------------->|                              |
    |                             |                              |
    |        Return auth token    |                              |
    |<----------------------------|                              |
    |                             |                              |
    | Request cert signing        |                              |
    | (Send public key + token)   |                              |
    |---------------------------->|                              |
    |                             |                              |
    |                             | Verify permissions           |
    |                             |------------------------+     |
    |                             |                        |     |
    |                             |<-----------------------+     |
    |                             |                              |
    |                             | Sign public key with         |
    |                             | CA private key               |
    |                             |------------------------+     |
    |                             |                        |     |
    |                             |<-----------------------+     |
    |                             |                              |
    |        Return signed cert   |                              |
    |<----------------------------|                              |
    |                             |                              |
    | SSH with private key + cert |                              |
    |---------------------------------------------------------->|
    |                             |                              |
    |                             |                              | Verify cert signature
    |                             |                              | using CA public key
    |                             |                              |---------------+
    |                             |                              |               |
    |                             |                              |<--------------+
    |                             |                              |
    |                             |                              | Verify cert not expired
    |                             |                              |---------------+
    |                             |                              |               |
    |                             |                              |<--------------+
    |                             |                              |
    |                             |                              | Verify authorized
    |                             |                              | principals
    |                             |                              |---------------+
    |                             |                              |               |
    |                             |                              |<--------------+
    |                             |                              |
    |                             |                 Grant access |
    |<----------------------------------------------------------|
    |                             |                              |
```

## Certificate Lifecycle

```
  +----------------+     +-------------------+     +------------------+
  | Key Generation |---->| Certificate       |---->| Certificate      |
  | User generates |     | Request           |     | Issued           |
  | SSH key pair   |     | User authenticates|     | Vault signs      |
  +----------------+     | to Vault          |     | public key       |
                         +-------------------+     +------------------+
                                                            |
                                                            v
  +----------------+     +-------------------+     +------------------+
  | Certificate    |<----| Certificate       |<----| Certificate      |
  | Request        |     | Expired           |     | Active           |
  | User requests  |     | TTL expires       |     | User receives    |
  | new certificate|     | (24h default)     |     | certificate      |
  +----------------+     +-------------------+     +------------------+
                                                            |
                                                            v
                                                   +------------------+
                                                   | Certificate      |
                                                   | Revoked          |
                                                   | Admin revokes    |
                                                   | access           |
                                                   +------------------+
```

## Traditional vs Certificate-Based SSH Authentication

```
Traditional SSH Key Management:
+----------------+     +----------------+     +----------------+
| Authorized     |---->| Key            |---->| Cron Jobs      |
| Keys Files     |     | Distribution   |     |                |
|                |     | Scripts        |     |                |
+----------------+     +----------------+     +----------------+
                                                      |
                                                      v
                                              +----------------+
                                              | Servers        |
                                              |                |
                                              +----------------+

Certificate-Based SSH Authentication:
                       +----------------+
                       | Certificate    |
                       | Authority      |
                       |                |
                       +----------------+
                          /          \
                         /            \
                        v              v
            +----------------+     +----------------+
            | CA Public Key  |     | Certificates   |
            |                |     |                |
            +----------------+     +----------------+
                    |                      |
                    v                      v
            +----------------+     +----------------+
            | Servers        |     | Users          |
            |                |     |                |
            +----------------+     +----------------+
```
