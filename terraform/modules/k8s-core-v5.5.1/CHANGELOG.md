# Changelog

## [5.22.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.21.0...k8s-core-v5.22.0) (2025-11-17)


### Features

* expose specific annotations for nginx controller ([#11558](https://github.com/chanzuckerberg/shared-infra/issues/11558)) ([29dd936](https://github.com/chanzuckerberg/shared-infra/commit/29dd93695bb7e773ec007309df93e761d556571d))

## [5.21.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.20.1...k8s-core-v5.21.0) (2025-11-04)


### Features

* allow nginx to use s3 maxmind db cache ([#11522](https://github.com/chanzuckerberg/shared-infra/issues/11522)) ([a6519ae](https://github.com/chanzuckerberg/shared-infra/commit/a6519aea6e92bb1ea5fd58588b450e707b1f0af9))

## [5.20.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.20.0...k8s-core-v5.20.1) (2025-10-08)


### BugFixes

* set nginx's external traffic policy to cluster by default, but configurable ([#11471](https://github.com/chanzuckerberg/shared-infra/issues/11471)) ([353d8d8](https://github.com/chanzuckerberg/shared-infra/commit/353d8d88b63482f250496beb351da57f7ceeae5f))

## [5.20.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.19.1...k8s-core-v5.20.0) (2025-09-30)


### Features

* add Linkerd annotations to nginx ingress controller for graceful shutdown ([#11460](https://github.com/chanzuckerberg/shared-infra/issues/11460)) ([0300da5](https://github.com/chanzuckerberg/shared-infra/commit/0300da5ec051ac0a6073606ba0fdff701a0ce288))


### BugFixes

* increase memory limit for linkerd controller ([#11458](https://github.com/chanzuckerberg/shared-infra/issues/11458)) ([01e8241](https://github.com/chanzuckerberg/shared-infra/commit/01e8241437b3e0cd8b0c96c5b157dd2e0d0946ed))

## [5.19.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.19.0...k8s-core-v5.19.1) (2025-09-22)


### BugFixes

* sane and configurable defaults for nginx ([#11438](https://github.com/chanzuckerberg/shared-infra/issues/11438)) ([79a912a](https://github.com/chanzuckerberg/shared-infra/commit/79a912ad1ed766877aaaa16cc0ca1ddd1d99a6fa))

## [5.19.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.18.1...k8s-core-v5.19.0) (2025-09-05)


### Features

* load IP database to create access controls using k8s-core ([#11318](https://github.com/chanzuckerberg/shared-infra/issues/11318)) ([e06b1d3](https://github.com/chanzuckerberg/shared-infra/commit/e06b1d3d81dea4e2a79c0b96e8d155357b66a911))

## [5.18.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.18.0...k8s-core-v5.18.1) (2025-08-13)


### BugFixes

* Change nginx variable name to proxy_body_size ([#11319](https://github.com/chanzuckerberg/shared-infra/issues/11319)) ([4ab87d1](https://github.com/chanzuckerberg/shared-infra/commit/4ab87d1e3e0f56b64944a86573e05393ade4b9e3))

## [5.18.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.17.0...k8s-core-v5.18.0) (2025-08-12)


### Features

* Add client_max_body_size to additional_addons ([#11313](https://github.com/chanzuckerberg/shared-infra/issues/11313)) ([2ea8d2a](https://github.com/chanzuckerberg/shared-infra/commit/2ea8d2a22d26c3dddebe6ee797eadde532df456c))

## [5.17.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.16.2...k8s-core-v5.17.0) (2025-08-12)


### Features

* Add max body size to nginx ([#11306](https://github.com/chanzuckerberg/shared-infra/issues/11306)) ([de73734](https://github.com/chanzuckerberg/shared-infra/commit/de73734db16822ab1fa7836f8a39315ee1659353))

## [5.16.2](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.16.1...k8s-core-v5.16.2) (2025-08-07)


### BugFixes

* allow annotations from now on in nginx ingress ([#11287](https://github.com/chanzuckerberg/shared-infra/issues/11287)) ([c1aea33](https://github.com/chanzuckerberg/shared-infra/commit/c1aea33e34c48a8ead7c5c9814d41ec0726d64e3))

## [5.16.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.16.0...k8s-core-v5.16.1) (2025-06-17)


### Misc

* CCIE-4705 increase default linkerd proxy mem ([#11157](https://github.com/chanzuckerberg/shared-infra/issues/11157)) ([e2c7b00](https://github.com/chanzuckerberg/shared-infra/commit/e2c7b00cb501bd9c80c3928793d7710331ad3360))

## [5.16.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.9...k8s-core-v5.16.0) (2025-06-16)


### Features

* Remove rancher providers from k8s-core module ([#11152](https://github.com/chanzuckerberg/shared-infra/issues/11152)) ([cf70621](https://github.com/chanzuckerberg/shared-infra/commit/cf706214b90349071a70179fd498dc07562b22a5))


### Misc

* CCIE-4705 increase linkerd proxy memory to 1Gi ([#11146](https://github.com/chanzuckerberg/shared-infra/issues/11146)) ([48b08e5](https://github.com/chanzuckerberg/shared-infra/commit/48b08e5026caed04534665f3a16af1a1f38f8e40))

## [5.15.9](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.8...k8s-core-v5.15.9) (2025-05-30)


### BugFixes

* Stub out rancher manifest url ([#11102](https://github.com/chanzuckerberg/shared-infra/issues/11102)) ([d7307a3](https://github.com/chanzuckerberg/shared-infra/commit/d7307a3e850164d2509bf2f34637d2b6b1f23584))

## [5.15.8](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.7...k8s-core-v5.15.8) (2025-05-29)


### Misc

* Remove rancher integration ([#11097](https://github.com/chanzuckerberg/shared-infra/issues/11097)) ([38de10d](https://github.com/chanzuckerberg/shared-infra/commit/38de10d7f73c0b5998475565fac8f4e04ce8438c))

## [5.15.7](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.6...k8s-core-v5.15.7) (2025-03-28)


### Misc

* fix path validation ([#10839](https://github.com/chanzuckerberg/shared-infra/issues/10839)) ([05a41fe](https://github.com/chanzuckerberg/shared-infra/commit/05a41fe2e5e24d6b8d102f5136039c6de8073738))
* make default nginx 4.12.1 ([#10836](https://github.com/chanzuckerberg/shared-infra/issues/10836)) ([9dfdfc6](https://github.com/chanzuckerberg/shared-infra/commit/9dfdfc639c60f9f04238b42df54fdd67573fa695))

## [5.15.6](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.5...k8s-core-v5.15.6) (2025-03-28)


### BugFixes

* update the risk analysis settings on nginx for custom configuration snippets ([#10834](https://github.com/chanzuckerberg/shared-infra/issues/10834)) ([e45b9a8](https://github.com/chanzuckerberg/shared-infra/commit/e45b9a8b9129cb763e281a6361b6ca75200b6027))

## [5.15.5](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.4...k8s-core-v5.15.5) (2025-03-28)


### BugFixes

* new version of nginx has this disallowed by default and we use it ([#10833](https://github.com/chanzuckerberg/shared-infra/issues/10833)) ([5b8a1ab](https://github.com/chanzuckerberg/shared-infra/commit/5b8a1ab977fef28e6c7cc22bc3f25f7aa291a2c9))

## [5.15.4](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.3...k8s-core-v5.15.4) (2025-03-26)


### BugFixes

* revert k8s-core breaking change ([#10828](https://github.com/chanzuckerberg/shared-infra/issues/10828)) ([dd59835](https://github.com/chanzuckerberg/shared-infra/commit/dd598353664d68a0153db3168e9d7f42461d0d8d))
* revert the revert; back to the way it was ([#10830](https://github.com/chanzuckerberg/shared-infra/issues/10830)) ([63af999](https://github.com/chanzuckerberg/shared-infra/commit/63af9997d66ee958452e4a62f882229c2d157c6e))

## [5.15.3](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.2...k8s-core-v5.15.3) (2025-03-25)


### BugFixes

* use official fixed version of nginx ingress ([#10824](https://github.com/chanzuckerberg/shared-infra/issues/10824)) ([82e1629](https://github.com/chanzuckerberg/shared-infra/commit/82e16295044e95bc4f83831fb43dae7ab866ceab))

## [5.15.2](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.1...k8s-core-v5.15.2) (2025-03-25)


### BugFixes

* refactor nginx ingress controller in k8s-core ([#10822](https://github.com/chanzuckerberg/shared-infra/issues/10822)) ([7bbc611](https://github.com/chanzuckerberg/shared-infra/commit/7bbc6119b571e7ec98a58c9078d6d3eeed32b5a8))

## [5.15.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.15.0...k8s-core-v5.15.1) (2025-03-14)


### BugFixes

* wrong typing for helm chart nginx autoscaling ([#10806](https://github.com/chanzuckerberg/shared-infra/issues/10806)) ([ef1a998](https://github.com/chanzuckerberg/shared-infra/commit/ef1a9980d66103bc8f277b69e44a9672cf32c024))

## [5.15.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.14.1...k8s-core-v5.15.0) (2025-03-11)


### Features

* make nginx more configurable ([#10793](https://github.com/chanzuckerberg/shared-infra/issues/10793)) ([3cc6dad](https://github.com/chanzuckerberg/shared-infra/commit/3cc6dadc08e3d58ecb83744eeac8b45355fb5561))

## [5.14.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.14.0...k8s-core-v5.14.1) (2025-03-05)


### Misc

* CCIE-4077 manually trigger k8s-core release please ([#10770](https://github.com/chanzuckerberg/shared-infra/issues/10770)) ([b91e680](https://github.com/chanzuckerberg/shared-infra/commit/b91e680b668dab096ff8a02c79b6bb559975d471))

## [5.14.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.13.1...k8s-core-v5.14.0) (2025-02-27)


### Features

* remove datadog from k8s-core ([#10730](https://github.com/chanzuckerberg/shared-infra/issues/10730)) ([0c5945a](https://github.com/chanzuckerberg/shared-infra/commit/0c5945a784085f0a8c80b5bc58ffdbaa2faf8e0f))


### Misc

* remove opsgenie vars from monitoring ([#10734](https://github.com/chanzuckerberg/shared-infra/issues/10734)) ([f5154b5](https://github.com/chanzuckerberg/shared-infra/commit/f5154b581a3273df869e35a4e129a68f93e8f218))

## [5.13.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.13.0...k8s-core-v5.13.1) (2025-02-11)


### Misc

* CCIE-3962 upgrade linkerd-crds to edge v2024.11.8 ([#10641](https://github.com/chanzuckerberg/shared-infra/issues/10641)) ([ec56c50](https://github.com/chanzuckerberg/shared-infra/commit/ec56c507eb51b38286394000568c4d8a7391430f))

## [5.13.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.12.0...k8s-core-v5.13.0) (2025-02-11)


### Features

* CCIE-3900 auto rotate linkerd webhook cert ([#10586](https://github.com/chanzuckerberg/shared-infra/issues/10586)) ([aff4089](https://github.com/chanzuckerberg/shared-infra/commit/aff40893879d158e04eaed04107030a371c245c0))

## [5.12.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.11.0...k8s-core-v5.12.0) (2024-12-10)


### Features

* allow for replicas to be set for nginx ingress controller ([#10535](https://github.com/chanzuckerberg/shared-infra/issues/10535)) ([b1ba93b](https://github.com/chanzuckerberg/shared-infra/commit/b1ba93bfefa4af6791197d109087f83d7fd3ffe8))

## [5.11.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.10.0...k8s-core-v5.11.0) (2024-12-05)


### Features

* Disable rancher integration by default ([#10522](https://github.com/chanzuckerberg/shared-infra/issues/10522)) ([9882a90](https://github.com/chanzuckerberg/shared-infra/commit/9882a90e3406d200378cf54dea83c73610c9d0b6))

## [5.11.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.10.0...k8s-core-v5.11.0) (2024-10-24)


### Features

* (empty) Triggering release of debezium-jmx-exporter ([#10354](https://github.com/chanzuckerberg/shared-infra/issues/10354)) ([4032074](https://github.com/chanzuckerberg/shared-infra/commit/403207436279015b59e67aa1ac74d4e2136a1848))
* Triggering shared-infra release ([#10362](https://github.com/chanzuckerberg/shared-infra/issues/10362)) ([0edb281](https://github.com/chanzuckerberg/shared-infra/commit/0edb2818a59747dd50d4d30f694f7604ade3be76))

## [5.10.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.9.0...k8s-core-v5.10.0) (2024-10-10)


### Features

* allow for extraArgs to be specified in nginx controller ([#10268](https://github.com/chanzuckerberg/shared-infra/issues/10268)) ([5e0492b](https://github.com/chanzuckerberg/shared-infra/commit/5e0492be12acc04a733ea3ae9413d05b3d8a327f))

## [5.9.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.8.0...k8s-core-v5.9.0) (2024-09-26)


### Features

* Enable nginx prometheus metrics ([#10174](https://github.com/chanzuckerberg/shared-infra/issues/10174)) ([f3d2eb9](https://github.com/chanzuckerberg/shared-infra/commit/f3d2eb933544b38968d362b0db1b338f160318a1))

## [5.8.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.7.0...k8s-core-v5.8.0) (2024-08-13)


### Features

* Make linkerd cert creation job wait longer ([#9954](https://github.com/chanzuckerberg/shared-infra/issues/9954)) ([66b1511](https://github.com/chanzuckerberg/shared-infra/commit/66b15116b9d6b8ece36e58a6887421f3354cd114))

## [5.7.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.6.0...k8s-core-v5.7.0) (2024-07-26)


### Features

* Streamline cluster import into rancher ([#9877](https://github.com/chanzuckerberg/shared-infra/issues/9877)) ([4b5c570](https://github.com/chanzuckerberg/shared-infra/commit/4b5c570e9ff9bb3ce18379f01b49c517fb98a60e))

## [5.6.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.5.1...k8s-core-v5.6.0) (2024-06-27)


### Features

* update TFE to create new workspace for route53 ([#9657](https://github.com/chanzuckerberg/shared-infra/issues/9657)) ([fb95df6](https://github.com/chanzuckerberg/shared-infra/commit/fb95df629bc6142aff4d293ab277c8ace0db972f))

## [5.5.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.5.0...k8s-core-v5.5.1) (2024-05-07)


### Bug Fixes

* updating linkerd version to helm chart 1.12.7 which maps to linkerd version stable-2.13.7 ([#9353](https://github.com/chanzuckerberg/shared-infra/issues/9353)) ([79e2bbe](https://github.com/chanzuckerberg/shared-infra/commit/79e2bbe12f5472ca5f6b813b9d70538756e5a6d9))

## [5.5.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.4.0...k8s-core-v5.5.0) (2024-05-02)


### Features

* Upgrade datadog agent to 7.53.0 ([#9337](https://github.com/chanzuckerberg/shared-infra/issues/9337)) ([ed2fc5c](https://github.com/chanzuckerberg/shared-infra/commit/ed2fc5c82dd5b610f6304c28e7f57699cf57a990))

## [5.4.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.3.1...k8s-core-v5.4.0) (2024-05-01)


### Features

* Switch datadog agents to use ecr instead of gcr which is going away 5/15/2024 ([#9304](https://github.com/chanzuckerberg/shared-infra/issues/9304)) ([ada7a9d](https://github.com/chanzuckerberg/shared-infra/commit/ada7a9df488b8504c2fd231428f290b93b568760))

## [5.3.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.3.0...k8s-core-v5.3.1) (2024-04-03)


### Bug Fixes

* Update cluster-monitoring helm chart version ([#9138](https://github.com/chanzuckerberg/shared-infra/issues/9138)) ([91c55e7](https://github.com/chanzuckerberg/shared-infra/commit/91c55e71d2e48adc556084cdd98f67f7466a0b26))

## [5.3.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.2.0...k8s-core-v5.3.0) (2024-03-07)


### Features

* Upgrade rancher monitoring application to 102.0.3+up40.1.2 ([#9101](https://github.com/chanzuckerberg/shared-infra/issues/9101)) ([c83fd4b](https://github.com/chanzuckerberg/shared-infra/commit/c83fd4b2969196f58c80b1d45ca7ea667e60b2b4))

## [5.2.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.1.0...k8s-core-v5.2.0) (2023-10-23)


### Features

* adding nginx proxy buffer config ([#8647](https://github.com/chanzuckerberg/shared-infra/issues/8647)) ([a89643c](https://github.com/chanzuckerberg/shared-infra/commit/a89643c76689879486821ef3a76435d219bc098a))

## [5.1.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v5.0.0...k8s-core-v5.1.0) (2023-10-03)


### Features

* Move Karpenter to a fargate profile and exclude nodelocaldns, rancher monitoring and datadog agent from running on fargate ([#8495](https://github.com/chanzuckerberg/shared-infra/issues/8495)) ([49a06ec](https://github.com/chanzuckerberg/shared-infra/commit/49a06ec2239445468879ae7a343ef9c70834b0ab))

## [5.0.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.12.0...k8s-core-v5.0.0) (2023-09-18)


### ⚠ BREAKING CHANGES

* Move core responsibilities of k8s-core into eks-cluster and eks-cluster-v2 (#8384)

### Features

* Move core responsibilities of k8s-core into eks-cluster and eks-cluster-v2 ([#8384](https://github.com/chanzuckerberg/shared-infra/issues/8384)) ([d173abf](https://github.com/chanzuckerberg/shared-infra/commit/d173abf516b61df8e8b013252557c6dec8f7ac0e))


### Bug Fixes

* Fix rancher monitoring app creation due to agents not starting timely ([#8411](https://github.com/chanzuckerberg/shared-infra/issues/8411)) ([ff76852](https://github.com/chanzuckerberg/shared-infra/commit/ff76852ecdc2a28e33f885b10bd2a8862bf917af))

## [4.12.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.11.1...k8s-core-v4.12.0) (2023-09-06)


### Features

* automate linkerd CA key generation and storage ([#8363](https://github.com/chanzuckerberg/shared-infra/issues/8363)) ([29135f7](https://github.com/chanzuckerberg/shared-infra/commit/29135f752cf9ed1f67dd1ee6b3b4c21143c8b142))

## [4.11.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.11.0...k8s-core-v4.11.1) (2023-09-06)


### Bug Fixes

* Make daemonset alerts more tolerant of scaling ([#8389](https://github.com/chanzuckerberg/shared-infra/issues/8389)) ([25df80a](https://github.com/chanzuckerberg/shared-infra/commit/25df80a5a9a119d4bac0f2cf0227ba48e5358baf))

## [4.11.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.10.1...k8s-core-v4.11.0) (2023-08-25)


### Features

* Add nvidia-device-plugin as an add-on to k8s-core ([#8345](https://github.com/chanzuckerberg/shared-infra/issues/8345)) ([636f70a](https://github.com/chanzuckerberg/shared-infra/commit/636f70a6083eb011fd0d39a75b557889fb288a7c))

## [4.10.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.10.0...k8s-core-v4.10.1) (2023-08-21)


### Bug Fixes

* Fix kubernetes rancher-monitoring ([#8309](https://github.com/chanzuckerberg/shared-infra/issues/8309)) ([0b3ae59](https://github.com/chanzuckerberg/shared-infra/commit/0b3ae596d4c6869cace8777a2553b6b2f0940daa))

## [4.10.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.9.0...k8s-core-v4.10.0) (2023-08-18)


### Features

* Enable rancher monitoring by default ([#8307](https://github.com/chanzuckerberg/shared-infra/issues/8307)) ([befc0e5](https://github.com/chanzuckerberg/shared-infra/commit/befc0e55dde4332fde0c7d34c55afe08d7c21c5a))

## [4.9.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.8.0...k8s-core-v4.9.0) (2023-08-15)


### Features

* Disable alb ingress controller service mutating webhook ([#8282](https://github.com/chanzuckerberg/shared-infra/issues/8282)) ([2b2e463](https://github.com/chanzuckerberg/shared-infra/commit/2b2e4631980bcaeb44c7a917ff25886e06f8ac08))

## [4.8.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.7.3...k8s-core-v4.8.0) (2023-08-15)


### Features

* Upgrade k8s-core helm charts ([#8274](https://github.com/chanzuckerberg/shared-infra/issues/8274)) ([fda796b](https://github.com/chanzuckerberg/shared-infra/commit/fda796b18b9479703410061e3e1df98eb18ef508))

## [4.7.3](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.7.2...k8s-core-v4.7.3) (2023-08-10)


### Bug Fixes

* Fix node dns in k8s-core ([#8244](https://github.com/chanzuckerberg/shared-infra/issues/8244)) ([d7b754d](https://github.com/chanzuckerberg/shared-infra/commit/d7b754db6307e4efdd0057f05c710a4bbd3d21e8))
* Incorrect reference to a dns service in k8s-core ([#8246](https://github.com/chanzuckerberg/shared-infra/issues/8246)) ([41c576a](https://github.com/chanzuckerberg/shared-infra/commit/41c576a610152693ad477e0705f4e88556562aa7))

## [4.7.2](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.7.1...k8s-core-v4.7.2) (2023-08-07)


### Bug Fixes

* update nginx issuer to cluster issuer and make linkerd pull key from parameter store ([#8167](https://github.com/chanzuckerberg/shared-infra/issues/8167)) ([2996b8b](https://github.com/chanzuckerberg/shared-infra/commit/2996b8ba140c615e8fa44ba00d38b5e7a6838eb8))

## [4.7.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.7.0...k8s-core-v4.7.1) (2023-07-31)


### Bug Fixes

* Upgrade eks blueprints version to fix the helm-addon issue ([#8166](https://github.com/chanzuckerberg/shared-infra/issues/8166)) ([2fd3860](https://github.com/chanzuckerberg/shared-infra/commit/2fd3860087b54cbb0678872e7f0b33c6aaa8ce86))

## [4.7.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.6.0...k8s-core-v4.7.0) (2023-07-28)


### Features

* Enforce GP3 storage class as default ([#8013](https://github.com/chanzuckerberg/shared-infra/issues/8013)) ([c814fe6](https://github.com/chanzuckerberg/shared-infra/commit/c814fe6802e280647948d862124d8ca56bcf0324))

## [4.6.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.5.0...k8s-core-v4.6.0) (2023-06-08)


### Features

* adding nginx and linkerd as options for k8s-core ([#7906](https://github.com/chanzuckerberg/shared-infra/issues/7906)) ([3379ec8](https://github.com/chanzuckerberg/shared-infra/commit/3379ec84dfdab015f9164cf3893b1579cb56cd3a))
* Remove network policy settings and consolidate rancher registration settings ([#7912](https://github.com/chanzuckerberg/shared-infra/issues/7912)) ([65e1c4b](https://github.com/chanzuckerberg/shared-infra/commit/65e1c4b3d8eb46970680e168dca6267b16086540))

## [4.5.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.4.0...k8s-core-v4.5.0) (2023-06-07)


### Features

* make fluentbit optional ([#7905](https://github.com/chanzuckerberg/shared-infra/issues/7905)) ([44f0760](https://github.com/chanzuckerberg/shared-infra/commit/44f0760fb8cfa7a8e04b30913b65d2321feb2d88))

## [4.4.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.3.0...k8s-core-v4.4.0) (2023-05-25)


### Features

* Expose Rancher config inputs to parent k8s-core module ([#7852](https://github.com/chanzuckerberg/shared-infra/issues/7852)) ([ae86ad3](https://github.com/chanzuckerberg/shared-infra/commit/ae86ad3f5dda9170637b8e02e990b0b3b35551a4))

## [4.3.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.2.0...k8s-core-v4.3.0) (2023-05-23)


### Features

* Parameterize Rancher cluster monitoring settings ([#7847](https://github.com/chanzuckerberg/shared-infra/issues/7847)) ([b10b2e4](https://github.com/chanzuckerberg/shared-infra/commit/b10b2e4a282f0dd788e80d95320243d4e276be3e))

## [4.2.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.1.0...k8s-core-v4.2.0) (2023-05-23)


### Features

* Combine eks blueprints module invocations ([#7820](https://github.com/chanzuckerberg/shared-infra/issues/7820)) ([6b710a7](https://github.com/chanzuckerberg/shared-infra/commit/6b710a771841a845466adb15233603f8d86bb1c4))

## [4.1.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v4.0.0...k8s-core-v4.1.0) (2023-05-15)


### Features

* Allow EKS clusters to be imported into Rancher through terraform provider ([#7795](https://github.com/chanzuckerberg/shared-infra/issues/7795)) ([47991a2](https://github.com/chanzuckerberg/shared-infra/commit/47991a2e9eb50355bb4ed3988bc05ebaf44b0311))


### Bug Fixes

* mark k8s additional_addons as sensitive ([#7779](https://github.com/chanzuckerberg/shared-infra/issues/7779)) ([f4ee75e](https://github.com/chanzuckerberg/shared-infra/commit/f4ee75ef3c8a0826ae1e3611e60aa5b2da0ea844))

## [4.0.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v3.0.1...k8s-core-v4.0.0) (2023-05-08)


### ⚠ BREAKING CHANGES

* clean up legacy k8s-core variables; optin dd (#7773)

### Features

* clean up legacy k8s-core variables; optin dd ([#7773](https://github.com/chanzuckerberg/shared-infra/issues/7773)) ([2371dd7](https://github.com/chanzuckerberg/shared-infra/commit/2371dd7a1b861a1dab052b49d832b0b3ce6bee91))

## [3.0.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v3.0.0...k8s-core-v3.0.1) (2023-05-05)


### Bug Fixes

* Switch efs driver to eks blueprints and update lp-dev Looker version ([#7755](https://github.com/chanzuckerberg/shared-infra/issues/7755)) ([a154cfd](https://github.com/chanzuckerberg/shared-infra/commit/a154cfd4f2d183cfeb1fed00193f2ad7a36cc65d))

## [3.0.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v2.0.0...k8s-core-v3.0.0) (2023-04-28)


### ⚠ BREAKING CHANGES

* clean up k8s-core calling convention (#7729)

### Features

* clean up k8s-core calling convention ([#7729](https://github.com/chanzuckerberg/shared-infra/issues/7729)) ([882d270](https://github.com/chanzuckerberg/shared-infra/commit/882d2704bbc84f51053e13b2c9f09a635aa2123a))

## [2.0.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.24.1...k8s-core-v2.0.0) (2023-04-28)


### ⚠ BREAKING CHANGES

* k8s-core major version bump (#7726)

### Features

* k8s-core major version bump ([#7726](https://github.com/chanzuckerberg/shared-infra/issues/7726)) ([1c44772](https://github.com/chanzuckerberg/shared-infra/commit/1c4477285cf5a26411a73396bb631eea39a67e6b))
* make datadog k8s-core optional ([#7721](https://github.com/chanzuckerberg/shared-infra/issues/7721)) ([d8b28c5](https://github.com/chanzuckerberg/shared-infra/commit/d8b28c5b76bd36f1aaede9b689c56fd0c7e91ee2))

## [1.24.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.24.0...k8s-core-v1.24.1) (2023-04-24)


### Bug Fixes

* Updated autoscaler for 1.24 ([#7686](https://github.com/chanzuckerberg/shared-infra/issues/7686)) ([acca8d5](https://github.com/chanzuckerberg/shared-infra/commit/acca8d5826eed14878b9f7163b0d76c042cb84c0))

## [1.24.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.23.0...k8s-core-v1.24.0) (2023-04-21)


### Features

* Upgrade k8s-core to support EKS 1.26 ([#7684](https://github.com/chanzuckerberg/shared-infra/issues/7684)) ([83bcb15](https://github.com/chanzuckerberg/shared-infra/commit/83bcb15954f4e04d9f1e21fc6d9feab52447e860))

## [1.23.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.22.1...k8s-core-v1.23.0) (2023-04-03)


### Features

* Deploy crossplane into playground-eks-v2 ([#7581](https://github.com/chanzuckerberg/shared-infra/issues/7581)) ([91fd926](https://github.com/chanzuckerberg/shared-infra/commit/91fd92697ac8ae2a375f880fc1a8fb6e32806fa4))
* Specify default value for crossplane addon ([#7582](https://github.com/chanzuckerberg/shared-infra/issues/7582)) ([9c1818c](https://github.com/chanzuckerberg/shared-infra/commit/9c1818cb315cbfd0928cfbab48e34f34528ae15b))

## [1.22.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.22.0...k8s-core-v1.22.1) (2023-03-31)


### Bug Fixes

* Update deprecated tf index syntax ([#7563](https://github.com/chanzuckerberg/shared-infra/issues/7563)) ([199960e](https://github.com/chanzuckerberg/shared-infra/commit/199960e35119617633249e57fea0a945dd759f3f))

## [1.22.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.21.1...k8s-core-v1.22.0) (2023-03-28)


### Features

* Upgrade chart versions for cluster-autoscaler and kube-state-metrics in EKS 1.25 ([#7548](https://github.com/chanzuckerberg/shared-infra/issues/7548)) ([0aab6bd](https://github.com/chanzuckerberg/shared-infra/commit/0aab6bdf93e8131dc48828f84591cba19f374e9d))

## [1.21.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.21.0...k8s-core-v1.21.1) (2023-03-16)


### Bug Fixes

* add variable to exclude paths for fluentbit ([#7467](https://github.com/chanzuckerberg/shared-infra/issues/7467)) ([d670a1a](https://github.com/chanzuckerberg/shared-infra/commit/d670a1a5bcb28d56067935f0c13d95d634500830))

## [1.21.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.20.3...k8s-core-v1.21.0) (2023-03-16)


### Features

* Upgrade external dns to a more recent version ([#7468](https://github.com/chanzuckerberg/shared-infra/issues/7468)) ([7791cfc](https://github.com/chanzuckerberg/shared-infra/commit/7791cfc387509b458743d4078d42067229d60947))

## [1.20.3](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.20.2...k8s-core-v1.20.3) (2023-03-15)


### Bug Fixes

* Fix k8s-core tflint ([#7460](https://github.com/chanzuckerberg/shared-infra/issues/7460)) ([8639e12](https://github.com/chanzuckerberg/shared-infra/commit/8639e12c5f4e85bc37e94b37d07010483929e484))

## [1.20.2](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.20.1...k8s-core-v1.20.2) (2023-03-15)


### Bug Fixes

* add sane default log retention for cloudwatch ([#7457](https://github.com/chanzuckerberg/shared-infra/issues/7457)) ([c5d2faa](https://github.com/chanzuckerberg/shared-infra/commit/c5d2faa172c71cd573a80d6f1efe91b452be631a))
* Force arm incompatible deployments onto amd nodes ([#7459](https://github.com/chanzuckerberg/shared-infra/issues/7459)) ([b120093](https://github.com/chanzuckerberg/shared-infra/commit/b120093a2b4981f7d1bc47a6ed43c89c5cf2dd4a))

## [1.20.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.20.0...k8s-core-v1.20.1) (2023-02-22)


### Bug Fixes

* CCIE-888 forgot tags in kiam module; defaults ([#7288](https://github.com/chanzuckerberg/shared-infra/issues/7288)) ([dd36fca](https://github.com/chanzuckerberg/shared-infra/commit/dd36fcaeef113ff32ea1f17d121d75ee77834cdc))

## [1.20.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.19.0...k8s-core-v1.20.0) (2023-02-18)


### Features

* CCIE-888 optional addons variable; kiam/dd ([#7263](https://github.com/chanzuckerberg/shared-infra/issues/7263)) ([0e26ca3](https://github.com/chanzuckerberg/shared-infra/commit/0e26ca319834724904e0d8530f56d05801fc5381))

## [1.19.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.18.0...k8s-core-v1.19.0) (2023-01-30)


### Features

* allow the ALB ingress controller access to secrets ([#7129](https://github.com/chanzuckerberg/shared-infra/issues/7129)) ([3ad1661](https://github.com/chanzuckerberg/shared-infra/commit/3ad166107ca0722ce9e8ffe57d4670de85229538))

## [1.18.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.17.1...k8s-core-v1.18.0) (2023-01-26)


### Features

* Reduce datadog scraping intervals ([#7111](https://github.com/chanzuckerberg/shared-infra/issues/7111)) ([a9294f6](https://github.com/chanzuckerberg/shared-infra/commit/a9294f6780758935636cff768d2712d9df65a995))


### Bug Fixes

* Remove unsupported scraping intervals ([#7113](https://github.com/chanzuckerberg/shared-infra/issues/7113)) ([4f25790](https://github.com/chanzuckerberg/shared-infra/commit/4f257903ba46da40beacc99d212e4d55e8308a6e))

## [1.17.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.17.0...k8s-core-v1.17.1) (2023-01-09)


### Bug Fixes

* Improve confidence on some of the Datadog monitors ([#7022](https://github.com/chanzuckerberg/shared-infra/issues/7022)) ([92a52bc](https://github.com/chanzuckerberg/shared-infra/commit/92a52bc6dac0eb9513910b2065eb1795fb36d32e))

## [1.17.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.16.2...k8s-core-v1.17.0) (2023-01-05)


### Features

* Upgrade datadog helm chart to 3.6.7 and agent to 7.41.1 ([#6984](https://github.com/chanzuckerberg/shared-infra/issues/6984)) ([3bc603a](https://github.com/chanzuckerberg/shared-infra/commit/3bc603a01ae6f1dcbbe76ea44e97ba796342f229))

## [1.16.2](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.16.1...k8s-core-v1.16.2) (2022-12-12)


### Bug Fixes

* owners ID in externaldns ([#6890](https://github.com/chanzuckerberg/shared-infra/issues/6890)) ([8a770d7](https://github.com/chanzuckerberg/shared-infra/commit/8a770d73e74a1d7d5ab5568aca4a04b5e4e64110))

## [1.16.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.16.0...k8s-core-v1.16.1) (2022-12-05)


### Bug Fixes

* Pin k8s-core in ie-ie-eks to prevent Route53 deletions ([#6845](https://github.com/chanzuckerberg/shared-infra/issues/6845)) ([e0bf9f6](https://github.com/chanzuckerberg/shared-infra/commit/e0bf9f60753051e76769a6f96f8c4c177c7619f5))

## [1.16.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.15.1...k8s-core-v1.16.0) (2022-12-01)


### Features

* make external-dns sync ([#6832](https://github.com/chanzuckerberg/shared-infra/issues/6832)) ([8448490](https://github.com/chanzuckerberg/shared-infra/commit/844849005c230b96191fa13dfa29834e69dc1b80))

## [1.15.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.15.0...k8s-core-v1.15.1) (2022-11-28)


### Bug Fixes

* compatible image version for dd ([#6791](https://github.com/chanzuckerberg/shared-infra/issues/6791)) ([75485b7](https://github.com/chanzuckerberg/shared-infra/commit/75485b79184c9b3ee9feffc18e8602a32c78dde8))
* move env var to right agent ([#6794](https://github.com/chanzuckerberg/shared-infra/issues/6794)) ([7448cfb](https://github.com/chanzuckerberg/shared-infra/commit/7448cfb78bb4e09f992ef9edda3f7fdac080728f))

## [1.15.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.14.0...k8s-core-v1.15.0) (2022-11-23)


### Features

* add 1.24 to kubechart ([#6784](https://github.com/chanzuckerberg/shared-infra/issues/6784)) ([b34e31c](https://github.com/chanzuckerberg/shared-infra/commit/b34e31ce7b60c3eb9c568e6d726a6dbc4f404d2b))

## [1.14.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.13.0...k8s-core-v1.14.0) (2022-11-23)


### Features

* add 1.24 to k8s-core version ([#6783](https://github.com/chanzuckerberg/shared-infra/issues/6783)) ([a497dad](https://github.com/chanzuckerberg/shared-infra/commit/a497dad20286f5524a537df77cdb39eeaab4f8dd))

## [1.13.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.12.0...k8s-core-v1.13.0) (2022-10-28)


### Features

* Allow ingress exclusion based on annotation filter ([#6567](https://github.com/chanzuckerberg/shared-infra/issues/6567)) ([992b45f](https://github.com/chanzuckerberg/shared-infra/commit/992b45ff4482c8b8f677b2f84bfd6e7f21eefbb7))

## [1.12.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.11.2...k8s-core-v1.12.0) (2022-10-26)


### Features

* Upgrade k8s-core helm charts ([#6541](https://github.com/chanzuckerberg/shared-infra/issues/6541)) ([02db227](https://github.com/chanzuckerberg/shared-infra/commit/02db22797840e458c7446b5e46f85888a9b7143d))

## [1.11.2](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.11.1...k8s-core-v1.11.2) (2022-09-29)


### Bug Fixes

* Create a statsd service ([#6349](https://github.com/chanzuckerberg/shared-infra/issues/6349)) ([b516975](https://github.com/chanzuckerberg/shared-infra/commit/b516975fbb13faa777882981e2020ee7033c3788))

## [1.11.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.11.0...k8s-core-v1.11.1) (2022-09-13)


### Bug Fixes

* Remove defunct node-termination-handler ([#6255](https://github.com/chanzuckerberg/shared-infra/issues/6255)) ([ddb0504](https://github.com/chanzuckerberg/shared-infra/commit/ddb0504d506e7024233088442686451865c94854))

## [1.11.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.10.0...k8s-core-v1.11.0) (2022-09-12)


### Features

* Remove pagerduty refs from monitored_service module ([#6240](https://github.com/chanzuckerberg/shared-infra/issues/6240)) ([a6b00c8](https://github.com/chanzuckerberg/shared-infra/commit/a6b00c8e95c87055ffb352563b3a6a0ce06c09f4))

## [1.10.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.9.0...k8s-core-v1.10.0) (2022-09-12)


### Features

* Support for EKS 1.23 ([#6236](https://github.com/chanzuckerberg/shared-infra/issues/6236)) ([31dc9df](https://github.com/chanzuckerberg/shared-infra/commit/31dc9df87a6fbc3445b465facef027422e43db5d))


### Bug Fixes

* Fix EKS autoscaler policy ([#6238](https://github.com/chanzuckerberg/shared-infra/issues/6238)) ([f07fb0b](https://github.com/chanzuckerberg/shared-infra/commit/f07fb0b3e73543b40ff348a24daac746c41230df))

## [1.9.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.8.0...k8s-core-v1.9.0) (2022-09-07)


### Features

* match all conditions for incident rule opsgenie and redo amundsen monitoring ([#6214](https://github.com/chanzuckerberg/shared-infra/issues/6214)) ([4cee746](https://github.com/chanzuckerberg/shared-infra/commit/4cee74629a1dfd3018466a15cbe704f9e6bacf46))

## [1.8.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.7.1...k8s-core-v1.8.0) (2022-09-06)


### Features

* New incident rule and datadog opsgenie tag in message ([#6201](https://github.com/chanzuckerberg/shared-infra/issues/6201)) ([2cd9647](https://github.com/chanzuckerberg/shared-infra/commit/2cd96470879c6b2e3e0aa159a61f0e56e1e8c471))
* Update k8s-core module for ie include opsgenie change ([#6183](https://github.com/chanzuckerberg/shared-infra/issues/6183)) ([b0488f3](https://github.com/chanzuckerberg/shared-infra/commit/b0488f3d385b9a01a0808458be8b4e53f379d489))

## [1.7.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.7.0...k8s-core-v1.7.1) (2022-09-01)


### Bug Fixes

* namespacing in tfe-agents ([#6157](https://github.com/chanzuckerberg/shared-infra/issues/6157)) ([7e59401](https://github.com/chanzuckerberg/shared-infra/commit/7e59401116599fa04a5503d151e13128dabee025))

## [1.7.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.6.3...k8s-core-v1.7.0) (2022-08-31)


### Features

* Add OPS Genie and keep PD for now ([#6076](https://github.com/chanzuckerberg/shared-infra/issues/6076)) ([a56c45c](https://github.com/chanzuckerberg/shared-infra/commit/a56c45cd41de4e4953e54c52513b9cce2cc6aa3d))

## [1.6.3](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.6.2...k8s-core-v1.6.3) (2022-08-16)


### Bug Fixes

* Modify the datadog agent name to match the one deployed with the helm chart ([#6000](https://github.com/chanzuckerberg/shared-infra/issues/6000)) ([67a961c](https://github.com/chanzuckerberg/shared-infra/commit/67a961cb8d8efc54dda935e62fade5a25511d7ee))

## [1.6.2](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.6.1...k8s-core-v1.6.2) (2022-08-09)


### Bug Fixes

* add databricks to dev-cutter providers ([#5900](https://github.com/chanzuckerberg/shared-infra/issues/5900)) ([fe7d0cc](https://github.com/chanzuckerberg/shared-infra/commit/fe7d0ccea6a694728e7d7aab4a35a08f630d02d9))

## [1.6.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.6.0...k8s-core-v1.6.1) (2022-07-29)


### Bug Fixes

* Upgrade cluster autoscaler for EKS 1.22 ([#5814](https://github.com/chanzuckerberg/shared-infra/issues/5814)) ([544afc3](https://github.com/chanzuckerberg/shared-infra/commit/544afc3155e2ada5aaa46607ca75203cbd813afe))

## [1.6.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.5.1...k8s-core-v1.6.0) (2022-07-21)


### Features

* Upgrade EKS module to 18.26.3 ([#5308](https://github.com/chanzuckerberg/shared-infra/issues/5308)) ([caa068f](https://github.com/chanzuckerberg/shared-infra/commit/caa068fb505271dea80bc8cc42fb7e17b661a724))

### [1.5.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.5.0...k8s-core-v1.5.1) (2022-05-23)


### Bug Fixes

* add more memory to external DNS to avoid OOM ([#5337](https://github.com/chanzuckerberg/shared-infra/issues/5337)) ([abd937e](https://github.com/chanzuckerberg/shared-infra/commit/abd937e2a7e0f22b609ee003a058f36bf1c72157))

## [1.5.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.4.0...k8s-core-v1.5.0) (2022-05-06)


### Features

* Adjust "pods stuck" and "ALB group out of sync" alerts ([#5118](https://github.com/chanzuckerberg/shared-infra/issues/5118)) ([72c82b3](https://github.com/chanzuckerberg/shared-infra/commit/72c82b3b4229bdd02e5a7abc4ec4fa575073668b))

## [1.4.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.3.1...k8s-core-v1.4.0) (2022-05-04)


### Features

* K8s nodelocal DNS caching  ([#5174](https://github.com/chanzuckerberg/shared-infra/issues/5174)) ([bc0a312](https://github.com/chanzuckerberg/shared-infra/commit/bc0a3124e90bb5db3887c0f438977b0d35dc9f28))


### Bug Fixes

* k8s-core set the FQDN for the datadog-agent service ([#5177](https://github.com/chanzuckerberg/shared-infra/issues/5177)) ([34c94a6](https://github.com/chanzuckerberg/shared-infra/commit/34c94a6b32d44699cb21b47ca2021a526c932ed9))

### [1.3.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.3.0...k8s-core-v1.3.1) (2022-05-04)


### Bug Fixes

* Use the official k8s charts for metrics servers, needed for HPAs; fix coredns HPA ([#5170](https://github.com/chanzuckerberg/shared-infra/issues/5170)) ([13cd394](https://github.com/chanzuckerberg/shared-infra/commit/13cd394d8822eeadf9c29d20b8a18639c7bad118))

## [1.3.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.2.1...k8s-core-v1.3.0) (2022-05-04)


### Features

* Add a HPA for CoreDNS ([#5167](https://github.com/chanzuckerberg/shared-infra/issues/5167)) ([987fcbc](https://github.com/chanzuckerberg/shared-infra/commit/987fcbc30375e62326fd9a9f7d9cca180986511c))

### [1.2.1](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.2.0...k8s-core-v1.2.1) (2022-04-28)


### Bug Fixes

* Upgrade ALB ingress controller to fix EKS 1.22 compatibility issue ([#5096](https://github.com/chanzuckerberg/shared-infra/issues/5096)) ([946699b](https://github.com/chanzuckerberg/shared-infra/commit/946699bd5b2c66e95789dc0d116bedb9d27645df))

## [1.2.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.1.0...k8s-core-v1.2.0) (2022-04-20)


### Features

* Added EFS controller into k8s-core ([#5045](https://github.com/chanzuckerberg/shared-infra/issues/5045)) ([db201b1](https://github.com/chanzuckerberg/shared-infra/commit/db201b1ac1ad36e20b0202cabea96bcc4a2f0965))


### Bug Fixes

* Fixed EFS driver service account namespace ([#5046](https://github.com/chanzuckerberg/shared-infra/issues/5046)) ([867055b](https://github.com/chanzuckerberg/shared-infra/commit/867055b59c0a42dc0968bfe7dab6aecf84d2f10c))

## [1.1.0](https://github.com/chanzuckerberg/shared-infra/compare/k8s-core-v1.0.0...k8s-core-v1.1.0) (2022-01-19)


### Features

* EKS node termination handler listens for events ([#4647](https://github.com/chanzuckerberg/shared-infra/issues/4647)) ([4e98fda](https://github.com/chanzuckerberg/shared-infra/commit/4e98fda93ea7f05cdf1caa64b1ea6e94536a77bb))

## 1.0.0 (2022-01-14)


### ⚠ BREAKING CHANGES

* k8s-core upgrade external dns to 0.10.1; requires k8s 1.19+ (#4457)
* Upgrade load balancer ingress controller to v2.3.0 (#4372)

### Features

* k8s-core upgrade external dns to 0.10.1; requires k8s 1.19+ ([#4457](https://github.com/chanzuckerberg/shared-infra/issues/4457)) ([c7abd9e](https://github.com/chanzuckerberg/shared-infra/commit/c7abd9e8d6443e1cbee1e992f2fcc33f378f4968))
* k8s-core: Add Node Termination Handler to gracefully react to EC2 lifecycle events ([#4578](https://github.com/chanzuckerberg/shared-infra/issues/4578)) ([32304c0](https://github.com/chanzuckerberg/shared-infra/commit/32304c0763ca3fe7511b67ec20acbebf84aad29a))
* Upgrade k8s-core components to latest; Upgrade si-dev-eks to 1.19 ([#4393](https://github.com/chanzuckerberg/shared-infra/issues/4393)) ([6cfd188](https://github.com/chanzuckerberg/shared-infra/commit/6cfd188d6dde1c9235c7ae15c462379b2673e180))
* Upgrade k8s-core datadog agent log4j patch ([#4447](https://github.com/chanzuckerberg/shared-infra/issues/4447)) ([2ffdb7c](https://github.com/chanzuckerberg/shared-infra/commit/2ffdb7cc66df77ff8b554a898da89588b6030c7e))
* Upgrade load balancer ingress controller to v2.3.0 ([#4372](https://github.com/chanzuckerberg/shared-infra/issues/4372)) ([41fdc2c](https://github.com/chanzuckerberg/shared-infra/commit/41fdc2c59dc1dcf39fd3f7124df416a7844467a4))


### Bug Fixes

* downgrade external-dns to 0.9.0 until k8s 1.19+ ([#4454](https://github.com/chanzuckerberg/shared-infra/issues/4454)) ([cdba671](https://github.com/chanzuckerberg/shared-infra/commit/cdba671def7a72801bb5f4650a3a012bf784a457))
* Downgrading k8s-core kube-state-metrics helm chart version ([#4551](https://github.com/chanzuckerberg/shared-infra/issues/4551)) ([d42608f](https://github.com/chanzuckerberg/shared-infra/commit/d42608fc56f46e9e1d4035a122e32d2232ddcd21))
* EKS instance termination handler use unerlying instance's metadata endpoint ([#4592](https://github.com/chanzuckerberg/shared-infra/issues/4592)) ([b90d3f5](https://github.com/chanzuckerberg/shared-infra/commit/b90d3f54e0adba8a1d06ab60be4aa012d2e1a0f0))
* eks node termination handler chart version is 0.16.0 ([#4601](https://github.com/chanzuckerberg/shared-infra/issues/4601)) ([3f2786e](https://github.com/chanzuckerberg/shared-infra/commit/3f2786e40d0e7cd7a1164a889d2196a0b0adc201))
* Resolve ingress ALB controller issue with tag updates ([#4502](https://github.com/chanzuckerberg/shared-infra/issues/4502)) ([fddb334](https://github.com/chanzuckerberg/shared-infra/commit/fddb334d097f817574502dc958275a413b1e180f))
