# Auto-generated by fogg. Do not edit
# Make improvements in fogg, so that everyone can benefit.


export TERRAFORM_VERSION := 1.3.6
export TFLINT_ENABLED := 0
export TF_PLUGIN_CACHE_DIR := ../../..//.terraform.d/plugin-cache
export TF_BACKEND_KIND := s3

export AWS_BACKEND_PROFILE := idseq-prod


export AWS_PROVIDER_PROFILE := idseq-dev




include ../../..//scripts/component.mk


help: ## display help for this makefile
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.PHONY: help

