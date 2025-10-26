# GraphHopper 11.0 — Foot (Running) Starter

A minimal, repeatable setup for **GraphHopper 11** tuned for running routes using the **built-in `foot.json`** custom model. Import once, then serve. Two small scripts keep it consistent.

## Folder layout
```
/srv/graphhopper
├── bin/                     # graphhopper-web.jar symlink -> graphhopper-web-11.0.jar
├── config/                  # config.yml (points to built-in foot.json)
├── custom_models/           # optional custom models; DO NOT place foot.json here (collides with built-in)
├── data/                    # put your region extract here as region.osm.pbf
├── graph-cache/             # generated graph/CH; delete to re-import
├── import.sh                # one-button import
└── serve.sh                 # one-button server
```

## Requirements
- Docker (user in `docker` group)
- `curl`, `python3` (for quick tests)
- OSM extract at `data/region.osm.pbf` (rename your PBF or change `config.yml`)

## Config (key bits)
`config/config.yml` should contain:
```yaml
graphhopper:
  datareader.file: /data/region.osm.pbf
  graph.location: /graph-cache
  import.osm.ignored_highways: []      # keep explicit; nothing ignored for foot

  profiles:
    - name: foot
      custom_model_files: [foot.json]  # use the built-in model

  profiles_ch:
    - profile: foot
  profiles_lm: []

  # v11 requires these when using the built-in foot model
  graph.encoded_values: road_class, road_class_link, road_environment, max_speed, road_access, foot_access, foot_average_speed, hike_rating, country, foot_road_access, mtb_rating, surface, track_type, foot_priority

server:
  application_connectors:
    - type: http
      port: 8989
      bind_host: 0.0.0.0
  admin_connectors:
    - type: http
      port: 8990
      bind_host: 0.0.0.0

logging:
  level: INFO
  appenders:
    - type: console
      time_zone: UTC
      log_format: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
```

> Note: `hike_rating` is the numeric version of OSM’s `sac_scale`. Do **not** declare `sac_scale` in v11.

## Getting the jar
We keep binaries out of git. Use the helper and a stable symlink:
```bash
bin/get-gh.sh 11.0
# creates bin/graphhopper-web-11.0.jar and symlink bin/graphhopper-web.jar
```

## Build the graph (import)
```bash
./import.sh
```
- Wipes `graph-cache/`, then runs:
  ```
  java -Xms2g -Xmx4g -jar bin/graphhopper-web.jar import config/config.yml
  ```
- Expect logs: *importing OSM file → creating graph → preparing CH for profile foot (1/1)*  
- `graph-cache/` fills with: `edges`, `nodes`, `geometry`, `location_index`, `shortcuts_foot`, `nodes_ch_foot`, etc.

## Serve the API
```bash
./serve.sh
```
- Runs GH with:
  ```
  java -Xms2g -Xmx4g -jar bin/graphhopper-web.jar server config/config.yml
  ```

## Smoke tests (local)
```bash
curl -s http://localhost:8989/health
curl -s http://localhost:8989/info | python3 -m json.tool | head
curl -s 'http://localhost:8989/route?profile=foot&point=38.5816,-121.4944&point=38.5758,-121.4789' \
  | python3 -m json.tool | head
```

## Nginx (TLS proxy, light rate limit)
Create `/etc/nginx/sites-available/map.chouinard.me`:
```nginx
upstream graphhopper { server 127.0.0.1:8989; keepalive 32; }

server {
  listen 80;
  server_name map.chouinard.me;
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  server_name map.chouinard.me;

  ssl_certificate     /etc/letsencrypt/live/map.chouinard.me/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/map.chouinard.me/privkey.pem;

  location ~ ^/(route|isochrone|map-matching|spt|nearest|info|health) {
    limit_req zone=gh_api burst=20 nodelay;
    add_header Cache-Control "no-store";
    proxy_pass http://graphhopper;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_request_buffering off;
    proxy_buffering off;
    proxy_read_timeout 300s;
  }

  location / {
    proxy_pass http://graphhopper;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_read_timeout 300s;
  }
}
```

Global rate-limit zone (required at `http{}` level):
```
/etc/nginx/conf.d/ratelimit.conf
--------------------------------
limit_req_zone $binary_remote_addr zone=gh_api:10m rate=10r/s;
```

Enable + reload:
```bash
sudo ln -sf /etc/nginx/sites-available/map.chouinard.me /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Certbot (Cloudflare DNS-only/gray is fine):
```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d map.chouinard.me
```

If you later flip Cloudflare to **proxied**, add a Cache Rule **Bypass** for:
```
/route* /isochrone* /map-matching* /spt* /nearest* /info /health
```

## Re-import rules
Any time you change:
- `profiles` / `custom_model_files`
- `graph.encoded_values`
- `profiles_ch` / `profiles_lm`

→ You **must** delete `graph-cache/` and re-run `./import.sh`, then `./serve.sh`.

## Troubleshooting quick hits
- **`Unknown encoded value: X`** → Add `X` to `graph.encoded_values` or remove the rule that references it. v11’s built-in `foot.json` needs `foot_priority`, `foot_road_access`.
- **`Custom model file name 'foot.json' is already used`** → Don’t store a local `custom_models/foot.json`. Use the built-in (or rename yours, e.g., `run_foot.json`).
- **Empty `graph-cache/` after import** → You didn’t actually run `import` (or volumes not mounted). Use the scripts; they mount `/data`, `/graph-cache`.
- **Permission issues deleting cache** → Fix ownership once: `sudo chown -R $USER:$USER /srv/graphhopper`.

## Test URLs
Local:
```
http://localhost:8989/health
http://localhost:8989/info
http://localhost:8989/maps/?point=38.5816,-121.4944&point=38.5758,-121.4789&profile=foot
```
Through nginx:
```
https://map.chouinard.me/health
https://map.chouinard.me/info
```

