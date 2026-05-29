# SAP Azure→GCP Cutover Runbook

## Pre-cutover checklist

- [ ] GCP greenfield SAP shell installed (playbooks 04–07 complete)
- [ ] Pacemaker cluster healthy (`pcs status` on any cluster node)
- [ ] HSR configured and replicating (if applicable pre-import)
- [ ] System copy import complete (playbook 10)
- [ ] SAP services started on GCP (`sapcontrol -function GetProcessList`)
- [ ] Functional smoke test passed in GCP isolated network
- [ ] DNS TTL lowered to 300s at least 24h before cutover
- [ ] Stakeholder sign-off recorded in change ticket

## Cutover steps (playbook 11)

1. **Validate HANA** — Confirm all HANA processes GREEN on primary node
2. **Validate Pacemaker** — No failed resources; VIPs on correct nodes
3. **Update /etc/hosts** — All GCP nodes point VIP hostnames to internal IPs
4. **Update DNS** — Point `{{ sap_sid | lower }}.{{ sap_domain }}` to GCP NW VIP
5. **Smoke test** — Run `sapcontrol -function GetSystemInstanceList`
6. **Application test** — Execute agreed transaction (e.g. SM50, VA01 in QA)

## Rollback plan

If cutover fails within maintenance window:

1. Revert DNS to Azure VIP/load balancer
2. Start SAP services on Azure (reverse stop order)
3. Stop GCP SAP services to prevent split-brain
4. Document failure in change ticket; do **not** run playbook 12

## Post-cutover (24–72 hours)

- Monitor SAP SM21, HANA trace, Pacemaker logs
- Verify backup jobs on GCP (Backint / native HANA backup)
- After stability period, run playbook 12 with approval to decommission Azure

## Emergency contacts

| Role | Contact |
|------|---------|
| SAP Basis lead | TBD |
| Cloud platform (GCP) | TBD |
| Network / DNS | TBD |
| Change manager | TBD |
