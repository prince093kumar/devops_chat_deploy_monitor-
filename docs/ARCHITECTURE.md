# System Architecture & Technical Design

## 1. High-Level Architecture Overview

This project implements an automated, production-grade DevOps deployment and continuous monitoring pipeline for a real-time microservices-based chat application. The system integrates **Terraform** for Infrastructure as Code (IaC), **Ansible** for automated configuration management and container orchestration, and **Nagios Core** for infrastructure and microservices health monitoring.

```mermaid
flowchart TD
    subgraph Local["Local Controller (WSL Ubuntu / Windows)"]
        TF["Terraform 1.x<br/>(Infrastructure as Code)"]
        AN["Ansible 2.15+<br/>(Configuration Management)"]
        SSH_KEY["Generated SSH Key Pair<br/>(4096-bit RSA)"]
    end

    subgraph AWS["Amazon Web Services (AWS Cloud)"]
        subgraph AppSG["App Security Group"]
            subgraph AppEC2["Chat Application Server (Ubuntu 22.04 LTS)"]
                subgraph DockerStack["Docker & Docker Compose Stack"]
                    FE["React Web Client<br/>(Port 3000)"]
                    GW["Central API Gateway<br/>(Port 5000)"]
                    AUTH["Auth Service<br/>(Port 5001)"]
                    CHAT["Chat Service<br/>(Port 5002)"]
                    NOTIF["Notification Service<br/>(Port 5003)"]
                    MONGO[("MongoDB 6.0<br/>Port 27017")]
                    REDIS[("Redis 7.0<br/>Port 6379")]
                end
                NRPE["NRPE Daemon<br/>(Port 5666)"]
            end
        end

        subgraph MonSG["Monitoring Security Group"]
            subgraph MonEC2["Nagios Monitoring Server (Ubuntu 22.04 LTS)"]
                NAGIOS["Nagios Core 4.x Engine"]
                APACHE["Apache2 + PHP Web UI<br/>(Port 80)"]
                PLUGINS["Nagios Plugins<br/>(check_http, check_ping, check_nrpe)"]
            end
        end
    end

    TF -->|"1. Provisions EC2, SGs, EBS"| AppEC2
    TF -->|"1. Provisions EC2, SGs, EBS"| MonEC2
    TF -->|"2. Auto-generates hosts.ini"| AN
    AN -->|"3. Installs Docker, clones app, runs compose"| AppEC2
    AN -->|"4. Installs & configures Nagios & Apache"| MonEC2

    NAGIOS -->|"Active HTTP Check (3000)"| FE
    NAGIOS -->|"Active HTTP Check (5000 /health)"| GW
    NAGIOS -->|"Active HTTP Check (5001, 5002, 5003)"| AUTH
    NAGIOS -->|"Active PING & SSH Check"| AppEC2
    NAGIOS -->|"NRPE Deep Metrics (Disk, Load, Docker Containers)"| NRPE
```

---

## 2. Infrastructure as Code (Terraform)

Terraform orchestrates the complete cloud infrastructure lifecycle declaratively on Amazon Web Services:

1. **EC2 Instances**:
   - **Chat Application Server (`app-server`)**: `t3.medium` (or `t2.medium`), 25 GB gp3 EBS root volume, Ubuntu 22.04 LTS. Sized to easily build and run 7 simultaneous Docker microservices.
   - **Nagios Monitoring Server (`monitoring-server`)**: `t3.micro` (or `t2.micro`), 15 GB gp3 EBS root volume, Ubuntu 22.04 LTS.
2. **Security Groups**:
   - `app_sg`:
     - Port 22: Restricted SSH administration.
     - Port 3000: Inbound HTTP for React Client.
     - Port 5000: Inbound HTTP for API Gateway.
     - Ports 5001, 5002, 5003: Inbound HTTP for direct microservice health verification.
     - Port 5666: Inbound NRPE encrypted monitoring from the Nagios server.
     - ICMP: Echo ping reachability from Nagios server.
   - `monitoring_sg`:
     - Port 22: Restricted SSH administration.
     - Port 80: Inbound HTTP for Nagios Core Web Dashboard.
3. **Automated SSH Key Management**:
   - Uses `tls_private_key` to generate a 4096-bit RSA key pair dynamically if no key is provided, saving it with `0600` permissions and attaching it to the instances.
4. **Automated Dynamic Inventory Synthesis**:
   - Using the `local_file` provider, Terraform automatically outputs `ansible/inventory/hosts.ini` containing the newly allocated public and private IP addresses, preventing manual copy-paste errors.

---

## 3. Configuration Management & Deployment (Ansible)

Ansible is organized into modular roles adhering to DevOps standards:

| Role | Target | Responsibility |
| :--- | :--- | :--- |
| **`common`** | All Nodes | System updates, baseline packages (`curl`, `git`, `htop`, `jq`), swap file setup (2GB to prevent build OOM), timezone sync. |
| **`docker`** | App Server | Official Docker CE repository setup, Docker Engine, Docker Compose Plugin, and user permissions (`usermod -aG docker ubuntu`). |
| **`app_deployment`**| App Server | Clones source repo from GitHub (`prince093kumar/winter_pep_final_project`), generates dynamic `docker-compose.override.yml` with current server IP, builds & launches containers, polls health endpoints. |
| **`nrpe_client`** | App Server | Installs `nagios-nrpe-server`, configures allowed hosts (`nrpe.cfg`), installs custom `check_docker_containers.sh` script to inspect running microservices. |
| **`nagios_server`** | Monitoring Server | Non-interactive installation of Nagios 4 & Apache2, htpasswd auth (`nagiosadmin`), configuration of hosts, service checks, commands, contacts, and automatic root HTTP redirect. |

---

## 4. Dynamic IP Injection Mechanism

The chat application contains client-side React code and an API Gateway that require the public IP address of the deployment server:

```mermaid
sequenceDiagram
    participant UserBrowser as User Browser
    participant ReactClient as React Frontend (:3000)
    participant APIGateway as API Gateway (:5000)
    participant Services as Microservices (Auth/Chat/Notif)

    UserBrowser->>ReactClient: Load Web UI (HTTP 3000)
    ReactClient-->>UserBrowser: Returns HTML + JS Bundle (configured with VITE_API_URL)
    UserBrowser->>APIGateway: REST / WebSocket Request (HTTP 5000)
    APIGateway->>APIGateway: Verifies JWT / Rate Limit
    APIGateway->>Services: Proxies to internal microservice (:5001, :5002, :5003)
    Services-->>APIGateway: Response
    APIGateway-->>UserBrowser: Final JSON Response
```

To eliminate hardcoded IP addresses, Ansible generates a `docker-compose.override.yml` using Jinja2 templating:
- Injects `CLIENT_URL=http://<app_server_ip>:3000` into `api_gateway`.
- Injects `VITE_API_URL=http://<app_server_ip>:5000` build argument into `chat_client`.
- Exposes internal service ports (`5001`, `5002`, `5003`) to allow direct monitoring checks by Nagios.

---

## 5. Monitoring & Failure Detection Architecture

Nagios Core runs continuous polling cycles against the Application Server using both **Active Network Checks** and **Passive/Agent NRPE Checks**:

```mermaid
flowchart LR
    subgraph Nagios["Nagios Poller"]
        CheckPing["check_ping"]
        CheckHTTP_FE["check_http (Port 3000)"]
        CheckHTTP_GW["check_http (Port 5000 /health)"]
        CheckHTTP_SVCS["check_http (Ports 5001-5003)"]
        CheckNRPE["check_nrpe (Port 5666)"]
    end

    subgraph AppHost["Application Host"]
        PingSvc["ICMP Ping Responder"]
        FESvc["React Frontend"]
        GWSvc["Express API Gateway"]
        MicroSvc["Auth/Chat/Notif Services"]
        NRPESvc["NRPE Server"]
        Dockerd["Docker Daemon & Containers"]
    end

    CheckPing -->|ICMP Echo| PingSvc
    CheckHTTP_FE -->|GET /| FESvc
    CheckHTTP_GW -->|GET /health| GWSvc
    CheckHTTP_SVCS -->|GET /| MicroSvc
    CheckNRPE -->|TCP 5666| NRPESvc
    NRPESvc -->|check_disk| AppHost
    NRPESvc -->|check_load| AppHost
    NRPESvc -->|check_docker_containers.sh| Dockerd
```

### State Transitions during Failure
1. **Normal Operation**: All checks return exit code `0` (`OK` - Green).
2. **Failure Introduced** (e.g. `docker stop chat_service`):
   - Active HTTP check on port 5002 returns `Connection Refused` (Exit code `2` -> `CRITICAL`).
   - NRPE `check_chat_containers` detects `chat_service` is missing/stopped (Exit code `2` -> `CRITICAL`).
   - Gateway `/api/messages` routes return 502/504 Bad Gateway.
   - Nagios triggers notification state and highlights the service in red.
3. **Recovery Introduced** (`./scripts/recover_service.sh`):
   - Container starts and binds to socket within 5 seconds.
   - Next polling cycle checks return exit code `0`.
   - Nagios transitions to `RECOVERY` (`OK` - Green).
