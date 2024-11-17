# gitlab-ldap

Configuring local GitLab server with LDAPS authentication and Grafana dashboards.

- Check [Report.md](./Report.md) for more details

## Overview

### Features

- [x] [GitLab-CE](https://hub.docker.com/r/gitlab/gitlab-ce) and [LLDAP](https://github.com/lldap/lldap) containers communicating over LDAPS (LDAP over TLS).
- [x] Provisioned Grafana [dashboards](https://gitlab.com/gitlab-org/grafana-dashboards/-/tree/master/omnibus?ref_type=heads) for monitoring GitLab-exported Prometheus metrics
- [x] Nginx config for enforcing HTTPS to web services.

### Screenshots

![gitlab-lldap](https://i.imgur.com/z2onzAg.png)

![grafana](https://i.imgur.com/BRDJWHN.png)

## Local testing

0. Clone project

   ```bash
   git clone https://github.com/sh3b0/gitlab-ldap
   cd gitlab-ldap
   ```

1. Create locally-trusted certs quickly with [mkcert](https://github.com/FiloSottile/mkcert)

   ```bash
   mkdir certs
   cd certs/
   mkcert "*.internal.test"
   mkcert -install
   
   # Shorter file names used in configs
   mv _wildcard.internal.test-key.pem tls.key
   mv _wildcard.internal.test.pem tls.crt
   ```

2. Update `/etc/hosts` with domains for internal services

   ```bash
   127.0.0.1       grafana.internal.test
   127.0.0.1       ldap.internal.test
   127.0.0.1       gitlab.internal.test
   ```

3. As per [docs](https://docs.gitlab.com/ee/administration/auth/ldap/#ssl-configuration-settings), you need to copy `tls.crt` and `tls.key` content into `./conf/gitlab.rb`.

   - Tweak other properties as desired [[template](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)]

     ```bash
     # conf/gitlab.rb:29
     ...
     tls_options:
       ssl_version: 'TLSv1_2'
       cert: '-----BEGIN CERTIFICATE----- <REDACTED> -----END CERTIFICATE -----'
       key: '-----BEGIN PRIVATE KEY----- <REDACTED> -----END PRIVATE KEY -----'
     ...
     
     # Update permissions for mounting into gitlab-ce container
     chmod root:root ./conf/gitlab.rb
     ```

4. Create secrets for LLDAP server

   ```bash
   ./scripts/generate_secrets.sh > .env
   ```

5. Run services with `docker compose`

   ```bash
   docker compose up -d
   ```

## References

- <https://docs.gitlab.com/ee/administration/auth/ldap/>
- <https://github.com/lldap/lldap>
- <https://grafana.com/docs/grafana/latest/administration/provisioning/>
- <https://nginx.org/en/docs/http/configuring_https_servers.html>
