SET SERVEROUTPUT ON;

CREATE OR REPLACE PACKAGE report_diff_analyzer AS 
TYPE param_array_type IS TABLE OF NUMBER INDEX BY VARCHAR2(45);
FUNCTION create_param_array RETURN param_array_type;
PROCEDURE compare_reports (old_report_name VARCHAR2, new_report_name VARCHAR2);
END;
/

CREATE OR REPLACE PACKAGE BODY report_diff_analyzer AS 

FUNCTION create_param_array
RETURN param_array_type
IS
param_array param_array_type;
BEGIN
param_array('sga use') := null;
param_array('pga use') := null;
param_array('host mem') := null;
param_array('sga target') := null;
RETURN param_array;
END;

PROCEDURE compare_reports (old_report_name VARCHAR2, new_report_name VARCHAR2) 
IS
report_dir VARCHAR2(20) := 'REPORT_DIR';
old_report UTL_FILE.FILE_TYPE;
new_report UTL_FILE.FILE_TYPE;
param_array_old param_array_type;
param_array_new param_array_type;
BEGIN
old_report := UTL_FILE.FOPEN(report_dir, old_report_name, 'R');
new_report := UTL_FILE.FOPEN(report_dir, new_report_name, 'R');
param_array_old := create_param_array();
param_array_new := create_param_array();
--execute analyze_report()
EXCEPTION
WHEN OTHERS THEN
UTL_FILE.FCLOSE(old_report);
UTL_FILE.FCLOSE(new_report);
dbms_output.put_line('Error occurred > ' || SQLERRM);
END;

END;
/