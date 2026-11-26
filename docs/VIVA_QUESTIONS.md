# Top 30 DevOps Viva & Technical Defense Questions

This reference guide provides in-depth technical answers tailored to your project: **"Automated Deployment and Monitoring of a Microservices-Based Chat Application Using Terraform, Ansible, and Nagios"**.

---

## Category 1: Infrastructure as Code (Terraform)

### Q1. What is Infrastructure as Code (IaC) and why did you choose Terraform?
**Answer:** IaC is the practice of managing and provisioning computing infrastructure through machine-readable definition files rather than manual interactive configuration. Terraform was chosen because:
1. It is declarative (you describe the desired end state, and Terraform figures out how to reach it).
2. It is cloud-agnostic and supports AWS natively via the AWS provider.
3. It maintains a state file (`terraform.tfstate`) that tracks real-world resources against configurations, enabling idempotent updates and clean resource destruction.

### Q2. How did you connect Terraform to Ansible in your project?
**Answer:** We used Terraform's `local_file` resource to dynamically generate the Ansible inventory file (`ansible/inventory/hosts.ini`). Once Terraform provisions the EC2 instances, it captures their newly allocated public and private IP addresses and renders the inventory file along with SSH parameters. This eliminates manual copy-pasting of dynamic cloud IP addresses.

### Q3. What is the difference between `terraform plan` and `terraform apply`?
**Answer:** `terraform plan` reads the current state and compares it with the configuration to generate an execution plan showing what resources will be created, modified, or destroyed without making any actual changes. `terraform apply` executes the actions proposed in the plan to create or update real infrastructure.

### Q4. How do you manage sensitive SSH keys in Terraform?
**Answer:** We used the `tls_private_key` resource to generate a 4096-bit RSA key pair in-memory. The public key is registered with AWS via `aws_key_pair`, and the private key is securely written to a local `.pem` file with strict POSIX permissions `0600` via `local_sensitive_file`.

### Q5. What happens if a resource is manually deleted in the AWS Console?
**Answer:** On the next `terraform plan` or `terraform apply`, Terraform refreshes its state by querying the AWS API. It detects the missing resource (drift) and plans to recreate it to restore the desired state defined in code.

---

## Category 2: Configuration Management & Automation (Ansible)

### Q6. What is idempotency in Ansible and why is it important?
**Answer:** Idempotency means that executing a playbook once or multiple times produces the exact same outcome without causing unintended side effects. If a package (like Docker) is already installed, Ansible reports `ok` instead of reinstalling or failing. This ensures reliability and consistency across deployments.

### Q7. How does Ansible differ from Terraform? Why did you use both?
**Answer:** 
- **Terraform** is primarily an **orchestration tool** designed to provision infrastructure (EC2 instances, VPCs, subnets, firewalls).
- **Ansible** is a **configuration management tool** designed to configure software inside provisioned operating systems (installing Docker, configuring users, templating config files, starting containers).
Combining them provides end-to-end automation: Terraform creates the virtual servers, and Ansible configures them and deploys the application.

### Q8. What is the purpose of Ansible Roles and how did you structure them?
**Answer:** Ansible Roles provide a structured, reusable way to organize tasks, variables, handlers, and templates. In our project, we structured roles modularly:
- `common`: Baseline setup, swap allocation, essential tools.
- `docker`: Docker Engine and Compose installation.
- `app_deployment`: Cloning the chat app, injecting dynamic environment variables, starting containers.
- `nrpe_client`: Installing and configuring the Nagios agent on the App Server.
- `nagios_server`: Installing and configuring Nagios 4 and Apache2 on the Monitoring Server.

### Q9. How did you resolve the hardcoded IP issue in the React frontend and Gateway?
**Answer:** In the source repository, the client and gateway had static IP addresses. We implemented a Jinja2 template (`docker-compose.override.yml.j2`) in Ansible. During deployment, Ansible dynamically substitutes `{{ ansible_host }}` into the environment variables (`CLIENT_URL` and `VITE_API_URL`) and exposes microservice ports. Docker Compose automatically merges this override file with the base compose file.

### Q10. Why did you configure a 2GB swap space on the App Server?
**Answer:** Building 5 Docker images simultaneously (Node.js npm install and Vite build) on an EC2 instance consumes significant memory. Adding 2GB of virtual swap space via the `common` role prevents out-of-memory (OOM) killer terminations during Docker builds on budget-friendly cloud instances.

---

## Category 3: Continuous Monitoring & Alerting (Nagios)

### Q11. What is Nagios Core and what is its architecture?
**Answer:** Nagios Core is an open-source monitoring and alerting engine. It uses a server-agent/polling architecture where the Nagios daemon periodically executes plugin binaries (e.g. `check_http`, `check_ping`, `check_nrpe`). The plugins evaluate target services and return exit codes to Nagios, which then updates host/service states and triggers alerts if necessary.

### Q12. What are the plugin return codes in Nagios?
**Answer:** Nagios plugins communicate check results using standard process exit codes:
- **0 = OK:** Service is functioning normally.
- **1 = WARNING:** Service is operational but has crossed a warning threshold.
- **2 = CRITICAL:** Service has stopped, crashed, or crossed a critical threshold.
- **3 = UNKNOWN:** Plugin could not determine status or encountered an error.

### Q13. What is the difference between Active Checks and Passive/Agent Checks?
**Answer:** 
- **Active Checks:** Initiated directly by the Nagios server across the network without needing an agent on the remote machine (e.g., `check_ping`, `check_http` to port 3000 or 5000).
- **Passive / Agent Checks (NRPE):** Executed by a local agent on the target server to inspect internal system parameters (CPU load, disk usage, memory, running Docker containers) and report the results back to the Nagios server.

### Q14. What is NRPE and why is it used?
**Answer:** **NRPE** stands for *Nagios Remote Plugin Executor*. It runs as a daemon (`nagios-nrpe-server`) on port 5666 of the monitored host. It allows the central Nagios server to securely execute local monitoring scripts on the remote host (e.g., checking if root disk space `/` is full or verifying Docker daemon health).

### Q15. What is the difference between a SOFT state and a HARD state in Nagios?
**Answer:**
- **SOFT State:** When a check fails for the first time, it enters a SOFT state. Nagios does not send an alert yet; instead, it rechecks the service at `retry_interval` to rule out transient network glitches.
- **HARD State:** If the service continues to fail for `max_check_attempts` (set to 2 in our project), it transitions into a HARD state, triggering administrative alerts and recording an outage.

### Q16. How did you monitor the microservices specifically?
**Answer:** We implemented dual-layer monitoring:
1. **Network Layer:** Nagios runs `check_http` against port 3000 (React Frontend), port 5000 (API Gateway `/health`), and ports 5001-5003 for individual microservices.
2. **Container Layer:** We wrote a custom shell plugin (`check_docker_containers.sh`) invoked via NRPE that verifies all 7 required Docker containers are active and running.

---

## Category 4: Microservices & Docker Architecture

### Q17. What microservices make up this chat application?
**Answer:** 
1. **Frontend Client:** React.js Single Page Application served via Nginx on port 3000.
2. **API Gateway:** Express.js reverse proxy on port 5000 handling routing, rate limiting, and JWT validation.
3. **Authentication Service:** Node.js service on port 5001 handling user registration and password hashing.
4. **Chat Service:** Node.js & Socket.IO service on port 5002 handling real-time messaging and chat rooms.
5. **Notification Service:** Background Node.js service on port 5003 managing alerts.
6. **MongoDB:** Persistent database on port 27017 storing user, room, and chat data.
7. **Redis:** In-memory store on port 6379 used for Pub/Sub messaging and socket clustering.

### Q18. Why is an API Gateway crucial in a microservices architecture?
**Answer:** An API Gateway acts as a single point of entry for client requests. It decouples the client from internal microservices, handles cross-cutting concerns like rate limiting, CORS, authentication verification, and routes incoming traffic to the appropriate backend service.

### Q19. How did you test failure recovery during your project?
**Answer:** We created `./scripts/simulate_failure.sh` which executes `docker stop <service>` over SSH (e.g. `docker stop chat_service`). Within 1-2 polling cycles, Nagios detects the dropped socket and transitions the check to `CRITICAL` (red). Then we run `./scripts/recover_service.sh` to restart the container; Nagios detects the restored service and returns to `OK` (green).

### Q20. What are the key benefits of combining Terraform, Ansible, and Nagios in DevOps?
**Answer:** 
- **Repeatability:** Environments can be spun up from scratch identically within minutes.
- **Zero Configuration Drift:** Everything is captured in version control (Git).
- **Reliability:** Automated continuous monitoring provides instant visibility into outages, minimizing mean time to detection (MTTD) and mean time to recovery (MTTR).

