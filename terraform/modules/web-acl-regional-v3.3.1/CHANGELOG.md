# Changelog

## [3.3.1](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v3.3.0...web-acl-regional-v3.3.1) (2025-07-15)


### BugFixes

* Allowed regions and aws versions ([#11205](https://github.com/chanzuckerberg/shared-infra/issues/11205)) ([bfc4f6c](https://github.com/chanzuckerberg/shared-infra/commit/bfc4f6ce29f1f1a262e2d6b402e9ed70ffecbcd1))

## [3.3.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v3.2.0...web-acl-regional-v3.3.0) (2025-07-11)


### Features

* Upgrade aws version for web acl regional module ([#11208](https://github.com/chanzuckerberg/shared-infra/issues/11208)) ([9f5c1d5](https://github.com/chanzuckerberg/shared-infra/commit/9f5c1d5f0d0a7a9a534e393e61fcadcac86f1089))

## [3.3.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v3.2.0...web-acl-regional-v3.3.0) (2024-10-24)


### Features

* (empty) Triggering release of debezium-jmx-exporter ([#10354](https://github.com/chanzuckerberg/shared-infra/issues/10354)) ([4032074](https://github.com/chanzuckerberg/shared-infra/commit/403207436279015b59e67aa1ac74d4e2136a1848))
* Triggering shared-infra release ([#10362](https://github.com/chanzuckerberg/shared-infra/issues/10362)) ([0edb281](https://github.com/chanzuckerberg/shared-infra/commit/0edb2818a59747dd50d4d30f694f7604ade3be76))

## [3.2.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v3.1.0...web-acl-regional-v3.2.0) (2024-06-27)


### Features

* update TFE to create new workspace for route53 ([#9657](https://github.com/chanzuckerberg/shared-infra/issues/9657)) ([fb95df6](https://github.com/chanzuckerberg/shared-infra/commit/fb95df629bc6142aff4d293ab277c8ace0db972f))

## [3.1.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v3.0.0...web-acl-regional-v3.1.0) (2024-03-04)


### Features

* waf allow 1mb body ([#9087](https://github.com/chanzuckerberg/shared-infra/issues/9087)) ([35e2242](https://github.com/chanzuckerberg/shared-infra/commit/35e22426fe97e07a610b280f9921c263fa70298c))

## [3.0.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.4.1...web-acl-regional-v3.0.0) (2023-11-03)


### ⚠ BREAKING CHANGES

* upgrade managed rule group versions for CZI WAFs (#8703)

### Bug Fixes

* upgrade managed rule group versions for CZI WAFs ([#8703](https://github.com/chanzuckerberg/shared-infra/issues/8703)) ([877458f](https://github.com/chanzuckerberg/shared-infra/commit/877458f2a1baedbe6d405f768ee4440ff6f4eeb6))

## [2.4.1](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.4.0...web-acl-regional-v2.4.1) (2023-10-09)


### Bug Fixes

* CDI-2022 - Update all bucket modules ([#8529](https://github.com/chanzuckerberg/shared-infra/issues/8529)) ([bd25e9d](https://github.com/chanzuckerberg/shared-infra/commit/bd25e9d2a61cbcced27f020665ab0b567f1ad485))

## [2.4.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.3.2...web-acl-regional-v2.4.0) (2023-09-22)


### Features

* make superset count_only waf ([#8461](https://github.com/chanzuckerberg/shared-infra/issues/8461)) ([69f9c60](https://github.com/chanzuckerberg/shared-infra/commit/69f9c6031d37795d61e59895d3ce0bb97ed79672))


### Bug Fixes

* Upgrade panther-s3-ingest module in web-acl-regional ([#8464](https://github.com/chanzuckerberg/shared-infra/issues/8464)) ([287aad5](https://github.com/chanzuckerberg/shared-infra/commit/287aad54a308282ae7d76939f6c9b6fa1036eda5))

## [2.3.2](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.3.1...web-acl-regional-v2.3.2) (2023-08-09)


### Bug Fixes

* add custom WAF variable to add only-count option ([#8234](https://github.com/chanzuckerberg/shared-infra/issues/8234)) ([ba900f1](https://github.com/chanzuckerberg/shared-infra/commit/ba900f161db26e5f21c72597219309da51e0f653))

## [2.3.1](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.3.0...web-acl-regional-v2.3.1) (2023-07-19)


### Bug Fixes

* issue with how custom WAF rules are structured for loops ([#8102](https://github.com/chanzuckerberg/shared-infra/issues/8102)) ([c48f364](https://github.com/chanzuckerberg/shared-infra/commit/c48f3646ba332014f06ab402108da9c0f1f8fdfe))
* WAF Fixes ([#8107](https://github.com/chanzuckerberg/shared-infra/issues/8107)) ([041ec3f](https://github.com/chanzuckerberg/shared-infra/commit/041ec3fb49b333ec26e1398d42f2ca43a4faccd0))

## [2.3.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.2.1...web-acl-regional-v2.3.0) (2023-07-13)


### Features

* allow an option to turn off Panther Ingesting of WAF logs to save costs ([#8079](https://github.com/chanzuckerberg/shared-infra/issues/8079)) ([81f3432](https://github.com/chanzuckerberg/shared-infra/commit/81f34323bddbeb1e1b53a6e2ed966b6275686ba8))

## [2.2.1](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.2.0...web-acl-regional-v2.2.1) (2023-07-10)


### Bug Fixes

* panther-cloudwatch-ingest causes errors on iam role length & not enforcing TLS ([#8047](https://github.com/chanzuckerberg/shared-infra/issues/8047)) ([f38e151](https://github.com/chanzuckerberg/shared-infra/commit/f38e151ae5d958b24ad3bfe2806975fb9bb01b0a))

## [2.2.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.1.1...web-acl-regional-v2.2.0) (2023-07-05)


### Features

* set WAF to block flagged rules instead of count ([#8004](https://github.com/chanzuckerberg/shared-infra/issues/8004)) ([5f1418d](https://github.com/chanzuckerberg/shared-infra/commit/5f1418dd163d4842db29120e64fe7827dcac310c))

## [2.1.1](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.1.0...web-acl-regional-v2.1.1) (2023-06-21)


### Bug Fixes

* typo with dynamic rule-building with already-existing rule groups ([#7977](https://github.com/chanzuckerberg/shared-infra/issues/7977)) ([7545753](https://github.com/chanzuckerberg/shared-infra/commit/75457536d65d6b7eb1eb6a48889a3cb856060cf5))

## [2.1.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.0.3...web-acl-regional-v2.1.0) (2023-06-16)


### Features

* customize selected rules to block in WAF module ([#7958](https://github.com/chanzuckerberg/shared-infra/issues/7958)) ([134a8c1](https://github.com/chanzuckerberg/shared-infra/commit/134a8c1cd65843023907baaf2692c062de0f6f50))

## [2.0.3](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.0.2...web-acl-regional-v2.0.3) (2023-06-14)


### Bug Fixes

* only log WAF requests that were counted or blocked ([#7851](https://github.com/chanzuckerberg/shared-infra/issues/7851)) ([beed0dc](https://github.com/chanzuckerberg/shared-infra/commit/beed0dced943e88523a856caf48b2265d2cb145e))

## [2.0.2](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.0.1...web-acl-regional-v2.0.2) (2023-05-02)


### Bug Fixes

* set WAF data retention to 1 yr ([#7741](https://github.com/chanzuckerberg/shared-infra/issues/7741)) ([2029a42](https://github.com/chanzuckerberg/shared-infra/commit/2029a420d3b57959e9b22e6c6d72015a55e298e2))

## [2.0.1](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v2.0.0...web-acl-regional-v2.0.1) (2023-05-01)


### Bug Fixes

* have WAF logs expire after 6 months ([#7736](https://github.com/chanzuckerberg/shared-infra/issues/7736)) ([52aae97](https://github.com/chanzuckerberg/shared-infra/commit/52aae97bc8e49cb19e6071fb455053b2938455c7))

## [2.0.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.2.4...web-acl-regional-v2.0.0) (2023-04-28)


### ⚠ BREAKING CHANGES

* k8s-core major version bump (#7726)

### Features

* k8s-core major version bump ([#7726](https://github.com/chanzuckerberg/shared-infra/issues/7726)) ([1c44772](https://github.com/chanzuckerberg/shared-infra/commit/1c4477285cf5a26411a73396bb631eea39a67e6b))

## [1.2.4](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.2.3...web-acl-regional-v1.2.4) (2023-04-06)


### Bug Fixes

* use versioned s3 ingest module for stability ([#7618](https://github.com/chanzuckerberg/shared-infra/issues/7618)) ([eaf1d30](https://github.com/chanzuckerberg/shared-infra/commit/eaf1d30dcc25176527cbe44e9df9e5cb280af8e9))

## [1.2.3](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.2.2...web-acl-regional-v1.2.3) (2023-04-06)


### Bug Fixes

* detangle WAF resources with the Logs configuration ([#7613](https://github.com/chanzuckerberg/shared-infra/issues/7613)) ([de93fc6](https://github.com/chanzuckerberg/shared-infra/commit/de93fc69ebd37fc76aa84dc2ff9bc6e303b3e058))

## [1.2.2](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.2.1...web-acl-regional-v1.2.2) (2023-04-06)


### Bug Fixes

* add another slot for SecEng IR ([#7608](https://github.com/chanzuckerberg/shared-infra/issues/7608)) ([7c7fd11](https://github.com/chanzuckerberg/shared-infra/commit/7c7fd114d69f61186452aeb8e472d0e305b0f6a9))
* help Panther subscribe to new WAF events by default ([#7603](https://github.com/chanzuckerberg/shared-infra/issues/7603)) ([f3045d4](https://github.com/chanzuckerberg/shared-infra/commit/f3045d4a50ba2c2d4d8f10fc17fb8a04ec844cdb))
* rearrange panther SNS topic configuration ([#7610](https://github.com/chanzuckerberg/shared-infra/issues/7610)) ([fe5aab0](https://github.com/chanzuckerberg/shared-infra/commit/fe5aab0850015fa830074bf1f89577f8f866afab))

## [1.2.1](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.2.0...web-acl-regional-v1.2.1) (2023-04-03)


### Bug Fixes

* typo with rate-limiting label ([#7587](https://github.com/chanzuckerberg/shared-infra/issues/7587)) ([f541e44](https://github.com/chanzuckerberg/shared-infra/commit/f541e4488ec58e6cd107b3f830bd759421c9d030))

## [1.2.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.1.0...web-acl-regional-v1.2.0) (2023-03-23)


### Features

* bump all shared-infra to 1.3.0 ([#7514](https://github.com/chanzuckerberg/shared-infra/issues/7514)) ([c56e63e](https://github.com/chanzuckerberg/shared-infra/commit/c56e63eac215442570762e62f27bab222f1837cb))

## [1.1.0](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.0.2...web-acl-regional-v1.1.0) (2023-03-10)


### Features

* rewrite optional WAF feature for oauth2-proxy-eks and superset ([#7408](https://github.com/chanzuckerberg/shared-infra/issues/7408)) ([eed933e](https://github.com/chanzuckerberg/shared-infra/commit/eed933e8fcc209e37c66ddcbed337781e4abda54))

## [1.0.2](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.0.1...web-acl-regional-v1.0.2) (2023-03-10)


### Bug Fixes

* tweak description to use allowed characters again ([#7369](https://github.com/chanzuckerberg/shared-infra/issues/7369)) ([8a5926b](https://github.com/chanzuckerberg/shared-infra/commit/8a5926b53dcc14998895ab22a8c92c543ce64f4b))

## [1.0.1](https://github.com/chanzuckerberg/shared-infra/compare/web-acl-regional-v1.0.0...web-acl-regional-v1.0.1) (2023-03-09)


### Bug Fixes

* description for web-acl-regional module ([#7357](https://github.com/chanzuckerberg/shared-infra/issues/7357)) ([4b19f78](https://github.com/chanzuckerberg/shared-infra/commit/4b19f78a3573306b505b2409e22e2878f4cdc191))

## 1.0.0 (2023-02-27)


### Features

* WAF for protecting regional resources ([#7270](https://github.com/chanzuckerberg/shared-infra/issues/7270)) ([c733616](https://github.com/chanzuckerberg/shared-infra/commit/c7336162a00b5f43bb1b9aaad2708567a20403f4))


### Bug Fixes

* stop collecting metrics that are just allowed ([#7286](https://github.com/chanzuckerberg/shared-infra/issues/7286)) ([1cdbd83](https://github.com/chanzuckerberg/shared-infra/commit/1cdbd83d4519326c8363a9db72fc10e8e2e148f7))
* WAF module pulling Account ID ([#7318](https://github.com/chanzuckerberg/shared-infra/issues/7318)) ([b59ac01](https://github.com/chanzuckerberg/shared-infra/commit/b59ac013963099c1540a102828ea645a326efe0f))
