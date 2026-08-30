# Running on Replit

This repository is a standalone Go console application that records audit events in a SHA-256-linked ledger and simulates cloud tasks with concurrent workers.

## Run

Use the configured **Start application** workflow, or run:

```bash
go run main.go
```

The program prints its boot status, creates a genesis audit record, logs four simulated cloud tasks, and exits after all workers complete.