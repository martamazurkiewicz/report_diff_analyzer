# report_diff_analyzer
This package aim is to compare 2 Statspack reports. It must be added to Oracle Database as package. It can be executed with SQL*PLUS. 
All scripts are written in PL\SQL with C fragments.
PERFSTAT schema is required for this package.

## Granting privileges to scripts from this package
Firstly, it is necessary to grand PERFSTAT (and probably SYS) USER privileges to directory with report_diff_analyzer scripts.
It is done by creating Oracle directory object associated with physical directory
```
CREATE OR REPLACE DIRECTORY scripts_dir AS '/home/admin/scripts/';
```
and granting read and write privileges to appropriate users
```
GRANT READ,WRITE ON DIRECTORY scripts_dir TO perfstat,sys;
```
