#!/usr/bin/env python3
''' submit various batch jobs '''

import os
import shutil
import subprocess
import sys
import traceback

'''
Instructions on how to make a package with the code here:

zip -r submit_batch_job.zip submit_batch_job.py

See also https://stackoverflow.com/questions/2915471/install-a-python-package-into-a-different-directory-using-pip
'''


def submit_ncbi_copy_job(event, context):
    ''' submit ncbi copy job '''
    lambda_root = os.environ.get('LAMBDA_TASK_ROOT')
    print(f"Lambda Root: {lambda_root}")
    command = '''
        cd /tmp;  mkdir mypy; mkdir myhome; export HOME=/tmp/myhome;
        export PYTHONPATH=/tmp/mypy/lib64/python3.6/site-packages:${PYTHONPATH};
        export PATH=/tmp/mypy/bin:${PATH}; export PYTHONUSERBASE=/tmp/mypy;
        pip3 install aegea --no-cache-dir --user; pip3 install argcomplete --no-cache-dir --user;
        aegea batch submit --command="cd /mnt; git clone https://github.com/chanzuckerberg/idseq-copy-tool.git; cd idseq-copy-tool; pip3 install schedule; python3 main.py " --storage /mnt=1000 --volume-type gp2 --ecr-image idseq_dag --memory 120000 --queue idseq-prod-lomem --vcpus 16 --job-role idseq-pipeline
   '''

    return command_execute(command)


def command_execute(cmd):
    ''' execute a command '''
    print(f"Command: {cmd}")
    proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    proc.wait()
    stdout, stderr = proc.communicate()
    stdout = stdout.decode("utf-8")
    stderr = stderr.decode("utf-8")
    if proc.returncode != 0:
        raise RuntimeError(f"Command error: {stderr}")
    return stdout
