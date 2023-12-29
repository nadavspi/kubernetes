reconcile:
  flux reconcile source git flux-system

setup host: 
  just set-token {{host}}
  just bootstrap 
  just sops

set-token host:
  ssh {{host}} "sudo cat /etc/rancher/k3s/k3s.yaml" | \
    sed --expression 's/127\.0\.0\.1/{{host}}/' \
    > ~/.kube/config

bootstrap:
  #!/usr/bin/env bash
  set -euxo pipefail

  export GITHUB_TOKEN=$(op read "op://cluster-main/khjznpny7hv2gziibyiyit27fq/password")
  flux bootstrap github \
  --owner=nadavspi \
  --repository=kubernetes \
  --personal \
  --path=clusters/main

sops-setup:
  op read "op://cluster-main/sops-age/age/private key" | \
       kubectl create secret generic sops-age \
       --namespace=flux-system \
       --from-file=age.agekey=/dev/stdin

config-kubectl:
  ssh 192.168.1.187 \
    "cat /etc/rancher/k3s/k3s.yaml" \
    | sed s/127\.0\.0\.1/192\.168\.1\.187/ \
    > ~/.kube/config

namespace name:
  #!/usr/bin/env bash
  set -euo pipefail
  cat <<EOF
  apiVersion: v1
  kind: Namespace
  metadata:
    name: {{name}}
  EOF

helmrepository name url:
  #!/usr/bin/env bash
  set -euo pipefail
  cat <<EOF
  apiVersion: source.toolkit.fluxcd.io/v1beta2
  kind: HelmRepository
  metadata:
    name: {{name}}
    namespace: flux-system
  spec:
    interval: 5m
    url: {{url}}
  EOF

kustomization name:
  #!/usr/bin/env bash
  set -euo pipefail
  cat <<EOF
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: {{name}}
    namespace: flux-system
  spec:
    path: ./clusters/main/apps/{{name}}
    interval: 15m
    prune: true # remove any elements later removed from the above path
    timeout: 2m # if not set, this defaults to interval duration, which is 1h
    sourceRef:
      kind: GitRepository
      name: flux-system
    healthChecks:
      - apiVersion: apps/v1
        kind: Deployment
        name: {{name}}
        namespace: {{name}}
  EOF

configmap name:
  #!/usr/bin/env bash
  set -euo pipefail
  cat <<EOF
  apiVersion: v1
  kind: ConfigMap
  metadata:
    creationTimestamp: null
    name: {{name}}-values
    namespace: {{name}}
  data:
    values.yaml: |-
      ## Content here
  EOF
  echo "Now paste values.yaml into {{name}}/values.yaml"

helmrelease name:
  #!/usr/bin/env bash
  set -euo pipefail
  cat <<EOF
  # yaml-language-server: \$schema=https://kubernetes-schemas.pages.dev/helm.toolkit.fluxcd.io/helmrelease_v2beta2.json
  apiVersion: helm.toolkit.fluxcd.io/v2beta2
  kind: HelmRelease
  metadata:
    name: {{name}}
    namespace: {{name}}
  spec:
    chart:
      spec:
        chart: {{name}} # the actual name of the chart
        version: 1.x
        sourceRef:
          kind: HelmRepository
          name: {{name}} # the name of the HelmRepository
          namespace: flux-system
    interval: 15m
    timeout: 5m
    releaseName: {{name}}
    valuesFrom:
    - kind: ConfigMap
      name: {{name}}-values
      valuesKey: values.yaml
  EOF

scaffold name url:
  # add --namespace infra-system
  mkdir -p apps/{{name}}
  just namespace {{name}} > apps/{{name}}/namespace.yaml

  just helmrepository {{name}} {{url}} > apps/{{name}}/helm.yaml
  echo "---" >> apps/{{name}}/helm.yaml
  just helmrelease {{name}} >> apps/{{name}}/helm.yaml

  just kustomization {{name}} > apps/{{name}}/ks.yaml
  just configmap {{name}} > apps/{{name}}/values.yaml

hurry name:
  flux suspend helmrelease {{name}} -n {{name}} \
  && flux resume helmrelease {{name}} -n {{name}}

sops-encrypt file:
  just sops --encrypt \
    --encrypted-regex 'data' \
    --in-place \
    {{file}}

warnings:
  kubectl get events -n flux-system --field-selector type=Warning

ready:
  flux get all -A --status-selector ready=false

ssh host="fedora":
  kubectl exec -it deployments/{{host}} -- sh

