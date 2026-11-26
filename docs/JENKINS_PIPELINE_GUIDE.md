# Jenkins CI/CD Pipeline Setup Guide (Windows Jenkins + WSL2 Ubuntu)

**Pipeline Flow:** `GitHub -> Jenkins -> Docker Hub -> Terraform -> AWS EC2 -> Ansible -> Nagios`

This guide explains how to configure your **Windows Jenkins** (`http://localhost:8080`) with **WSL2 Ubuntu** to orchestrate the complete 5-tool DevOps pipeline.

---

## 1. Architecture of the 5-Tool Pipeline

1. **GitHub (Dual-Repo Model):**
   - **Developer Repo (`winter_pep_final_project`):** Application microservices source & Dockerfiles.
   - **Operations Repo (`devops_chat_deploy_monitor-`):** `Jenkinsfile`, `terraform/`, `ansible/`, `scripts/`.
2. **Jenkins (CI/CD Orchestrator):** Runs `Jenkinsfile` (cross-platform: uses PowerShell + Docker + Terraform on Windows, and delegates Ansible & Bash verification scripts to WSL2 `Ubuntu`).
3. **Docker Hub (Container Registry):** Jenkins builds the 4 backend microservices (`gateway`, `auth-service`, `chat-service`, `notification-service`), tags them with `build-<BUILD_NUMBER>` and `latest`, and pushes them to Docker Hub.
4. **Terraform (Infrastructure as Code):** Provisions AWS EC2 instances (`app-server`, `monitoring-server`), Security Groups, 4096-bit RSA SSH keypair, and generates `ansible/inventory/hosts.ini`.
5. **Ansible (Configuration Management):** Pulls the pre-built backend images from Docker Hub, builds `chat_client` dynamically with `VITE_API_URL=http://<APP_IP>:5000`, and installs NRPE + Nagios Core.
6. **Nagios Core (Continuous Monitoring):** Monitors all 11 host, HTTP, and NRPE container checks on the deployed stack.

---

## 2. Prerequisites on Windows + WSL2

- **Jenkins** running on Windows (`http://localhost:8080`) with the **Pipeline** and **Git** plugins
- **Docker Desktop** running (accessible via `docker.exe`)
- **Terraform** installed on Windows PATH (`C:\Terraform\terraform.exe`)
- **WSL2 (`Ubuntu`)** with **Ansible** installed (`/usr/bin/ansible-playbook`)
- **AWS CLI credentials** configured (`aws configure`) for the user account running Jenkins

---

## 3. Configure Docker Hub Credentials in Jenkins

1. Open Jenkins (`http://localhost:8080`) -> **Manage Jenkins -> Credentials -> System -> Global credentials (unrestricted) -> Add Credentials**.
2. Set:
   - **Kind:** `Username with password`
   - **Username:** `<your-dockerhub-username>`
   - **Password:** `<your-dockerhub-access-token>`
   - **ID:** `dockerhub-creds` *(must match `Jenkinsfile`)*
3. Click **Create**.

---

## 4. Push `Jenkinsfile` and Create the Pipeline Job

1. Commit and push the latest pipeline & Ansible changes to your Operations GitHub repository (`main` branch).
2. In Jenkins, create a **Pipeline** (or **Multibranch Pipeline**) job pointing to:
   - **Repository URL:** `https://github.com/prince093kumar/devops_chat_deploy_monitor-.git`
   - **Script Path:** `Jenkinsfile`
3. Run **Build with Parameters**:
   - `ACTION = deploy` -> Builds & pushes backend images to Docker Hub, provisions AWS EC2 via Terraform, deploys via Ansible, and verifies Nagios.
   - `ACTION = destroy` -> Tears down all AWS resources cleanly via `terraform destroy`.
