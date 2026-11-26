pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['deploy', 'destroy'],
            description: 'Choose "deploy" to run Jenkins -> Docker Hub -> Terraform -> Ansible -> Nagios, or "destroy" to tear down AWS resources'
        )
        string(
            name: 'DOCKERHUB_USER',
            defaultValue: 'your_dockerhub_username',
            description: 'Docker Hub username (used when SKIP_IMAGE_BUILD is checked; otherwise taken from dockerhub credential)'
        )
        string(
            name: 'APP_REPO_URL',
            defaultValue: 'https://github.com/prince093kumar/winter_pep_final_project.git',
            description: 'Source repository of the Microservices Chat Application'
        )
        string(
            name: 'APP_REPO_BRANCH',
            defaultValue: 'main',
            description: 'Branch of the Microservices Chat Application to build and deploy'
        )
        booleanParam(
            name: 'SKIP_IMAGE_BUILD',
            defaultValue: false,
            description: 'Skip Docker Hub build/push and pull existing :latest images instead'
        )
    }

    environment {
        IMAGE_TAG                 = "build-${env.BUILD_NUMBER}"
        AWS_DEFAULT_REGION        = 'us-east-1'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        TF_IN_AUTOMATION          = 'true'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('1. Checkout DevOps & App Repositories') {
            steps {
                script {
                    if (!fileExists('terraform/ec2_instances.tf')) {
                        checkout scm
                    }
                    if (isUnix()) {
                        sh '''
                            set -e
                            rm -rf app-src
                            git clone --depth 1 --branch "${APP_REPO_BRANCH}" "${APP_REPO_URL}" app-src
                        '''
                    } else {
                        powershell '''
                            if (Test-Path "app-src") { Remove-Item -Recurse -Force "app-src" }
                            git clone --quiet --depth 1 --branch $env:APP_REPO_BRANCH $env:APP_REPO_URL app-src
                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                        '''
                    }
                }
            }
        }

        stage('2. Build & Push Backend Images to Docker Hub') {
            when {
                allOf {
                    expression { params.ACTION == 'deploy' }
                    expression { !params.SKIP_IMAGE_BUILD }
                }
            }
            steps {
                withCredentials([
                    [$class: 'UsernamePasswordMultiBinding',
                     credentialsId: 'dockerhub',
                     usernameVariable: 'DOCKERHUB_USERNAME',
                     passwordVariable: 'DOCKERHUB_TOKEN']
                ]) {
                    script {
                        env.RESOLVED_DOCKERHUB_USER = env.DOCKERHUB_USERNAME?.trim()
                        if (isUnix()) {
                            sh '''
                                set -e
                                echo "Logging in to Docker Hub as: ${DOCKERHUB_USERNAME}"
                                printf '%s' "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

                                build_and_push() {
                                    local svc_name="$1"
                                    local context_dir="$2"
                                    local repo="${DOCKERHUB_USERNAME}/microchat-${svc_name}"
                                    echo "Building ${repo}:${IMAGE_TAG} from ${context_dir}"
                                    docker build -t "${repo}:${IMAGE_TAG}" -t "${repo}:latest" "${context_dir}"
                                    docker push "${repo}:${IMAGE_TAG}"
                                    docker push "${repo}:latest"
                                }

                                build_and_push "gateway"              "app-src/gateway"
                                build_and_push "auth-service"         "app-src/services/auth-service"
                                build_and_push "chat-service"         "app-src/services/chat-service"
                                build_and_push "notification-service" "app-src/services/notification-service"

                                docker logout
                            '''
                        } else {
                            bat '''
                                @echo off
                                echo Logging in to Docker Hub as: %DOCKERHUB_USERNAME%
                                echo %DOCKERHUB_TOKEN%| docker login -u %DOCKERHUB_USERNAME% --password-stdin
                                if errorlevel 1 exit /b 1

                                docker build -t %DOCKERHUB_USERNAME%/microchat-gateway:%IMAGE_TAG% -t %DOCKERHUB_USERNAME%/microchat-gateway:latest app-src/gateway
                                if errorlevel 1 exit /b 1
                                docker push %DOCKERHUB_USERNAME%/microchat-gateway:%IMAGE_TAG%
                                if errorlevel 1 exit /b 1
                                docker push %DOCKERHUB_USERNAME%/microchat-gateway:latest
                                if errorlevel 1 exit /b 1

                                docker build -t %DOCKERHUB_USERNAME%/microchat-auth-service:%IMAGE_TAG% -t %DOCKERHUB_USERNAME%/microchat-auth-service:latest app-src/services/auth-service
                                if errorlevel 1 exit /b 1
                                docker push %DOCKERHUB_USERNAME%/microchat-auth-service:%IMAGE_TAG%
                                if errorlevel 1 exit /b 1
                                docker push %DOCKERHUB_USERNAME%/microchat-auth-service:latest
                                if errorlevel 1 exit /b 1

                                docker build -t %DOCKERHUB_USERNAME%/microchat-chat-service:%IMAGE_TAG% -t %DOCKERHUB_USERNAME%/microchat-chat-service:latest app-src/services/chat-service
                                if errorlevel 1 exit /b 1
                                docker push %DOCKERHUB_USERNAME%/microchat-chat-service:%IMAGE_TAG%
                                if errorlevel 1 exit /b 1
                                docker push %DOCKERHUB_USERNAME%/microchat-chat-service:latest
                                if errorlevel 1 exit /b 1

                                docker build -t %DOCKERHUB_USERNAME%/microchat-notification-service:%IMAGE_TAG% -t %DOCKERHUB_USERNAME%/microchat-notification-service:latest app-src/services/notification-service
                                if errorlevel 1 exit /b 1
                                docker push %DOCKERHUB_USERNAME%/microchat-notification-service:%IMAGE_TAG%
                                if errorlevel 1 exit /b 1
                                docker push %DOCKERHUB_USERNAME%/microchat-notification-service:latest
                                if errorlevel 1 exit /b 1

                                docker logout
                            '''
                        }
                    }
                }
            }
        }

        stage('3. Provision AWS Infrastructure (Terraform)') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                dir('terraform') {
                    script {
                        if (isUnix()) {
                            sh '''
                                set -e
                                terraform init -input=false
                                terraform plan -input=false
                                terraform apply -auto-approve -input=false
                            '''
                            env.APP_IP = sh(script: 'terraform output -raw app_server_public_ip', returnStdout: true).trim()
                            env.MONITORING_IP = sh(script: 'terraform output -raw monitoring_server_public_ip', returnStdout: true).trim()
                        } else {
                            powershell '''
                                terraform init -input=false
                                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                                terraform plan -input=false
                                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                                terraform apply -auto-approve -input=false
                                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                            '''
                            env.APP_IP = powershell(script: '(terraform output -raw app_server_public_ip).Trim()', returnStdout: true).trim()
                            env.MONITORING_IP = powershell(script: '(terraform output -raw monitoring_server_public_ip).Trim()', returnStdout: true).trim()
                        }
                    }
                }
                echo "App Server IP        : ${env.APP_IP}"
                echo "Monitoring Server IP : ${env.MONITORING_IP}"
            }
        }

        stage('4. Wait for EC2 SSH Readiness') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                script {
                    if (isUnix()) {
                        sh '''
                            set -e
                            chmod 600 ansible/id_rsa_devops || true
                            wait_for_ssh() {
                                local host="$1"
                                local retries=30
                                local count=0
                                echo "Waiting for SSH on ${host}:22..."
                                until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i ansible/id_rsa_devops "ubuntu@${host}" "echo ready" >/dev/null 2>&1; do
                                    count=$((count + 1))
                                    if [ "$count" -ge "$retries" ]; then
                                        echo "Timed out waiting for SSH on ${host}"
                                        exit 1
                                    fi
                                    sleep 5
                                done
                                echo "${host} SSH is ONLINE"
                            }
                            wait_for_ssh "${APP_IP}"
                            wait_for_ssh "${MONITORING_IP}"
                        '''
                    } else {
                        powershell '''
                            $wslRoot = $env:WORKSPACE.Replace('\\', '/') -replace '^[a-zA-Z]:', { '/mnt/' + $_.Value.Substring(0,1).ToLower() }
                            $keyPath = "$wslRoot/ansible/id_rsa_devops"
                            wsl -d Ubuntu -e chmod 600 $keyPath
                            foreach ($targetIp in @($env:APP_IP, $env:MONITORING_IP)) {
                                Write-Host "Waiting for SSH on ${targetIp}:22..."
                                $ready = $false
                                for ($i = 1; $i -le 30; $i++) {
                                    wsl -d Ubuntu -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i $keyPath "ubuntu@$targetIp" "echo ready" 2>&1 | Out-Null
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Host "$targetIp SSH is ONLINE"
                                        $ready = $true
                                        break
                                    }
                                    Start-Sleep -Seconds 5
                                }
                                if (-not $ready) {
                                    Write-Error "Timed out waiting for SSH on $targetIp"
                                    exit 1
                                }
                            }
                        '''
                    }
                }
            }
        }

        stage('5. Configure Servers, Pull Images & Setup Nagios (Ansible)') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                script {
                    def dhUser = env.RESOLVED_DOCKERHUB_USER ?: params.DOCKERHUB_USER
                    def imgTag = params.SKIP_IMAGE_BUILD ? 'latest' : env.IMAGE_TAG
                    if (!dhUser || dhUser == 'your_dockerhub_username') {
                        error('Set DOCKERHUB_USER or configure dockerhub credentials in Jenkins before running Ansible.')
                    }

                    if (isUnix()) {
                        dir('ansible') {
                            sh """
                                set -e
                                export ANSIBLE_CONFIG="\$(pwd)/ansible.cfg"
                                ansible-playbook -i inventory/hosts.ini site.yml \
                                    -e "use_dockerhub_images=true" \
                                    -e "dockerhub_username=${dhUser}" \
                                    -e "docker_image_tag=${imgTag}" \
                                    -e "app_repo_url=${params.APP_REPO_URL}" \
                                    -e "app_repo_branch=${params.APP_REPO_BRANCH}"
                            """
                        }
                    } else {
                        withEnv(["TARGET_DH_USER=${dhUser}", "TARGET_IMG_TAG=${imgTag}"]) {
                            powershell '''
                                $wslRoot = $env:WORKSPACE.Replace('\\', '/') -replace '^[a-zA-Z]:', { '/mnt/' + $_.Value.Substring(0,1).ToLower() }
                                $wslAnsible = "$wslRoot/ansible"
                                $cmd = "set -e; export ANSIBLE_CONFIG='$wslAnsible/ansible.cfg'; export ANSIBLE_HOST_KEY_CHECKING=False; cd '$wslAnsible' && ansible-playbook -i inventory/hosts.ini site.yml -e 'use_dockerhub_images=true' -e 'dockerhub_username=$($env:TARGET_DH_USER)' -e 'docker_image_tag=$($env:TARGET_IMG_TAG)' -e 'app_repo_url=$($env:APP_REPO_URL)' -e 'app_repo_branch=$($env:APP_REPO_BRANCH)'"
                                wsl -d Ubuntu -e bash -c $cmd
                                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                            '''
                        }
                    }
                }
            }
        }

        stage('6. Verify Microservices & Nagios Monitoring') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                script {
                    if (isUnix()) {
                        sh '''
                            set -e
                            chmod +x scripts/*.sh
                            ./scripts/test_endpoints.sh
                            ./scripts/verify_nagios.sh
                        '''
                    } else {
                        powershell '''
                            $wslRoot = $env:WORKSPACE.Replace('\\', '/') -replace '^[a-zA-Z]:', { '/mnt/' + $_.Value.Substring(0,1).ToLower() }
                            $cmd = "set -e; cd '$wslRoot' && chmod +x scripts/*.sh && ./scripts/test_endpoints.sh && ./scripts/verify_nagios.sh"
                            wsl -d Ubuntu -e bash -c $cmd
                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                        '''
                    }
                }
            }
        }

        stage('Destroy AWS Infrastructure (Terraform)') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir('terraform') {
                    script {
                        if (isUnix()) {
                            sh '''
                                set -e
                                terraform init -input=false
                                terraform destroy -auto-approve -input=false
                            '''
                        } else {
                            powershell '''
                                terraform init -input=false
                                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                                terraform destroy -auto-approve -input=false
                                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                if (params.ACTION == 'deploy') {
                    echo """
                    ====================================================================
                    PIPELINE SUCCEEDED: Jenkins -> Docker Hub -> Terraform -> Ansible -> Nagios
                    ====================================================================
                    React Chat Client     : http://${env.APP_IP}:3000
                    API Gateway Health    : http://${env.APP_IP}:5000/health
                    Nagios Core Dashboard : http://${env.MONITORING_IP}/nagios4/
                    Nagios Credentials    : nagiosadmin / Devops@2026
                    ====================================================================
                    """.stripIndent()
                } else {
                    echo 'AWS infrastructure destroyed cleanly via Terraform.'
                }
            }
        }
        always {
            script {
                if (isUnix()) {
                    sh 'rm -rf app-src'
                } else {
                    powershell 'if (Test-Path "app-src") { Remove-Item -Recurse -Force "app-src" }'
                }
            }
        }
    }
}
