#!/bin/bash
# Thin bootstrap only — no deployment logic lives here.
# New app versions are shipped by publishing a new Launch Template version
# and triggering an ASG Instance Refresh from CI/CD, not by editing this file.
set -euxo pipefail

# --- SSM Agent --------------------------------------------------------------
# NOT pre-installed on this AMI (confirmed via boot diagnostics — the enable
# command was failing with "Unit file amazon-ssm-agent.service does not
# exist", which aborted this entire script under set -e). Install it explicitly.
dnf install -y amazon-ssm-agent
systemctl enable --now amazon-ssm-agent

# --- Docker ---------------------------------------------------------------
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# --- CloudWatch Agent -------------------------------------------------------
dnf install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWAGENT'
{
  "agent": { "metrics_collection_interval": 60, "run_as_user": "root" },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["used_percent"], "resources": ["/"] }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/${app_container_name}/app.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 14
          }
        ]
      }
    }
  }
}
CWAGENT

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

mkdir -p /var/log/${app_container_name}

# --- Pull and run the app container ----------------------------------------
aws ecr get-login-password --region ${aws_region} | \
  docker login --username AWS --password-stdin ${ecr_registry}

docker pull ${ecr_repository_url}:${image_tag}

# NOTE: the app logs to container stdout (Python logging.basicConfig with
# stream=sys.stdout), so we ship logs via Docker's awslogs driver directly —
# not by tailing a file, which avoids relying on the app ever writing to
# the mounted /var/log path below (kept only for any future file-based logs).
docker run -d \
  --name ${app_container_name} \
  --restart unless-stopped \
  -p ${app_port}:${app_port} \
  -v /var/log/${app_container_name}:/var/log/${app_container_name} \
  --log-driver awslogs \
  --log-opt awslogs-region=${aws_region} \
  --log-opt awslogs-group=${log_group_name} \
  --log-opt awslogs-stream=app \
  -e SSM_DB_PARAM_PREFIX="${ssm_param_prefix}" \
  -e AWS_REGION="${aws_region}" \
  ${ecr_repository_url}:${image_tag}
