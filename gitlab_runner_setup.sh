#!/bin/bash

set -e

usage() {
  echo "Usage: $0 [-c CONCURRENT] [-o OUTPUT_LIMIT] [-k DEFAULT_KEEP_STORAGE] [-u GITLAB_URL] [-t GITLAB_REGISTRATION_TOKEN] [-s SHELL] [-e EXECUTOR] [-l LOCKED]"
  echo
  echo "  -c CONCURRENT                Set the number of concurrent jobs (default: 8)"
  echo "  -o OUTPUT_LIMIT              Set the output limit for jobs (default: 20480)"
  echo "  -k DEFAULT_KEEP_STORAGE      Set the default keep storage for the docker daemon (default: 100GB)"
  echo "  -u GITLAB_URL                Set the GitLab URL (default: https://gitlab.nil.rs/)"
  echo "  -t GITLAB_REGISTRATION_TOKEN GitLab registration token (required)"
  echo "  -s SHELL                     Set the shell to use (default: pwsh)"
  echo "  -e EXECUTOR                  Set the executor for GitLab Runner (default: shell)"
  echo "  -l LOCKED                    Set the locked status for GitLab Runner (default: false)"
  exit 1
}

echo_green() {
  echo -e "\033[0;32m [ INFO ] $1\033[0m"
}

CONCURRENT=8
OUTPUT_LIMIT=20480
DEFAULT_KEEP_STORAGE="100GB"
GITLAB_URL="https://gitlab.nil.rs/"
SHELL="pwsh"
EXECUTOR="shell"
LOCKED="false"

while getopts ":c:o:k:u:t:s:e:l:" opt; do
  case $opt in
    c) CONCURRENT="$OPTARG" ;;
    o) OUTPUT_LIMIT="$OPTARG" ;;
    k) DEFAULT_KEEP_STORAGE="$OPTARG" ;;
    u) GITLAB_URL="$OPTARG" ;;
    t) GITLAB_REGISTRATION_TOKEN="$OPTARG" ;;
    s) SHELL="$OPTARG" ;;
    e) EXECUTOR="$OPTARG" ;;
    l) LOCKED="$OPTARG" ;;
    \?) usage ;;
  esac
done

if [ -z "$GITLAB_REGISTRATION_TOKEN" ]; then
  echo "Error: GITLAB_REGISTRATION_TOKEN is required."
  usage
fi

echo_green "Installing dependencies..."
sudo apt-get update && sudo apt-get install -y ca-certificates curl jq bash-completion yq

echo_green "Installing PowerShell..."
sudo snap install powershell --classic

echo_green "Installing Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt install --reinstall snapd
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo_green "Configuring Docker daemon..."
DOCKER_CONFIG_FILE="/etc/docker/daemon.json"
if [ -f "$DOCKER_CONFIG_FILE" ]; then
  sudo jq --arg keep_storage "$DEFAULT_KEEP_STORAGE" \
    '. + {
      "features": {
        "containerd-snapshotter": true
      },
      "builder": {
        "gc": {
          "enabled": true,
          "defaultKeepStorage": $keep_storage
        }
      }
    }' "$DOCKER_CONFIG_FILE" | sudo tee "$DOCKER_CONFIG_FILE" > /dev/null
else
  sudo jq -n \
    --arg keep_storage "$DEFAULT_KEEP_STORAGE" \
    '{
      "features": {
        "containerd-snapshotter": true
      },
      "builder": {
        "gc": {
          "enabled": true,
          "defaultKeepStorage": $keep_storage
        }
      }
    }' | sudo tee "$DOCKER_CONFIG_FILE" > /dev/null
fi
sudo systemctl restart docker

echo_green "Installing GitLab Runner..."
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner -y

echo_green "Adding GitLab Runner to Docker group..."
sudo usermod -aG docker gitlab-runner

echo_green "Enabling GitLab Runner to use sudo without password..."
echo 'gitlab-runner ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/gitlab-runner
sudo chmod 0440 /etc/sudoers.d/gitlab-runner

echo_green "Overriding GitLab Runner systemd service..."
sudo mkdir -p /etc/systemd/system/gitlab-runner.service.d
echo "[Service]
User=gitlab-runner
ExecStart=
ExecStart=/usr/bin/sudo /usr/bin/gitlab-runner \"run\" \"--config\" \"/etc/gitlab-runner/config.toml\" \"--working-directory\" \"/home/gitlab-runner\" \"--service\" \"gitlab-runner\"" | sudo tee /etc/systemd/system/gitlab-runner.service.d/override.conf > /dev/null

sudo systemctl daemon-reload
sudo systemctl restart gitlab-runner


echo_green "Registering GitLab Runner..."
sudo gitlab-runner register --non-interactive \
  --url "$GITLAB_URL" \
  --token "$GITLAB_REGISTRATION_TOKEN" \
  --executor "$EXECUTOR" \
  --shell "$SHELL" \
  --locked "$LOCKED" \
  --request-concurrency "$CONCURRENT" \
  --output-limit "$OUTPUT_LIMIT"

sudo systemctl restart gitlab-runner