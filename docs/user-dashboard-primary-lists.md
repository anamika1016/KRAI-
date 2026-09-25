# User dashboard primary lists

Authenticated GET `/api/v1/user-dashboard/lists/:list_type`.
Keep the same Authorization header and filters for each list:

```text
?month=June&main_activity=Farmers%27%20Training&sub_activity=All&fco=FCO-C%20Turekela&ics=All
```

| Section | Box | list_type |
| --- | --- | --- |
| Dashboard Summary | Total ICS | summary_ics |
| Dashboard Summary | Total Villages | summary_villages |
| Dashboard Summary | Total Farmers | summary_farmers |
| Dashboard Summary | Mapped Main Activities | total_mapped_main_activities |
| Dashboard Summary | Mapped Sub-Activities | total_mapped_sub_activities |
| Farmer Training Participation Status | Mapped Farmer | training_unique_farmers |
| Farmer Training Participation Status | Pending | training_red |
| Farmer Training Participation Status | Only 1 Training | training_yellow |
| Farmer Training Participation Status | 1+ Trainings | training_green |
| Demonstration Method | OPG Training Target | opg_training_target |
| Demonstration Method | General Training/Meeting | general_training_meeting |
| Demonstration Method | Input Demo INM | input_demo_inm |
| Demonstration Method | Input Demo PM | input_demo_pm |
| Demonstration Method | FFS Exposure | ffs_exposure |
| Demonstration Method | CC TARGET STATUS | cc_target_status |

Demonstration boxes return the same complete per-JJ report as the web View List;
`demonstration_method` remains available. Each row includes all method metrics.

Responses retain `success`, `list_type`, `title`, `filters`, `count`, and `records`.
No pagination or row limit is applied. Append `/export` before the query string for XLSX.
Summary uses the web summary scope; month/activity filters apply to the other sections.

Farmer rows include FCO, FPO, ICS and village IDs and names when stored in AFL.
Historical mapped farmers remain included, with IDs available from their target mapping.
A historical farmer missing from AFL has `historical_mapping: true`; unavailable
FPO details are `null`, since target mappings do not store FPO IDs.
Grouped activity rows expose `fco_ids`, `ics_ids`, and `village_ids` arrays because
one activity can span several locations.
