# Project Files & Folders Directory Guide

This document explains **every single folder and file** in this DevOps project in simple, easy-to-understand language.

---

## High-Level Folder Overview

```
project/
├── terraform/   - Provisions cloud resources on AWS (Servers, Firewalls, Keys)
├── ansible/     - Configures software on servers and deploys the Chat App & Nagios
├── scripts/     - Verification and failure/recovery test scripts
├── docs/        - Complete documentation, lab manual, test reports, and viva answers
├── .gitignore   - Tells Git which temporary/secret files NOT to upload to GitHub
└── README.md    - The main homepage for your GitHub project
```

---

## 1. `terraform/` (Infrastructure as Code)
*Purpose: Automatically creates your virtual servers on AWS without clicking in the AWS Console.*

| File Name | Simple Explanation |
| :--- | :--- |
| **`versions.tf`** | Specifies which versions of Terraform and cloud plugins (AWS, TLS, Local file) are required. |
| **`variables.tf`** | Stores all configurable settings like AWS region (`us-east-1`), server sizes (`t3.medium`, `t3.micro`), and disk sizes. |
| **`provider.tf`** | Connects Terraform to your AWS account and tags all created resources with your project name. |
| **`key_pair.tf`** | Automatically generates a secure 4096-bit RSA SSH key pair so you can securely log into your EC2 instances. |
| **`security_groups.tf`** | Virtual firewalls. Opens necessary ports: `22` (SSH), `3000` (React Frontend), `5000` (API Gateway), `80` (Nagios Web), and `5666` (NRPE monitoring). |
| **`ec2_instances.tf`** | The blueprint that tells AWS to launch **2 EC2 virtual machines** running Ubuntu 22.04 LTS (one for the Chat App, one for Nagios). |
| **`inventory.tf`** | The bridge between Terraform and Ansible. Once servers are created, it automatically writes their public IP addresses into `ansible/inventory/hosts.ini`. |
| **`outputs.tf`** | Prints the final IP addresses, website links, and SSH login commands on your screen after Terraform finishes. |
| **`terraform.tfvars.example`** | An optional template file where you can customize values (like instance sizes) before running. |

---

## 2. `ansible/` (Configuration Management & Deployment)
*Purpose: Connects to the AWS servers via SSH, installs software, clones your chat app, starts Docker, and configures Nagios.*

### Core Files & Folders
| File / Folder Name | Simple Explanation |
| :--- | :--- |
| **`ansible.cfg`** | Ansible configuration file. Sets connection settings, disables strict host key checking, and points to the inventory. |
| **`site.yml`** | **The Master Playbook.** Coordinates all steps in order: (1) baseline setup, (2) Docker & Chat App deployment, (3) Nagios monitoring setup. |
| **`deploy-app.yml`** | A mini-playbook used when you only want to re-deploy or update the chat app without touching Nagios. |
| **`configure-nagios.yml`**| A mini-playbook used when you only want to update Nagios monitoring rules without touching the chat app. |

### `ansible/inventory/` (Server Address Books)
| File Name | Simple Explanation |
| :--- | :--- |
| **`hosts.ini.example`** | A sample inventory file showing how server IPs are grouped. |
| **`hosts.ini`** | *(Auto-generated at runtime by Terraform)*. Contains the real, live public IP addresses of your AWS servers. |

### `ansible/group_vars/` (Settings & Variables)
| File Name | Simple Explanation |
| :--- | :--- |
| **`all.yml`** | Settings shared by all servers (e.g., adding 2GB swap space to prevent memory crashes). |
| **`app_servers.yml`** | Chat app settings: GitHub repo URL (`winter_pep_final_project`), ports (`3000`, `5000`, etc.), and secrets. |
| **`monitoring_servers.yml`** | Nagios settings: admin login (`nagiosadmin`), password (`Devops@2026`), and check check intervals. |

### `ansible/roles/` (Modular Task Packages)

#### A. Role: `common` (Applies to all servers)
* **`tasks/main.yml`**: Updates Ubuntu packages, installs basic tools (`curl`, `git`, `htop`, `jq`), and creates 2GB of virtual RAM (swap space).
* **`handlers/main.yml`**: Restarts background time synchronization services.

#### B. Role: `docker` (Applies to App Server)
* **`tasks/main.yml`**: Installs official Docker Engine and Docker Compose, and gives permissions to run Docker without typing `sudo`.
* **`handlers/main.yml`**: Restarts the Docker daemon if settings change.

#### C. Role: `app_deployment` (Applies to App Server)
* **`tasks/main.yml`**: Clones your GitHub repository (`winter_pep_final_project`), generates dynamic IP configs, and runs `docker compose up -d --build`.
* **`templates/docker-compose.override.yml.j2`**: A template that dynamically inserts your new AWS server IP into the frontend and gateway, and exposes service ports for monitoring.
* **`handlers/main.yml`**: Restarts the chat containers if configurations update.

#### D. Role: `nrpe_client` (Applies to App Server)
* **`tasks/main.yml`**: Installs the Nagios Remote Plugin Executor (NRPE) agent on the App Server so Nagios can check internal disk space, CPU, and containers.
* **`templates/nrpe.cfg.j2`**: Configuration file that allows the Nagios server to connect to port `5666`.
* **`templates/check_docker_containers.sh.j2`**: A custom bash script that checks if all 7 microservice containers (`mongodb`, `redis`, `auth`, `chat`, `notification`, `gateway`, `client`) are alive.
* **`handlers/main.yml`**: Restarts the NRPE daemon when configs change.

#### E. Role: `nagios_server` (Applies to Monitoring Server)
* **`tasks/main.yml`**: Installs Apache2, PHP, Nagios Core 4, sets the admin password, and applies monitoring check files.
* **`templates/apache_nagios_redirect.conf.j2`**: Redirects visitors from `http://<ip>/` directly to `http://<ip>/nagios4/`.
* **`templates/hosts.cfg.j2`**: Tells Nagios the IP address and name of your App Server.
* **`templates/services.cfg.j2`**: Defines all 11 health checks (Ping, SSH, Frontend, Gateway, Microservices, Disk, CPU, Docker).
* **`templates/commands.cfg.j2`**: Defines the commands Nagios uses to check ports and run NRPE queries.
* **`templates/contacts.cfg.j2`**: Sets up the notification email and admin contact for alerts.
* **`handlers/main.yml`**: Restarts Apache and Nagios services when configurations change.

---

## 3. `scripts/` (Verification & Failure-Demo Scripts)
*Purpose: Health verification and live failure/recovery demonstration scripts.*

| File Name | Simple Explanation |
| :--- | :--- |
| **`test_endpoints.sh`** | Tests all microservices and displays a colorful green/red status report showing response times. |
| **`simulate_failure.sh`**| **For Viva/Demo:** Lets you choose a container to stop (e.g. `chat_service`) so you can watch Nagios turn **RED (CRITICAL)**. |
| **`recover_service.sh`** | Restarts the stopped container and shows Nagios turning back to **GREEN (OK)**. |
| **`verify_nagios.sh`** | Runs check plugins directly from the Nagios command line to verify raw monitoring outputs. |

---

## 4. `docs/` (Project Documentation)
*Purpose: Everything needed for your B.Tech 7th semester submission, report, and oral examination.*

| File Name | Simple Explanation |
| :--- | :--- |
| **`ARCHITECTURE.md`** | Deep technical architecture guide with Mermaid flowcharts, network diagrams, and service interactions. |
| **`LAB_MANUAL_GUIDE.md`** | Step-by-step reproduction guide for professors and lab evaluators to test your project. |
| **`TESTING_AND_VERIFICATION.md`** | Formal test case matrix (TC-01 to TC-15) showing expected vs actual test results. |
| **`VIVA_QUESTIONS.md`** | The **Top 30 Viva Questions & Answers** covering Terraform, Ansible, Nagios, Docker, and DevOps. |

---

## 5. Root Files
*Purpose: Essential repository files.*

| File Name | Simple Explanation |
| :--- | :--- |
| **`README.md`** | The main landing page of your project with badges, quick start, and synopsis alignment. |
| **`.gitignore`** | Prevents private SSH keys, `.tfstate` files, and temporary caches from being uploaded to GitHub. |
| **`PROJECT_FILES_GUIDE.md`** | *This guide!* A complete dictionary of every file in the project. |

