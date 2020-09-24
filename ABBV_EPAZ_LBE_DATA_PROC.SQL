/* Formatted on 9/24/2020 6:06:48 PM (QP5 v5.336) */
CREATE OR REPLACE PROCEDURE ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA_PROC
IS
    /****************************************************************************
    **
    NAME:       AMP_EPAZ_PROC
    PURPOSE:    The below Proc Initializes and sets the Commit Month and the COMMIT_STATUS for the costs incurred for the respective Plan activities
    REVISIONS:
    VER        DATE        AUTHOR           DESCRIPTION
    ---------  ----------  ---------------  ------------------------------------
    1.0        9/24/2020   SINGHAX48       1. CREATED THIS PROCEDURE.
    NOTES:
    AUTOMATICALLY AVAILABLE AUTO REPLACE KEYWORDS:
    OBJECT NAME:     AMP_EPAZ_PROC
    SYSDATE:         9/24/2020
    DATE AND TIME:   9/24/2020, 4:43:59 PM, AND 7/29/2020 4:43:59 PM
    USERNAME:        SINGHAX48 (SET IN TOAD OPTIONS, PROCEDURE EDITOR)
    TABLE NAME:       (SET IN THE "NEW PL/SQL OBJECT" DIALOG)
    *****************************************************************************/


    V_COUNT   NUMBER := 0;
	V_COUNT_2 NUMBER := 0;
	
BEGIN

--Check if ABBV_EPAZ_LBE_DATA_HISTORY table already contains the latest data that needs to be uploaded
BEGIN
    SELECT COUNT (*)
      INTO V_COUNT
      FROM ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA_HISTORY a
     WHERE EXISTS
               (SELECT '1'
                  FROM ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA b
                 WHERE a.BASELINE_NAME = b.BASELINE_NAME);
				 
	EXCEPTION WHEN NO_DATA_FOUND THEN
	V_COUNT:=0;
	END;
	
	----For 1st time entries in History table
	BEGIN
    SELECT COUNT (*)
      INTO V_COUNT_2
      FROM ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA_HISTORY  ;
				 
	EXCEPTION WHEN NO_DATA_FOUND THEN
	V_COUNT_2:=0;
	END;
				 


    IF V_COUNT > 0 OR V_COUNT_2=0 
    THEN
	--Delete Previous entries from History table for same Baseline data if exists
	
        DELETE FROM ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA_HISTORY a
              WHERE EXISTS
                        (SELECT '1'
                           FROM ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA b
                          WHERE a.BASELINE_NAME = b.BASELINE_NAME);

        INSERT INTO ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA_HISTORY
            SELECT BASELINE_NAME,
                   TA,
                   PROGRAM_NAME,
                   PAID,
                   PAID_NAME,
                   PROJECT_TYPE,
                   FINANCE_PROJECT,
                   PROJECT_STATUS,
                   FUNCTIONAL_AREA,
                   RES_NAME,
                   ACTIVITY,
                   TASK_STATUS,
                   PARTNER_SUPPORTED_ACTIVITY,
                   COMMIT_MONTH,
                   START_YEAR,
                   QUARTER,
                   MONTH,
                   COST_TYPE,
                   COST_THOUSANDS,
                   EPAZ_BASELINE_DATE,
                   PROGRAM_UPD,
                   SEQ_EPAZ_DATA.NEXTVAL
              FROM ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA;
    END IF;
	
----Truncate and Upload the new data in EPAZ table 

    EXECUTE IMMEDIATE ('TRUNCATE TABLE ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA');

    INSERT INTO ABBV_AMPR_OUTBOUND.ABBV_EPAZ_LBE_DATA
        SELECT A.BSL_NAME
                   BASELINE_NAME,
               B.THERAPEUTIC_AREA
                   TA,
               (CASE
                    WHEN B.ACTIVITY_PAID = 'G0999911'
                    THEN
                        'MILESTONE BS'
                    WHEN B.ACTIVITY_PAID = 'G0900153'
                    THEN
                        'MILESTONE C PLACEHOLDER'
                    ELSE
                        B.PROGRAM_NAME
                END)
                   AS PROGRAM,
               B.ACTIVITY_PAID
                   PAID,
               B.PROJECT_NAME
                   PAID_NAME,
               B.PROJECT_TYPE
                   PROJ_TYPE,
               B.DEVELOPMENT_COMPASS_CODE
                   FINANCE_PROJECT,
               B.PROJECT_STATUS
                   PROJ_STATUS,
               B.CABS_FUNCTION
                   FUNCTIONAL_AREA,
               B.CABS_NAME
                   RES_NAME,
               CASE
                   WHEN     B.ACTIVITY_TYPE = 'STUDY_CLINICAL'
                        AND TO_CHAR (STUDY_FSFD, 'YYYY') <
                            TO_CHAR (SYSDATE, 'YYYY')
                   THEN
                          B.PROTOCOL_NUMBER
                       || ' '
                       || B.ACTIVITY_NAME
                       || '(STARTUP)'
                   WHEN     B.ACTIVITY_TYPE = 'STUDY_CLINICAL'
                        AND TO_CHAR (STUDY_FSFD, 'YYYY') >=
                            TO_CHAR (SYSDATE, 'YYYY')
                   THEN
                          B.PROTOCOL_NUMBER
                       || ' '
                       || B.ACTIVITY_NAME
                       || '(MAIN)'
                   ELSE
                       B.PROTOCOL_NUMBER || ' ' || B.ACTIVITY_NAME
               END
                   AS ACTIVITY,
               B.BUDGET_STATUS
                   TASK_STATUS,
               CASE
                   WHEN B.PARTNER_SUPPORTED_ACTIVITY LIKE '%FALSE' THEN 'NO'
                   WHEN B.PARTNER_SUPPORTED_ACTIVITY LIKE '%TRUE' THEN 'YES'
               END
                   AS PARTNER_SUPPORTED,
               B.COMMIT_MONTH,
               EXTRACT (YEAR FROM B.START_DATE)
                   YEAR,
               CASE
                   WHEN EXTRACT (MONTH FROM B.START_DATE) IN (1, 2, 3)
                   THEN
                       1
                   WHEN EXTRACT (MONTH FROM B.START_DATE) IN (4, 5, 6)
                   THEN
                       2
                   WHEN EXTRACT (MONTH FROM B.START_DATE) IN (7, 8, 9)
                   THEN
                       3
                   WHEN EXTRACT (MONTH FROM B.START_DATE) IN (10, 11, 12)
                   THEN
                       4
               END
                   AS QUARTER,
               EXTRACT (MONTH FROM B.START_DATE)
                   MONTH,
               B.COMMIT_STATUS
                   COST_TYPE,
               B.COST
                   COST_THOUSANDS,
               INITCAP (
                   TO_CHAR (
                       TO_DATE (A.BSL_YEAR || '-' || A.BSL_MONTH, 'YYYY-MM'),
                       'MON-YY'))
                   EPAZ_BASELINE_DATE,
                  B.PROGRAM_NAME
               || '_'
               || (SELECT TA_ABBREVIATION
                     FROM ABBV_AMPR_BASELINE.TA_ABBRV
                    WHERE UPPER (TA) = UPPER (B.THERAPEUTIC_AREA))
                   AS PROGRAM_UPD
          FROM ABBV_AMPR_BASELINE.BSL_HDR A, ABBV_AMPR_BASELINE.LBE_COST_FINALIZATION B
         WHERE     A.BASELINE_HDR_ID = B.BASELINE_HDR_ID
               AND A.BSL_TYPE = 'CURRENT_MONTH_CET'
               AND (TO_CHAR (B.START_DATE, 'YYYY')) IN
                       ((TO_CHAR (SYSDATE, 'YYYY')),
                        (TO_CHAR (SYSDATE, 'YYYY')) + 1,
                        (TO_CHAR (SYSDATE, 'YYYY')) + 2);
						
 COMMIT;
EXCEPTION
WHEN OTHERS THEN
   PR_OBD_ERR_LOG('ERROR-'||SQLCODE,'ERROR-'||SQLERRM,'MODIFYING--ABBV_EPAZ_LBE_DATA','AMP-DB');
   
						
END ABBV_EPAZ_LBE_DATA_PROC;
