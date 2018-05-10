{%- from "keystone/map.jinja" import client with context %}
{%- if client.enabled %}

{%- for server_name, server in client.get('server', {}).iteritems() %}

{%- if server.admin.get('api_version', '3') == '3' %}
{%- set version = "/v3" %}
{%- endif %}
{%- if server.admin.get('api_version', '3') == '2' %}
{%- set version = "/v2.0" %}
{%- endif %}
{%- if server.admin.get('api_version', '3') == '' %}
{%- set version = "" %}
{%- endif %}


{%- if server.admin.get('protocol', 'http') == 'http' %}
{%- set protocol = 'http' %}
{%- else %}
{%- set protocol = 'https' %}
{%- endif %}

{%- if server.admin.token is defined %}
{%- set connection_args = {'endpoint': protocol+'://'+server.admin.host+':'+server.admin.port|string+version,
                           'token': server.admin.token} %}
{%- else %}
{%- set connection_args = {'auth_url': protocol+'://'+server.admin.host+':'+server.admin.port|string+version,
                           'tenant': server.admin.project,
                           'user': server.admin.user,
                           'password': server.admin.password} %}
{%- endif %}

{%- if server.roles is defined %}

keystone_{{ server_name }}_roles:
  keystoneng.role_present:
  - names: {{ server.roles }}
  {%- if server.admin.token is defined %}
  - connection_token: {{ connection_args.token }}
  - connection_endpoint: {{ connection_args.endpoint }}
  {%- else %}
  - connection_user: {{ connection_args.user }}
  - profile: admin_identity
  - connection_password: {{ connection_args.password }}
  - connection_tenant: {{ connection_args.tenant }}
  - connection_auth_url: {{ connection_args.auth_url }}
  {%- endif %}

{%- endif %}

{% for service_name, service in server.get('service', {}).iteritems() %}

keystone_{{ server_name }}_service_{{ service_name }}:
  keystoneng.service_present:
  - name: {{ service_name }}
  - service_type: {{ service.type }}
  - description: {{ service.description }}
  {%- if server.admin.token is defined %}
  - connection_token: {{ connection_args.token }}
  - connection_endpoint: {{ connection_args.endpoint }}
  {%- else %}
  - connection_user: {{ connection_args.user }}
  - profile: admin_identity
  - connection_password: {{ connection_args.password }}
  - connection_tenant: {{ connection_args.tenant }}
  - connection_auth_url: {{ connection_args.auth_url }}
  {%- endif %}

{%- for endpoint in service.get('endpoints', ()) %}

{%- set public_port = "" %}
{%- set public_port = ':'+endpoint.public_port|string if not (endpoint.get('public_protocol', 'http') == 'https' and endpoint.public_port|int == 443) %}
{%- set internal_port = "" %}
{%- set internal_port = ':'+endpoint.internal_port|string if not (endpoint.get('internal_protocol', 'http') == 'https' and endpoint.internal_port|int == 443) %}
{%- set admin_port = "" %}
{%- set admin_port = ':'+endpoint.admin_port|string if not (endpoint.get('admin_protocol', 'http') == 'https' and endpoint.admin_port|int == 443) %}
{%- set endpoint_urls = {
    'public': endpoint.get('public_protocol', 'http')+'://'+endpoint.public_address+public_port+endpoint.public_path,
    'internal': endpoint.get('internal_protocol', 'http')+'://'+endpoint.internal_address+internal_port+endpoint.internal_path,
    'admin': endpoint.get('admin_protocol', 'http')+'://'+endpoint.admin_address+admin_port+endpoint.admin_path
    } %}

{%- if version == '2'  %}
keystone_{{ server_name }}_service_{{ service_name }}_endpoint_{{ endpoint.region }}:
  keystoneng.endpoint_present:
  - name: {{ service_name }}
  - publicurl: '{{ endpoint_urls.public }}'
  - internalurl: '{{ endpoint_urls.internal }}'
  - adminurl: '{{ endpoint_urls.admin }}'
  - region: {{ endpoint.region }}
  - require:
    - keystoneng: keystone_{{ server_name }}_service_{{ service_name }}
  {%- if server.admin.token is defined %}
  - connection_token: {{ connection_args.token }}
  - connection_endpoint: {{ connection_args.endpoint }}
  {%- else %}
  - connection_user: {{ connection_args.user }}
  - connection_password: {{ connection_args.password }}
  - connection_tenant: {{ connection_args.tenant }}
  - connection_auth_url: {{ connection_args.auth_url }}
  {%- endif %}
{%- else %}
{%- for interface, url in endpoint_urls.iteritems() %}
keystone_{{ server_name }}_service_{{ service_name }}_endpoint_{{ endpoint.region }}_{{ interface }}:
  keystoneng.endpoint_present:
  - name: {{ service_name }}
  - url: {{ url }}
  - interface: {{ interface }}
  - region: {{ endpoint.region }}
  - require:
    - keystoneng: keystone_{{ server_name }}_service_{{ service_name }}
  {%- if server.admin.token is defined %}
  - connection_token: {{ connection_args.token }}
  - connection_endpoint: {{ connection_args.endpoint }}
  {%- else %}
  - connection_user: {{ connection_args.user }}
  - connection_password: {{ connection_args.password }}
  - profile: admin_identity
  - connection_tenant: {{ connection_args.tenant }}
  - connection_auth_url: {{ connection_args.auth_url }}
  {%- endif %}
{%- endfor %}
{%- endif %}

{%- endfor %}

{%- endfor %}

{%- for tenant_name, tenant in server.get('project', {}).iteritems() %}

keystone_{{ server_name }}_tenant_{{ tenant_name }}:
  keystoneng.tenant_present:
  - name: {{ tenant_name }}
  {%- if tenant.description is defined %}
  - description: {{ tenant.description }}
  {%- endif %}
  {%- if server.admin.token is defined %}
  - connection_token: {{ connection_args.token }}
  - connection_endpoint: {{ connection_args.endpoint }}
  {%- else %}
  - connection_user: {{ connection_args.user }}
  - profile: admin_identity
  - connection_password: {{ connection_args.password }}
  - connection_tenant: {{ connection_args.tenant }}
  - connection_auth_url: {{ connection_args.auth_url }}
  {%- endif %}

{%- if tenant.quota is defined and tenant.quota is mapping %}

keystone_{{ server_name }}_tenant_{{ tenant_name }}_quota:
  novang.quota_present:
    - profile: {{ server_name }}
    - tenant_name: {{ tenant_name }}
    {%- for quota_name, quota_value in tenant.quota.iteritems() %}
    - {{ quota_name }}: {{ quota_value }}
    {%- endfor %}
    - require:
      - keystoneng: keystone_{{ server_name }}_tenant_{{ tenant_name }}

{%- endif %}

{%- for user_name, user in tenant.get('user', {}).iteritems() %}

keystone_{{ server_name }}_tenant_{{ tenant_name }}_user_{{ user_name }}:
  keystoneng.user_present:
  - name: {{ user_name }}
  - password: {{ user.password }}
  {%- if user.email is defined %}
  - email: {{ user.email }}
  {%- endif %}
  - tenant: {{ tenant_name }}
  - domain: {{ user.get('domain', 'default') }}
  - roles:
      "{{ tenant_name }}":
        {%- if user.get('is_admin', False) %}
        - admin
        {%- elif user.get('roles', False) %}
        {{ user.roles }}
        {%- else %}
        - Member
        {%- endif %}
  - require:
    - keystoneng: keystone_{{ server_name }}_tenant_{{ tenant_name }}
    - keystoneng: keystone_{{ server_name }}_roles
  {%- if server.admin.token is defined %}
  - connection_token: {{ connection_args.token }}
  - connection_endpoint: {{ connection_args.endpoint }}
  {%- else %}
  - connection_user: {{ connection_args.user }}
  - profile: admin_identity
  - connection_password: {{ connection_args.password }}
  - connection_tenant: {{ connection_args.tenant }}
  - connection_auth_url: {{ connection_args.auth_url }}
  {%- endif %}

{%- endfor %}

{%- endfor %}

{%- endfor %}

{%- endif %}
