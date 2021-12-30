SET SERVEROUTPUT ON;
CREATE OR REPLACE PACKAGE report_diff_analyzer AS 
TYPE param_array_type IS TABLE OF NUMBER INDEX BY VARCHAR2(45);
TYPE meta_info_array_type IS TABLE OF VARCHAR2(70) INDEX BY VARCHAR2(45);
PROCEDURE compare_reports (old_report_name IN VARCHAR2, new_report_name IN VARCHAR2);
FUNCTION create_param_array RETURN param_array_type;
FUNCTION create_meta_info_array RETURN meta_info_array_type;
PROCEDURE analyze_report (report_name IN VARCHAR2, param_array IN OUT param_array_type, meta_info_array IN OUT meta_info_array_type);
PROCEDURE set_param_with_val (report_line IN VARCHAR2, param_array IN OUT param_array_type, meta_info_array IN OUT meta_info_array_type);
FUNCTION get_num_val_from_line(report_line IN VARCHAR2, key_word IN VARCHAR2, value_order IN NUMBER DEFAULT 1) RETURN NUMBER;
FUNCTION split_varchar_by_space(report_line IN VARCHAR2, key_word IN VARCHAR2, value_order IN NUMBER DEFAULT 1) RETURN VARCHAR2;
PROCEDURE compare_and_display_params (
	param_array_old IN OUT param_array_type, 
	param_array_new IN OUT param_array_type, 
	meta_info_array_old IN OUT meta_info_array_type, 
	meta_info_array_new IN OUT meta_info_array_type);
PROCEDURE order_param_arrays(
	param_array_old IN OUT param_array_type, 
	param_array_new IN OUT param_array_type, 
	meta_info_array_old IN OUT meta_info_array_type, 
	meta_info_array_new IN OUT meta_info_array_type);
PROCEDURE compare_values(exp_worse_val IN NUMBER, exp_better_val IN NUMBER);
END;
/
CREATE OR REPLACE PACKAGE BODY report_diff_analyzer AS 
report_dir VARCHAR2(20) := 'REPORT_DIR';
PROCEDURE compare_reports (old_report_name IN VARCHAR2, new_report_name IN VARCHAR2) 
IS
old_report UTL_FILE.FILE_TYPE;
new_report UTL_FILE.FILE_TYPE;
param_array_old param_array_type;
param_array_new param_array_type;
meta_info_array_old meta_info_array_type;
meta_info_array_new meta_info_array_type;
BEGIN
old_report := UTL_FILE.FOPEN(report_dir, old_report_name, 'R');
new_report := UTL_FILE.FOPEN(report_dir, new_report_name, 'R');
UTL_FILE.FCLOSE(old_report);
UTL_FILE.FCLOSE(new_report);
param_array_old := create_param_array();
param_array_new := create_param_array();
meta_info_array_old := create_meta_info_array();
meta_info_array_new := create_meta_info_array();
analyze_report(old_report_name, param_array_old, meta_info_array_old);
analyze_report(new_report_name, param_array_new, meta_info_array_new);
compare_and_display_params(param_array_old, param_array_new, meta_info_array_old, meta_info_array_new);
EXCEPTION
WHEN OTHERS THEN
UTL_FILE.FCLOSE(old_report);
UTL_FILE.FCLOSE(new_report);
dbms_output.put_line('Error occurred > ' || SQLERRM);
END;
FUNCTION create_param_array
RETURN param_array_type
IS
param_array param_array_type;
BEGIN
param_array('UCsga use') := null;
param_array('UCpga use') := null;
param_array('UChost mem') := null;
param_array('UCbuffer cache') := null;
param_array('NCsga target') := null;
param_array('NCpga target') := null;
RETURN param_array;
END;
FUNCTION create_meta_info_array RETURN meta_info_array_type
IS
meta_info_array meta_info_array_type;
BEGIN
meta_info_array('MIend snap date') := null;
RETURN meta_info_array;
END;
PROCEDURE analyze_report (report_name IN VARCHAR2, param_array IN OUT param_array_type, meta_info_array IN OUT meta_info_array_type)
IS
report_file UTL_FILE.FILE_TYPE;
report_line VARCHAR2(32767);
BEGIN 
report_file := UTL_FILE.FOPEN(report_dir, report_name, 'R');
LOOP
UTL_FILE.GET_LINE(report_file, report_line);
IF report_line IS NOT NULL THEN
set_param_with_val(report_line, param_array, meta_info_array);
END IF;
END LOOP;
EXCEPTION
when NO_DATA_FOUND then
UTL_FILE.FCLOSE(report_file);
WHEN OTHERS THEN dbms_output.put_line('Error occurred > ' || SQLERRM);
END;
PROCEDURE set_param_with_val (report_line IN VARCHAR2, param_array IN OUT param_array_type, meta_info_array IN OUT meta_info_array_type)
IS
BEGIN
    IF meta_info_array('MIend snap date') IS NULL AND LOWER(report_line) LIKE '%end snap:%' THEN 
        meta_info_array('MIend snap date') := split_varchar_by_space(report_line, 'snap:', 2);
    END IF;
    IF param_array('UCbuffer cache') IS NULL AND LOWER(report_line) LIKE '%buffer cache:%' THEN 
        param_array('UCbuffer cache') := get_num_val_from_line(report_line, 'cache');
    END IF;
    IF param_array('UCsga use') IS NULL AND LOWER(report_line) LIKE '%sga use (%' THEN 
        param_array('UCsga use') := get_num_val_from_line(report_line, 'B)', 2);
    END IF;
    IF param_array('UCpga use') IS NULL AND LOWER(report_line) LIKE '%pga use (%' THEN 
        param_array('UCpga use') := get_num_val_from_line(report_line, 'B)', 2);
    END IF;
    IF param_array('UChost mem') IS NULL AND LOWER(report_line) LIKE '%host mem (%' THEN 
        param_array('UChost mem') := get_num_val_from_line(report_line, 'B)', 2);
    END IF;
    IF param_array('NCsga target') IS NULL AND LOWER(report_line) LIKE 'sga target%' THEN 
        param_array('NCsga target') := get_num_val_from_line(report_line, 'target');
    END IF;
    IF param_array('NCpga target') IS NULL AND LOWER(report_line) LIKE 'pga target%' THEN 
        param_array('NCpga target') := get_num_val_from_line(report_line, 'target');
    END IF;
END;
FUNCTION get_num_val_from_line(report_line IN VARCHAR2, key_word IN VARCHAR2, value_order IN NUMBER DEFAULT 1)
RETURN NUMBER
IS
temp_val VARCHAR2(45);
BEGIN
	temp_val := split_varchar_by_space(report_line, key_word, value_order);
	IF temp_val IS NOT NULL THEN
		temp_val := TO_NUMBER(regexp_replace(temp_val, '[A-Za-z,]'));
	END IF;
	RETURN temp_val;
END;
FUNCTION split_varchar_by_space(report_line IN VARCHAR2, key_word IN VARCHAR2, value_order IN NUMBER DEFAULT 1) 
RETURN VARCHAR2
IS
    temp_index INTEGER := -1;
    number_of_separators NUMBER := regexp_count(report_line, '[^ ]+');
    number_of_words NUMBER := number_of_separators + 1;
BEGIN
FOR CURRENT_ROW IN (
      select rownum, regexp_substr(report_line, '[^ ]+', 1, rownum) word
      from dual
      connect by level <= number_of_words)
  LOOP
    --IF CURRENT_ROW.word = key_word THEN
    IF instr(lower(CURRENT_ROW.word),lower(key_word),1) > 0 THEN
         temp_index := current_row.rownum + value_order;
    END IF;
    IF current_row.rownum = temp_index THEN
        RETURN CURRENT_ROW.word;
    END IF;
  END LOOP;
	RETURN NULL;
END;
PROCEDURE compare_and_display_params (
	param_array_old IN OUT param_array_type, 
	param_array_new IN OUT param_array_type, 
	meta_info_array_old IN OUT meta_info_array_type, 
	meta_info_array_new IN OUT meta_info_array_type)
IS
param varchar2(45);
param_cat varchar2(2);
old_value NUMBER;
new_value NUMBER;
loop_counter INTEGER;
BEGIN
	order_param_arrays(param_array_old, param_array_new, meta_info_array_old, meta_info_array_new);
	param := param_array_old.first;
	while (param is not null) loop
		param_cat := SUBSTR(param,1,2);
		dbms_output.put_line(chr(10) || UPPER(SUBSTR(param, 3)));
		FOR loop_counter IN 0..15 LOOP
			dbms_output.put('~');
		END LOOP;
		DBMS_OUTPUT.put_line(' ');
		old_value := param_array_old(param);
		new_value := param_array_new(param);
		IF old_value IS NULL AND new_value IS NULL THEN
			dbms_output.put_line(chr(9) || 'Parameter values not found');
		ELSE
			IF old_value IS NULL THEN
				dbms_output.put_line(chr(9) || 'Old value not found');
				IF new_value IS NULL THEN
					dbms_output.put_line(chr(9) || 'New value not found');
				ELSE
					dbms_output.put_line(chr(9) || 'New value: ' || new_value);
				END IF;
			ELSE
				dbms_output.put_line(chr(9) || 'Old value: ' || old_value);
				IF new_value IS NULL THEN
					dbms_output.put_line(chr(9) || 'New value not found');
				ELSE
					dbms_output.put_line(chr(9) || 'New value: ' || new_value);
					IF param_cat = 'UC' THEN
						compare_values(old_value, new_value);	
					END IF;
				END IF;
			END IF;
		END IF;
		param := param_array_old.next(param);
	end loop;
END;
PROCEDURE order_param_arrays(
	param_array_old IN OUT param_array_type, 
	param_array_new IN OUT param_array_type, 
	meta_info_array_old IN OUT meta_info_array_type, 
	meta_info_array_new IN OUT meta_info_array_type)
IS
temp_param_array param_array_type := param_array_type();
temp_meta_info_array meta_info_array_type := meta_info_array_type();
BEGIN
	IF meta_info_array_old('MIend snap date') IS NULL OR meta_info_array_new('MIend snap date') IS NULL THEN
		dbms_output.put_line(chr(9) || '-> COULDN''T FIND END SNAPSHOTS CREATION DATES, REPORT ORDER WAS GIVEN BY USER <-');
	ELSE
		IF TO_DATE(meta_info_array_old('MIend snap date')) > TO_DATE(meta_info_array_new('MIend snap date')) THEN
			temp_param_array := param_array_old;
			param_array_old := param_array_new;
			param_array_new := temp_param_array;
			temp_meta_info_array := meta_info_array_old;
			meta_info_array_old := meta_info_array_new;
			meta_info_array_new := temp_meta_info_array;
		END IF;
	END IF;
END;
PROCEDURE compare_values(exp_worse_val IN NUMBER, exp_better_val IN NUMBER)
IS
param_diff NUMBER := 0;
BEGIN
	IF exp_better_val = exp_worse_val THEN 
		dbms_output.put_line(chr(9) || '--> Parameter value did''t change');
	ELSE
		IF exp_better_val > exp_worse_val THEN 
			dbms_output.put_line(chr(9) || '--> Parameter value got better!');
		ELSE
			dbms_output.put_line(chr(9) || '--> Parameter value got worse');
		END IF;
		param_diff := exp_better_val-exp_worse_val;
		dbms_output.put_line(chr(9) || '---> Difference between new value and old value is: ' ||  param_diff);
	END IF;
END;
END;
/

