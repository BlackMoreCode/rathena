# CopeRO level policy: high Base, official Job progression

The Base ceiling remains 1000 with the existing custom Base EXP tables.
`db/cope_job_policy.yml` restores only Renewal Job caps and Job EXP from the
merged official rAthena snapshot `d4b8e7b8f`. It is loaded after the existing
Renewal EXP file and before the final custom `db/import/job_stats.yml`.

Normal Job caps are 10 (Novice), 50 (ordinary first/second jobs), 70
(transcendent second/third and selected expanded jobs), and 60 (Summoner/fourth
jobs). Super Novice/Super Baby use 99; expanded Super Novice/Super Baby use 70.
Gangsi/Death Knight/Dark Collector retain their existing 99/50 special limits.
Cosmetic classes without EXP tables are not ordinary leveling classes.

The inactive legacy `db/import/job_exp.yml` is retained but is not activated.
Job Master skill-point checks and other skill prerequisites remain unchanged.
This change neither resets character levels nor removes skill points.

Before applying to production, run the supplied read-only
`level-policy-preflight.sql` against the production `ragnarok` database. An empty
result means no saved character is above the new Job cap. If rows are returned,
review those existing characters before switching policy; no automatic SQL
level/point reduction is provided.

Stop/restart the game servers to reload JobDatabase after pulling this change.
No recompilation or SQL schema migration is needed. Keep machine-specific
network and database configuration in place.

The matching client is rebuilt from the clean 2025-07-16 Ragexe using
`profiles/cope_release.yml` (42 patches) and `Inputs/CopeExpSpec.yml`.
It includes CustomBarLimits, headgear viewID 32000, Allow65kHairs,
CustomWalkDelay 20ms and ZoomMax. Publish the final CopeRO.exe to web/exe and
regenerate the web manifest. Only then remove the temporary CopeRO.exe client
update exclusion. The separate proxy DLL development project is not rebased by
this release.
