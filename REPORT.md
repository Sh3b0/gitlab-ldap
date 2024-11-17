# SSN Project - GitLab with LDAP Authentication and Monitoring

## Introduction

- [GitLab](https://about.gitlab.com/) is a platform for collaboration and version control that is open-source and can be [self-hosted](https://docs.gitlab.com/ee/install/docker/index.html).
  - It's highly configurable with extensive documentation and a wide-range of [security-related services](https://docs.gitlab.com/ee/user/application_security/secure_your_application.html), and thus is very popular among security-focused organizations.
  - It includes many features for:
    - Collaboration on remote git repositories
    - Powerful CI/CD pipeline system
    - Integration with a wide-range of tools and technologies
    - User and project management
- [Lightweight Directory Access Protocol (LDAP)](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol) is a a protocol for maintaining directory information services over a network.
  - A directory can be considered a lightweight database, often stored as a tree-like structure, optimized for small number of writes and many reads.
  - It contains structured information about users, systems, sub-networks, services, and/or applications in the network.
  - LDAP is commonly used as a central place of usernames, their passwords, and privileges, allowing applications or services to connect to LDAP and authenticate/authorize users.
  - To implement LDAP authentication system, one needs an LDAP server implementation (e.g., OpenLDAP). It's also common to use a GUI (e.g., phpLDAPadmin) for easier management and visualization.
- Integrating both tools together would make it easier for employees registered in LDAP to use unified credentials for getting access to different services in the infrastructure, making the authentication and authorization process more convenient.

## Methods

### Directory Access

- [Multiple](https://en.wikipedia.org/wiki/List_of_LDAP_software) LDAP server/client software exists, the following services were analyzed.
  - [osixia/openldap](https://github.com/osixia/docker-openldap) & [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin): popular server and web client based on OpenLDAP
    - **Pros:** popular and feature-rich with deployment options for docker/Kubernetes.
    - **Cons:** quite old and may not include the latest security patches/fixes.
  - [bitnami/openldap](https://hub.docker.com/r/bitnami/openldap): trusted OpenLDAP fork from VMWare.
    - **Pros:** actively maintained, highly configurable, and cloud-ready.
    - **Cons:** need to find additional GUI and deploy it alongside.  
  - [lldap/lldap](https://github.com/lldap/lldap): Lightweight implementation of LDAP
    - **Pros:** minimal server and nice-looking web client with a focus on authentication features
    - **Cons:** pre-configured with opinionated defaults and may not support advanced use-cases.
- LLDAP has shown effectiveness, ease of use, and suitability to our needs for this project.

### System Architecture

- Docker containers were used to quickly run interconnected services in an isolated network.
  - Containers are the industry standard for reproducibility and easy migration to the cloud.

- Docker compose allows to launch a container infrastructure in one command `docker compose up`

- Infrastructure is written as a `docker-compose.yaml` file to run the following services:

  - **LLDAP:** database and web server for admin to manage directory entries.
  - **GitLab:** platform to which developers authenticate and use.
  - **Grafana:** visualizes GitLab exported Prometheus metrics for monitoring.
  - **Nginx:** provides SSL termination to access internal services over HTTPS.

  ![architecture](https://i.postimg.cc/dtB306mL/architecture.png)

### Configuration

#### 1. Docker Compose

- Overall structure of the network of services

  ```yaml
  name: gitlab-ldap
  
  services:
    gitlab:
      image: gitlab/gitlab-ce:latest
      container_name: gitlab
      volumes:
        - ./conf/gitlab.rb:/etc/gitlab/gitlab.rb
        - gitlab_data:/var/opt/gitlab
      depends_on:
        - lldap
      restart: unless-stopped
  
    lldap:
      image: lldap/lldap:stable
      container_name: lldap
      volumes:
        - "lldap_data:/data"
        - "./certs:/certs"
      environment: ... # See below
  
    grafana:
      image: grafana/grafana:latest
      container_name: grafana
      volumes:
        - ./provisioning:/etc/grafana/provisioning
  
    nginx:
      image: nginx:latest
      container_name: nginx
      volumes:
        - ./conf/nginx.conf:/etc/nginx/nginx.conf:ro
        - ./certs:/etc/nginx/certs:ro
      ports:
        - "80:80"
        - "443:443"
  
  volumes:
    gitlab_data:
    lldap_data:
  ```

#### 2. LDAP

- Used environment variables to change defaults and enable LDAP over TLS

- Secret were generated from using a [bash script](https://github.com/lldap/lldap/blob/main/generate_secrets.sh) and read from a  `.env` file on the host.

  ```bash
  - TZ=Europe/Moscow
  - LLDAP_JWT_SECRET='${LLDAP_JWT_SECRET}'
  - LLDAP_KEY_SEED='${LLDAP_KEY_SEED}'
  - LLDAP_LDAP_BASE_DN=dc=example,dc=com
  - LLDAP_LDAPS_OPTIONS__ENABLED=true
  - LLDAP_LDAPS_OPTIONS__CERT_FILE=/certs/tls.crt
  - LLDAP_LDAPS_OPTIONS__KEY_FILE=/certs/tls.key
  ```

- A Distinguished Name (DN) is a unique identifier specifying the location of an entry in the directory.
  - Base DN is the starting point (root) in LDAP directory where searches are performed.
  - Bind DN specifies the LDAP user that services use to access LDAP and perform authentication.

#### 3. GitLab

- Referred to the [template](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template) to add relevant entries for configuring LDAPS connectivity, monitoring, and other settings. The file contained secrets and should not be pushed to version control without redaction.

  ```ruby
  # Monitoring config (using 0.0.0.0 only for local testing)
  gitlab_rails['monitoring_whitelist'] = ['0.0.0.0/0']
  prometheus['enable'] = true
  prometheus['listen_address'] = '0.0.0.0:9090'
  
  # LDAP config
  gitlab_rails['ldap_enabled'] = true
  gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'
    main:
      label: 'LDAP'
      host: 'lldap'
      port: 6360
      uid: 'user_id'
      base: 'ou=people,dc=example,dc=com'
      bind_dn: 'uid=admin,ou=people,dc=example,dc=com'
      password: '<ADMIN_PASSWORD>'
      encryption: 'simple_tls'
      verify_certificates: false # Disabled for local testing
      active_directory: false
      user_filter: ''
      attributes:
        username: 'uid'
        email: 'mail'
        name: 'displayName'
        first_name: 'givenName'
        last_name: 'sn'
      tls_options:
        ssl_version: 'TLSv1_2'
        cert: ...
        key: ...
  EOS
  
  # Disabling unused services
  registry['enable'] = false
  mattermost['enable'] = false
  gitlab_pages['enable'] = false
  gitlab_kas['enable'] = false
  ```

- Mounted `gitlab.rb` into the container for easier configuration from my host

- Run `gitlab-ctl reconfigure` to apply changes and `gitlab-rake gitlab:ldap:check` to check LDAPS connectivity:

  ![image-20241117191228786](/home/ahmed/.config/Typora/typora-user-images/image-20241117191228786.png)

#### 4. Grafana

- Provisioned datasources and dashboards from YAML files.

- Datasource `GitLab Omnibus` configures connection to the prometheus server exposed by GitLab

  ```yaml
  apiVersion: 1
  
  datasources:
    - name: GitLab Omnibus
      type: prometheus
      access: proxy
      url: http://gitlab:9090
  ```

- Dashboard folder specifies parameters when loading `.json` dashboards to show them in UI.

  ```yaml
  apiVersion: 1
  
  providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /etc/grafana/provisioning/dashboards
  ```

- Dashboards were obtained from [gitlab-org/grafana-dashboards](https://gitlab.com/gitlab-org/grafana-dashboards/-/tree/master/omnibus?ref_type=heads)

#### 5. Nginx

- Server `nginx.conf` to redirect HTTP communications to HTTPS for secure connection to web servers.

  ```nginx
  events { }
  
  http {
      # Redirect all HTTP traffic to HTTPS
      server {
          listen 80;
          server_name grafana.internal.test ldap.internal.test gitlab.internal.test;
  
          return 301 https://$host$request_uri;
      }
  
      # HTTPS configuration for Grafana
      server {
          listen 443 ssl;
          server_name grafana.internal.test;
          ssl_certificate /etc/nginx/certs/tls.crt;
          ssl_certificate_key /etc/nginx/certs/tls.key;
  
          location / {
              proxy_pass http://grafana:3000;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
      }
  
      # HTTPS configuration for LDAP
      server {
          listen 443 ssl;
          server_name ldap.internal.test;
          ...
      }
  
      # HTTPS configuration for GitLab
      server {
          listen 443 ssl;
          server_name gitlab.internal.test;
          ...
      }
  }
  
  ```

- Certificates were generated using [mkcert](https://github.com/FiloSottile/mkcert) then mounted into containers for usage in LDAPS and HTTPS access to web servers

  ```bash
  mkdir certs
  cd certs/
  mkcert "*.internal.test" # Generate certs
  mkcert -install          # Trust them in system and browsers
  ```

- Configured local hostnames at `/etc/hosts` for testing

  ```bash
  127.0.0.1       grafana.internal.test
  127.0.0.1       ldap.internal.test
  127.0.0.1       gitlab.internal.test
  ```

## Discussion (areas of improvement)

- **Secret management**
  - Hardcoding secrets in configuration files is a bad practice.
  - Placing them in environment may cause leakage.
  - Using a secret manager is the recommended practice
  - One can utilize docker secrets or a dedicated secret manager (e.g., Vault) to inject secrets into running containers to achieve a more secure setup.
  - It's also recommended to generate and periodically rotate strong passwords used to login to services (GitLab, LDAP, and Grafana in our case).
- **Access Control**
  - Any LDAP user may currently use their credentials to login to GitLab.
    - One may use the `user_filter` property to restrict access only to a certain LDAP group (e.g., `developers`)
  - Bind user (`admin`) used by GitLab for accessing LDAP has root access to the server.
    - It's recommended to use an account with less permissions
  - GitLab server is exposing monitoring metrics on all interfaces (`0.0.0.0`)
    - One should modify this to restrict monitoring only to applications that need access (Grafana container in our case).
- **Alerting**
  - For better observability, one may setup automated alerts in Grafana to report incidents to a certain contact point (e.g., Slack, MSTeams, Telegram, ...) for faster response.
- **Production server tweaking**
  - Nginx configuration used above is by no means intended for a production server.
  - Configuring best security and performance practices can get very difficult as Nginx is highly customizable. Organizations tend to reuse templates or delegate this functionality to cloud providers to avoid such overhead.

## References

- <https://docs.gitlab.com/ee/administration/auth/ldap/>
- <https://github.com/lldap/lldap>
- <https://grafana.com/docs/grafana/latest/administration/provisioning/>
- <https://nginx.org/en/docs/http/configuring_https_servers.html>
