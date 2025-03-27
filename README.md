<!-- START -->
----

> **FOR CZIF USE ONLY. This repo belongs to [CZIF](https://wiki.czi.team/display/CZIF2/CZIF+2.0+Home). You should only use this repo for Foundation work. Contact [CZIFHelp@chanzuckerberg.com](mailto:CZIFHelp@chanzuckerberg.com) with questions.**

----
<!-- END -->
# IDSEQ Infrastructure

This repo exists to configure the infrastructure for the IDSEQ project. Generally we are striving to practice [infrastructure-as-code](https://en.wikipedia.org/wiki/Infrastructure_as_Code) with [Terraform](https://terraform.io) and [fogg](https://github.com/chanzuckerberg/fogg) as the primary tools.

## Setup

To use this repo you need Docker set up and running on the machine from which you are running commands.

You also need your `~/.aws/config` to contain a profile `idseq-dev`, which is [expected by fogg](https://github.com/chanzuckerberg/idseq-infra/blob/master/fogg.yml).

## Making Changes

This repo is managed by `fogg` and is divided up in to environments and components. Changes are always applied at the component level. So run plans or apply changes you need to `cd` to that component's directory.

## Workflow

1. cut branch
1. loop for dev/sandbox -> staging -> production
    1. make changes
    1. verify manually with `make plan`
    1. submit pull request
    1. get pull request approved (it's allowable to force merge for dev/sandbox), merge to `main`
    1. change should be auto-applied. Verify status in [Terraform Enterprise](https://si.prod.tfe.czi.technology/app/idseq-infra/workspaces).
    1. verify changes on the deployed infra to your satisfaction

- Make intensive use of modules so that differences between the environments are minimal (to avoid typos and divergent infra).

## SSH

To configure your ssh access:
1. Make sure you have a GitHub SSH key. Otherwise follow instructions [here](https://wiki.czi.team/display/SI/Accessing+GitHub+chanzuckerberg+organization)
1. Make sure your ssh agent is running. You can run `ssh-add -L` to test it out.
1. Ask #help-infra to be added to the `idseq` SSH group (usually happens with the previous step).
1. [Install blessclient](https://github.com/chanzuckerberg/blessclient):
```
# TLDR If you're on a Mac:

# Make sure you have your GitHub key loaded to your ssh agent
ssh-add
# Test you are able to connect to GitHub
ssh -T git@github.com

# Install blessclient
brew tap chanzuckerberg/tap
# if you had the old version of blessclient then we need to unlink it first
brew unlink blessclient
brew install blessclient@1
blessclient import-config git@github.com:/chanzuckerberg/idseq-infra/blessconfig.yml
```
SSH, scp, rsync, etc as you normally would

## individual-attr instances
* To make a change to the on-call, comp-bio instances, make a change to the `amis/{on-call, comp-bio}/main.pkr.hcl` and run ```packer build amis/comp-bio/main.pkr.hcl``` or ```aws-oidc exec --profile idseq-prod-poweruser -- packer build amis/comp-bio/main.pkr.hcl```
