#################################################################
CREATE FUNCTION fnPOSSD_GetFileDates(@IsStartDate BIT) 
RETURNS DATETIME 
AS 
BEGIN 

DECLARE @startDateName NVARCHAR(50) = 'AmnCfg_FPDate',
        @endDateName NVARCHAR(50) = 'AmnCfg_EPDate'
DECLARE @date DATETIME;

  SET @date = (SELECT 
	           CASE ISDATE([Value]) WHEN 1 THEN CONVERT(DATETIME, [Value]) ELSE CONVERT(DATETIME, [Value], 105) END 
		       FROM op000 
			   WHERE Name = CASE @IsStartDate WHEN 1 THEN  @startDateName ELSE @endDateName END)

  RETURN  @date
END
#################################################################
CREATE FUNCTION FnStringLibSplitString(@List NVARCHAR(MAX),@Delimiter NVARCHAR(255)) 
RETURNS TABLE
AS
	/*******************************************************************************************************
	Company : Syriansoft
	SP : FnStringLibSplitString
	Purpose: split string based on specfied delimiter
	Create By: Hanadi Salka													Created On: 19 Nov 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
RETURN
  WITH E1(N)        AS ( SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 
                         UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 
                         UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1),
       E2(N)        AS (SELECT 1 FROM E1 a, E1 b),
       E4(N)        AS (SELECT 1 FROM E2 a, E2 b),
       E42(N)       AS (SELECT 1 FROM E4 a, E2 b),
       cteTally(N)  AS (SELECT 0 UNION ALL SELECT TOP (DATALENGTH(ISNULL(@List,1))) 
                         ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM E42),
       cteStart(N1) AS (SELECT t.N+1 FROM cteTally t
                         WHERE (SUBSTRING(@List,t.N,1) = @Delimiter OR t.N = 0))
  SELECT Item = SUBSTRING(@List, s.N1, ISNULL(NULLIF(CHARINDEX(@Delimiter,@List,s.N1),0)-s.N1,8000))
  FROM cteStart s;
#################################################################
#END 