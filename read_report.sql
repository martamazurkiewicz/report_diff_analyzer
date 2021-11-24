CREATE OR REPLACE PROCEDURE read_report (report_path VARCHAR2, report_name VARCHAR2) IS report_file UTL_FILE.FILE_TYPE;
text_buffer VARCHAR2(32767);
BEGIN report_file := UTL_FILE.FOPEN(report_path, report_name, 'R');
LOOP
UTL_FILE.GET_LINE(report_file, text_buffer);
dbms_output.put_line(text_buffer);
END LOOP;
EXCEPTION
when NO_DATA_FOUND then
UTL_FILE.FCLOSE(report_file);
WHEN OTHERS THEN dbms_output.put_line(SQLERRM);
END;
/