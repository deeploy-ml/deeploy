<h1 align="center"> Deploying Deeploy </h1> <br>

<p align="center">
A guide for the installation of Deeploy.
</p>

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
    - [1. Structure the database](#1-structure-the-database)
    - [2. Deploy the Deeploy stack](#2-deploy-the-deeploy-stack)
        - [1. Istio](#1-istio)
        - [2. Knative](#2-knative)
        - [3. Cert-manager](#3-cert-manager)
        - [4. Deeploy stack](#4-deeploy-stack)
- [Troubelshooting](#troubelshooting)
- [FAQ](#faq)
    - [Helm](#helm)

## Prerequisites

1. Kubernetes cluster version 1.16.13+
    The **minimal hardware requirements**, spread out over all the nodes, are as follows
    - 3 (v)CPU
    - 6 GB RAM

    The **recommended hardware requirements**, spread out over all the nodes, are as follows
    - 6 (v)CPU
    - 12 GB RAM

    **NOTE**: When deploying models with heavier requirements, your cluster needs access to nodes that can handle these workloads.
    I.e. when you deploy a model that requires 7GB RAM to run, you need at least 1 Kubernetes nodepool with nodes that have a minimum of 8GB RAM.
    It is for this reason that you should prefer _less but bigger_ nodes over _more but smaller_ nodes.

    **NOTE**: It is advised that you turn on autoscaling on this cluster. 
    This way, when users deploy models without enough resources available on the cluster, new nodes can be spawned to take on the workload.

2. Helm v3 installed.
3. Postgres database for use by the microservices. The database should be reachable from the kubernetes nodes.
4. A (sub)domain which you control. In order to automatically generate TLS certificates using cert-manager, the DNS provider for this domain should be one of:
    - ACMEDNS
    - Akamai
    - AzureDNS
    - CloudFlare
    - Google
    - Route53
    - DigitalOcean
    - RFC2136
5. A remote storage bucket (Optional, see [Remote S3](#remote-s3)
    1. An AWS S3 bucket & AWS sericeaccount access keys with read/write access to the bucket.
    2. A Google Cloud Storage bucket & GCP serviceaccount with read/write access to the bucket.

## Installation
### 1. Structure the database

On the AWS RDS Postgres database server, create a seperate database for every microservice that needs one. Currently, these databases are:

1. `deeploy_companies`
2. `deeploy_deployment`
3. `deeploy_introspector`
4. `deeploy_logs`
5. `deeploy_repository`
6. `deeploy_projects`
7. `deeploy_token`
8. `deeploy_kratos`

Make sure that the username and password for all of these databases are the same. The user should have all rights on the database.

### 2. Deploy the Deeploy stack

We assume that you now have the infrastructure as defined in [Prerequisites](#prerequisites). From here we continue deploying the Deeploy stack. 
The installation steps assume you are in the folder `deeploy/install`.

Create all the Deeploy namespaces in kubernetes.
```bash
$ kubectl apply -f namespaces/
```

#### 1. Istio

> Current Istio installation instructions are based on `istio version 1.3.8` that should work on common cloud platforms. Always double check [platform specific installation requirements](https://istio.io/docs/setup/platform-setup/) and [the istio helm installation instructions](https://istio.io/docs/setup/install/helm/) to check the latest installation instructions.

**Installation steps:**

1. Download the Istio release:
    ```bash
    $ curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.3.8 sh -
    ```

2. Install Istio CRD's:
    ```bash
    $ for i in ./istio-1.3.8/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
    ```

3. Install Istio:
    ```bash
    $ # A lighter template, with just pilot/gateway.
    # Based on install/kubernetes/helm/istio/values-istio-minimal.yaml
    helm template --namespace=istio-system \
    -f ./istio/values.yaml \
    istio-1.3.8/install/kubernetes/helm/istio \
    | sed -e "s/custom-gateway/cluster-local-gateway/g" -e "s/customgateway/clusterlocalgateway/g" \
    > ./istio.yaml

    kubectl apply -f istio.yaml
    ```

4. Wait for a couple seconds and verify everything is in the running state by running:
    ```bash
    kubectl get pods --namespace istio-system
    ```

For additional information about installing Istio, see the [official website](https://archive.istio.io/v1.4/docs/setup/install/istioctl/)

#### 2. Knative

1. Install Knative CRDs using
    ```bash
    $ kubectl apply --filename ./knative/serving-crds.yml
    ```

2. Install core components
    ```bash
    $ kubectl apply --filename ./knative/serving-core.yml
    ```

3. Install the Knative Istio controller:
    ```bash
    $ kubectl apply --filename ./knative/serving-istio.yml
    ```

#### 3. Cert-manager

This step is optional, but recommended. If you do not want to use certmanager, there are two alternatives:

1. **Supply your own certificates**. You would do this by placing the root certificate in the `deeploy-cert` secret, and the wildcard certificate in the `deeploy-wildcard-cert` secret. Both reside in the `istio-system` namespace.
2. **Run Deeploy without TLS**. If you decide to run Deeploy without terminating TLS on the cluster level, make sure to do it elsewhere. You can turn off TLS by setting `security.tls.enabled` to `false` in the `values.yaml` during installation.

If you choose to use certmanager, follow these steps:

1. [Install cert-manager](https://cert-manager.io/docs/installation/kubernetes/#installing-with-helm).
2. [Set up auto-renewal through ACME](https://cert-manager.io/docs/configuration/acme/). Make sure to generate two certificates as described above.

#### 4. Deeploy stack

##### 1. Configure the installation

Edit `./helm/values.yml`:

1. Fill out the gitlab registry information and secrets.
2. Add a host (i.e. `deeploy.enjins.com`)
3. Add the database host and credentials (these should be the same for every microservice).

__Deeploy General Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `host` | the hostname on which you will be running deeploy | `""` |
| `deeployLicenseKey` | the supplied Deeploy license key | `""` |


__Deeploy Image Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `images.registry` | the registry to pull the Deeploy images from | `"registry.hub.docker.com"` |
| `images.path` | the path to the DeeployML registry | `"/deeployml"` |
| `images.tag` | the version tag of the deeploy deployment | same as application version |
| `images.username` | the username for the Docker registry | `""` |
| `images.password` | the password for the Docker registry | `""` |


__Deeploy Database Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `database.host` | the hostname of the database server | `""` |
| `database.port` | the port for use of the database server | `5432` |
| `database.username` | the username to access the database | `""` |
| `database.password` | the password to access the database server | `""` |


__Deeploy S3 Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `remoteBlobStorage.enabled` | whether to use off-cluster S3 storage. If enabled, set `minio.enabled` to `false` | `true` |
| `minio.enabled` | whether to use on-cluster S3 storage. If enabled, set `remoteBlobStorage.enabled` to `false` | `false` |
| `remoteBlobStorage.type` | storage service to use with Deeploy. One of `AWS_S3`, `GCS`. | `"AWS_S3"` |
| `remoteBlobStorage.bucketName` | name of the remote storage bucket to use | `""` |
| `remoteBlobStorage.s3AccessKey` | access key for the S3 server. Only set if `remoteBlobStorage.type` is `AWS_S3`. | `""` |
| `remoteBlobStorage.s3SecretKey` | secret key for the S3 server Only set if `remoteBlobStorage.type` is `AWS_S3`. | `""` |
| `remoteBlobStorage.gcloudApplicationCredentialsJson` | the json file with the credentials for the GCP service account. Only set if `remoteBlobStorage.type` is `GCS`. | `""` |


__Deeploy E-mail Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `email.smtpHost` | the hostname of the smtp server | `""` |
| `email.port` | the port for use of the smtp server | `465` |
| `email.username` | the username to access the smtp server | `""` |
| `email.password` | the password to access the smtp server | `""` |
| `email.fromAddress` | the email address for Deeploy to send emails from, i.e. `deeploy@example.com` | `""` |


__Deeploy Monitoring Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `monitoring.enabled` | whether to enable monitoring | `true` |
| `monitoring.credentials.username` | username for the monitoring server | `""` |
| `monitoring.credentials.password` | password for the monitoring server | `""` |


__Deeploy Security Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `security.tls.enabled` | whether to enable TLS | `true` |

###### Image repository

**registry**: The image registry, i.e. `registry.gitlab.com` or `index.docker.io/v2`

**path**: path to the deeploy image in the registry, i.e. `/deeploy-ml/deeploy`

**tag**: tag/version to be used for the Deeploy images

**username** & **password**: username and password for access to the registry

###### Host

**host**: The url on which you will deploy Deeploy, i.e. `deeploy.client.com`

###### License Key

**deeployLicenseKey**: the Deeploy license key

###### Email

**username**: username for access to the mail server

**password**: password for access to the mail server

**smtpHost**: host of the smtp server, i.e. `smtp.sendgrid.net`

**port**: the port on which to reach the server, i.e. `465`

**fromAddress**: the address to send the email from, i.e. `notify@deeploy.client.ml`


###### Database

**host**: host of the database server

**port**: database port, i.e. 5432

**username**: username

**password**: password

###### Remote S3

For S3 you have two options:
1. **Use a remote Storage repository (recommended)**. Deeploy currently supports AWS S3 & Google Cloud Storage
2. **Don't configure remote Storage (not recommended)**. Deeploy spawns an on-cluster S3 service.
    This is not recommended, as it does not make Deeploy stateless on the cluster. 
    If you do want to use it, set `minio.enabled` to true.

**enabled**: boolean. Whether to use remote S3.

**accessKey** (optional): Acces key for the AWS S3 bucket

**secretKey** (optional): Secret key for the AWS S3 bucket

**bucketName** (optional): AWS S3 bucket to be used by deeploy

###### Monitoring

The Deeploy Monitoring feature sends anonimized usage data back to Deeploy. This helps us to improve the product.

**enabled**: boolean. Whether to opt in for the Monitoring feature.

**credentials.username**: username for the monitoring feature

**credentials.password**: password for the monitoring feature

##### 2. Install

1. Deploy the Deeploy stack using
    ```
    $ helm install -f ./helm/values.yml deeploy ./helm/deeploy --namespace deeploy
    ```

    **Important**: This might print out the following line. This is expected behavior and not a bug:
    ```
    manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
    ```

2. Add the s3 secret to the default service account:
    ```
    $ kubectl edit sa default -n deeploy
    ```
    and add the `s3-secret` name
    ```
    secrets:
    - name: default-...
    - name: s3-secret
    ```
    Close and save.

Create first admin user.

## Troubelshooting

### `Permission Denied` errors on GKE

When running on GKE (Google Kubernetes Engine), you may encounter a ‘permission denied’ error when creating some of the resources. This is a nuance of the way GKE handles RBAC and IAM permissions, and as such you should ‘elevate’ your own privileges to that of a ‘cluster-admin’ before running the above commands. If you have already run the above commands, you should run them again after elevating your permissions.

## FAQ
