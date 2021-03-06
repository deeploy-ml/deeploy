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
      - [1. Configure the installation](#1-configure-the-installation)
      - [2. Install](#2-install)
- [Troubelshooting](#troubelshooting)
  - [`Permission Denied` errors on GKE](#permission-denied-errors-on-gke)
- [FAQ](#faq)

## Prerequisites

1. Kubernetes cluster version >=1.18.16, <1.19.0
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

2. `kubectl` installed. Due to [a performance issue applying deeply nested CRDs](https://github.com/kubernetes/kubernetes/issues/91615), please ensure that your `kubectl` version
fits into one of the following categories to ensure that you have the fix: `>=1.16.14,<1.17.0` or `>=1.17.11,<1.18.0` or `>=1.18.8`.
3. Helm v3 installed.
4. Postgres database for use by the microservices. The database should be reachable from the kubernetes nodes. Also, Deeploy currently requires the postgres user used by Deeploy to be a super user.
5. A (sub)domain which you control. In order to automatically generate TLS certificates using cert-manager, the DNS provider for this domain should be one of:
    - ACMEDNS
    - Akamai
    - AzureDNS
    - CloudFlare
    - Google
    - Route53
    - DigitalOcean
    - RFC2136
6. A remote storage bucket (Optional, see [Remote S3](#remote-s3)
    1. An AWS S3 bucket & AWS sericeaccount access keys with read/write access to the bucket.
    2. A Google Cloud Storage bucket & GCP serviceaccount with read/write access to the bucket.
7. An email server. The email server is required to send registration invitation to Deeploy. This is also used to create the initial admin account on Deeploy.

## Installation
### 1. Structure the database

On the AWS RDS Postgres database server, create a seperate database for every microservice that needs one. Currently, these databases are:

1. `deeploy`
2. `deeploy_kratos`

Make sure that the username and password for all of these databases are the same. The user should have all rights on the database.

### 2. Deploy the Deeploy stack

We assume that you now have the infrastructure as defined in [Prerequisites](#prerequisites). From here we continue deploying the Deeploy stack.
Make sure you are in the `deeploy` root folder.

Create all the Deeploy namespaces in kubernetes.
```bash
$ kubectl apply -f namespaces/
```

#### 1. Istio

> Current Istio installation instructions are based on `istio version 1.4.10` that should work on common cloud platforms. Always double check [platform specific installation requirements](https://istio.io/docs/setup/platform-setup/) and [the istio helm installation instructions](https://istio.io/docs/setup/install/helm/) to check the latest installation instructions.

**Installation steps:**

1. Download the Istio release:
    ```bash
    $ curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.4.10 sh -
    ```

2. Install Istio CRD's:
    ```bash
    $ for i in ./istio-1.4.10/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
    ```

3. Install Istio:
    ```bash
    $ # A lighter template, with just pilot/gateway.
    # Based on install/kubernetes/helm/istio/values-istio-minimal.yaml
    helm template --namespace=istio-system \
    -f ./istio/values.yaml \
    istio-1.4.10/install/kubernetes/helm/istio \
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

1. [Install cert-manager](https://cert-manager.io/docs/installation/kubernetes/#installing-with-helm).


2. (__Optional__) [Set up auto-renewal through ACME](https://cert-manager.io/docs/configuration/acme/). Only do this if you want to terminate TLS on this cluster. Make sure to generate two certificates as described above.

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
| `license.type` | The type of license. Either "AWS" or "DEEPLOY" | `"AWS"` |
| `license.deeployLicenseKey` | if the license type is "DEEPLOY", this is the supplied Deeploy license key | `""` |
| `license.availabilityZone` | if the license type is "AWS", this is the region where your cluster resides | `"eu-central-1"` |


__Deeploy Image Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `images.registry` | the registry to pull the Deeploy images from | `"709825985650.dkr.ecr.us-east-1.amazonaws.com/deeploy/"` |
| `images.path` | the path to the DeeployML registry | `"/deeploy"` |
| `images.tag` | the version tag of the deeploy deployment | same as application version |
| `images.username` | the username for the Docker registry | `""` |
| `images.password` | the password for the Docker registry | `""` |


__Deeploy Database Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `database.host` | the hostname of the database server | `""` |
| `database.port` | the port for use of the database server | `5432` |
| `database.username` | the username to access the database. **Note**: this user needs to be a superuser | `""` |
| `database.password` | the password to access the database server | `""` |


__Deeploy S3 Values:__

For S3 you have two options:
1. **Use a remote Storage repository (recommended)**. Deeploy currently supports AWS S3 & Google Cloud Storage
2. **Don't configure remote Storage (not recommended)**. Deeploy spawns an on-cluster S3 service.
    This is not recommended, as it does not make Deeploy stateless on the cluster. 
    If you do want to use it, set `minio.enabled` to true.

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

The Deeploy Monitoring feature sends anonimized usage data back to Deeploy. This helps us to improve the product.

| Parameter | Description | Default |
| --- | --- | --- |
| `monitoring.enabled` | whether to enable monitoring | `true` |
| `monitoring.credentials.username` | username for the monitoring server | `""` |
| `monitoring.credentials.password` | password for the monitoring server | `""` |


__Deeploy Security Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `security.tls.enabled` | whether to enable TLS | `true` |
| `security.adminCredentials.firstName` | first name of the main admin user | `""` |
| `security.adminCredentials.lastName` | last name of the main admin user | `""` |
| `security.adminCredentials.email` | email of the main admin user | `""` |
| `security.keyManagement.kms.keyId` | ID of a KMS key used to encrypt/decrypt | `""` |
| `security.keyManagement.kms.awsAccessKey` | IAM Access Key of an account that has access to the key | `""` |
| `security.keyManagement.kms.awsSecretKey` | IAM Secret Key of an account that has access to the key | `""` |

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

### Istio error

The current Istio version 1.3.8 could throw an error when using the commands above. Make sure to check this git hub isse: https://github.com/istio/istio/pull/22295 in that case.

## FAQ
