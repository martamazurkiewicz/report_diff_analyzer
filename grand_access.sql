SET SERVEROUTPUT ON;
CREATE OR REPLACE PROCEDURE grand_access (os_path VARCHAR2) 
IS 
    dirSQL varchar2(4000);
BEGIN 
    dirSQL := 'CREATE OR REPLACE DIRECTORY report_dir AS ''' || os_path || '''';
    EXECUTE IMMEDIATE(dirSQL);
    dirSQL := 'GRANT READ, WRITE ON DIRECTORY report_dir TO perfstat';
    EXECUTE IMMEDIATE(dirSQL);
EXCEPTION
    WHEN OTHERS THEN dbms_output.put_line(SQLERRM);
END;
/

