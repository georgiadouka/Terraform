# Review: METLEN Azure Resource Naming Standard & IaC Enablement (v0.2)

| Item | Value |
|---|---|
| Document reviewed | [METLEN_Azure_Naming_Standard_IaC_Working_Draft_v0.2.docx](../METLEN_Azure_Naming_Standard_IaC_Working_Draft_v0.2.docx) (METLEN-AZU-NAM-STD-001, v0.2, 19 October 2026) and [METLEN_Azure_Naming_Register_IaC_v0.2.xlsx](../METLEN_Azure_Naming_Register_IaC_v0.2.xlsx) (see Section 9) |
| Review date | 26 October 2026 |
| Prepared by | Microsoft — [Reviewer name] |
| Purpose | Technical review before implementing the standard in Terraform |
| Review basis | Microsoft Learn *Naming rules and restrictions for Azure resources*, Azure Functions storage considerations, Azure Policy definition structure, Key Vault soft-delete behaviour |

## 1. Summary

The draft is well structured and technically sound. It correctly separates
confirmed decisions from workshop proposals, the Azure limits it quotes are
accurate, and the IaC principles (deterministic names, fail-closed token
validation, audit-before-deny, no forced renaming, tags for full identity) match
Microsoft guidance.

It is **not yet ready to be implemented as an enforceable contract**. The main
blockers are:

1. Token lengths are not fixed, so the compact naming families only fit Azure
   limits for the specific example values (R-02).
2. A number of resource types that a typical workload needs are not in the
   catalogue — notably Container Registry, Log Analytics, Public IP, NAT Gateway,
   Cosmos DB and MySQL/PostgreSQL (R-16).
3. Several internal inconsistencies and platform behaviours need a decision
   before templates are frozen (R-01, R-04, R-09, R-10).

All Section 11 decisions (D-01 – D-08) remain open and have no owner. Findings
below reference the related decision where one exists.

## 2. What works well

- **Accurate platform limits.** All checked examples are correct: Key Vault
  full pattern 31 > 24 characters; Storage example 23/24; lowercase Container
  App example 31/32; SQL logical server lowercase requirement; Function App
  32-character host ID.
- **Clear precedence of sources** (§2.1), with Azure service restrictions
  always taking priority and CAF abbreviations treated as informative only.
- **Safe IaC principles** (§8): explicit subscription ID as deployment scope,
  no random or date components, plan/what-if before approval, Azure Policy in
  audit mode first.
- **Legacy discipline** (§7.3): existing resources are not renamed, because a
  name change usually means delete and recreate.
- **Security separation**: PUB/PRV is explicitly not evidence of network
  exposure (§5, §8.2).
- **Testable acceptance criteria** (§9) that can be automated.

## 3. Findings

Severity: **High** = blocks implementation or causes deployment failures;
**Medium** = causes inconsistency or rework; **Low** = clarification.

### 3.1 Internal consistency

| ID | Severity | Section | Finding | Recommendation |
|---|---|---|---|---|
| R-01 | High | §6, §4 | The compact Key Vault example `mazukvitppaecmdevswe00` uses `kv`, not the catalogue code `KVA`, breaking the three-character code rule. | Use `KVA` in the compact family: `mazukvaitppaecmdevswe00` is 23 characters and still fits the 24-character limit. Otherwise record `kv` as an approved exception. (D-03) |
| R-02 | High | §3.1 | No maximum length is defined for BU, DPT, APP, ENV, REG or NN. The compact families only fit with the example lengths (BU 2, DPT 3, APP 3). A 5-character APP code breaks Storage, Key Vault and Container App names. | Fix maximum token lengths in the token dictionary. See the budget in Section 4. (D-02) |
| R-03 | Medium | §3.1, §4 | PUB/PRV applies to "designated network types", but these are not listed. VNet, route table and NSG are all "network family". A VNet usually contains both public and private subnets, so a single classifier does not describe it. | List the exact resource types that carry PUB/PRV, e.g. NSG and route table, and probably not VNet. |
| R-04 | Medium | §3.1, §4 | Code ambiguity: `APP` is both the App Service type code and the name of the workload token; `SQL` is used for both logical server and database; `UDR` (a single route) is used for a route table. | Use distinct codes, for example `WEB` or `APS` for App Service, `SQS` / `SQD` for SQL server / database, `RTB` for route table. (D-01, D-04) |
| R-05 | Medium | §4 | The subnet pattern `DPTAPPENV<PUB/PRV>N` uses a single-digit `N`, unlike the two-digit `NN` elsewhere. It has no separators and no functional tier (web, app, data, PE, integration). | Align numbering with `NN`, add a tier token and decide whether separators are used. (D-05) |
| R-06 | Medium | §4, §6 | The AVD example `M-AZU-HSP-IT-AVD-PRD-WEU-00` has no DPT token, which contradicts the canonical grammar. The workshop patterns also repeat HSP/WSP. APL vs DAG is unresolved. | Confirm one pattern for host pool, workspace, application group and scaling plan (not in the catalogue). Decide whether AVD is an APP value under a DPT. (D-04) |
| R-07 | Low | §6 | Two different compact styles are used: `mazu…` (no separators) and `m-azu-…` (lowercase hyphenated). There is no rule for which one applies to which type. | Define exactly two constrained families, *lowercase-hyphenated* and *lowercase-alphanumeric*, and assign each resource type to one in the catalogue. |
| R-08 | Medium | §3.1, §8 | NN rules are incomplete: start value (00 or 01), who allocates numbers, where allocations are recorded, and what happens at 99. "Stable across redeployments" requires a persisted register. | Define NN allocation in the naming register and say whether IaC receives NN as an input or derives it. |

### 3.2 Azure platform behaviour

| ID | Severity | Section | Finding | Recommendation |
|---|---|---|---|---|
| R-09 | High | §4, §5 | **Function App host ID collision.** The host ID is the lowercase first 32 characters of the app name. With a 5-character APP code, instances `-00` and `-01` produce the same host ID: `M-AZU-FUN-IT-PPA-ECMPO-DEV-SWE-00` and `…-01` both become `m-azu-fun-it-ppa-ecmpo-dev-swe-0`. This breaks apps that share a storage account. | Keep Function App names within 32 characters (Section 4 budget) or require a dedicated storage account per Function App. Add an acceptance test. |
| R-10 | High | §3.1, §8 | **Soft-delete name reservation.** A deleted Key Vault keeps its name reserved for the soft-delete retention period (7–90 days; it cannot be purged early if purge protection is on). Deterministic names mean that destroying and redeploying, which is common in DEV, fails until the name is purged or released. The same applies to other soft-delete services, e.g. API Management, App Configuration and Azure AI services. | Document the lifecycle rule: purge in non-production, or increment NN on redeploy. Record it in the exception register and the IaC runbook. |
| R-11 | Medium | §6 | Globally unique names (Storage, Key Vault, SQL server, App Service, ACR, Cosmos DB, MySQL/PostgreSQL) can be taken by another tenant, and become free for others after deletion. | Keep the §8 availability check and define the fallback (e.g. next NN) so a collision does not need an ad-hoc decision. |
| R-12 | Medium | §3.1, §8 | **Upper/lower case.** Azure names are case-insensitive but keep their case. Azure Policy `match`/`like` comparisons are case-sensitive (`matchInsensitively` exists), and some IaC tools compare names or resource IDs case-sensitively, which can show unexpected plan changes. | Fix one canonical case per resource type in the catalogue. In Policy, use the matching operator that fits that choice. Include an uppercase-name pilot in training session 3. |
| R-13 | Low | §4 | Private endpoint `<PARENTNAME>-<SERVICE>` collides when one parent has two endpoints for the same sub-resource (e.g. two VNets). The endpoint's network interface, private service connection and DNS zone group names are not defined. | Add an optional discriminator (NN or network token). Define names for the PE NIC (e.g. `<pe-name>-nic`), connection and zone group. (D-05) |
| R-14 | Medium | §4 | Some subnets **must** use exact Azure names: `GatewaySubnet`, `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, `AzureBastionSubnet`, `RouteServerSubnet`. | Record these as fixed exceptions to the subnet grammar. This is a platform rule, not a decision. |
| R-15 | Low | §4 | Some resources have fixed names: private DNS zones (`privatelink.*`) and some child resources (e.g. the Container Apps `Consumption` workload profile). | Add a "fixed by platform" category to the catalogue so validation does not flag them. |

### 3.3 Coverage gaps

| ID | Severity | Section | Finding | Recommendation |
|---|---|---|---|---|
| R-16 | High | §4 | Common resource types are missing from the catalogue. Several are globally unique or tightly constrained (see Section 5). | Add them, with codes, naming family, scope and limits, before module freeze. (D-01) |
| R-17 | Low | §3.1 | Shared platform resources (hub VNet, firewall, central Log Analytics) do not naturally have a BU/DPT/APP. | Define token values for platform/shared components, e.g. a platform BU or a `HUB` APP. |
| R-18 | Medium | §3.2, §4 | The subscription pattern `M-AZU-SBS-<BU>-<DPT>` has no ENV, which implies production and non-production share a subscription and are separated only by resource group. Landing-zone guidance normally separates them at subscription level. | Confirm with the landing-zone design. If subscriptions are split by environment, add ENV to the subscription pattern now, before more are created. |
| R-19 | Medium | §3.1, D-02 | The region dictionary is incomplete. `SWE` could be Sweden Central or Sweden South, and `GWC` appears only in D-02. | Publish the mapping table, e.g. `WEU` = `westeurope`, `SWE` = `swedencentral` (to confirm), `GWC` = `germanywestcentral`, `NEU` = `northeurope`. |
| R-20 | Low | §2 | It does not say whether management groups, policy and role assignments, diagnostic settings, action groups or Entra ID groups are in scope. | State in or out of scope for each. |
| R-21 | Low | §4 | VMs are excluded (external server standard), but their dependent resources (NIC, OS and data disks) and the 15-character Windows computer-name limit are not covered. AVD session hosts fall under this too. | Reference the server standard and state how NIC and disk names derive from the server name. |

### 3.4 Governance and IaC

| ID | Severity | Section | Finding | Recommendation |
|---|---|---|---|---|
| R-22 | Medium | Document control, §11 | Business owner, approver and all decision owners are TBD. The standard cannot move from audit to deny without an approver. | Assign owners for D-01 – D-08 before training session 1. |
| R-23 | Low | §8.1, D-08 | The companion IaC starter is Bicep only, but AT-10 requires Bicep/Terraform parity. | Confirm the target language(s). Microsoft will deliver the Terraform implementation; the shared JSON rule catalogue should be the single source of truth for both. |
| R-24 | Low | §9 | Acceptance tests do not cover the risks above. | Add tests for: Function host ID uniqueness (R-09), Key Vault redeploy after delete (R-10), duplicate private endpoint names (R-13), fixed subnet names (R-14), unknown region code (R-19). |

## 4. Proposed token length budget

Azure limits fix how long the three variable business tokens can be when
combined. Using the confirmed fixed tokens (`M-AZU`, 3-character TYPE, 3-character
ENV, 3-character REG, 2-character NN):

| Family / resource | Limit | Fixed part | Max BU + DPT + APP |
|---|---|---|---|
| Storage, Key Vault, ACR compact (`mazu` + TYPE + ENV + REG + NN) | 24 | 15 | **9** |
| Container App, lowercase hyphenated (`m-azu-cap-` … `-dev-swe-00`) | 32 | 23 incl. separators | **9** |
| Function App host-ID safe (`M-AZU-FUN-` … `-DEV-SWE-00`) | 32 | 23 incl. separators | **9** |

**Recommendation:** BU = 2, DPT = 3, APP = 2–4 characters (total ≤ 9),
ENV = 3, REG = 3, NN = 2. This keeps every family within limits without
truncating. The example (IT + PPA + ECM = 8) leaves one character of headroom.

## 5. Resource types to add to the catalogue

The codes below are suggestions for METLEN to approve or replace.
Limits are taken from Microsoft Learn.

| Resource | Suggested code | Name scope | Limit / characters | Family |
|---|---|---|---|---|
| Container Registry | ACR | Global | 5–50, letters and digits only | Lowercase-alphanumeric |
| Cosmos DB account | CDB | Global | 3–44, lowercase, digits, hyphens | Lowercase-hyphenated |
| MySQL Flexible Server | MYS | Global | 3–63, lowercase, digits, hyphens | Lowercase-hyphenated |
| PostgreSQL Flexible Server | PGS | Global | 3–63, lowercase, digits, hyphens | Lowercase-hyphenated |
| Log Analytics workspace | LAW | Resource group | 4–63, letters, digits, hyphens | Full |
| Application Insights | AIN | Resource group | 1–260 | Full |
| Public IP address | PIP | Resource group | 1–80 | Full |
| NAT Gateway | NGW | Resource group | 1–80 | Full |
| Network interface | NIC | Resource group | 1–80 | Full / derived from parent |
| Managed disk | DSK | Resource group | 1–80 | Derived from VM |
| Azure Firewall | AFW | Resource group | 1–80 | Full (platform) |
| Azure Bastion | BAS | Resource group | 1–80 | Full (platform) |
| Virtual network gateway | VGW | Resource group | 1–80 | Full (platform) |
| Application Gateway | AGW | Resource group | 1–80 | Full |
| VNet peering | PER | Parent VNet | 1–80 | Full |
| Recovery Services vault | RSV | Resource group | 2–50, letters, digits, hyphens | Full |
| User-assigned managed identity | UMI | Resource group | 3–128 | Full |
| Container Apps Environment | CEV (existing) | Resource group | Validate | Full |
| AVD scaling plan | to define | Resource group | Validate | Full |
| Private DNS zone | — | Resource group | Fixed by Azure (`privatelink.*`) | Fixed |

## 6. Questions for METLEN

1. Who owns and approves the standard and each open decision (D-01 – D-08)?
2. Compact Key Vault: keep `KVA` (`mazukva…`, 23 characters) or approve `kv`? (R-01)
3. Do you accept the token length budget in Section 4? (R-02)
4. Which resource types carry PUB/PRV? (R-03)
5. New codes for App Service, SQL server/database and route table? (R-04)
6. How is NN allocated and recorded, and where does it start? (R-08)
7. Lifecycle rule for soft-deleted names in DEV/UAT? (R-10)
8. Which BU/DPT/APP tokens should shared platform resources use? (R-17)
9. Are production and non-production subscriptions separate? If so, add ENV to the subscription name. (R-18)
10. Exact Azure region for `SWE`, and the full region dictionary? (R-19)
11. Codes for the missing resource types in Section 5? (R-16)
12. Target IaC language(s): Terraform only, or Bicep and Terraform? (R-23)

## 7. Implications for the Terraform implementation

- Names are generated once, in a central naming layer, from the approved token
  dictionary; modules receive final names as inputs.
- Unknown tokens, over-length names and wrong character sets fail at
  `terraform plan`, before any deployment.
- Anything not yet approved (Section 6) will be implemented as a clearly marked
  working assumption, replaced when the decision is made.
- Changing a name in Terraform plans a **destroy and recreate** for most Azure
  resources. Once a name reaches PRD, change it only through the exception and
  ADR process in §7.3.
- The full identity (BU, DPT, APP, ENV, NamingStandardVersion, ExceptionId)
  will be applied as tags, aligned with the METLEN tagging runbook, once the
  tag set is confirmed (register D-09). It is not implemented yet.

## 8. Recommended next steps

1. METLEN assigns owners and answers the questions in Section 6, ideally before
   training session 1.
2. Microsoft implements the naming layer in Terraform using the agreed and
   working-assumption rules, with automated acceptance tests (§9 plus R-24).
3. The decisions are recorded in v0.3 of the standard and the naming register.
4. Pilot in a non-production subscription, with Azure Policy in audit mode.

## 9. Naming register v0.2

The naming register workbook (Resource Catalogue, Token Dictionary, Validation
Examples, Decision Log, Exception Register, IaC Inputs) was reviewed against
the standard. Finding IDs in Sections 3–6 refer to the standard.

### 9.1 Points the register resolves

| Finding | Resolution in the register |
|---|---|
| R-05 (subnet numbering) | The example `PPAECMDEVPRV01` uses two digits, which removes the nine-subnet limit of a single digit. The tier token and reserved Azure subnet names remain open (register D-07). |
| Missing examples | Representative examples now exist for VNet, route table, App Service, App Service Plan, Function App, Container Apps Environment and Load Balancer; all follow the standard's grammar. |
| R-12 (case) | Validation Examples correctly reject uppercase Container App and SQL logical server names. |

### 9.2 New or remaining findings

| ID | Severity | Sheet | Finding | Recommendation |
|---|---|---|---|---|
| R-25 | Medium | Resource Catalogue vs standard | The subnet example `PPAECMDEVPRV01` (two digits) does not match the standard's pattern `<DPT><APP><ENV><PUB/PRV><N>` (one digit). | Change the pattern in the standard to `<NN>`. |
| R-26 | Medium | Token Dictionary | Only 12 resource codes are listed. `APP`, `ASP`, `FUN`, `CEV`, `LBL`, `LAP`, `AAA` and `SQL` are used in the Resource Catalogue but missing from the dictionary, so IaC cannot validate them against the controlled list. | Add every catalogue code to the Token Dictionary with status and owner. |
| R-27 | Low | Decision Log | The register has D-01 to D-11; the standard has D-01 to D-08, and the meaning differs from D-05 on (for example D-05 is subnets and private endpoints in the standard, Container Apps in the register). | Use one numbering in both artifacts; the register's finer split is clearer. |
| R-28 | Low | Resource Catalogue | The SQL database example `M-AZU-SQL-IT-PPA-ECM-DEV-SWE` has no NN while its server `m-azu-sql-it-ppa-ecm-dev-swe-00` has one, so the two are not visibly linked. | Decide with D-04 whether the database repeats the server's NN or uses its own code. |
| R-29 | Low | Token Dictionary, IaC Inputs | Only `WEU` is mapped to an Azure location; `SWE` and `GWC` are "NEEDS DECISION" (confirms R-19). | Publish the location mapping for every region code before module freeze. |
| R-30 | Low | Resource Catalogue | The same gaps as the standard (R-16): no codes for Container Registry, Cosmos DB, MySQL/PostgreSQL, Log Analytics, Public IP, NAT Gateway and others. | Add them with the codes in Section 5. |
| R-31 | Low | Resource Catalogue | The Key Vault example `mazukvitppaecmdevswe00` uses `kv`, while the catalogue code is `KVA` (confirms R-01). | Use `mazukvaitppaecmdevswe00` (23 characters), or approve `kv` as an exception. |

## 10. Status since the review (28 October 2026)

The findings above are kept as reviewed on 26 October. Decisions taken since
then, and how the Terraform implementation applies them, are recorded in
[naming-standard-v0.2-implementation.md](naming-standard-v0.2-implementation.md):

| Finding | Status |
|---|---|
| R-16, R-30 (missing codes) | Partly resolved. Agreed on 2026-10-28: `LAW` (Log Analytics workspace), `PIP` (Public IP) and `NGW` (NAT Gateway), as suggested in Section 5, plus `SMI` (SQL Managed Instance) and `SEL` (SQL Elastic Pool). All five still need adding to the naming register by METLEN. `ACR`, `CDB`, `MYS` and `PGS` remain working assumptions. |
| R-28, D-04 (SQL database name) | Resolved differently: database names (Azure SQL, PostgreSQL, MySQL, Cosmos DB) are chosen by the application and follow no convention; D-04 now only concerns the server code. Blob containers and file shares follow the same rule. |
| R-21 (VM dependants) | Open. VMs, scale sets, NICs and disks still use the sample naming until the server naming standard is referenced. |
| All other findings and Section 6 questions | Open. |
