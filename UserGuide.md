# GraphHopper Foot/Run API User Guide

This guide covers how to **use** your GraphHopper instance day-to-day — from API requests to testing profiles. It assumes you’ve already built and served the graph with `./import.sh` and `./serve.sh` as described in the README.

---

## 1. Server Overview

Your instance runs at:
```
https://map.chouinard.me
```
Port 8989 is exposed internally, and HTTPS is handled by nginx + certbot.

---

## 2. Available Profiles

Use `/info` to list active profiles:

```bash
curl -s https://map.chouinard.me/info | python3 -m json.tool | grep '"name"'
```
Expected output:
```
"name": "foot"
"name": "run"
```

- **foot** — Walking profile (default OSM behavior).
- **run** — Custom profile tuned for runners at 10 km/h with surface, trail, and gradient preferences.

---

## 3. Routing API

### Basic route
Send two or more `point` parameters (lat,lon order):

```bash
curl -s 'https://map.chouinard.me/route?profile=run&point=38.5816,-121.4944&point=38.5758,-121.4789'   | python3 -m json.tool | head
```

### With multiple waypoints
```bash
curl -s 'https://map.chouinard.me/route?profile=run&point=38.5816,-121.4944&point=38.5793,-121.4892&point=38.5758,-121.4789'   | python3 -m json.tool | head
```

### Optional parameters
| Parameter | Description | Example |
|------------|-------------|----------|
| `profile` | Which routing profile to use (`foot`, `run`, etc.) | `profile=run` |
| `points_encoded` | Return polyline as raw lat/lon pairs | `points_encoded=false` |
| `ch.disable` | Disable Contraction Hierarchies (for custom testing) | `ch.disable=true` |
| `instructions` | Include turn-by-turn instructions | `instructions=true` |

Example with decoded geometry:
```bash
curl -s 'https://map.chouinard.me/route?profile=run&point=38.58,-121.49&point=38.57,-121.48&points_encoded=false'   | jq -r '.paths[0].points.coordinates[] | @csv'
```

---

## 4. Isochrone API (Reachability)

Use this to map how far a runner can go in a set time (seconds).

```bash
curl -s 'https://map.chouinard.me/isochrone?profile=run&type=geojson&point=38.58,-121.49&time_limit=1200&buckets=3'   -o isochrone-run-20m.geojson
```

- `time_limit` = seconds (1200 = 20 minutes).
- `buckets` = number of nested contours.
- Output is standard GeoJSON.

You can drag the `.geojson` file into [geojson.io](https://geojson.io) to visualize it.

---

## 5. Testing a Temporary Custom Model

For experimentation, you can POST a new model *without rebuilding* (useful for testing different running speeds):

```bash
curl -s -X POST 'https://map.chouinard.me/route?ch.disable=true'   -H 'Content-Type: application/json'   -d '{
    "profile": "run",
    "points": [[38.5816,-121.4944],[38.5758,-121.4789]],
    "custom_model": {
      "speed": [{"if": "true", "limit_to": 11.0}]
    }
  }' | python3 -m json.tool | head
```

The request bypasses the CH cache, runs the modified model once, and returns a JSON result.

---

## 6. Common Errors

| Error | Meaning / Fix |
|-------|----------------|
| `Point is out of bounds` | The coordinate is outside your imported region. Use `/info` to check the bounding box. |
| `Unknown profile: run` | Graph wasn’t re-imported after adding the profile. Run `rm -rf graph-cache && ./import.sh && ./serve.sh`. |
| `Cannot load custom_model` | `custom_models` directory not mounted or filename mismatch. Check `config.yml` and `serve.sh`. |
| `Invalid JSON` | Usually an HTML error page (nginx misroute or wrong URL). Check `docker logs graphhopper`. |

---

## 7. Monitoring and Logs

See what’s happening inside the container:

```bash
docker logs -f graphhopper
```
Stop/start cleanly:
```bash
./serve.sh
docker stop graphhopper
```

---

## 8. Example Workflow (Daily Use)

1. Start your server:
   ```bash
   ./serve.sh
   ```
2. Open in browser:
   ```
   https://map.chouinard.me/maps/?profile=run&point=38.58,-121.49&point=38.57,-121.48
   ```
3. Export GPX from UI or fetch via API to feed into your workout app.

If you modify profiles or surfaces:
```bash
rm -rf graph-cache
./import.sh
./serve.sh
```

---

## 9. Backup and Maintenance

- **Graph cache**: can always be rebuilt; no need to back up.
- **Config and models**: back up `config/config.yml` and everything in `custom_models/`.
- **TLS certificates**: auto-renewed by Certbot (check with `sudo certbot renew --dry-run`).

---

### Final Notes

Your `run` profile models a 10 km/h average with surface and trail weighting tuned for real-world running conditions. It’s a fast, low-maintenance setup — perfect for both route planning and isochrone analysis.
