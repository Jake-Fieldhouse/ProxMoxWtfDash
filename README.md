# ProxMoxWtfDash
Dash for automatically consolidating addresses and service links for a Proxmox host.

Install on your Proxmox host with:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Jake-Fieldhouse/ProxMoxWtfDash/main/install.sh) [hostname]
```

Replace `[hostname]` with your desired hostname (default `wtf`). For example:

```bash
install.sh myhost
```

The dashboard will then be available at `http://[hostname]-proxmoxdash.hosted.jke:8750` and at `http://<lan-ip>:8750`.

## License

This project is licensed under the terms of the [MIT License](LICENSE).
