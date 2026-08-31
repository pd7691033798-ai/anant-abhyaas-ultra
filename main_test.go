package main

import "testing"

func TestAutonomousHealthCheckRepairsTamperedLedger(t *testing.T) {
	app := &AnantAbhyaasUltra{
		BlockchainLedger:   make([]AuditBlock, 0),
		PendingApproval:    make(map[string]string),
		RemediationLogs:    make([]RemediationEvent, 0),
		QuarantinedThreats: make([]QuarantinedThreat, 0),
	}

	genesis := app.AddAuditLog("GENESIS: test system initialized")
	app.Lock()
	app.TrustedGenesis = genesis
	app.Unlock()
	app.AddAuditLog("valid activity")

	app.Lock()
	app.BlockchainLedger[1].ActivityData = "unauthorized mutation"
	app.Unlock()

	app.runAutonomousHealthCheck()

	app.Lock()
	defer app.Unlock()
	if len(app.RemediationLogs) != 1 {
		t.Fatalf("expected one remediation event, got %d", len(app.RemediationLogs))
	}
	if len(app.QuarantinedThreats) != 1 {
		t.Fatalf("expected one quarantined threat, got %d", len(app.QuarantinedThreats))
	}
	if app.SystemHealth != "AUTO_HEALED_THREAT_QUARANTINED" {
		t.Fatalf("unexpected health state: %s", app.SystemHealth)
	}
	if ok, reason := app.validateBlockchainLocked(); !ok {
		t.Fatalf("repaired ledger is invalid: %s", reason)
	}
	if app.RemediationLogs[0].RestoredGenesisHash != genesis.Hash {
		t.Fatal("remediation did not report the trusted genesis hash")
	}

}
