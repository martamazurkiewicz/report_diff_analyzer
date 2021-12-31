SET SERVEROUTPUT ON;
CREATE OR REPLACE PACKAGE report_diff_analyzer AS 
	TYPE param_data_type IS RECORD (
		description VARCHAR2(45), 
		key_phrase1 VARCHAR2(45), 
		key_phrase2 VARCHAR2(45), 
		key_word VARCHAR2(45), 
		word_offset1 INTEGER, 
		word_offset2 INTEGER,
		upper_comp BOOLEAN);
	TYPE param_value_type IS RECORD (
		old_value NUMBER,
		new_value NUMBER,
		param_diff NUMBER,
		threshold_message VARCHAR2(150));

	TYPE param_array_type IS TABLE OF param_data_type INDEX BY VARCHAR2(45);
	TYPE param_value_array_type IS TABLE OF param_value_type INDEX BY VARCHAR2(45);
	TYPE temp_array_type IS TABLE OF VARCHAR2(70) INDEX BY VARCHAR2(45);
	PROCEDURE compare_reports(
		old_report_name IN VARCHAR2, 
		new_report_name IN VARCHAR2);
	PROCEDURE check_if_reports_exist(
		old_report_name IN VARCHAR2, 
		new_report_name IN VARCHAR2);
	PROCEDURE analyze_report(
		report_name IN VARCHAR2, 
		temp_array IN OUT temp_array_type,
		rep_creation_date IN OUT DATE);
	PROCEDURE set_val(
		report_line IN VARCHAR2, 
		temp_array IN OUT temp_array_type,
		rep_creation_date IN OUT DATE);
	PROCEDURE set_date_from_line(
		report_line IN VARCHAR2, 
		rep_creation_date IN OUT DATE);
	PROCEDURE set_value_from_line(
		report_line IN VARCHAR2, 
		temp_array IN OUT temp_array_type,
		param_name IN VARCHAR2);
	PROCEDURE set_sum_value_from_line(
		report_line IN VARCHAR2, 
		temp_array IN OUT temp_array_type,
		param_name IN VARCHAR2);
	FUNCTION get_num_val_from_line(
		report_line IN VARCHAR2, 
		key_word IN VARCHAR2, 
		word_offset IN INTEGER) RETURN NUMBER;
	FUNCTION get_value_from_line(
		report_line IN VARCHAR2, 
		key_word IN VARCHAR2, 
		word_offset IN INTEGER) RETURN VARCHAR2;
	PROCEDURE check_rep_order_and_populate_val_arrays;
	PROCEDURE populate_param_arrays_in_order;
	PROCEDURE display_rep_creation_date(
		exp_old_creation_date IN DATE,
		exp_new_creation_date IN DATE);
	PROCEDURE populate_value_arrays(
		first_temp_array IN temp_array_type,
		second_temp_array IN temp_array_type);
	PROCEDURE set_diff_values;
	PROCEDURE display_params;
	PROCEDURE display_value(
		param_value IN NUMBER,
		text_arg IN VARCHAR2);
	PROCEDURE display_decoration_chars;
	PROCEDURE compare_values(
	param_name IN VARCHAR2);
	PROCEDURE display_comparison(
		param_diff IN NUMBER);
	PROCEDURE init_package_variables;
	PROCEDURE init_param_array;
	PROCEDURE init_value_array;
	PROCEDURE init_temp_array(temp_array IN OUT temp_array_type);
	PROCEDURE display_suggestion(
	param_name IN VARCHAR2);
	PROCEDURE set_threshold_messages;
END;
/



CREATE OR REPLACE PACKAGE BODY report_diff_analyzer AS 
	REPORT_DIR VARCHAR2(20) := 'REPORT_DIR';
	creation_date_old_rep DATE := null;
	creation_date_new_rep DATE := null;
	param_array param_array_type;
	value_array param_value_array_type;
	temp_array_old temp_array_type;
	temp_array_new temp_array_type;

PROCEDURE compare_reports(
	old_report_name IN VARCHAR2, 
	new_report_name IN VARCHAR2) 
IS
BEGIN
	check_if_reports_exist(old_report_name, new_report_name);	
	dbms_output.put_line('~~~ STATSPACK REPORTS COMPARISON -->');
	init_package_variables();
	analyze_report(old_report_name, temp_array_old, creation_date_old_rep);
	analyze_report(new_report_name, temp_array_new, creation_date_new_rep);
	check_rep_order_and_populate_val_arrays();
	set_diff_values();
	set_threshold_messages();
	display_params();
	dbms_output.put_line(chr(10) || '<-- STATSPACK REPORTS COMPARISON ~~~');
EXCEPTION
	WHEN OTHERS THEN
		UTL_FILE.FCLOSE_ALL;
		dbms_output.put_line('Error occurred > ' || SQLERRM);
END;


PROCEDURE check_if_reports_exist(
	old_report_name IN VARCHAR2, 
	new_report_name IN VARCHAR2) 
IS
	fexists_old BOOLEAN;
	fexists_new BOOLEAN;
	file_length_old NUMBER;
	file_length_new NUMBER;
	block_size_old BINARY_INTEGER;
	block_size_new BINARY_INTEGER;
BEGIN
	UTL_FILE.FGETATTR(REPORT_DIR, old_report_name, fexists_old, file_length_old, block_size_old);
	UTL_FILE.FGETATTR(REPORT_DIR, new_report_name, fexists_new, file_length_new, block_size_new);
	IF NOT fexists_old OR NOT fexists_new THEN
		RAISE UTL_FILE.INVALID_FILENAME;
	END IF;
END;


PROCEDURE analyze_report(
	report_name IN VARCHAR2, 
	temp_array IN OUT temp_array_type,
	rep_creation_date IN OUT DATE)
IS
	report_file UTL_FILE.FILE_TYPE;
	report_line VARCHAR2(32767);
BEGIN 
	report_file := UTL_FILE.FOPEN(REPORT_DIR, report_name, 'R');
	LOOP
		UTL_FILE.GET_LINE(report_file, report_line);
		IF report_line IS NOT NULL THEN
			set_val(report_line, temp_array, rep_creation_date);
		END IF;
	END LOOP;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
	UTL_FILE.FCLOSE_ALL;
END;


PROCEDURE set_val(
	report_line IN VARCHAR2, 
	temp_array IN OUT temp_array_type,
	rep_creation_date IN OUT DATE)
IS
	param_name VARCHAR2(45);
BEGIN
	set_date_from_line(report_line, rep_creation_date);
	param_name := param_array.first;
	WHILE (param_name IS NOT NULL) LOOP
		IF param_array(param_name).key_phrase2 IS NULL THEN
			set_value_from_line(report_line, temp_array, param_name);
		ELSE
			set_sum_value_from_line(report_line, temp_array, param_name);
		END IF;
		param_name := param_array.next(param_name);
	END LOOP;
END;


PROCEDURE set_date_from_line(
	report_line IN VARCHAR2, 
	rep_creation_date IN OUT DATE)
IS
BEGIN
	IF rep_creation_date IS NULL AND LOWER(report_line) LIKE '%end snap:%' THEN 
		rep_creation_date := get_value_from_line(report_line, 'snap:', 2);
	END IF;
END;


PROCEDURE set_value_from_line(
	report_line IN VARCHAR2, 
	temp_array IN OUT temp_array_type,
	param_name IN VARCHAR2)
IS
BEGIN
	IF temp_array(param_name) IS NULL AND LOWER(report_line) LIKE param_array(param_name).key_phrase1 THEN 
		temp_array(param_name) := get_num_val_from_line(
			report_line, 
			param_array(param_name).key_word, 
			param_array(param_name).word_offset1);
	END IF;
END;


PROCEDURE set_sum_value_from_line(
	report_line IN VARCHAR2, 
	temp_array IN OUT temp_array_type,
	param_name IN VARCHAR2)
IS
value_at_st_pos NUMBER;
value_at_nd_pos NUMBER;
BEGIN
	IF temp_array(param_name) IS NULL 
		AND LOWER(report_line) LIKE param_array(param_name).key_phrase1 
		AND LOWER(report_line) LIKE param_array(param_name).key_phrase2 THEN 
			value_at_st_pos := get_num_val_from_line(
				report_line, 
				param_array(param_name).key_word, 
				param_array(param_name).word_offset1);
			value_at_nd_pos := get_num_val_from_line(
				report_line, 
				param_array(param_name).key_word, 
				param_array(param_name).word_offset2);
			temp_array(param_name) := value_at_nd_pos + value_at_st_pos;
	END IF;
END;


FUNCTION get_num_val_from_line(
	report_line IN VARCHAR2, 
	key_word IN VARCHAR2, 
	word_offset IN INTEGER)
RETURN NUMBER
IS
temp_val VARCHAR2(45);
BEGIN
	temp_val := get_value_from_line(report_line, key_word, word_offset);
	IF temp_val IS NOT NULL THEN
		temp_val := TO_NUMBER(regexp_replace(temp_val, '[A-Za-z,]'));
	END IF;
	RETURN temp_val;
END;


FUNCTION get_value_from_line(
	report_line IN VARCHAR2, 
	key_word IN VARCHAR2, 
	word_offset IN INTEGER) 
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
		IF instr(lower(word_row.single_word),lower(key_word),1) > 0 THEN
			temp_index := word_row.rownum + word_offset;
		END IF;
		IF word_row.rownum = temp_index THEN
			RETURN word_row.single_word;
		END IF;
	END LOOP;
	RETURN NULL;
END;

PROCEDURE check_rep_order_and_populate_val_arrays
IS
BEGIN
	IF creation_date_new_rep IS NULL OR creation_date_old_rep IS NULL THEN
		dbms_output.put_line(chr(9) || '-> COULDN''T FIND END SNAPSHOTS CREATION DATES, REPORT ORDER WAS GIVEN BY USER <-');
		populate_value_arrays(temp_array_old, temp_array_new);
	ELSE
		IF TO_DATE(creation_date_new_rep) > TO_DATE(creation_date_old_rep) THEN
			display_rep_creation_date(creation_date_old_rep, creation_date_new_rep);
		ELSE
			display_rep_creation_date(creation_date_new_rep, creation_date_old_rep);
		END IF;
		populate_param_arrays_in_order();
	END IF;
END;

PROCEDURE display_rep_creation_date(
	exp_old_creation_date IN DATE,
	exp_new_creation_date IN DATE)
IS
BEGIN
	dbms_output.put_line(chr(9) || '-> Old report''s end snapshot creation date: ' || exp_old_creation_date || ' <-');
	dbms_output.put_line(chr(9) || '-> New report''s end snapshot creation date: ' || exp_new_creation_date || ' <-');
END;

PROCEDURE populate_param_arrays_in_order
IS
BEGIN
	IF TO_DATE(creation_date_new_rep) > TO_DATE(creation_date_old_rep) THEN
		populate_value_arrays(temp_array_old, temp_array_new);
	ELSE
		populate_value_arrays(temp_array_new, temp_array_old);
	END IF;
END;

PROCEDURE populate_value_arrays(
	first_temp_array IN temp_array_type,
	second_temp_array IN temp_array_type)
IS 
	param_name VARCHAR2(45);
BEGIN
	param_name := param_array.first;
	WHILE (param_name IS NOT NULL) LOOP
		value_array(param_name).old_value := first_temp_array(param_name);
		value_array(param_name).new_value := second_temp_array(param_name);
		param_name := param_array.next(param_name);
	END LOOP;
END;

PROCEDURE set_diff_values
IS
	param_name VARCHAR2(45);
BEGIN
	param_name := param_array.first;
	WHILE (param_name IS NOT NULL) LOOP
		IF param_array(param_name).upper_comp IS NOT NULL 
			AND value_array(param_name).old_value IS NOT NULL
			AND value_array(param_name).new_value IS NOT NULL THEN 
				IF param_array(param_name).upper_comp THEN
					value_array(param_name).param_diff := value_array(param_name).new_value - value_array(param_name).old_value;
				ELSE
					value_array(param_name).param_diff := value_array(param_name).old_value - value_array(param_name).new_value;
				END IF;
		END IF;
		param_name := param_array.next(param_name);
	END LOOP;
END;

PROCEDURE display_params
IS
	param_name VARCHAR2(45);
	param_index INTEGER := 1;
BEGIN
	param_name := param_array.first;
	WHILE (param_name IS NOT NULL) LOOP
		dbms_output.put_line(chr(10) || param_index || '. ' || UPPER(param_array(param_name).description));
		display_decoration_chars();
		IF value_array(param_name).old_value IS NULL AND 
			value_array(param_name).new_value IS NULL THEN
				dbms_output.put_line(chr(9) || 'Parameter values not found');
		ELSE
				display_value(value_array(param_name).old_value, 'Old');
				display_value(value_array(param_name).new_value, 'New');
				compare_values(param_name);
				display_suggestion(param_name);
		END IF;
		param_name := param_array.next(param_name);
		param_index := param_index + 1;
	END LOOP;
END;


PROCEDURE display_value(
	param_value IN NUMBER,
	text_arg IN VARCHAR2)
IS
BEGIN
	IF param_value IS NULL THEN
		dbms_output.put_line(chr(9) || text_arg || ' value not found');
	ELSE
		dbms_output.put_line(chr(9) || text_arg || ' value: ' || param_value);
	END IF;
END;


PROCEDURE display_decoration_chars
IS
	loop_counter INTEGER;
BEGIN
	FOR loop_counter IN 0..26 LOOP
			dbms_output.put('~');
	END LOOP;
	dbms_output.put_line(' ');
END;


PROCEDURE compare_values(
	param_name IN VARCHAR2)
IS
BEGIN
	IF value_array(param_name).param_diff IS NOT NULL THEN
		display_comparison(value_array(param_name).param_diff);
	END IF;
END;


PROCEDURE display_comparison(
	param_diff IN NUMBER)
IS
BEGIN
	IF param_diff = 0 THEN 
		dbms_output.put_line(chr(9) || '--> Parameter value did''t change');
	ELSIF param_diff > 0 THEN 
		dbms_output.put_line(chr(9) || '--> Parameter value got better!');
	ELSE
		dbms_output.put_line(chr(9) || '--> Parameter value got worse');
	END IF;
	dbms_output.put_line(chr(9) || '---> Difference between new value and old value is: ' ||  param_diff);
END;


PROCEDURE init_package_variables
IS
BEGIN
	creation_date_old_rep := null;
	creation_date_new_rep := null;
	init_param_array();
	init_value_array();
	init_temp_array(temp_array_old);
	init_temp_array(temp_array_new);
END;


PROCEDURE init_param_array
IS
BEGIN
	param_array('sga use') := param_data_type('sga use (MB)', '%sga use (%', null, 'B)', 2, null, FALSE);
	param_array('pga use') := param_data_type('pga use (MB)', '%pga use (%', null, 'B)', 2, null, FALSE);
	param_array('host mem') := param_data_type('host mem (MB)', '%host mem (%', null, 'B)', 2, null, TRUE);
	param_array('host mem %') := param_data_type('host mem used for sga+pga %', '%host mem used for%', null, 'pga', 2, null, FALSE);
	param_array('buffer cache') := param_data_type('buffer cache (MB)', '%buffer cache:%', null, 'cache', 1, null, FALSE);

	param_array('shared pool') := param_data_type('shared pool (MB)', 'shared pool%', null, 'pool', 1, null, FALSE);
	param_array('large pool') := param_data_type('large pool (MB)', 'large pool%', null, 'pool', 1, null, FALSE);
	param_array('java pool') := param_data_type('java pool (MB)', '%java pool%', null, 'pool', 1, null, FALSE);
	param_array('log buffer') := param_data_type('log buffer (KB)', '%log buffer:%', null, 'buffer', 1, null, FALSE);

	param_array('optimal wa exec') := param_data_type('optimal w/a exec %', '%optimal w/a exec%', null, '%', 1, null, null);
	param_array('soft parse') := param_data_type('soft parse %', '%soft parse%', null, '%', 1, null, TRUE);
	param_array('buffer hit') := param_data_type('buffer hit %', '%buffer  hit%', null, '%', 1, null, TRUE);
	param_array('library hit') := param_data_type('library hit %', '%library hit%', null, '%', 1, null, TRUE);

	param_array('buffer nowait') := param_data_type('buffer nowait %', '%buffer nowait%', null, '%', 1, null, TRUE);
	param_array('logical reads') := param_data_type('logical reads per s', '%logical reads%', null, 'reads', 1, null, FALSE);
	param_array('physical reads') := param_data_type('physical reads per s', '%physical reads%', null, 'reads', 1, null, FALSE);
	param_array('physical writes') := param_data_type('physical writes per s', '%physical writes%', null, 'writes', 1, null, FALSE);

	param_array('pga target') := param_data_type('pga target', 'pga target%', null, 'target', 1, null, null);
	param_array('sga target') := param_data_type('sga target', 'sga target%', null, 'target', 1, null, null);
	param_array('pga aggregate target') := param_data_type('pga aggregate target (B)', 'pga_aggregate_target%', null, 'target', 1, null, null);
	param_array('transactions') := param_data_type('transactions per s', '%transactions%', null, 'transactions', 1, null, FALSE);

	param_array('rollbacks') := param_data_type('rollbacks per s', '%rollbacks%', null, 'rollbacks', 1, null, FALSE);
	param_array('dbwr read') := param_data_type('dbwr data file read (MB)', '%dbwr%', '%data file%', 'file', 1, 3, FALSE);
	param_array('dbwr write') := param_data_type('dbwr data file write (MB)', '%dbwr%', '%data file%', 'file', 2, 4, FALSE);
	param_array('lgwr write') := param_data_type('lgwr log file write (MB)', '%lgwr%', '%log file%', 'file', 2, 4, FALSE);
END;


PROCEDURE init_value_array
IS
param_name VARCHAR2(45);
BEGIN
	param_name := param_array.first;
	WHILE (param_name IS NOT NULL) LOOP
		value_array(param_name) := param_value_type(null, null, null, null);
		param_name := param_array.next(param_name);
	END LOOP;
END;


PROCEDURE init_temp_array(temp_array IN OUT temp_array_type)
IS
param_name VARCHAR2(45);
BEGIN
	param_name := param_array.first;
	WHILE (param_name IS NOT NULL) LOOP
		temp_array(param_name) := null;
		param_name := param_array.next(param_name);
	END LOOP;
END;

PROCEDURE display_suggestion(
	param_name IN VARCHAR2)
IS
BEGIN
	IF value_array(param_name).threshold_message IS NOT NULL THEN
		dbms_output.put_line(chr(9) || '---> ' || value_array(param_name).threshold_message);
	END IF;
END;

PROCEDURE set_threshold_messages
IS
temp_val NUMBER;
BEGIN
	IF value_array('host mem').new_value IS NOT NULL THEN
		temp_val := 0.6 * value_array('host mem').new_value;
		value_array('sga use').threshold_message := 'Parameter value should be < 60% of host mem (< ' || temp_val || ' MB)';
		temp_val := 0.2 * value_array('host mem').new_value;
		value_array('pga use').threshold_message := 'Parameter value should be < 20% of host mem (< ' || temp_val || ' MB)';
		temp_val := 0.8 * value_array('host mem').new_value;
		value_array('host mem %').threshold_message := 'Parameter value should be < 80% of host mem (< ' || temp_val || ' MB)';
	END IF;
	IF value_array('sga use').new_value IS NOT NULL AND 
		value_array('pga use').new_value IS NOT NULL THEN
			temp_val := 1.25 * (value_array('sga use').new_value + value_array('pga use').new_value);
			value_array('host mem').threshold_message := 'Parameter value should be > 125% of PGA and SGA use sum (> ' || temp_val || ' MB)';
	END IF;
	IF value_array('optimal wa exec').new_value IS NOT NULL THEN
		value_array('soft parse').threshold_message := 'Parameter value should be equal optimal w/a exec % (~' || value_array('optimal wa exec').new_value || '%)';
	END IF;
	value_array('buffer hit').threshold_message := 'Parameter value should be close to 100%';
	value_array('library hit').threshold_message := 'Parameter value should be close to 100%';
	value_array('buffer nowait').threshold_message := 'Parameter value should be close to 100%';
END;

END;
/

