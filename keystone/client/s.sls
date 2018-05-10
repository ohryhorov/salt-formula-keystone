{%- from "keystone/map.jinja" import client with context %}

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

{%- for tenant_name, tenant in server.get('project', {}).iteritems() %}
keystone_{{ server_name }}_tenant_{{ tenant_name }}:
  keystoneng.tenant_present:
  - name: {{ tenant_name }}
  - description: 
  - profile: admin_identity
  - connection_user: {{ connection_args.user }}
  - connection_password: {{ connection_args.password }}
  - connection_tenant: {{ connection_args.tenant }}
  - connection_auth_url: {{ connection_args.auth_url }}

{% endfor %}
{% endfor %}
