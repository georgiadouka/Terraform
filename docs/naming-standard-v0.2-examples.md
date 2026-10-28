# METLEN naming standard v0.2 – naming examples

Example names for each resource type, following
[METLEN_Azure_Naming_Standard_IaC_Working_Draft_v0.2.docx](../METLEN_Azure_Naming_Standard_IaC_Working_Draft_v0.2.docx)
as currently written. For the review of the standard, see
[naming-standard-v0.2-review.md](naming-standard-v0.2-review.md); for the
names the Terraform implementation generates, including codes agreed after
v0.2, see
[naming-standard-v0.2-implementation.md](naming-standard-v0.2-implementation.md).

## Example tokens

| Token | Value | Meaning |
|---|---|---|
| BU | `IT` | Business unit |
| DPT | `PPA` | Department |
| APP | `ECM` | Application / workload |
| ENV | `DEV` | Environment (DEV, UAT, PRD) |
| REG | `SWE` | Region code |
| NN | `00` | Instance sequence |

## Name formats

```text
Full:     M-AZU-<TYPE>-<BU>-<DPT>-<APP>-<ENV>-<REG>[-NN]
Network:  M-AZU-<TYPE>-<BU>-<DPT>-<APP>-<PUB|PRV>-<ENV>-<REG>[-NN]
Compact:  lowercase variants for resources where Azure does not allow the full format
```

## Examples

| Resource | Example | Length / Azure limit | Status in the standard |
|---|---|---|---|
| Subscription (display name) | `M-AZU-SBS-IT-PPA` | 16 / 64 | Confirmed |
| Resource Group | `M-AZU-RGP-IT-PPA-ECM-DEV-SWE` | 28 / 90 | Confirmed |
| Virtual Network | `M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE` | 32 / 64 | Working |
| Route Table | `M-AZU-UDR-IT-PPA-ECM-PRV-DEV-SWE` | 32 / 80 | Working |
| Network Security Group | `M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE` | 32 / 80 | Working |
| Subnet | `PPAECMDEVPRV01` | 14 / 80 | Validate |
| Storage Account | `mazusoaitppaecmdevswe00` | 23 / 24 | Working |
| Private Endpoint (storage blob) | `mazusoaitppaecmdevswe00-blob` | 28 / 64 | Validate |
| Key Vault (meeting pattern) | `M-AZU-KVA-IT-PPA-ECM-DEV-SWE-00` | **31 / 24 – invalid** | Conflict |
| Key Vault (compact) | `mazukvitppaecmdevswe00` | 22 / 24 | Proposed |
| SQL logical server | `m-azu-sql-it-ppa-ecm-dev-swe-00` | 31 / 63 | Proposed |
| SQL database | `M-AZU-SQL-IT-PPA-ECM-DEV-SWE` | 28 / 128 | Validate (server/database code undecided) |
| App Service | `M-AZU-APP-IT-PPA-ECM-DEV-SWE-00` | 31 / 60 | Working |
| App Service Plan | `M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00` | 31 / 60 | Working |
| Function App | `M-AZU-FUN-IT-PPA-ECM-DEV-SWE` | 28 / 60 | Working |
| Container App | `m-azu-cap-it-ppa-ecm-dev-swe-00` | 31 / 32 | Proposed |
| Container Apps Environment | `M-AZU-CEV-IT-PPA-ECM-DEV-SWE-00` | 31 / 60 | Validate |
| Load Balancer | `M-AZU-LBL-IT-PPA-ECM-DEV-SWE-00` | 31 / 80 | Working |
| Logic App | `M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00` | 31 / 43 (Consumption) | Working |
| Automation Account | `M-AZU-AAA-IT-PPA-ECM-DEV-SWE-00` | 31 / 50 | Working |
| AVD Host Pool | `M-AZU-HSP-IT-PPA-AVD-PRD-WEU-00` | 31 / 64 | Conflict |
| AVD Workspace | `M-AZU-WSP-IT-PPA-AVD-PRD-WEU-00` | 31 / 64 | Conflict |
| AVD Application Group | `M-AZU-APL-IT-PPA-AVD-PRD-WEU-00` | 31 / 64 | Conflict (APL or DAG) |
| Virtual Machine | — | — | Exception: separate server naming standard |

## Notes and interpretations

- **NN:** added only where the standard's catalogue shows it. Resource Group,
  NSG, Function App, SQL database and the network types have no NN in the
  examples.
- **PUB/PRV:** the standard only gives an NSG example. It is applied here to the
  VNet and Route Table as well, since they are in the same "network family";
  the standard does not yet list which types carry it.
- **Subnet:** follows the `DPTAPPENV<PUB|PRV>N` pattern without separators or
  BU, with the two-digit number from the naming register example
  `PPAECMDEVPRV01`.
- **Private Endpoint:** follows `<PARENTNAME>-<SERVICE>`.
- **AVD:** the standard's example `M-AZU-HSP-IT-AVD-PRD-WEU-00` omits DPT. DPT
  (`PPA`) is added here to match the full format, with `AVD` as the APP token.
  The examples use PRD and WEU, as in the standard.
- **Compact names:** Storage Account, Key Vault, SQL logical server and Container
  App cannot use the full uppercase format because of Azure character or length
  rules, so they use lowercase variants.
- **Global uniqueness:** Storage Account, Key Vault, SQL logical server and App
  Service names must be unique across Azure; the examples are not checked for
  availability.
