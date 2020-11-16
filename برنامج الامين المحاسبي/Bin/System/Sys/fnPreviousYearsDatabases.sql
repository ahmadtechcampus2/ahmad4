##################################################################################
CREATE FUNCTION fnPreviousYearsDatabases()
RETURNS @result Table
(
	[DatabaseName] NVARCHAR(255),
	DataSourceGuid UNIQUEIDENTIFIER
) 
AS
BEGIN
	INSERT INTO @result
	SELECT [DatabaseName], [Guid] FROM ReportDataSources000
	WHERE DatabaseName <> DB_NAME() AND DatabaseName NOT IN (SELECT DatabaseName FROM FinancialCycleInfo000)
	RETURN
END
##################################################################################
CREATE FUNCTION fnFinancialCyclesInfo()
RETURNS @result Table
(
	[CycleGuid]	UNIQUEIDENTIFIER, 
	[DatabaseName]	NVARCHAR(255),
	[FileName]	NVARCHAR(255),
	[CycleName]	NVARCHAR(255),
	OpeningDate DATETIME,
	EndingDate DATETIME,
	Number INT
) 
AS
BEGIN
	INSERT INTO @result
	SELECT FC.[Guid], FC.DatabaseName, FC.[FileName], FC.Name, FC.FirstPeriod, FC.EndPeriod, Number
	FROM FinancialCycleInfo000 FC 

	RETURN
END
##################################################################################
#END