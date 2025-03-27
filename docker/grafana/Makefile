profile = $(AWS_PROFILE)
ifeq ($(strip $(profile)),)
	profile := idseq-dev
endif

grafana_version = $(GRAFANA_VERSION)
ifeq ($(strip $(grafana_version)),)
	grafana_version := 7.1.2
endif

AWS_ACCOUNT_ID=$(shell aws sts get-caller-identity --output text --query 'Account' --profile ${profile})
AWS_DEFAULT_REGION=$(shell aws configure get region --profile ${profile})
AWS_ECR_REPO_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/grafana

build:
	@echo "[Build Grafana image]"
	docker build --build-arg grafana_version=${grafana_version} -t ${AWS_ECR_REPO_URI}:latest -t ${AWS_ECR_REPO_URI}:${grafana_version} .

push:
	@echo "[Push Grafana image]"
	aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/grafana:${grafana_version}

build-push: build push
