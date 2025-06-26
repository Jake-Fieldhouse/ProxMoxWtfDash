#!/usr/bin/env python3
import os
import json
import subprocess
from flask import Flask, render_template_string
from proxmoxer import ProxmoxAPI

TOKEN_FILE = os.path.expanduser('~/.wtf-proxmoxdash_tokens')


def load_tokens():
    if not os.path.exists(TOKEN_FILE):
        return []
    with open(TOKEN_FILE) as f:
        return [l.strip() for l in f if l.strip()]


def select_token(tokens):
    if not tokens:
        tok = input('Enter Proxmox API token user@pam!token=value: ').strip()
        os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
        with open(TOKEN_FILE, 'w') as f:
            f.write(tok + '\n')
        return tok
    if len(tokens) == 1:
        return tokens[0]
    for i, t in enumerate(tokens, 1):
        print(f'{i}) {t.split("=")[0]}')
    idx = input('Select token [1]: ').strip() or '1'
    return tokens[int(idx) - 1]


def get_proxmox():
    token = select_token(load_tokens())
    usertoken, secret = token.split('=')
    user, token_name = usertoken.split('!')
    return ProxmoxAPI('localhost', user=user, token_name=token_name, token_value=secret, verify_ssl=False)


def tailscale_info():
    try:
        data = json.loads(subprocess.check_output(['tailscale', 'status', '--json']))
        self = data.get('Self', {})
        return self.get('TailscaleIPs', []), self.get('DNSName', '')
    except Exception:
        return [], ''


def vm_status(px, node, vmtype, vmid):
    info = px.nodes(node).__getattr__(vmtype)(vmid).status.current.get()
    ips = []
    if 'ip-addresses' in info:
        ips = info['ip-addresses']
    elif isinstance(info.get('ip'), list):
        ips = info.get('ip')
    elif info.get('ip'):
        ips = [info.get('ip')]
    return info.get('status', 'unknown'), ips


app = Flask(__name__)


@app.route('/')
def index():
    px = get_proxmox()
    nodes = px.nodes.get()
    node = nodes[0]['node'] if nodes else 'localhost'
    ts_ips, ts_name = tailscale_info()
    items = []

    host_stat = px.nodes(node).status.get()
    items.append({'name': f'Host {node}',
                  'vmid': '',
                  'status': host_stat.get('status', 'unknown'),
                  'ips': ts_ips,
                  'ts': ts_name,
                  'ssh': f'ssh root@{ts_name}' if ts_name else '',
                  'web': f'https://{node}:8006'})

    for vm in px.nodes(node).qemu.get():
        stat, ips = vm_status(px, node, 'qemu', vm['vmid'])
        items.append({'name': vm.get('name', 'vm' + str(vm['vmid'])),
                      'vmid': vm['vmid'],
                      'status': stat,
                      'ips': ips,
                      'ts': '',
                      'ssh': f'ssh root@{ips[0]}' if ips else '',
                      'web': ''})

    for ct in px.nodes(node).lxc.get():
        stat, ips = vm_status(px, node, 'lxc', ct['vmid'])
        items.append({'name': ct.get('name', 'ct' + str(ct['vmid'])),
                      'vmid': ct['vmid'],
                      'status': stat,
                      'ips': ips,
                      'ts': '',
                      'ssh': f'ssh root@{ips[0]}' if ips else '',
                      'web': ''})

    html = '''<html>
    <head>
      <meta http-equiv="refresh" content="30">
      <style>
        table{border-collapse:collapse;}
        th,td{border:1px solid #666;padding:4px;}
      </style>
      <script>function copy(t){navigator.clipboard.writeText(t);}</script>
    </head>
    <body>
    <h1>wtf-proxmoxdash</h1>
    <table>
    <tr><th>Name</th><th>VMID</th><th>Status</th><th>IPs</th><th>Tailscale</th><th>SSH</th><th>Web</th></tr>
    {% for i in items %}
    <tr style="background-color:{{'lightgreen' if i.status=='running' else 'lightcoral'}}">
      <td>{{i.name}}</td>
      <td>{{i.vmid}}</td>
      <td>{{i.status}}</td>
      <td>{{', '.join(i.ips)}}</td>
      <td>{{i.ts}}</td>
      <td>{% if i.ssh %}<button onclick="copy('{{i.ssh}}')">copy ssh</button>{% endif %}</td>
      <td>{% if i.web %}<a href="{{i.web}}" target="_blank">web</a>{% endif %}</td>
    </tr>
    {% endfor %}
    </table>
    </body>
    </html>'''
    return render_template_string(html, items=items)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8750)

