# GitLab Runner Setup for Ubuntu 24.04 LTS

Automates the installation and configuration of **GitLab Runner** with **PowerShell (`pwsh`)** on **Ubuntu 24.04 LTS**, enabling **sudo** access without a password for managing root-owned/container files.

## Features

- Installs **GitLab Runner**, **Docker**, and **PowerShell**.
- Grants **sudo** access to **GitLab Runner**.
- Runs GitLab Runner as **sudo** to handle root/container files, enabling operations like `git clean` after jobs that create volumes or modify project directories.

## Usage

1. Copy the script to the target server where you want to install GitLab Runner.
2. SSH into the server and navigate to the directory containing the script.
3. Run the script with the following command:
```bash
./install.sh  -h
Usage: ./install.sh [-c CONCURRENT] [-o OUTPUT_LIMIT] [-k DEFAULT_KEEP_STORAGE] [-u GITLAB_URL] -t GITLAB_REGISTRATION_TOKEN

-c CONCURRENT                Set the number of concurrent jobs (default: 8)
-o OUTPUT_LIMIT              Set the output limit for jobs (default: 20480)
-k DEFAULT_KEEP_STORAGE      Set the default keep storage for the docker daemon (default: 100GB)
-u GITLAB_URL                Set the GitLab URL (default: https://gitlab.nil.rs/)
-t GITLAB_REGISTRATION_TOKEN GitLab registration token (required)
```