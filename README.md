# QuakeWatch

**QuakeWatch** is a Flask-based web application that monitors and displays earthquake data. It leverages Kubernetes to ensure high **scalability**, **availability**, resilience, and efficient management of the application and its related components.

## 1. Kubernetes Cluster Setup

### a. Set up Kubernetes cluster using Docker Desktop

#### Goal

- To establish a local Kubernetes environment for development and testing using Docker Desktop's integrated single-node Kubernetes cluster.

#### Steps

-  **Install Docker Desktop:** Download and install Docker Desktop from the official Docker website.
-  **Enable Kubernetes:** In Docker Desktop's settings, navigate to the "Kubernetes" tab and check the "Enable Kubernetes" box.

### b. Deploy Dockerized app as Kubernetes Pod

#### Goal

- To run the QuakeWatch web application as a containerized app within a Kubernetes Pod. 
- **No** dealing with **networking** considered.

#### Steps

- Define the desired state of the application instance in a `pod.yaml`.
- Instruct Kubernetes to create this Pod:
  
```bash
  kubectl apply -f pod.yaml
```

#### Key Manifests

- `pod.yaml` – Specifies details like the Docker image (`alkon100/quakewatch-web:2.0.1`) and the Pod's name (`quakewatch-web-pod`).

#### Vertification

```bash
  kubectl get pods 
```
 - Shows the `quakewatch-web-pod` running and its details columns. 
 - The `STATUS` column may be:
   - **`Pending`:** The Pod has been created but its containers haven't been scheduled onto a node yet, or the images are being pulled.
   - **`Running`:** The Pod has been scheduled to a node, and all of its containers have been created and started. This is the desired state.
   - **`Succeeded`:** All containers in the Pod have terminated successfully and will not be restarted. This is not typical for long-running applications like web servers.
   - **`Failed`:** One or more containers in the Pod terminated with a non-zero exit code. Use `kubectl describe pod <pod-name>` to get more details about the failure.
   - **`Unknown`:** The state of the Pod could not be determined, typically due to a communication error with the kubelet on the node.

## 2. Basic Kubernetes Resources

### a. Exposing the app extrernally using a Kubernetes Service

#### Goal

- To provide a stable external IP address and distribute incoming traffic across the QuakeWatch application pods, ensuring high availability and accessibility.

#### Steps

-  **Define the Service Manifest:** Create `svc.yaml` that defines a Kubernetes `Service` of type `LoadBalancer`.
-  **Specify Selectors:** Configure the `selector` field in the Service manifest to target the pod `app: quakewatch-web`.
-  **Define Port Mapping:** Specify the port mapping, indicating that traffic arriving at a specific `port=5011` on the LoadBalancer should be automatically forwarded to the `targetPort=5000` on the app containers.
-  **Apply the Manifest:** Create the LoadBalancer Service in your Kubernetes cluster.
```bash
   kubectl apply -f svc.yaml 
```

#### Key Manifests
- `svc.yaml` – Defines the `quakewatch-web-svc` LoadBalancer service.
- `pod.yaml` – Specifies details like the Docker image and the Pod's name

#### Verifications
 
 ```bash
    kubectl get svc quakewatch-web-svc -w
 ```
- Retrieve details about the service and watch for changes
- Look for the `EXTERNAL-IP` column
---
 
```bash
   curl http://<EXTERNAL-IP>:5011
 ```
- Receive a HTML content response from the app on its root path.
---

### b. 🚀 Running Multiple Instances with a Deployment

#### Goal

- To ensure the app is highly **available** and can handle increased traffic(i.e., be **scalable**) by running multiple replicas of the QuakeWatch web application. Deployments also facilitate rolling updates and rollbacks.

#### Steps

-  **Define the Deployment Manifest:** Create `dpl.yaml` to define a Kubernetes `Deployment` named `quakewatch-web-dpl`.
-  **Specify Replicas:** In the `spec` section of the Deployment, set the `replicas` field to the desired number of application instances (e.g.,`2`).
-  **Define the Pod Selector:** Configure the `selector` field to specify how the Deployment identifies the Pods it manages (e.g., using the label `app: quakewatch-web` in `matchLabels`).
-  **Define the Pod Template:** Within the `template` section, define the specifications for the Pods that the Deployment will create and manage. This includes:
    - `metadata`: Labels to be applied to the Pods (must match the `selector`).
    - `spec`: The container specifications, such as the Docker image (`alkon100/quakewatch-web:2.0.1`), ports (`containerPort: 5000`)
- **Apply the Deployment Manifest**:
```bash
   kubectl apply -f dpl.yaml 
```

#### Key Manifests

- `dpl.yaml` – Defines the `quakewatch-web-dpl` Deployment.
- `svc.yaml` – Defines the `quakewatch-web-svc` LoadBalancer service. 
  - **Note**: The Service targets the Pods based on the labels defined in the Deployment's Pod template. So for now, the Pod's manifest is unrelevent and the `pod.yaml` is not listed here. 

#### Verifications
```bash
   kubectl get deployment quakewatch-web-dpl
```
- The READY column should match the DESIRED number of replicas
---
```bash
   kubectl get pods -l app=quakewatch-web
```
- Displays the number of Pods matching the replicas count 
- The pods STATUS should be `Running`

### c. 📈 HPA (Horizontal Pod Autoscaler) Based on CPU Usage

#### Goal

- Implement HPA in combination with a simulated CPU load generator.
- Demonstrate **scalability** and **auto-recovery**.

#### Steps
- **CPU resources management** addition:  `resources.requests.cpu:"100m"`
  and `resources.limits.cpu:"500m"` to `crj.yaml`(`stress-ng` container) and `dpl.yaml` (`quakewatch-web-container`)
  
   
-  ⚠️ **Deploy the Metrics Server:** Ensure the Kubernetes Metrics Server is installed in the cluster (for load tests).
```bash
   kubectl apply -f [https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml](https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml)
```
-  **Apply the HPA Manifest:** 
```bash
    kubectl apply -f hpa.yaml
```
-  **Apply the CPU Load Simulation (CronJob) Manifest:**
```bash
    kubectl apply -f crj.yaml
```
-  **Apply the Deployment Manifest:**
```bash
    kubectl apply -f dpl.yaml
```
    
#### Key Manifests

- `hpa.yaml` – Defines the scaling policy for the target Deployment based on CPU utilization (for test purposes)
- `crj.yaml` (its `cpu-burst-cronjob` part) – Simulates CPU load on a schedule.
- `dpl.yaml` The target Deployment for the HPA (`cpu-load-generator-dpl`) 

#### How It Works 

- For test env a `CronJob` named `cpu-burst-cronjob` runs every minute.
- It triggers a short burst of CPU stress using `stress-ng`.
- The `HPA` named `cpu-load-hpa` monitors the average CPU utilization of the Deployment named `cpu-load-generator-dpl`.
- When the average CPU utilization exceeds **50%**, HPA automatically increases the number of pod replicas (up to a maximum of 5).
- It scales back down automatically as the CPU load subsides.
---
- The tested CPU resource `requests/limits` are defined in the `dpl.yaml` to take scale advantages for higher-level environments (staging and prod)

#### Verification
-  **Monitor HPA Status:** Observe the HPA's status to see its current state
```bash
    kubectl get hpa cpu-load-hpa -w
```
- The `TARGETS` column shows the current CPU utilization percentage of the `quakewatch-web-dpl` Pods. 
- The `REPLICAS` column shows the current number of Pods managed by the HPA. 
- The `REPLICAS` should increase and decrease over time as the CPU load simulation runs.
---
-  **Monitor Pod Count:** Track the number of app Pods to see the scaling in action:
 ```bash
    kubectl get pods -w -l app=quakewatch-web
 ```
 - If the CPU utilization goes above the target (50%) new `quakewatch-web-dpl` Pods created. 
 - When CPU utilization drops, the Pods termination begins.

### 3. Advanced Kubernetes Concepts

#### a. Use ConfigMaps and Secrets to Manage Configuration

#### Goal:
- To externalize application configuration from container images, enhancing **scalability** and **manageability**. ConfigMaps handle non-sensitive configuration, while Secrets securely manage sensitive information.

#### How It Works

- **Log path configuration** is stored in `log-paths-cfm`, injected as the `SHARED_LOG_PATH` environment variable.
- **Feature toggle** for failure simulation is set via the `enabled` key in `failure-config`.
- **Logging script** (`quake-log.sh`) is stored as a `ConfigMap` and used by a sidecar to log quake data regularly.
- **Access token** used for auditing/debug purposes is stored in `Secret` (`quake-log-token`) and injected into the logging container at runtime.
- A shared **PersistentVolumeClaim** (`quake-logs-pvc`) enables both the app and the logger to read/write logs.

#### 🛠️ Key Manifests

- `log-paths-cfm.yaml` – defines shared log path.
- `failure-config.yaml` – toggles failure simulation logic.
- `log-script-cfm.yaml` – contains the logging shell script.
- `quake-log-token.yaml` – stores sensitive token as a secret.
- `quakewatch-web-dpl.yaml` – mounts and injects above configs.
- `quake-logs-pvc.yaml` – shared volume for log data.

---

