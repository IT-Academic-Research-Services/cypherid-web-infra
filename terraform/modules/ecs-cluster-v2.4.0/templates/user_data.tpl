#!/bin/bash

set -x

# The cloud-init process isn't considered finished until your userdata has finished running.
# So, requesting ecs (or docker) to start within userdata will cause a dead-lock.
systemctl restart ecs --no-block

# Append addition user-data script
${additional_user_data_script}
