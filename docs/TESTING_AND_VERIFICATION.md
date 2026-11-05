# Testing, Verification & Failure Analysis Report

## 1. Quality Assurance Test Matrix

The following test suite verifies the infrastructure provisioning, configuration management, application functionality, and monitoring coverage:

| Test ID | Test Domain | Description | Verification Method | Expected Outcome | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** | Terraform | EC2 Provisioning | `terraform apply` | 2 EC2 instances provisioned in selected AWS region with proper tags and public IPs | **PASS** |
| **TC-02** | Terraform | Security Group Rules | AWS Console / CLI | Inbound ports (22, 80, 3000, 5000-5003, 5666) properly restricted and open | **PASS** |
| **TC-03** | Terraform | Dynamic Inventory | File inspection (`hosts.ini`) | Ansible inventory dynamically created with correct IPs and variables | **PASS** |
| **TC-04** | Ansible | Baseline & Swap | `free -h` on App Server | 2GB swapfile active, preventing out-of-memory errors during Docker build | **PASS** |
| **TC-05** | Ansible | Docker Installation | `docker --version` | Docker CE 24+ and Docker Compose v2 plugin installed and running | **PASS** |
| **TC-06** | Ansible | Microservices Launch | `docker ps` | 7 containers active (`chat_mongodb`, `chat_redis`, `auth_service`, `chat_service`, `notification_service`, `api_gateway`, `chat_client`) | **PASS** |
| **TC-07** | Application | Frontend HTTP Check | `curl -I http://<app_ip>:3000` | HTTP 200 OK, HTML/JS payload returned | **PASS** |
| **TC-08** | Application | API Gateway Health | `curl http://<app_ip>:5000/health` | HTTP 200 `{"status":"healthy","service":"API Gateway"}` | **PASS** |
| **TC-09** | Application | Microservice Routing | `curl http://<app_ip>:5001/` | HTTP 200 `{"service":"Auth Service","status":"Running"}` | **PASS** |
| **TC-10** | Nagios | Apache & Web UI | `curl -I http://<mon_ip>/nagios4/` | HTTP 401 Unauthorized (Auth challenge) / HTTP 200 with credentials | **PASS** |
| **TC-11** | Nagios | NRPE Daemon Comms | `check_nrpe -H <app_ip>` | NRPE daemon responds without SSL handshake failure | **PASS** |
| **TC-12** | Monitoring | Host Ping Check | Nagios Web Dashboard | Host `app-server` status UP | **PASS** |
| **TC-13** | Monitoring | Service Checks | Nagios Web Dashboard | All 11 configured service checks return green `OK` | **PASS** |
| **TC-14** | Resilience | Service Failure | `docker stop chat_service` | Nagios detects failure and switches status to `CRITICAL` within 2 check intervals | **PASS** |
| **TC-15** | Resilience | Automated Recovery | `docker start chat_service` | Service restores, Nagios returns to `OK` state without service reboot | **PASS** |

---

## 2. Monitored Services & Thresholds

| Service Check Name | Polling Method | Check Command | Warning Threshold | Critical Threshold |
| :--- | :--- | :--- | :--- | :--- |
| **Host Ping** | Active Network | `check_ping` | RTA > 100ms, Loss > 20% | RTA > 500ms, Loss > 60% |
| **SSH Port 22** | Active Network | `check_ssh` | Timeout > 10s | Connection refused / down |
| **Frontend Web Client** | Active HTTP | `check_http -p 3000` | HTTP 4xx | HTTP 5xx / Connection refused |
| **API Gateway Health** | Active HTTP | `check_http -p 5000 -u /health` | HTTP 4xx | HTTP 5xx / Content mismatch |
| **Auth Microservice** | Active HTTP | `check_http -p 5001 -u /` | HTTP 4xx | Connection refused |
| **Chat Microservice** | Active HTTP | `check_http -p 5002 -u /` | HTTP 4xx | Connection refused |
| **Notification Service**| Active HTTP | `check_http -p 5003 -u /` | HTTP 4xx | Connection refused |
| **Root Disk Utilization** | Passive / NRPE | `check_disk` | Disk free < 20% | Disk free < 10% |
| **System CPU Load** | Passive / NRPE | `check_load` | Load > 5.0, 4.0, 3.0 | Load > 10.0, 6.0, 4.0 |
| **Docker Daemon** | Passive / NRPE | `check_procs -a dockerd` | - | Processes < 1 (dockerd stopped)|
| **Microservice Containers**| Passive / NRPE | `check_docker_containers.sh` | Containers unready | Any required container missing/dead |

---

## 3. Failure Injection & Alert Lifecycle

The failure simulation script (`./scripts/simulate_failure.sh`) demonstrates Nagios's state engine:

```
[Service OK (Hard)]
        │
        │ Event: 'docker stop chat_service'
        ▼
[Check Attempt 1/2] ──► Exit Code 2 (CRITICAL) ──► State: SOFT CRITICAL
        │
        │ 60 seconds (retry_interval)
        ▼
[Check Attempt 2/2] ──► Exit Code 2 (CRITICAL) ──► State: HARD CRITICAL
        │
        ├──► Dashboard banner turns Red
        └──► Notification trigger (admins group)
        │
        │ Event: './scripts/recover_service.sh'
        ▼
[Check Attempt 1/1] ──► Exit Code 0 (OK) ────────► State: RECOVERY OK
        │
        └──► Dashboard banner turns Green
```

### Verification Logs (Sample Terminal Output)

```text
$ ./scripts/test_endpoints.sh
======================================================================
             🔍 MICROSERVICES & NAGIOS ENDPOINTS HEALTH CHECK        
======================================================================
App Server IP       : 54.210.15.42
Monitoring Server IP: 54.210.22.88
----------------------------------------------------------------------
Testing Microservices Stack on App Server:
  Frontend React Client               [ http://54.210.15.42:3000   ] Status: 200  OK (42ms)
  API Gateway Health                  [ http://54.210.15.42:5000/health ] Status: 200  OK (28ms)
  API Gateway Base Route              [ http://54.210.15.42:5000/  ] Status: 200  OK (25ms)
  Auth Microservice Direct            [ http://54.210.15.42:5001/  ] Status: 200  OK (31ms)
  Chat Microservice Direct            [ http://54.210.15.42:5002/  ] Status: 200  OK (33ms)
  Notification Service Direct         [ http://54.210.15.42:5003/  ] Status: 200  OK (29ms)

Testing Nagios Monitoring Stack on Monitoring Server:
  Nagios Web UI Root Redirect         [ http://54.210.22.88/       ] Status: 302  OK
  Nagios Core Protected UI            [ http://54.210.22.88/nagios4/ ] Status: 401  OK
  Nagios Dashboard Authenticated      [ http://54.210.22.88/nagios4/ ] Status: 200  OK (Auth Valid)
======================================================================
```
