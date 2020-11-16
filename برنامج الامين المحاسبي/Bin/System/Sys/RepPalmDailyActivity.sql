##############################################################
CREATE PROCEDURE RepPalmDailyActivity
	@DistGuid	AS	UNIQUEIDENTIFIER,
	@SrcGuid	AS	UNIQUEIDENTIFIER,
	@StartDate	AS	DATETIME,
	@EndDate	AS	DATETIME

AS
	SET NOCOUNT ON

	DECLARE @UserId UNIQUEIDENTIFIER
	SET @UserId = dbo.fnGetCurrentUserGUID()

	CREATE TABLE #BillTbl (Type 	UNIQUEIDENTIFIER, Security 	INT, ReadPriceSecurity	INT, UnPostedSecurity	INT) 
	CREATE TABLE #EntryTbl(Type 	UNIQUEIDENTIFIER, Security  INT)  

	INSERT INTO #BillTbl EXEC prcGetBillsTypesList2 @SrcGuid, @UserID
	INSERT INTO #EntryTbl EXEC prcGetEntriesTypesList @SrcGuid, @UserID


	DECLARE @DeviceType AS INT
	SELECT @DeviceType = DeviceType FROM pl000 WHERE Guid = @DistGuid

	CREATE TABLE #Result
	(
		VisitGuid		UNIQUEIDENTIFIER,
		CustGuid		UNIQUEIDENTIFIER,
		CustName		NVARCHAR(250),
		DetailGuid		UNIQUEIDENTIFIER,
		DetailType		INT, -- 0 Bill	,1 Entry
		TypeName		NVARCHAR(250),
		DetailNumber	INT,
		Total			FLOAT,
		Date			DATETIME,
		StartTime		DATETIME,
		FinishTime		DATETIME,
		Direction		INT -- 1 for input  AND 0 for output 
	)
	--Visits from palm 
	IF (@DeviceType = 0) 
	BEGIN 
		--Add the Visits with bills 
		INSERT INTO #Result 
			SELECT 
				newid(), 
				pt.CustGUID, 
				cu.CustomerName, 
				bu.Guid, 
				0, --Bill 
				bt.Name, 
				bu.Number, 
				bu.Total, 
				pt.VisitDate, 
				pt.InTime, 
				pt.OutTime,
				CASE bt.bIsInput WHEN 1 THEN 1 ELSE 0 END
			FROM palmtiming AS pt 
			INNER JOIN cu000 AS cu ON pt.CustGUID = cu.Guid 
			INNER JOIN bu000 AS bu ON bu.CustGuid = pt.CustGuid 
			INNER JOIN #BillTbl AS Bs ON Bs.Type = Bu.TypeGuid
			INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid 
			WHERE	pt.DistributorGuid = @DistGuid 
				AND bu.Date = pt.VisitDate 
				AND (pt.VisitDate BETWEEN @StartDate AND @EndDate) 
		--Add the Visits with Entries 
		INSERT INTO #Result 
			SELECT 
				newid(), 
				pt.CustGUID, 
				cu.CustomerName, 
				ce.Guid, 
				1, --Entry 
				et.Name, 
				ce.Number, 
				CASE en.Debit WHEN 0 THEN en.Credit ELSE en.Debit END, 
				pt.VisitDate, 
				pt.InTime, 
				pt.OutTime,
				CASE en.Debit WHEN 0 THEN 0 ELSE 1 END
			FROM palmtiming AS pt 
			INNER JOIN cu000 AS cu ON pt.CustGUID = cu.Guid 
			INNER JOIN en000 AS en ON en.AccountGuid = cu.AccountGuid 
			INNER JOIN ce000 AS ce ON ce.Guid = en.ParentGuid 
			INNER JOIN #EntryTbl AS es ON es.Type = ce.TypeGuid 
			INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid 
			WHERE	pt.DistributorGuid = @DistGuid 
				AND ce.Date = pt.VisitDate 
				AND (pt.VisitDate BETWEEN @StartDate AND @EndDate) 
	END 
	--Visits from PocketPc 
	ELSE 
	BEGIN 
		--Add the Visits with bills 
		INSERT INTO #Result 
			SELECT 
				Vi.ViGuid, 
				Vi.viCustomerGUID, 
				Cu.CustomerName, 
				bu.Guid, 
				0, --Bill 
				bt.Name, 
				bu.Number, 
				bu.Total, 
				dbo.fnGetDateFromDT(Vi.TrDate), 
				Vi.viStartTime, 
				Vi.viFinishTime,
				CASE bt.bIsInput WHEN 1 THEN 1 ELSE 0 END
			FROM vwdisttrvi AS Vi 
			INNER JOIN Cu000 AS Cu ON Vi.viCustomerGUID = cu.Guid 
			INNER JOIN DistVd000 AS Vd ON Vi.ViGuid = Vd.VistGuid 
			INNER JOIN bu000 AS bu ON bu.Guid = Vd.ObjectGuid 
			INNER JOIN #BillTbl AS Bs ON Bs.Type = Bu.TypeGuid 
			INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid 
			WHERE	Vi.TrDistributorGuid = @DistGuid 
				AND (Vi.TrDate BETWEEN @StartDate AND @EndDate) 
		--Add the Visits with entries 
		INSERT INTO #Result 
			SELECT 
				Vi.ViGuid, 
				Vi.viCustomerGUID, 
				Cu.CustomerName, 
				ce.Guid, 
				1, --Entry 
				et.Name, 
				ce.Number, 
				CASE en.Debit WHEN 0 THEN en.Credit ELSE en.Debit END, 
				dbo.fnGetDateFromDT(Vi.TrDate), 
				Vi.viStartTime, 
				Vi.viFinishTime,
				CASE en.Debit WHEN 0 THEN 0 ELSE 1 END
			FROM vwdisttrvi AS Vi 
			INNER JOIN Cu000 AS Cu ON Vi.viCustomerGUID = cu.Guid 
			INNER JOIN DistVd000 AS Vd ON Vi.ViGuid = Vd.VistGuid 
			INNER JOIN en000 AS En ON En.Guid = Vd.ObjectGuid 
			INNER JOIN ce000 AS Ce ON Ce.Guid = En.ParentGuid 
			INNER JOIN #EntryTbl AS Es ON Es.Type = Ce.TypeGuid 
			INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid 
			WHERE	Vi.TrDistributorGuid = @DistGuid 
				AND (dbo.fnGetDateFromDT(Vi.TrDate) BETWEEN @StartDate AND @EndDate) 
	END 
	CREATE TABLE #FinalResult 
	( 
		ID			INT	IDENTITY(1, 1), 
		VisitGuid		UNIQUEIDENTIFIER, 
		CustGuid		UNIQUEIDENTIFIER, 
		CustName		NVARCHAR(250), 
		DetailGuid		UNIQUEIDENTIFIER, 
		DetailType		INT, -- 0 Bill	,1 Entry 
		TypeName		NVARCHAR(250), 
		DetailNumber	INT, 
		Total			FLOAT, 
		Date			DATETIME, 
		StartTime		DATETIME, 
		FinishTime		DATETIME,
		Direction		INT
	) 
	 
	INSERT INTO #FinalResult 
		SELECT 
			VisitGuid, 
			CustGuid, 
			CustName, 
			DetailGuid, 
			DetailType, 
			TypeName, 
			DetailNumber, 
			Total, 
			Date, 
			StartTime, 
			FinishTime,
			Direction
		FROM #Result 
		ORDER BY StartTime 
	SELECT * FROM #FinalResult

#################################################################
#END