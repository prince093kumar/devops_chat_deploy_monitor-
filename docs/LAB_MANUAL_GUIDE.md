# Laboratory Manual & Step-by-Step Reproduction Guide

**Course:** DevOps Advance Configuration Management (B.Tech 7th Semester)  
**Project:** Automated Deployment and Monitoring of a Microservices-Based Chat Application Using Terraform, Ansible, and Nagios  
**Student:** Prince Kumar  

---

## 1. Prerequisites & Environment Setup

Before starting the lab, ensure the following tools are installed on your local workstation:

| Tool | Recommended Version | Purpose |
| :--- | :--- | :--- |
| **AWS CLI** | 2.x | Interacting with AWS account |
| **Terraform** | >= 1.3.0 | Infrastructure as Code |
| **Ansible** | >= 2.14 | Configuration management & deployment |
| **Git** | 2.x | Source code management |
| **WSL Ubuntu** | Ubuntu 22.04 LTS | Linux automation environment (for Windows users) |

### 1.1 Configuring AWS Credentials
Ensure your AWS Access Key ID and Secret Access Key have permissions for EC2, VPC, and Security Groups.

```bash
aws configure
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: ap-south-1
# Default output format [None]: json
```

Verify your credentials:
```bash
aws sts get-caller-identity
```

---

## 2. Project Directory Organization

Navigate to the project root directory:
```bash
cd "d:\B.Tech-7 semester\Devops Advance Config Management\project"
```

In WSL Ubuntu:
```bash
cd "/mnt/d/B.Tech-7 semester/Devops Advance Config Management/project"
```

The repository structure:
```
project/
├── Jenkinsfile         # CI/CD pipeline (Jenkins -> Docker Hub -> Terraform -> Ansible -> Nagios)
├── terraform/          # Infrastructure as Code (AWS EC2, SGs, Key Pairs)
├── ansible/            # Configuration Management & Playbooks
│   ├── inventory/      # Auto-generated hosts.ini
│   ├── roles/          # common, docker, app_deployment, nrpe_client, nagios_server
│   └── site.yml        # Master orchestration playbook
├── scripts/            # Verification & failure-demo scripts
│   ├── test_endpoints.sh
│   ├── verify_nagios.sh
│   ├── simulate_failure.sh
│   └── recover_service.sh
└── docs/               # Architecture, Jenkins Guide, Lab Manual, Viva Questions
```

---

## 3. End-to-End Automated Deployment

Run the Jenkins pipeline (`Jenkinsfile`) at `http://localhost:8080` with **`ACTION = deploy`** (see [JENKINS_PIPELINE_GUIDE.md](file:///D:/B.Tech-7%20semester/Devops%20Advance%20Config%20Management/project/docs/JENKINS_PIPELINE_GUIDE.md)).

---

## 4. Manual Step-by-Step Deployment (For Detailed Understanding)

If your examiner asks you to demonstrate each phase individually, follow these steps:

### Phase 4.1: Infrastructure Provisioning (Terraform)
1. Navigate to the terraform directory:
   ```bash
   cd terraform
   ```
2. Initialize providers:
   ```bash
   terraform init
   ```
3. Preview the infrastructure plan:
   ```bash
   terraform plan
   ```
4. Apply the configuration:
   ```bash
   terraform apply -auto-approve
   ```
5. View outputs:
   ```bash
   terraform output
   ```
   *Note: Terraform will automatically generate the `../ansible/inventory/hosts.ini` file and `../ansible/id_rsa_devops` SSH private key.*

### Phase 4.2: Server Configuration & App Deployment (Ansible)
1. Navigate to the ansible directory:
   ```bash
   cd ../ansible
   ```
2. Secure the private key permissions:
   ```bash
   chmod 600 id_rsa_devops
   ```
3. Test SSH connectivity with Ansible ping:
   ```bash
   ansible -i inventory/hosts.ini all -m ping
   ```
4. Execute the master playbook:
   ```bash
   ansible-playbook -i inventory/hosts.ini site.yml
   ```

---

## 5. Verification & Live Demonstrations

### 5.1 Accessing the Chat Web Application
- Open your browser and navigate to:
  ```
  http://<APP_SERVER_PUBLIC_IP>:3000
  ```
- Test registration and login:
  - Register a new user account.
  - Verify that the chat interface loads and communicates via the API Gateway (`:5000`).

### 5.2 Accessing the Nagios Core Web Dashboard
- Open your browser and navigate to:
  ```
  http://<MONITORING_SERVER_PUBLIC_IP>/nagios4/
  ```
- Log in with default credentials:
  - **Username:** `nagiosadmin`
  - **Password:** `Devops@2026`
- Click on **Services** on the left menu:
  - All 11 services should display green **`OK`** status.

### 5.3 Automated Endpoint Health Check
Run the automated testing script to check response codes and latencies across all microservices:
```bash
./scripts/test_endpoints.sh
```

---

## 6. Failure Injection & Recovery Demonstration

This experiment satisfies **Objective 5 & 7** of the project syllabus:

1. Launch the failure simulator:
   ```bash
   ./scripts/simulate_failure.sh
   ```
2. Select **`1`** to stop the `chat_service` container.
3. Switch to the Nagios Web UI (`http://<MONITORING_SERVER_IP>/nagios4/`).
4. Under **Services**, observe:
   - `Microservice - Chat Service (Port 5002)` changes from **`OK`** to **`CRITICAL`** (Connection refused).
   - `Containers - Chat Microservices Health` changes to **`CRITICAL`** (Missing container: chat_service).
5. Run the recovery script:
   ```bash
   ./scripts/recover_service.sh
   ```
6. Observe the Nagios Dashboard:
   - Within 60 seconds, all services automatically transition back to green **`OK`** state.

---

## 7. Cloud Resource Clean Teardown

To avoid incurring ongoing AWS EC2 charges after evaluation, run the Jenkins pipeline with **`ACTION = destroy`**, or manually from `terraform/`:
```bash
cd terraform
terraform destroy -auto-approve
```
Confirm all EC2 instances and security groups are terminated.

