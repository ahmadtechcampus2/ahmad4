#########################################################################
CREATE PROCEDURE PrcGetPriceStudyOfMaterials
@Gr AS [UNIQUEIDENTIFIER]= 0x0,
@StartDate DateTime = '1/1/1980',
@EndDate DAteTime = '1/1/2100',
@ReportSource UNIQUEIDENTIFIER = 0x00,
@isCancled BIT = 0  ,
@isFinished BIT = 0  
AS
SET NOCOUNT ON 
-------Bill Resource ------------------------------------------------------------------------------------------------        
CREATE TABLE #Src ( Guid UNIQUEIDENTIFIER, Sec INT,ReadPrice INT, UnPostedSec INT , OrderName NVARCHAR(15) default '',OrderLatinName NVARCHAR(15) default '')  
INSERT INTO #Src (Guid , Sec , ReadPrice , UnPostedSec)  
EXEC prcGetBillsTypesList2 @ReportSource  
----------------------------------------------------------------------------------------------------------------------
SELECT fm.Name, mn.Guid 
INTO #Forms
FROM mn000 mn INNER JOIN fm000 fm ON fm.Guid = mn.FormGuid WHERE Type  =  0 -- ‰„«–Ã
----------------------------------------------------------------------------------------------------------------------
SELECT  mi.MatGuid ,mt.Code MatCode, mt.Name MatName, mi.ParentGuid, mi.Type, mt.Unity MatUnit , mt.Qty StoreMatQty 
INTO #RawMat
FROM mi000 mi INNER JOIN mt000 mt ON mt.Guid = mi.MatGuid  
WHERE mi.Type= 1 --„«œ… √Ê·Ì…
----------------------------------------------------------------------------------------------------------------------
SELECT bi.MatGuid , SUM(CASE bi.Unity WHEN 1 then bi.Qty when 2 then bi.Qty * Unit2Fact when  3 then bi.Qty * Unit3Fact else bi.Qty END ) OrderMatQty  
INTO #ORDERS
FROM bi000 bi INNER JOIN bu000 bu ON bu.Guid = bi.ParentGuid
	      INNER JOIN  OrAddInfo000 OInfo ON OInfo.ParentGuid = bu.Guid
	      INNER JOIN #Src bt ON bt.Guid = bu.TypeGuid 
	      INNER JOIN mt000 mt ON mt.Guid = bi.MatGuid
WHERE bu.Date BETWEEN @StartDate AND @EndDate 
AND  (OInfo.Finished =( Case @isFinished WHEN 0 THEN 0 else OInfo.Finished end  ) )
AND (OInfo.Add1 =( Case @isCancled WHEN 0 THEN '0' else OInfo.Add1 end  ) )	
AND  mt.GroupGUID = Case @Gr when 0x00 then mt.GroupGUID ELSE @Gr END
GROUP BY bi.MatGuid
------------------------------------------------------------------------------------------------------------
SELECT RawMat.MatGuid, RawMat.MatCode, RawMat.MatName,f.Name, RawMat.MatUnit , RawMat.StoreMatQty , Orders.OrderMatQty  
FROM #RawMat RawMat INNER JOIN #ORDERS ORDERS ON ORDERS.MatGuid = RawMat.MatGuid
		    INNER JOIN #Forms f ON f.Guid = RawMat.ParentGuid ORDER BY RawMat.MatCode
#########################################################################
CREATE PROCEDURE PrcGetProductionPlan
@StartDate DateTime = '1/1/1980',
@EndDate DAteTime = '1/1/2100',
@Week bit = 0,
@Month bit = 0
AS
SET NOCOUNT ON 
CREATE TABLE #EndResult (StrDate NVARCHAR(50), FormGuid UNIQUEIDENTIFIER , FormName NVARCHAR(50), FormQty FLOAT)

SELECT fm.Name, FM.Guid 
INTO #Forms
FROM mn000 mn INNER JOIN fm000 fm ON fm.Guid = mn.FormGuid WHERE Type  =  0 -- ‰„«–Ã
----------------------------------------------------------------------------------------------------------------------

SELECT CONVERT(NVARCHAR(2),DATEPART(Day , PSI.StartDate)) AS DayNum,
       CONVERT(NVARCHAR(1),DATEPART(WEEK , PSI.StartDate)) AS WeekNum ,
       CONVERT(NVARCHAR(2),DATEPART(Month , PSI.StartDate)) AS  MonthNum,
       CONVERT(NVARCHAR(4),DATEPART(YEAR , PSI.StartDate)) AS YearNum, PSI.StartDate, PSI.FormGuid, f.Name FormName, PSI.QTY FormQty
INTO #Result
FROM PSI000 PSI  INNER JOIN #Forms f ON PSI.FormGuid = f.Guid
WHERE PSI.StartDate BETWEEN @StartDate AND @EndDate

IF @Week = 1
BEGIN
	INSERT INTO #EndResult	SELECT WeekNum + '/' + MonthNum + '/' + YearNum, FormGuid, FormName, FormQty FROM #Result
END
ELSE IF @Month = 1
BEGIN
	INSERT INTO #EndResult SELECT MonthNum + '/' + YearNum, FormGuid, FormName, FormQty FROM #Result
END
ELSE
BEGIN
	INSERT INTO #EndResult SELECT  Convert(NVARCHAR(50),StartDate) StrDate ,FormGuid, FormName, FormQty FROM #Result
END

select StrDate StartDate, FormGuid, FormName, Sum(FormQty) FormQty from #EndResult
Group BY StrDate, FormGuid, FormName
#########################################################################
#END