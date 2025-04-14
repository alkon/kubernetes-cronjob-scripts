# QuakeWatch

**QuakeWatch** is a Flask-based web application that monitors and displays earthquake data. It leverages Kubernetes to ensure high **scalability**, **availability**, resilience, and efficient management of the application and its related components.

## 1. Kubernetes Cluster Setup

### a. Set up Kubernetes cluster using Docker Desktop

#### Goal

- To establish a local Kubernetes environment for development and testing using Docker Desktop's integrated single-node Kubernetes cluster.
---
#### Steps
-  **Install Docker Desktop:** Download and install Docker Desktop from the official Docker website.
-  **Enable Kubernetes:** In Docker Desktop's settings, navigate to the "Kubernetes" tab and check the "Enable Kubernetes" box.
---
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
---
#### Key Manifests

- `pod.yaml` – Specifies details like the Docker image (`alkon100/quakewatch-web:2.0.1`) and the Pod's name (`quakewatch-web-pod`).
---

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
---
## 2. Basic Kubernetes Resources

### a. Exposing the app extrernally using a Kubernetes Service

#### Goal

- To provide a stable external IP address and distribute incoming traffic across the QuakeWatch application pods, ensuring high availability and accessibility.
---
#### Steps

-  **Define the Service Manifest:** Create `svc.yaml` that defines a Kubernetes `Service` of type `LoadBalancer`.
-  **Specify Selectors:** Configure the `selector` field in the Service manifest to target the pod `app: quakewatch-web`.
-  **Define Port Mapping:** Specify the port mapping, indicating that traffic arriving at a specific `port=5011` on the LoadBalancer should be automatically forwarded to the `targetPort=5000` on the app containers.
-  **Apply the Manifest:** Create the LoadBalancer Service in your Kubernetes cluster.
```bash
   kubectl apply -f svc.yaml 
```
---
#### Key Manifests
- `svc.yaml` – Defines the `quakewatch-web-svc` LoadBalancer service.
- `pod.yaml` – Specifies details like the Docker image and the Pod's name
---
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
---
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
---
#### Key Manifests

- `dpl.yaml` – Defines the `quakewatch-web-dpl` Deployment.
- `svc.yaml` – Defines the `quakewatch-web-svc` LoadBalancer service. 
  - **Note**: The Service targets the Pods based on the labels defined in the Deployment's Pod template. So for now, the Pod's manifest is unrelevent and the `pod.yaml` is not listed here. 
---
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
---
### c. 📈 HPA (Horizontal Pod Autoscaler) Based on CPU Usage

#### Goal

- Implement HPA in combination with a simulated CPU load generator.
- Demonstrate **scalability** and **auto-recovery**.
---
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
---  
#### Key Manifests

- `hpa.yaml` – Defines the scaling policy for the target Deployment based on CPU utilization (for test purposes)
- `crj.yaml` (its `cpu-burst-cronjob` part) – Simulates CPU load on a schedule.
- `dpl.yaml` The target Deployment for the HPA (`cpu-load-generator-dpl`) 

#### How It Works 

- For test env a `CronJob` named `cpu-burst-cronjob` runs every minute.
- It triggers a short burst of CPU stress using `stress-ng`.
- The `HPA` named `cpu-load-hpa` monitors the average CPU utilization of the Deployment named `cpu-load-generator-dpl`.
- When the average CPU utilization exceeds **50%**, HPA automatically increases the number of pod replicas (up to a maximum of 5).
- It scales back down automatically as the CPU load drops.
- The tested CPU resource `requests/limits` are defined in the `dpl.yaml` to take scale advantages for higher-level environments (staging and prod)
---
#### Verification
-  **Monitor HPA Status:** Observe the HPA's status to see its current state
```bash
    kubectl get hpa cpu-load-hpa -w
```
- The `TARGETS` column shows the current CPU utilization percentage of the `quakewatch-web-dpl` Pods. 
- The `REPLICAS` column shows the current number of Pods managed by the HPA. 
- The `REPLICAS` should increase and decrease over time as the CPU load simulation runs.


-  **Monitor Pod Count:** Track the number of app Pods to see the scaling in action:
 ```bash
    kubectl get pods -w -l app=quakewatch-web
 ```
 - If the CPU utilization goes above the target (50%) new `quakewatch-web-dpl` Pods created. 
 - When CPU utilization drops, the Pods termination begins.
---

### 3. Advanced Kubernetes Concepts

#### a. Use ConfigMaps and Secrets to Manage Configuration
#### b. Set up Kubernetes CronJobs to automate periodic tasks 

#### Goal
- a. To externalize application configuration from container images, enhancing **scalability** and **manageability**. ConfigMaps handle non-sensitive configuration, while Secrets securely manage sensitive information.
- b. To **automate** recurring tasks (i.e., daily logging) using CronJobs
---
#### Steps
- **Apply Manifests Sequentially:** To ensure Kubernetes resources are created in the correct order, especially when dependencies exist, apply the manifests in the following sequence:

```bash
  kubectl apply -f cfg.yaml   # ConfigMaps
  kubectl apply -f scrt.yaml  # Secrets
  kubectl apply -f pvc.yaml   # PersistentVolumeClaim
  kubectl apply -f dpl.yaml   # Deployment
  kubectl apply -f svc.yaml   # Service
  kubectl apply -f pod.yaml   # Inspector(debug) Pod
  kubectl apply -f hpa.yaml   # HorizontalPodAutoscaler
  kubectl apply -f crj.yaml   # CronJobs 
```
---
#### How It Works

- **Log path configuration** is stored in `log-paths-cfm`, injected as the `SHARED_LOG_PATH` environment variable.
- **Logging script** (`quake-log.sh`) is stored as a `ConfigMap` and used by a dedicated container within the `log-extreme-quakes` CronJob to log quake data.
- **Access token** used for accessing external resources is stored in a `Secret` (`quake-log-token`) and securely mounted into the logging container at runtime.
- A shared **PersistentVolumeClaim** (`quake-logs-pvc`) provides persistent storage, allowing the `quake-logger` CronJob to write log files that can be inspected later by other Pods (like the application or the `quake-log-reader-pod`).
- The `log-extreme-quakes` **CronJob** is configured to run daily at 15:00 (as defined by the `schedule: "* 15 * * *"`). It executes a Pod with a container (`quake-logger`) that runs the `quake-log.sh` script. This script writes the earthquake logs to the `/logs` directory within its container.
- The `/logs` directory in the `quake-logger` container is mounted to the `quake-logs-pvc` using the `volumes` and `volumeMounts` definitions. This ensures that the logs are written to the persistent volume.
- Inspector(debug) pod `quake-log-reader-pod` helps to verify the logs written to the shared PersistentVolumeClaim by mounting the same `quake-logs-pvc`.
---
#### Key Manifests
- cfg.yaml:
  - `log-paths-cfm` – defines shared log path
  - `log-script-cfm` – contains the logging shell script
- scrt.yaml:
  - `quake-log-token` – stores sensitive token as a secret
- dpl.yaml
  - `quakewatch-web-dpl` – mounts and injects above configs
- pvc.yaml
  - `quake-logs-pvc` – shared volume for log data
- pod.yaml
  - `quake-log-reader-pod` - debug pod to check the logs mounted
- crj.yaml
  - `log-extreme-quakes` - cronjob to schedules the daily execution of the `quake-logger` container to fetch and write extreme earthquake logs to the persistent volume. 
---
#### Verification
- View the logs written to the shared volume using debug pod:
```bash
   kubectl exec -it quake-log-reader-pod -- sh 
```
```sh
   cat /mnt/logs/*.log
```

### c. Implement Liveness Probe for Application Health Checks

#### Goal
- To automatically detect and restart unhealthy instances of the QuakeWatch application, improving **availability** and **resilience**.
---
#### Steps

-  **Define Liveness Probe in Deployment:** In the `quakewatch-web-dpl.yaml` manifest, a `livenessProbe` is defined within the `quakewatch-web-container` specification.
-  **Configure HTTP Get Probe:** The probe uses an `httpGet` action to check the health of the application by sending a GET request to the `/health` endpoint on port `5000`.
-  **Set Probe Parameters:**
    - `initialDelaySeconds: 30`: Specifies the number of seconds to wait after the container has started before the first probe is initiated. This allows the application some time to start up.
    - `periodSeconds: 20`: Defines how often (in seconds) the kubelet will perform the probe.
-  **Apply Deployment Manifest:** Ensure the Deployment with the liveness probe configuration is applied to the cluster:
    ```bash
    kubectl apply -f dpl.yaml
    ```
-  **Simulate Application Failure:** To observe the liveness probe in action, temporarily enable the `failure-simulator` sidecar container in the `quakewatch-web-dpl` (dpl.yaml) by setting the `enabled` key in the `failure-config` ConfigMap to `"true"` and reapplying the Deployment:
    ```bash
    kubectl apply -f cfm.yaml
    kubectl apply -f dpl.yaml
    ```
    This sidecar is configured to terminate the main application container after 60 seconds if the `FAILURE_MODE` environment variable is set to `"true"`.
---
#### Key Manifests
- `dpl.yaml` – Defines the `quakewatch-web-dpl` Deployment, including the `livenessProbe` configuration for the `quakewatch-web-container`.
- `cfm.yaml` – Contains the `failure-config` ConfigMap, used (optionally) to simulate application failures for testing the liveness probe.
---
#### Verification
- **Monitor Pod Status:** Observe the status of your application Pods. If the liveness probe detects a failure, the kubelet will restart the container, and you might see the `RESTARTS` count increase:
    ```bash
    kubectl get pods -w -l app=quakewatch-web
    ```

- **If Failure Simulation Enabled**, observe Pod Restarts: after waiting for apprx 60 seconds. 
  - The `STATUS` of the `quakewatch-web-dpl` Pods transition, and the `RESTARTS` column for the `quakewatch-web-container` should increment.
-  **Describe the Pod:** Get detailed information about a specific Pod to see the liveness probe's status and any recent events:
    ```bash
    kubectl describe pod <quakewatch-web-pod-name>
    ```
    - In the `Liveness` section check the probe's configuration. Also, see the `Events` section for any "Killing" and "Created container" events related to the liveness probe.
---

### d. Implement Readiness Probe for Traffic Management

#### Goal
- To ensure that application instances are only considered ready to receive traffic when they are fully initialized and healthy, improving the reliability of service interactions.
---
#### Steps
- **Define Readiness Probe in Deployment:** In the `quakewatch-web-dpl.yaml` manifest, add a `readinessProbe` within the `quakewatch-web-container` specification.
- **Configure TCP Socket Probe:** The readiness probe will use a `tcpSocket` action to check if the application is listening on port `5050` (after modification). This indicates that the main application process is ready to accept connections.
- **Set Probe Parameters:**
    - `initialDelaySeconds: 45`: Specifies the number of seconds to wait after the container has started before the first probe is initiated. This allows for a longer initial startup period if needed.
    - `periodSeconds: 15`: Defines how often (in seconds) the kubelet will perform the probe.
- **Implement Readiness Check Logic (Implicit):** In this TCP-based probe, the application itself doesn't need explicit readiness check logic in the `/health` endpoint. As long as the Flask development server is listening on port `5050`, the probe will succeed.
- **Simulate Unready State:** To observe the readiness probe in action, modify the `failure-config` ConfigMap to use a different value for the `enabled` key (e.g., `"unready"`). Then, update your application (if you choose to implement this logic) to stop listening on port `5050` or listen on a different port when `FAILURE_MODE` is set to `"unready"`. Reapply the Deployment and ConfigMap:
```bash
   kubectl apply -f cfm.yaml
   kubectl apply -f dpl.yaml
 ```
---
#### Key Manifests
- **`dpl.yaml`** – Defines the `quakewatch-web-dpl` Deployment, including the `readinessProbe` configuration for the `quakewatch-web-container` using a TCP socket on port `5050` (instead of `5000`).
- **`cfm.yaml`** – Contains the `failure-config` ConfigMap, used (optionally) to simulate an unready state by potentially influencing the port the application listens on.
---
#### Verification
- **Monitor Pod Readiness:** Observe the `READY` column in the `kubectl get pods` output. Initially, the Pod might show `0/2` or `1/2` ready (if the sidecar starts faster). Once the readiness probe on port `5050` succeeds, it should become `2/2` or `1/1` (depending on whether you are observing a single container or both).
```bash
   kubectl get pods -w -l app=quakewatch-web
```
- **Check Application is Not Listening on Port `5050`:** If going to simulate an unready state, ensure first that the app is not listening on port `5050`. If not included in port list, it will be OK to use it to simulate TCP probe failure
```bash
   kubectl exec <pod-name> -c quakewatch-web-container -- netstat -tuln | grep 5050
```
- **Expected Output:** No output should be returned, indicating the app is not listening on port `5050`.
- **(Simulating Unready State) Observe Pod Not Ready:** If `failure-config` modified to simulate an unready state (e.g., by listening on port `5050`), the `READY` column remains at `0/2` or `0/1` for the affected Pods.
- **Describe the Pod:** Get detailed info about a specific Pod to see the readiness probe's status and any recent events.
  - *Expected Output:* Check `Readiness` section, which will show the probe's configuration and the results of recent checks. Events related to the readiness probe failing or succeeding will also be visible.
```bash
   kubectl describe pod <quakewatch-web-pod-name>
```

- **Check Service Endpoints:** Before a Pod is ready, it should not be included in the endpoints of any Service that selects it. After the readiness probe succeeds, the Pod's IP address should appear in the Service's endpoints.
  - *Expected Output:* Observe when the IP address of `quakewatch-web-dpl` Pod appears in the `ENDPOINTS` list after the Pod starts. If unready state is simulated, the Pod's IP should disappear from the endpoints.
```bash
   kubectl get endpoints quakewatch-web-svc -w
```

