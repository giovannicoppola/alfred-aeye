# Vendored package pins

| Package | Upstream | Tag | Commit |
|---------|----------|-----|--------|
| cursor-usage | https://github.com/javaisbetterthanpython/cursor-usage | v0.2.0 | `9238796932e8cc1a6f91bf45d20feb374b77846a` |
| claude-monitor | https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor | v4.0.0 | `c59a83bf943f329f0e61f1a29c760353ee1860a5` |

Local patches on top of the pin:

- `claude-monitor` `output/api_usage.py`: treat OAuth `utilization` as a 0–100 percentage (not a 0–1 fraction), and prefer the structured `limits[].percent` fields when present. Without this, weekly `utilization: 1.0` (1%) was shown as 100%.

Refresh:

```bash
# re-clone into /tmp, rsync into vendor/, then:
./scripts/bootstrap_lib.sh
./scripts/build_workflow.sh
```
