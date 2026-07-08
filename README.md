# Ryan's Steps

## The Quickstart

Assumptions:
- POC / Non-prod
- Podman (v4+)
- Ubuntu
- CloudNativePG NKP Catalog App Deployed
- Deploying to an empty NKP Workload cluster (no service using the traefik's root [`/`] route.)
> Note: Generally recommend bringing your own ingress controller outside of NKP's default Traefik instance as that's used for NKP Platform apps
- NKP Project created

Typical "don't use some random strangers github code" disclaimer. Double check what gets deployed. As of 7/7/26, the Dockerfile assumed in this has no vulnerabilities image.

Ensure you have java installed
```bash
sudo apt install openjdk-17-jdk
```

And JAVA_HOME path set with optional podman socket exposed
```bash
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> ~/.bashrc
```

Podman configurations
```
# Point to podman.sock
export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock

# Save to profile for future logins
echo 'export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"'  >> ~/.bashrc

# Enable and start the Podman API socket for the current user
systemctl --user enable --now podman.socket

# Verify the socket is now active and listening
systemctl --user status podman.socket

# Enable user lingering to prevent the socket from stopping after logout
loginctl enable-linger $(whoami)

# Verify the socket file now exists
ls -la /run/user/$(id -u)/podman/podman.sock
```

Build and retag the container
```bash
HARBOR_IP="10.38.48.51:5000"
HARBOR_PROJECT="demo"
./mvnw spring-boot:build-image -DskipTests
podman tag docker.io/library/spring-petclinic:1.0.0 ${HARBOR_IP}/${HARBOR_PROJECT}/petclinic:1.0.0
```

Be sure you're logged into your registry
```bash
podman login ${HARBOR_IP} --tls-verify=false
```

Push to your registry.
```bash
podman push ${HARBOR_IP}/${HARBOR_PROJECT}/petclinic:1.0.0 --tls-verify=false
```

Edit the `k8s/kustomization.yaml` file with your unique values (image name, namespace, ingress fqdn, etc)
> Note: If no fqdn available, optionally you can use a fake one (ex: pet-clinic.local), and update your /etc/hosts file to point the IP address to it. Ingress controller uses the host header for routing purposes.

Git Commit, and add the repo to an NKP Project's CI/CD.

To confirm deployment:
```bash
NAMESPACE="pet-clinic" # Should match your Project's namespace

watch kubectl get cluster,pod,svc,deploy,pvc,ing -n ${NAMESPACE}
```

## Remote debugging (JDWP) — optional / demos

### Toggle on/off with Kustomize

In `k8s/kustomization.yaml`, comment out **only the first** `patches` entry
(the `components/remote-debug/patch.yaml` one) to disable. Keep a **single**
`patches:` list — duplicate `patches:`.

```yaml
patches:
  - path: components/remote-debug/patch.yaml   # comment this block to disable
    target:
      kind: Deployment
      name: petclinic
  - target:
      kind: Ingress
      ...
```

Verify the patch reached the cluster before attaching:

```bash
kubectl get deploy petclinic -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].env}' | grep jdwp
kubectl logs -n ${NAMESPACE} deploy/petclinic | grep -i 'Listening for transport'
```

Once confirmed, port-forward in either two different terminals or send them both as background processes (`ps` / `kill <pid>` later):

```bash
kubectl port-forward -n ${NAMESPACE} deploy/petclinic 5005:5005 --insecure-skip-tls-verify &
kubectl port-forward -n ${NAMESPACE} deploy/petclinic 8080:8080 --insecure-skip-tls-verify &
```

In VS Code / Cursor: **Run and Debug → "Attach to Petclinic (K8s)"**.

**If attach hangs on "Importing projects"** (JDWP/`jdb` already work — this is IDE-only):

1. Open the **`spring-petclinic` folder** as the workspace root (not the parent `git` folder).
2. Select the pom.xml file and you should be prompted about importing in the JAVA project.
3. If stuck, run **Java: Clean Java Language Server Workspace** → Reload Window → import again.
4. Attach once port-forward is running (5005).
5. Drop a break point (Recommendation: WelcomeController.java file, line 31, to modify the Welcome messaging in memory on the fly)

Browse locally at `http://localhost:8080` (8080 forward) or via ingress (example: `petclinic.local`, which can be faked by updated your /etc/hosts if you don't have a fqdn).

## Pro Tips:

To force flux to take most recent change without waiting on the polling cycle:
```
alias forceflux='flux reconcile source git petclinic -n ${NAMESPACE} && flux reconcile kustomization petclinic -n ${NAMESPACE}'
```

# ORIGINAL PETCLINIC README BELOW

# Spring PetClinic Sample Application [![Build Status](https://github.com/spring-projects/spring-petclinic/actions/workflows/maven-build.yml/badge.svg)](https://github.com/spring-projects/spring-petclinic/actions/workflows/maven-build.yml)[![Build Status](https://github.com/spring-projects/spring-petclinic/actions/workflows/gradle-build.yml/badge.svg)](https://github.com/spring-projects/spring-petclinic/actions/workflows/gradle-build.yml)

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/spring-projects/spring-petclinic) [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=7517918)

## Understanding the Spring Petclinic application with a few diagrams

See the presentation here:  
[Spring Petclinic Sample Application (legacy slides)](https://speakerdeck.com/michaelisvy/spring-petclinic-sample-application?slide=20)

> **Note:** These slides refer to a legacy, pre–Spring Boot version of Petclinic and may not reflect the current Spring Boot–based implementation.  
> For up-to-date information, please refer to this repository and its documentation.


## Run Petclinic locally

Spring Petclinic is a [Spring Boot](https://spring.io/guides/gs/spring-boot) application built using [Maven](https://spring.io/guides/gs/maven/) or [Gradle](https://spring.io/guides/gs/gradle/).
Java 17 or later is required for the build, and the application can run with Java 17 or newer.

You first need to clone the project locally:

```bash
git clone https://github.com/spring-projects/spring-petclinic.git
cd spring-petclinic
```
If you are using Maven, you can start the application on the command-line as follows:

```bash
./mvnw spring-boot:run
```
With Gradle, the command is as follows:

```bash
./gradlew bootRun
```

You can then access the Petclinic at <http://localhost:8080/>.

<img width="1042" alt="petclinic-screenshot" src="https://cloud.githubusercontent.com/assets/838318/19727082/2aee6d6c-9b8e-11e6-81fe-e889a5ddfded.png">

You can, of course, run Petclinic in your favorite IDE.
See below for more details.

## Building a Container

There is no `Dockerfile` in this project. You can build a container image (if you have a docker daemon) using the Spring Boot build plugin:

## Running the Container Image

```bash
./mvnw spring-boot:build-image
docker images | grep petclinic
docker run -p 8080:8080 docker.io/library/spring-petclinic:latest
```

## In case you find a bug/suggested improvement for Spring Petclinic

Our issue tracker is available [here](https://github.com/spring-projects/spring-petclinic/issues).

## Database configuration

In its default configuration, Petclinic uses an in-memory database (H2) which
gets populated at startup with data. The h2 console is exposed at `http://localhost:8080/h2-console`,
and it is possible to inspect the content of the database using the `jdbc:h2:mem:<uuid>` URL. The UUID is printed at startup to the console.

A similar setup is provided for MySQL and PostgreSQL if a persistent database configuration is needed. Note that whenever the database type changes, the app needs to run with a different profile: `spring.profiles.active=mysql` for MySQL or `spring.profiles.active=postgres` for PostgreSQL. See the [Spring Boot documentation](https://docs.spring.io/spring-boot/how-to/properties-and-configuration.html#howto.properties-and-configuration.set-active-spring-profiles) for more detail on how to set the active profile.

You can start MySQL or PostgreSQL locally with whatever installer works for your OS or use docker:

```bash
docker run -e MYSQL_USER=petclinic -e MYSQL_PASSWORD=petclinic -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=petclinic -p 3306:3306 mysql:9.7
```

or

```bash
docker run -e POSTGRES_USER=petclinic -e POSTGRES_PASSWORD=petclinic -e POSTGRES_DB=petclinic -p 5432:5432 postgres:18.4
```

Further documentation is provided for [MySQL](https://github.com/spring-projects/spring-petclinic/blob/main/src/main/resources/db/mysql/petclinic_db_setup_mysql.txt)
and [PostgreSQL](https://github.com/spring-projects/spring-petclinic/blob/main/src/main/resources/db/postgres/petclinic_db_setup_postgres.txt).

Instead of vanilla `docker` you can also use the provided `docker-compose.yml` file to start the database containers. Each one has a service named after the Spring profile:

```bash
docker compose up mysql
```

or

```bash
docker compose up postgres
```

## Test Applications

At development time we recommend you use the test applications set up as `main()` methods in `PetClinicIntegrationTests` (using the default H2 database and also adding Spring Boot Devtools), `MySqlTestApplication` and `PostgresIntegrationTests`. These are set up so that you can run the apps in your IDE to get fast feedback and also run the same classes as integration tests against the respective database. The MySql integration tests use Testcontainers to start the database in a Docker container, and the Postgres tests use Docker Compose to do the same thing.

## Compiling the CSS

There is a `petclinic.css` in `src/main/resources/static/resources/css`. It was generated from the `petclinic.scss` source, combined with the [Bootstrap](https://getbootstrap.com/) library. If you make changes to the `scss`, or upgrade Bootstrap, you will need to re-compile the CSS resources using the Maven profile "css", i.e. `./mvnw package -P css`. There is no build profile for Gradle to compile the CSS.

## Working with Petclinic in your IDE

### Prerequisites

The following items should be installed in your system:

- Java 17 or newer (full JDK, not a JRE)
- [Git command line tool](https://help.github.com/articles/set-up-git)
- Your preferred IDE
  - Eclipse with the m2e plugin. Note: when m2e is available, there is a m2 icon in `Help -> About` dialog. If m2e is
  not there, follow the installation process [here](https://www.eclipse.org/m2e/)
  - [Spring Tools Suite](https://spring.io/tools) (STS)
  - [IntelliJ IDEA](https://www.jetbrains.com/idea/)
  - [VS Code](https://code.visualstudio.com)

### Steps

1. On the command line run:

    ```bash
    git clone https://github.com/spring-projects/spring-petclinic.git
    ```

1. Inside Eclipse or STS:

    Open the project via `File -> Import -> Maven -> Existing Maven project`, then select the root directory of the cloned repo.

    Then either build on the command line `./mvnw generate-resources` or use the Eclipse launcher (right-click on project and `Run As -> Maven install`) to generate the CSS. Run the application's main method by right-clicking on it and choosing `Run As -> Java Application`.

1. Inside IntelliJ IDEA:

    In the main menu, choose `File -> Open` and select the Petclinic [pom.xml](pom.xml). Click on the `Open` button.

    - CSS files are generated from the Maven build. You can build them on the command line `./mvnw generate-resources` or right-click on the `spring-petclinic` project then `Maven -> Generates sources and Update Folders`.

    - A run configuration named `PetClinicApplication` should have been created for you if you're using a recent Ultimate version. Otherwise, run the application by right-clicking on the `PetClinicApplication` main class and choosing `Run 'PetClinicApplication'`.

1. Navigate to the Petclinic

    Visit [http://localhost:8080](http://localhost:8080) in your browser.

## Looking for something in particular?

|Spring Boot Configuration | Class or Java property files  |
|--------------------------|---|
|The Main Class | [PetClinicApplication](https://github.com/spring-projects/spring-petclinic/blob/main/src/main/java/org/springframework/samples/petclinic/PetClinicApplication.java) |
|Properties Files | [application.properties](https://github.com/spring-projects/spring-petclinic/blob/main/src/main/resources) |
|Caching | [CacheConfiguration](https://github.com/spring-projects/spring-petclinic/blob/main/src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java) |

## Interesting Spring Petclinic branches and forks

The Spring Petclinic "main" branch in the [spring-projects](https://github.com/spring-projects/spring-petclinic)
GitHub org is the "canonical" implementation based on Spring Boot and Thymeleaf. There are
[quite a few forks](https://spring-petclinic.github.io/docs/forks.html) in the GitHub org
[spring-petclinic](https://github.com/spring-petclinic). If you are interested in using a different technology stack to implement the Pet Clinic, please join the community there.

## Interaction with other open-source projects

One of the best parts about working on the Spring Petclinic application is that we have the opportunity to work in direct contact with many Open Source projects. We found bugs/suggested improvements on various topics such as Spring, Spring Data, Bean Validation and even Eclipse! In many cases, they've been fixed/implemented in just a few days.
Here is a list of them:

| Name | Issue |
|------|-------|
| Spring JDBC: simplify usage of NamedParameterJdbcTemplate | [SPR-10256](https://github.com/spring-projects/spring-framework/issues/14889) and [SPR-10257](https://github.com/spring-projects/spring-framework/issues/14890) |
| Bean Validation / Hibernate Validator: simplify Maven dependencies and backward compatibility |[HV-790](https://hibernate.atlassian.net/browse/HV-790) and [HV-792](https://hibernate.atlassian.net/browse/HV-792) |
| Spring Data: provide more flexibility when working with JPQL queries | [DATAJPA-292](https://github.com/spring-projects/spring-data-jpa/issues/704) |

## Contributing

The [issue tracker](https://github.com/spring-projects/spring-petclinic/issues) is the preferred channel for bug reports, feature requests and submitting pull requests.

For pull requests, editor preferences are available in the [editor config](.editorconfig) for easy use in common text editors. Read more and download plugins at <https://editorconfig.org>. All commits must include a __Signed-off-by__ trailer at the end of each commit message to indicate that the contributor agrees to the Developer Certificate of Origin.
For additional details, please refer to the blog post [Hello DCO, Goodbye CLA: Simplifying Contributions to Spring](https://spring.io/blog/2025/01/06/hello-dco-goodbye-cla-simplifying-contributions-to-spring).

## License

The Spring PetClinic sample application is released under version 2.0 of the [Apache License](https://www.apache.org/licenses/LICENSE-2.0).
