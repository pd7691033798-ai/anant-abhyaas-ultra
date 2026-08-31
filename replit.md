# Running on Replit

This repository contains:

- A Go backend and command-center dashboard with a SHA-256-linked audit ledger, 39 directives, worker simulation, and admin API endpoints.
- A Flutter admin-vault client with biometric gating and a master-key blockchain handshake.

## Run

Use the configured **Project** workflow to start both apps. To run them individually:

```bash
go run main.go
```

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5000
```

The Go service listens on port `8080` by default, while the Flutter preview is available on port `5000`. The mobile client currently calls `http://localhost:8080/api/admin/handshake`; Android devices need a reachable backend address instead of device-localhost when used outside the local preview.