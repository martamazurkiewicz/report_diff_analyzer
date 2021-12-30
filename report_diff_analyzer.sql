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
FUNCTION get_value_from_line(report_line IN VARCHAR2, key_word IN VARCHAR2, value_order IN NUMBER DEFAULT 1) RETURN VARCHAR2;
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
PROCEDURE find_value(
	param_array IN OUT param_array_type,
	report_line IN VARCHAR2, 
	param_name IN VARCHAR2, 
	key_phrase IN VARCHAR2, 
	key_word VARCHAR2, 
	value_position IN NUMBER DEFAULT 1);
PROCEDURE find_sum_value(
	param_array IN OUT param_array_type,
	report_line IN VARCHAR2, 
	param_name IN VARCHAR2, 
	key_phrase_st IN VARCHAR2,
	key_phrase_nd IN VARCHAR2,  
	key_word VARCHAR2, 
	value_position_st IN NUMBER,
	value_position_nd IN NUMBER);
END;
/


CREATE OR REPLACE PACKAGE BODY report_diff_analyzer AS 
	report_dir VARCHAR2(20) := 'REPORT_DIR';
	param_array_old param_array_type;
	param_array_new param_array_type;
	meta_info_array_old meta_info_array_type;
	meta_info_array_new meta_info_array_type;


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


FUNCTION create_param_array RETURN param_array_type
IS
	param_array param_array_type;
BEGIN
	param_array('DCsga use') := null;
	param_array('DCpga use') := null;
	param_array('UChost mem') := null;
	param_array('DChost mem used for sga+pga %') := null;
	param_array('DCbuffer cache') := null;
	param_array('DCshared pool') := null;
	param_array('DClarge pool') := null;
	param_array('DCjava pool') := null;
	param_array('DClog buffer') := null;
	param_array('UCoptimal w/a exec %') := null;
	param_array('UCsoft parse %') := null;
	param_array('UCbuffer hit %') := null;
	param_array('UClibrary hit %') := null;
	param_array('UCbuffer nowait %') := null;
	param_array('DClogical reads per s') := null;
	param_array('DCphysical reads per s') := null;
	param_array('DCphysical writes per s') := null;
	param_array('NCpga target') := null;
	param_array('NCsga target') := null;
	param_array('NCpga aggregate target') := null;
	param_array('DCtransactions per s') := null;
	param_array('DCrollbacks per s') := null;
	param_array('DCdbwr data file read (MB)') := null;
	param_array('DCdbwr data file write (MB)') := null;
	param_array('DClgwr log file write (MB)') := null;
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
--WHEN OTHERS THEN 
	--dbms_output.put_line('Error occurred > ' || SQLERRM);
END;


PROCEDURE set_param_with_val (report_line IN VARCHAR2, param_array IN OUT param_array_type, meta_info_array IN OUT meta_info_array_type)
IS
BEGIN
	IF meta_info_array('MIend snap date') IS NULL AND LOWER(report_line) LIKE '%end snap:%' THEN 
		meta_info_array('MIend snap date') := get_value_from_line(report_line, 'snap:', 2);
	END IF;
	find_value(param_array, report_line, 'DCbuffer cache', '%buffer cache:%', 'cache');
	find_value(param_array, report_line, 'DCsga use', '%sga use (%', 'B)', 2);
	find_value(param_array, report_line, 'DCpga use', '%pga use (%', 'B)', 2);
	find_value(param_array, report_line, 'UChost mem', '%host mem (%', 'B)', 2);
	find_value(param_array, report_line, 'DChost mem used for sga+pga %', '%host mem used for%', 'pga', 2);
	find_value(param_array, report_line, 'DCshared pool', 'shared pool%', 'pool');
	find_value(param_array, report_line, 'DClarge pool', 'large pool%', 'pool');
	find_value(param_array, report_line, 'DCjava pool', '%java pool%', 'pool');
	find_value(param_array, report_line, 'DClog buffer', '%log buffer:%', 'buffer');
	find_value(param_array, report_line, 'UCoptimal w/a exec %', '%optimal w/a exec%', '%');
	find_value(param_array, report_line, 'UCsoft parse %', '%soft parse%', '%');
	find_value(param_array, report_line, 'UCbuffer hit %', '%buffer  hit%', '%');
	find_value(param_array, report_line, 'UClibrary hit %', '%library hit%', '%');
	find_value(param_array, report_line, 'UCbuffer nowait %', '%buffer nowait%', '%');
	find_value(param_array, report_line, 'DClogical reads per s', '%logical reads%', 'reads');
	find_value(param_array, report_line, 'DCphysical reads per s', '%physical reads%', 'reads');
	find_value(param_array, report_line, 'DCphysical writes per s', '%physical writes%', 'writes');
	find_value(param_array, report_line, 'NCsga target', 'sga target%', 'target');
	find_value(param_array, report_line, 'NCpga target', 'pga target%', 'target');
	find_value(param_array, report_line, 'NCpga aggregate target', 'pga_aggregate_target%', 'target');
	find_value(param_array, report_line, 'DCtransactions per s', '%transactions%', 'transactions');
	find_value(param_array, report_line, 'DCrollbacks per s', '%rollbacks%', 'rollbacks');
	find_sum_value(param_array, report_line, 'DCdbwr data file read (MB)', '%dbwr%', '%data file%', 'file', 1, 3);
	find_sum_value(param_array, report_line, 'DCdbwr data file write (MB)', '%dbwr%', '%data file%', 'file', 2, 4);
	find_sum_value(param_array, report_line, 'DClgwr log file write (MB)', '%lgwr%', '%log file%', 'file', 2, 4);
END;


FUNCTION get_num_val_from_line(report_line IN VARCHAR2, key_word IN VARCHAR2, value_order IN NUMBER DEFAULT 1)
RETURN NUMBER
IS
temp_val VARCHAR2(45);
BEGIN
	temp_val := get_value_from_line(report_line, key_word, value_order);
	IF temp_val IS NOT NULL THEN
		temp_val := TO_NUMBER(regexp_replace(temp_val, '[A-Za-z,]'));
	END IF;
	RETURN temp_val;
END;


FUNCTION get_value_from_line(report_line IN VARCHAR2, key_word IN VARCHAR2, value_order IN NUMBER DEFAULT 1) 
RETURN VARCHAR2
IS
    temp_index INTEGER := -1;
    number_of_separators NUMBER := regexp_count(report_line, '[^ ]+');
    number_of_words NUMBER := number_of_separators + 1;
BEGIN
FOR word_row IN (
    SELECT rownum, REGEXP_SUBSTR(report_line, '[^ ]+', 1, rownum) single_word
    FROM dual
    CONNECT BY LEVEL <= number_of_words)
	LOOP
		--IF word_row.word = key_word THEN
		IF instr(lower(word_row.single_word),lower(key_word),1) > 0 THEN
			temp_index := word_row.rownum + value_order;
		END IF;
			IF word_row.rownum = temp_index THEN
				RETURN word_row.single_word;
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
	param_index INTEGER := 1;
BEGIN
	dbms_output.put_line('~~~ STATSPACK REPORTS COMPARISON -->');
	order_param_arrays(param_array_old, param_array_new, meta_info_array_old, meta_info_array_new);
	param := param_array_old.first;
	WHILE (param IS NOT NULL) LOOP
		param_cat := SUBSTR(param,1,2);
		dbms_output.put_line(chr(10) || param_index || '. ' || UPPER(SUBSTR(param, 3)));
		FOR loop_counter IN 0..26 LOOP
			dbms_output.put('~');
		END LOOP;
		dbms_output.put_line(' ');
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
					ELSIF param_cat = 'DC' THEN
						compare_values(new_value, old_value);
					END IF;

				END IF;
			END IF;
		END IF;
		param := param_array_old.next(param);
		param_index := param_index + 1;
	END LOOP;
	dbms_output.put_line(chr(10) || '<-- STATSPACK REPORTS COMPARISON ~~~');
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


PROCEDURE find_value(
	param_array IN OUT param_array_type,
	report_line IN VARCHAR2, 
	param_name IN VARCHAR2, 
	key_phrase IN VARCHAR2, 
	key_word VARCHAR2, 
	value_position IN NUMBER DEFAULT 1)
IS
BEGIN
	IF param_array(param_name) IS NULL AND LOWER(report_line) LIKE key_phrase THEN 
		param_array(param_name) := get_num_val_from_line(report_line, key_word, value_position);
	END IF;
END;

PROCEDURE find_sum_value(
	param_array IN OUT param_array_type,
	report_line IN VARCHAR2, 
	param_name IN VARCHAR2, 
	key_phrase_st IN VARCHAR2,
	key_phrase_nd IN VARCHAR2,  
	key_word VARCHAR2, 
	value_position_st IN NUMBER,
	value_position_nd IN NUMBER)
IS
value_at_st_pos NUMBER;
value_at_nd_pos NUMBER;
BEGIN
	IF param_array(param_name) IS NULL AND LOWER(report_line) LIKE key_phrase_st AND LOWER(report_line) LIKE key_phrase_nd THEN 
		value_at_st_pos := get_num_val_from_line(report_line, key_word, value_position_st);
		value_at_nd_pos := get_num_val_from_line(report_line, key_word, value_position_nd);
		value_at_nd_pos := value_at_nd_pos + value_at_st_pos;
		param_array(param_name) := value_at_nd_pos; 
	END IF;
END;


END;
/
