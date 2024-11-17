# Template: https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template

# Monitoring config
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
    password: 'password' # default admin in LLDAP
    encryption: 'simple_tls'
    verify_certificates: false
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
      cert: '-----BEGIN CERTIFICATE----- <REDACTED> -----END CERTIFICATE -----'
      key: '-----BEGIN PRIVATE KEY----- <REDACTED> -----END PRIVATE KEY -----'    
EOS


# Optimizations
registry['enable'] = false
mattermost['enable'] = false
gitlab_pages['enable'] = false
gitlab_kas['enable'] = false