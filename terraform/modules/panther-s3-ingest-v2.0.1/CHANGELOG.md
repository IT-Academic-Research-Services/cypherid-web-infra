# Changelog

## [2.0.1](https://github.com/chanzuckerberg/shared-infra/compare/panther-s3-ingest-v2.0.0...panther-s3-ingest-v2.0.1) (2023-07-10)


### Bug Fixes

* panther-cloudwatch-ingest causes errors on iam role length & not enforcing TLS ([#8047](https://github.com/chanzuckerberg/shared-infra/issues/8047)) ([f38e151](https://github.com/chanzuckerberg/shared-infra/commit/f38e151ae5d958b24ad3bfe2806975fb9bb01b0a))

## [2.0.0](https://github.com/chanzuckerberg/shared-infra/compare/panther-s3-ingest-v1.0.0...panther-s3-ingest-v2.0.0) (2023-04-28)


### ⚠ BREAKING CHANGES

* k8s-core major version bump (#7726)

### Features

* k8s-core major version bump ([#7726](https://github.com/chanzuckerberg/shared-infra/issues/7726)) ([1c44772](https://github.com/chanzuckerberg/shared-infra/commit/1c4477285cf5a26411a73396bb631eea39a67e6b))

## 1.0.0 (2023-04-06)


### Features

* bump all shared-infra to 1.3.0 ([#7514](https://github.com/chanzuckerberg/shared-infra/issues/7514)) ([c56e63e](https://github.com/chanzuckerberg/shared-infra/commit/c56e63eac215442570762e62f27bab222f1837cb))


### Bug Fixes

* help Panther subscribe to new WAF events by default ([#7603](https://github.com/chanzuckerberg/shared-infra/issues/7603)) ([f3045d4](https://github.com/chanzuckerberg/shared-infra/commit/f3045d4a50ba2c2d4d8f10fc17fb8a04ec844cdb))
* panther-ingest module depends on bucket that might not exist yet ([#7616](https://github.com/chanzuckerberg/shared-infra/issues/7616)) ([d236734](https://github.com/chanzuckerberg/shared-infra/commit/d236734ee860d1dbe83fdfe462f7e410fe55496b))
* rearrange panther SNS topic configuration ([#7610](https://github.com/chanzuckerberg/shared-infra/issues/7610)) ([fe5aab0](https://github.com/chanzuckerberg/shared-infra/commit/fe5aab0850015fa830074bf1f89577f8f866afab))
* refactor panther logs ingest structure to use modular logic ([#7126](https://github.com/chanzuckerberg/shared-infra/issues/7126)) ([7481e85](https://github.com/chanzuckerberg/shared-infra/commit/7481e854d2a17355308bba76b8a2bc860322ee20))
