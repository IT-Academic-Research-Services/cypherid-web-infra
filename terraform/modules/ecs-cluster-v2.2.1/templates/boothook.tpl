#!/bin/bash
set -x

# docker storage driver
cloud-init-per once docker_options echo 'DOCKER_STORAGE_OPTIONS="--storage-driver overlay2"' > /etc/sysconfig/docker-storage

# ecs config
cloud-init-per once ecs_options cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=${cluster_name}
EOF
