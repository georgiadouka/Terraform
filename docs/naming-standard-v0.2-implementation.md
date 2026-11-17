# METLEN naming standard v0.2 – requested vs implemented names

| Item | Value |
|---|---|
| Standard | [METLEN_Azure_Naming_Standard_IaC_Working_Draft_v0.2.docx](../METLEN_Azure_Naming_Standard_IaC_Working_Draft_v0.2.docx) (METLEN-AZU-NAM-STD-001, v0.2) |
| Naming register | [METLEN_Azure_Naming_Register_IaC_v0.2.xlsx](../METLEN_Azure_Naming_Register_IaC_v0.2.xlsx) (Resource Catalogue, Token Dictionary, Decision Log) |
| Implementation | [environments/metlenwithnaming](../environments/metlenwithnaming) (Terraform) |
| Status date | 28 October 2026 |
| Related | [Review of the standard](naming-standard-v0.2-review.md), [Naming examples](naming-standard-v0.2-examples.md) |

This document compares, for each Azure resource type, the name METLEN asks for
with the name the Terraform implementation generates and the name actually
deployed in a Microsoft test subscription. "Requested by METLEN" uses the
Representative Example from the register's Resource Catalogue where one exists,
otherwise the pattern from the standard.

## 1. Example tokens

| Token | Value | Source in Terraform |
|---|---|---|
| BU | `IT` | `naming_tokens.business_unit` |
| DPT | `PPA` | `naming_tokens.department` |
| APP | `ECM` | `naming_tokens.application` |
| ENV | `DEV` (DEV, UAT, PRD only) | `naming_tokens.environment` |
| REG | `SWE` | Derived from the Azure location (`swedencentral` → `SWE`); assumption, see 4.7 |
| NN | `00` | `sequence` on each resource (two digits) |

All token values must exist in the controlled dictionary
([locals.naming-dictionary.tf](../environments/metlenwithnaming/locals.naming-dictionary.tf));
`terraform plan` fails on any unknown value.

## 2. Match legend

| Status | Meaning |
|---|---|
| **Exact** | Identical to the register example (or the standard's example). |
| **As described** | No example exists; the implementation follows the pattern. |
| **Interpreted** | The standard leaves a detail open; the implementation makes a documented choice. |
| **Deviation** | The implementation differs from the example, with the reason stated. |
| **Working assumption** | The register has no code for the type; the code was agreed with the Microsoft partner and needs METLEN approval. |

## 3. Requested vs implemented names

| # | Resource | Register status | Requested by METLEN | Implemented (example) | Deployed in test subscription | Match |
|---|---|---|---|---|---|---|
| 1 | Subscription (display name) | CONFIRMED | `M-AZU-SBS-IT-PPA` | `M-AZU-SBS-IT-PPA` (output only) | — (not created by IaC) | Exact |
| 2 | Resource Group | CONFIRMED | `M-AZU-RGP-IT-PPA-ECM-DEV-SWE` | `M-AZU-RGP-IT-PPA-ECM-DEV-SWE` | `M-AZU-RGP-IT-PPA-ECM-DEV-SWE` | Exact |
| 3 | Virtual Network | WORKING | `M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE` | `M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE` | `M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE` | Exact |
| 4 | Network Security Group | WORKING | `M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE` | `M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE[-NN]` | `M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE-01`, `-02` | Exact (single NSG); NN added when several |
| 5 | Route Table | WORKING | `M-AZU-UDR-IT-PPA-ECM-PRV-DEV-SWE` | `M-AZU-UDR-IT-PPA-ECM-PRV-DEV-SWE[-NN]` | `M-AZU-UDR-IT-PPA-ECM-PRV-DEV-SWE` | Exact |
| 6 | Subnet | NEEDS DECISION | `PPAECMDEVPRV01` | `PPAECMDEVPRV01` … `PPAECMDEVPRV99` | `PPAECMDEVPRV1`, `2`, `3`, `4`, `8`, `9` ³ | Exact; number per subnet role (see 4.4) |
| 7 | Storage Account | WORKING | `mazusoaitppaecmdevswe00` | `mazusoaitppaecmdevswe00` | `mazusoaitppaecmdevswe01` ¹ | Exact |
| 8 | Storage Account – Premium Files | (Storage) | `mazusoa…NN` | `mazusoaitppaecmdevswe<NN>` | — | Exact (same family) |
| 9 | Storage Account – Function host | (Storage) | `mazusoa…NN` | `mazusoaitppaecmdevswe<NN>` | `mazusoaitppaecmdevswe02` | Exact (same family) |
| 10 | Key Vault | CONFLICT | `mazukvitppaecmdevswe00` (proposed compact) | `mazukvaitppaecmdevswe00` | `mazukvaitppaecmdevswe01` ¹ | Deviation: keeps code KVA (see 4.1) |
| 11 | Azure SQL logical server | CONFLICT | `m-azu-sql-it-ppa-ecm-dev-swe-00` | `m-azu-sql-it-ppa-ecm-dev-swe-00` | `m-azu-sql-it-ppa-ecm-dev-swe-01` ¹ | Exact |
| 12 | Azure SQL database | NEEDS DECISION | `M-AZU-SQL-IT-PPA-ECM-DEV-SWE` | Chosen by the application, e.g. `appdb` (default: entry key) | `M-AZU-SQL-IT-PPA-ECM-DEV-SWE-01` | Deviation: no convention by design (see 4.13) |
| 13 | Private Endpoint | NEEDS DECISION | `mazusoaitppaecmdevswe00-blob` | `<parent name>-<subresource>` | `mazusoaitppaecmdevswe01-blob`, `-file`; `mazukvaitppaecmdevswe01-vault`; `m-azu-sql-it-ppa-ecm-dev-swe-01-sqlserver`; `M-AZU-APP-IT-PPA-ECM-DEV-SWE-00-sites`; `M-AZU-FUN-IT-PPA-ECM-DEV-SWE-01-sites`; `mazusoaitppaecmdevswe02-blob/-file/-queue/-table` | Exact |
| 14 | App Service (Web App) | WORKING | `M-AZU-APP-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-APP-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-APP-IT-PPA-ECM-DEV-SWE-00` | Exact |
| 15 | App Service Plan | WORKING | `M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00` (web), `-01` (function) | `M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00`, `-01` | Exact |
| 16 | Function App | WORKING | `M-AZU-FUN-IT-PPA-ECM-DEV-SWE` (no NN) | `M-AZU-FUN-IT-PPA-ECM-DEV-SWE` (optional `-NN`) | `M-AZU-FUN-IT-PPA-ECM-DEV-SWE-01` ² | Exact; optional NN added (see 4.3) |
| 17 | Container App | CONFLICT | `m-azu-cap-it-ppa-ecm-dev-swe-00` | `m-azu-cap-it-ppa-ecm-dev-swe-00` | `m-azu-cap-it-ppa-ecm-dev-swe-00` | Exact |
| 18 | Container Apps Environment | NEEDS VALIDATION | `M-AZU-CEV-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-CEV-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-CEV-IT-PPA-ECM-DEV-SWE-00` | Exact; validated in Azure |
| 19 | Load Balancer | WORKING | `M-AZU-LBL-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-LBL-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-LBL-IT-PPA-ECM-DEV-SWE-00` | Exact |
| 20 | PostgreSQL Flexible server | Not in register | — | `m-azu-pgs-it-ppa-ecm-dev-swe-00` | `m-azu-pgs-it-ppa-geo-dev-swe-05` ⁴ | Working assumption (see 4.9) |
| 21 | PostgreSQL database | Not in register | — | Chosen by the application (default: entry key) | `Sales_Reporting` ⁴ | No convention by design (see 4.13) |
| 22 | MySQL Flexible server | Not in register | — | `m-azu-mys-it-ppa-ecm-dev-swe-00` | `m-azu-mys-it-ppa-geo-dev-swe-05` ⁴ | Working assumption (see 4.9) |
| 23 | MySQL database | Not in register | — | Chosen by the application, lowercase (default: entry key) | `sales_reporting` ⁴ | No convention by design (see 4.13) |
| 24 | Container Registry | Not in register | — | `mazuacritppaecmdevswe00` | — | Working assumption (see 4.10) |
| 25 | Cosmos DB account | Not in register | — | `m-azu-cdb-it-ppa-ecm-dev-swe-00` | `m-azu-cdb-it-ppa-geo-dev-swe-05` ⁴ | Working assumption (see 4.11) |
| 26 | Cosmos DB database and container | Not in register | — | Chosen by the application (default: entry key) | `catalog-db` / `products` ⁴ | No convention by design (see 4.13) |
| 27 | SQL Elastic Pool | Not in register | — | `M-AZU-SEL-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-SEL-IT-PPA-GEO-DEV-SWE-05` ⁴ | Code `SEL` agreed 2026-10-28; full family with the server's NN (see 4.12) |
| 28 | SQL Managed Instance | Not in register | — | `m-azu-smi-it-ppa-ecm-dev-swe-00` | — | Code `SMI` agreed 2026-10-28; lowercase variant (see 4.12) |
| 29 | NAT Gateway | Not in register | — | `M-AZU-NGW-IT-PPA-ECM-PRV-DEV-SWE-00` | `M-AZU-NGW-IT-PPA-GEO-DEV-SWE-05` ⁴ | Code `NGW` agreed 2026-10-28; network family with NN and the VNet's PUB/PRV since 2026-10-29 (see 4.12) |
| 30 | Public IP (NAT Gateway) | Not in register | — | `M-AZU-PIP-IT-PPA-ECM-PRV-DEV-SWE-00` | `M-AZU-PIP-IT-PPA-GEO-DEV-SWE-05` ⁴ | Code `PIP` agreed 2026-10-28; mirrors the NAT Gateway's name (see 4.12) |
| 31 | Log Analytics workspace | Not in register | — | `M-AZU-LAW-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-LAW-IT-PPA-GEO-DEV-SWE-05` ⁴ | Code `LAW` agreed 2026-10-28; full family with NN (see 4.12) |
| 32 | Application Insights | Not in register | — | `M-AZU-AIN-IT-PPA-ECM-DEV-SWE-00` | — | Code `AIN` agreed 2026-10-29; full family with NN (see 4.15) |
| 33 | Recovery Services vault | Not in register | — | `M-AZU-RSV-IT-PPA-ECM-DEV-SWE-00` | — | Code `RSV` agreed 2026-10-31; full family with NN (see 4.17) |
| 34 | Logic App (Standard) | WORKING | `M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00` | `M-AZU-LAP-IT-PPA-GEO-UAT-SWE-07`, `-08` ⁵ | Exact (see 4.18) |
| 35 | Storage Account – Logic App host | (Storage) | `mazusoa…NN` | `mazusoaitppaecmdevswe<NN>` | `mazusoaitppageouatswe07`, `08` ⁵ | Exact (same family) |

¹ The `00` name already exists in Azure outside the test subscription (see 5),
so the test deployment used NN `01`.
² The plain name became unavailable during the test deployment (see 5).
³ Deployed before the implementation moved to the register's two-digit
numbers; the next test deployment uses `PPAECMDEVPRV01` and so on.
⁴ Deployed on 2026-10-28 in a separate sandbox test with the application token
`GEO` and NN `05` (see 6).
⁵ Deployed on 2026-10-31 in the sandbox Logic Apps test with `GEO`, `UAT` and
NN `07`/`08` (resource group `M-AZU-RGP-IT-PPA-GEO-UAT-SWE`).

### Names inside resources (not covered by the standard)

| Item | Implemented name | Reason |
|---|---|---|
| Blob containers, file shares (standard and premium) | Exactly as configured, e.g. `invoices` | Named by the application (see 4.13) |
| Function App content share | `function-content` | Internal to the Functions host; one per app, in the app's own host storage account |
| Logic App content share | `logic-app-content` | Internal to the Logic Apps runtime; one per app, in the app's own host storage account |
| Private endpoint connection | Same as the private endpoint name | Azure portal default; scoped to the endpoint |
| Private endpoint DNS zone group | `default` | Azure portal default; scoped to the endpoint |
| Load Balancer frontend IP configuration | `frontend` | Scoped to the load balancer |
| Load Balancer backend pool | `backend` | Scoped to the load balancer |
| Load Balancer probes and rules | Their logical key, e.g. `http` | Same approach as NSG rules and routes |
| NSG rules, routes | Their logical key | Scoped to the NSG or route table |

## 4. Interpretations and deviations

### 4.1 Key Vault keeps the code KVA

The standard's catalogue code is `KVA` and its three-character rule applies to
all types (D-01), but the proposed compact example uses `kv`
(`mazukvitppaecmdevswe00`) and is marked "not approved". The implementation
keeps `KVA`: `mazukvaitppaecmdevswe00` is 23 characters and still fits the
24-character limit. A live Key Vault named `mazukvaitppaecmdevswe00` already
exists in Azure, while `mazukvitppaecmdevswe00` does not, which suggests KVA is
already in use. Changing to `kv` is a one-value change in the dictionary.

### 4.2 SQL database name (superseded by 4.13)

The register's example is `M-AZU-SQL-IT-PPA-ECM-DEV-SWE`, without NN, and the
server/database split is still open (D-04). The implementation first gave the
database the server's NN (`M-AZU-SQL-IT-PPA-ECM-DEV-SWE-00`). Since
2026-10-28 database names are chosen by the application instead (see 4.13),
so D-04 now only concerns the server code. Each server hosts one database in
this implementation.

### 4.3 Function App optional NN

The standard defines no NN for Function Apps. During the test deployment, the
plain name `M-AZU-FUN-IT-PPA-ECM-DEV-SWE` became unavailable in Azure and there
was no way to choose another name. The implementation therefore allows an
optional `sequence`; when it is not set, the name matches the standard exactly.
With NN the name is 31 characters, still within the 32 characters Azure uses
for the Functions host ID.

### 4.4 Subnet number

The standard's pattern is `<DPT><APP><ENV><PUB|PRV><N>`; the register's
example `PPAECMDEVPRV01` uses two digits, which the implementation follows.
There is no tier token, so the number is fixed per subnet role and names do
not change when other subnets are enabled or disabled:

| NN | Subnet | NN | Subnet |
|---|---|---|---|
| 01 | Private endpoints | 06 | MySQL |
| 02 | Virtual machines | 07 | SQL Managed Instance |
| 03 | Web App integration | 08 | Load balancers |
| 04 | Function App integration | 09 | Container Apps (default; configurable 01-99) |
| 05 | PostgreSQL | 10, 11 | Databricks host, container (default; configurable 01-99) |
| | | 14 | Logic App integration (in the examples; configurable 01-99) |

PUB/PRV is the classification of the subnet's VNet. Subnet names are scoped to
their VNet, so every VNet uses the same numbers, and Container Apps and
Databricks numbers need only be unique within their VNet.

### 4.5 PUB/PRV classifier

The standard gives an example only for the NSG. The implementation applies the
classifier to the VNet, NSGs, route tables and subnets, and since 2026-10-29 to
NAT Gateways and their Public IPs. Each VNet in `virtual_networks` sets its
classification (the network intent, `PRV` by default or `PUB`). Its subnets,
NAT Gateway and Public IP take it, and so do its NSGs and route tables unless
they set their own (including the SQL Managed Instance and Databricks NSGs).

The VNet grammar has no NN, so the classification is what tells VNets apart:
at most one PRV and one PUB VNet per BU/DPT/APP/ENV/REG. A second VNet with
the same intent needs a decision from METLEN (for example an optional NN for
VNets).

### 4.6 Sequence (NN) allocation

Every resource with NN has an explicit two-digit `sequence` input (default
`00`). Terraform rejects duplicates at plan time:

| Scope of uniqueness | Resources |
|---|---|
| All Storage Accounts | General-purpose, Premium Files, Function host and Logic App host storage |
| Per resource type | Key Vaults, Container Registries, SQL servers, PostgreSQL servers, MySQL servers, Cosmos DB accounts, Load Balancers, Container Apps environments, Logic Apps |
| All App Service Plans | Web App, Function App and Logic App plans |
| All Container Apps in the resource group | Across every Container Apps environment |
| Per classification | NSGs and route tables with the same PUB/PRV value |
| One per classification, no NN | VNets (at most one PRV and one PUB) |
| One per VNet | NAT Gateways and their Public IPs (the VNet's classification keeps them apart) |

Changing a sequence renames the resource, which replaces it in Azure.

### 4.7 Region codes

The register confirms only `WEU` = `westeurope`; `SWE` and `GWC` are
"NEEDS DECISION", and its IaC Inputs sheet says not to derive the Azure
location from `SWE`. The implementation works in the safe direction: the Azure
location is an explicit input and the code is looked up from it. The mappings
`swedencentral` → `SWE` and `germanywestcentral` → `GWC` are working
assumptions until D-02 is decided.

### 4.8 Issues found in the register itself

| Issue | Detail |
|---|---|
| Subnet example vs pattern | The register example `PPAECMDEVPRV01` has two digits; the standard's pattern says `<N>` |
| Missing resource codes | The Token Dictionary lists 12 resource codes; `APP`, `ASP`, `FUN`, `CEV`, `LBL`, `LAP`, `AAA` and `SQL` appear in the Resource Catalogue but not in the dictionary |
| Decision numbering | The register's Decision Log has D-01 to D-11; the standard has D-01 to D-08 with different meanings from D-05 on (for example D-05 is subnets and private endpoints in the standard, Container Apps in the register). This document uses the register's numbers. |

### 4.9 MySQL and PostgreSQL (working assumption)

The register has no codes for Azure Database for MySQL and PostgreSQL Flexible
Server. They follow the Azure SQL approach: the server name is global DNS
(`<name>.mysql.database.azure.com`, `<name>.postgres.database.azure.com`) and
must be lowercase; the database name is chosen by the application (see 4.13).

| Item | Value |
|---|---|
| Codes | `PGS` (PostgreSQL), `MYS` (MySQL), as suggested in the [review](naming-standard-v0.2-review.md) (section 5); three characters, so no code-length exception (D-01) is needed |
| Server rule | 3-63 characters, lowercase letters, digits and hyphens |
| Database rule (checked at plan time) | PostgreSQL 1-63 letters, digits, `-`, `_`, not starting with a digit; MySQL 1-63 lowercase letters, digits, `-`, `_` |
| NN | Explicit `sequence` per server, unique per server type |

An earlier working version used `PSQL` and `MSQL`. They were replaced because
four characters break the three-character rule and `MSQL` can be read as
"MS SQL" (Microsoft SQL Server).

Points to confirm:

- Azure Database for MySQL uses `lower_case_table_names = 1` by default and
  stores database names in lowercase. Confirmed in the test deployment (with
  the earlier code): a database requested as `M-AZU-MSQL-IT-PPA-GDK-DEV-SWE-00`
  was stored as `m-azu-msql-it-ppa-gdk-dev-swe-00`. MySQL database names must
  therefore be lowercase; Terraform rejects uppercase names at plan time.
- Uppercase PostgreSQL database names must be quoted in SQL statements
  (`"SalesReporting"`), as must any name containing hyphens.

### 4.10 Container Registry (working assumption)

The register has no code for Azure Container Registry. Registry names are
global (`<name>.azurecr.io`) and allow only letters and digits, 5-50
characters, the same restriction as Storage Accounts. The implementation
therefore uses the Storage Account compact family with the code `ACR`:
`mazuacr<BU><DPT><APP><ENV><REG><NN>`, for example `mazuacritppaecmdevswe00`
(23 characters). `ACR` keeps the three-character rule and is the common Azure
abbreviation. Each registry has an explicit `sequence`, unique per registry,
and its private endpoint becomes `mazuacritppaecmdevswe00-registry`.

### 4.11 Cosmos DB (working assumption)

The register has no code for Cosmos DB. The account uses the standard's
lowercase variant with the code `CDB` (three characters):
`m-azu-cdb-it-ppa-ecm-dev-swe-00` (global `<name>.documents.azure.com`, 3-44
lowercase letters, digits and hyphens), as for the SQL logical server. The
database and container are chosen by the application (see 4.13). Each account
hosts one database and one container in this implementation.

### 4.12 Codes agreed on 2026-10-28 (SEL, SMI, NGW, PIP, LAW)

The codes `SEL`, `SMI`, `NGW`, `PIP` and `LAW` were agreed on 2026-10-28 and
still need adding to the naming register.

| Item | Azure rule | Family | Example |
|---|---|---|---|
| SQL Elastic Pool (`SEL`) | Scoped to its logical server, up to 128 characters, uppercase allowed | Full family with the server's NN, like the database; each server has at most one pool | `M-AZU-SEL-IT-PPA-ECM-DEV-SWE-00` |
| SQL Managed Instance (`SMI`) | Global (`<name>.<id>.database.windows.net`), lowercase | Lowercase variant, like the SQL logical server, with its own NN | `m-azu-smi-it-ppa-ecm-dev-swe-00` |
| NAT Gateway (`NGW`) | Resource group, 1-80 characters | Network family with the classification of its VNet (one gateway per VNet) and NN (`virtual_networks.<VNet key>.nat_gateway.sequence`, default `00`) | `M-AZU-NGW-IT-PPA-ECM-PRV-DEV-SWE-00` |
| Public IP (`PIP`) | Resource group, 1-80 characters | Mirrors the NAT Gateway's name (same classifier and NN), so the pair is visibly linked; the classifier names the VNet the address serves, not its exposure | `M-AZU-PIP-IT-PPA-ECM-PRV-DEV-SWE-00` |
| Log Analytics workspace (`LAW`) | Resource group, 4-63 letters, digits and hyphens | Full family with NN (`log_analytics_workspace.sequence`, default `00`); one workspace shared by every Container Apps environment | `M-AZU-LAW-IT-PPA-ECM-DEV-SWE-00` |

### 4.13 Names chosen by the application (no convention)

Decided on 2026-10-28: the data containers inside a resource are named by the
application that uses them, not by the standard. Terraform uses the configured
name exactly as written and checks it against Azure's rules at plan time.
Changing a name replaces that container, share or database and its data.

| Item | Input | Default | Azure rule checked |
|---|---|---|---|
| Blob container | `storage_accounts.<key>.containers` | `["appdata", "archive"]` | 3-63 lowercase letters, digits and hyphens, start and end with a letter or digit, no `--` |
| File share (standard, premium) | `storage_accounts.<key>.file_shares` / `premium_file_accounts.<key>.file_shares` keys | none / `premium` | Same as blob containers |
| Azure SQL database | `azure_sql_servers.<key>.database_name` | Entry key | 1-128 characters without `< > * % & : \ / ?`, not ending in `.` or a space, not a system database |
| PostgreSQL database | `postgresql_servers.<key>.database_name` | Entry key | 1-63 letters, digits, `-`, `_`, not starting with a digit, not a system database |
| MySQL database | `mysql_servers.<key>.database_name` | Entry key | 1-63 lowercase letters, digits, `-`, `_` (MySQL stores names in lowercase), not a system database |
| Cosmos DB database / container | `cosmos_db_accounts.<key>.database_name` / `.container_name` | Entry key | NoSQL and Gremlin 1-255 characters without `/ \ # ?` and no trailing space; MongoDB 1-63 letters, digits, `-`, `_`; Cassandra a letter then up to 47 letters, digits, `_`; Table (container only) a letter then 2-62 letters and digits |

Entry keys allow hyphens, so a Cassandra or Table account whose key contains
one must set the names explicitly. The Function App content share is not in
this list: it is internal to the Functions host and always called
`function-content` in the app's own host storage account.

### 4.14 Azure Databricks (`DBR`, chosen 2026-10-29)

The register has no code for Azure Databricks; `DBR` was chosen on
2026-10-29 and still needs adding to the register. The workspace name is
scoped to its resource group and allows 3-64 letters, digits, underscores and
hyphens, so it uses the full family. Every other name the workspace needs
reuses an existing family:

| Item | Family | Example |
|---|---|---|
| Workspace | Full family with NN (`databricks_workspaces.<key>.sequence`) | `M-AZU-DBR-IT-PPA-GEO-DEV-SWE-00` |
| Access Connector (Unity Catalog identity) | Same name as its workspace (another resource type, so no clash) | `M-AZU-DBR-IT-PPA-GEO-DEV-SWE-00` |
| Managed resource group (created and locked by Azure Databricks) | Resource group family with the workspace NN (working assumption) | `M-AZU-RGP-IT-PPA-GEO-DEV-SWE-00` |
| Root (DBFS) storage account | Storage compact family with `storage_sequence`; Azure-generated when not set | `mazusoaitppageodevswe08` |
| NSG on both workspace subnets | Network family with `network_sequence` (default: the workspace NN), like SQL Managed Instance | `M-AZU-NSG-IT-PPA-GEO-PRV-DEV-SWE-00` |
| Host and container subnets | Subnet pattern with the `number` of the `databricks/<key>/host` and `databricks/<key>/container` subnets (10 and 11 in the examples) | `PPAGEODEVPRV10`, `PPAGEODEVPRV11` |
| Private Endpoints | `<workspace>-<subresource>` | `M-AZU-DBR-IT-PPA-GEO-DEV-SWE-00-databricks_ui_api`, `…-browser_authentication` |

The managed resource group NN must not clash with another resource group
that carries the same NN; the main resource group has none.

### 4.15 Application Insights (`AIN`, agreed 2026-10-29)

The register has no code for Application Insights; `AIN` was agreed on
2026-10-29 and still needs adding to the register (`API` was avoided because
it reads as API Management). The name is scoped to the resource group and
allows 1-255 characters, so it uses the full family with NN
(`application_insights.sequence`, default `00`), like the Log Analytics
workspace it stores its data in. One resource is shared by every Web App and
Function App that sends telemetry.

| Item | Family | Example |
|---|---|---|
| Application Insights | Full family with NN | `M-AZU-AIN-IT-PPA-ECM-DEV-SWE-00` |
| Monitoring Metrics Publisher role assignments | Generated by Azure (GUID) | — |

### 4.16 Names derived from VNet names (VNet peerings, Private DNS zone links)

The standard has no code for VNet peerings or Private DNS zone links. Both are
derived from the METLEN VNet names, so they stay readable and unique:

| Item | Rule | Example |
|---|---|---|
| VNet peering | `<local VNet name>-to-<remote VNet name>`, scoped to the local VNet; Terraform rejects names over the 80-character limit instead of truncating them | `M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE-to-M-AZU-VNT-IT-PPA-ECM-PUB-DEV-SWE` |
| Hub peering, spoke / hub side | Same rule with the hub VNet name read from `hub_peering.hub_virtual_network_id` | `M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE-to-vnet-hub` / `vnet-hub-to-M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE` |
| Private DNS zone link | The name of the linked VNet; link names are scoped to their zone | `M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE` |

### 4.17 Recovery Services vault (`RSV`, agreed 2026-10-31)

The register has no code for Recovery Services vaults; `RSV`, suggested in
the v0.2 review, was agreed on 2026-10-31 and still needs adding to the
register. The name is scoped to the resource group and allows 2-50 letters,
digits and hyphens, so it uses the full family with NN
(`vm_backup.sequence`, default `00`). One vault backs up every VM.

| Item | Family | Example |
|---|---|---|
| Recovery Services vault | Full family with NN | `M-AZU-RSV-IT-PPA-ECM-DEV-SWE-00` |
| VM backup policies | Scoped to the vault: the `vm_backup.policies` key | `default` |
| Instant-restore snapshot resource group | Created and named by Azure Backup, outside Terraform | `AzureBackupRG_swedencentral_1` |

### 4.18 Logic App (Standard) (`LAP`)

The register lists `LAP` (WORKING) with the example
`M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00`; its 43-character limit is the Consumption
(multitenant) one. The implementation creates Logic Apps (Standard), which are
App Service sites: the name is global (`<name>.azurewebsites.net`, 2-60
characters), and the 31-character example also stays within the 32
characters Azure uses for the Functions host ID. Each app has an explicit
`sequence` (default `00`), unique per Logic App.

| Item | Family | Example |
|---|---|---|
| Logic App | Full family with NN (`logic_apps.<key>.sequence`) | `M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00` |
| Workflow Standard plan | App Service Plan family with its own NN in `app_service_plans` | `M-AZU-ASP-IT-PPA-ECM-DEV-SWE-03` |
| Host storage account | Storage compact family with `logic_apps.<key>.storage_sequence` | `mazusoaitppaecmdevswe06` |
| Content share | Fixed, inside the app's own host storage account | `logic-app-content` |
| Integration subnet | Subnet pattern with the `number` of the `logic_app_integration` subnet (14 in the examples) | `PPAECMDEVPRV14` |
| Private Endpoints | `<app name>-sites`, `<storage name>-blob`/`-file`/`-queue`/`-table` | `M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00-sites` |

## 5. Names already taken in Azure

Several names generated from the standard's own examples were unavailable in
Azure during the test deployment. The resources were not in the Microsoft test
subscription.

| Name | Finding |
|---|---|
| `mazusoaitppaecmdevswe00` | Exists (Sweden Central) |
| `m-azu-sql-it-ppa-ecm-dev-swe-00` | Exists (Sweden Central) |
| `mazukvaitppaecmdevswe00` | Exists; Azure's name check reported it as free |
| `mazukvitppaecmdevswe00` | Free |
| `M-AZU-FUN-IT-PPA-ECM-DEV-SWE` | Became unavailable during deployment |

**Question for METLEN:** are the existing `00` resources yours? If so, the
implementation reproduces your names exactly. Either way, globally unique names
need an NN fallback and an availability check before deployment (§8 stage 05
of the standard).

## 6. Validated in Azure

All names in section 3 marked as deployed were created successfully, and a
second `terraform plan` reported no changes, so uppercase names cause no
configuration drift. This settles two "VALIDATE" items: Azure accepts uppercase
App Service names and the uppercase Container Apps environment name.

A second test on 2026-10-28 (resource group `M-AZU-RGP-IT-PPA-GEO-DEV-SWE`,
68 resources) deployed the codes agreed that day and the names chosen by the
application; again a second `terraform plan` reported no changes:

- `SEL`, `NGW`, `PIP` and `LAW` with NN `05`. The uppercase pool and
  workspace names are referenced by other resources (the database, the
  Container Apps environment) without drift.
- Blob containers `invoices` and `customer-documents-archive-2026`, the
  premium share `render-cache`, the SQL database `Sales Reporting` (with a
  space), the PostgreSQL database `Sales_Reporting` (mixed case kept), the
  MySQL database `sales_reporting`, and the Cosmos DB database `catalog-db`
  with container `products`, all exactly as configured.
- A Function App running on its fixed `function-content` share.

## 7. Not yet implemented

### 7.1 In the Terraform, without a METLEN code (still using the sample naming)

| Resource | Note |
|---|---|
| Virtual Machines, NICs, OS and data disks, computer names | Standard refers to a separate server naming standard |
| VM Scale Sets, NICs, autoscale settings | Same as VMs |
| Container name inside Container Apps, workload profiles | Inside resources; not covered |
| Subnet delegations | Inside subnets; not covered |

### 7.2 In the standard, not part of this Terraform

| Resource | Requested by METLEN |
|---|---|
| Logic App | `M-AZU-LAP-<BU>-<DPT>-<APP>-<ENV>-<REG>-NN` |
| Automation Account | `M-AZU-AAA-<BU>-<DPT>-<APP>-<ENV>-<REG>-NN` |
| AVD Host Pool | `HSP` (pattern under discussion) |
| AVD Workspace | `WSP` (pattern under discussion) |
| AVD Application Group | `APL` or `DAG` (undecided) |

### 7.3 Fixed by Azure (never renamed)

Private DNS zones (`privatelink.*`), the Container Apps `Consumption` workload
profile, and private endpoint network interfaces (named by Azure as
`<private endpoint>.nic.<id>`).

## 8. Decisions needed from METLEN that affect names

Decision IDs follow the register's Decision Log.

| Decision | Current implementation |
|---|---|
| Key Vault compact grammar: `KVA` or `kv` (D-03) | `KVA` |
| SQL server vs database naming (D-04) | `SQL` for the server; database names are chosen by the application (see 4.13) |
| Container App lowercase pattern (D-05) | `m-azu-cap-…-NN` as in the register |
| AVD codes (D-06) | Not implemented (no AVD in this Terraform yet) |
| Subnet naming with tiers and reserved subnets (D-07) | Two-digit number per subnet role |
| Private endpoint suffix (D-08) | Lowercase Private Link subresource |
| Which types carry PUB/PRV | VNet, NSG, route table, subnet |
| NN allocation and register | Explicit `sequence` per resource, default `00` |
| NN for Function Apps | Optional, not set by default |
| `SWE` / `GWC` region mapping (D-02) | `swedencentral` / `germanywestcentral` (assumption) |
| Codes for MySQL and PostgreSQL | `MYS` and `PGS` (working assumption) |
| Code for Container Registry | `ACR` (working assumption) |
| Code for Cosmos DB | `CDB` (working assumption) |
| Code for Azure Databricks | `DBR` (chosen 2026-10-29, not yet in the register); managed resource group in the RGP family with the workspace NN (working assumption) |
| Register entries for SQL Elastic Pool, SQL Managed Instance, NAT Gateway, Public IP and Log Analytics workspace | `SEL`, `SMI`, `NGW`, `PIP` and `LAW` (agreed, not yet in the register) |
| Register entry for Application Insights | `AIN` (agreed 2026-10-29, not yet in the register) |
| Codes for the resources in 7.1 | Not yet implemented |
