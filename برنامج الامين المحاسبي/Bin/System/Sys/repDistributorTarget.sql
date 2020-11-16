############################
CREATE PROCEDURE repDistributorTarget
	@PeriodGUID		UNIQUEIDENTIFIER,
	@UseUnit		INT,
	@PricePolicy	INT,
	@PriceType		INT,		-- 4 whole, 8 half , 16 export, 32 vendor, 64retail, else endUser
	@CurrencyGUID	UNIQUEIDENTIFIER,
	@CurrencyVal	INT,
	@IsGrouped		BIT,		-- 0 By Mat 1 General Not by mat
	@ShowEmpty		BIT = 0,
	@SalesFactor	INT = 0, 	-- 0 not used , 1 first, 2 second
	@BranchGuid		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE @EPDate DATETIME
	SELECT @EPDate = GETDATE()

	DECLARE @brEnabled INT,
			@BranchMask	BIGINT
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '1')
	SELECT @BranchMask = brBranchMask FROM vwbr WHERE brGuid = @BranchGuid  

	CREATE TABLE #Result
		(
			DistributorGuid		 UNIQUEIDENTIFIER, 
			DistributorCode		 NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			DistributorName		 NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			DistributorTargetQty FLOAT, 
			TotalTargetPrice 	 FLOAT, 
			BranchGUID 			 UNIQUEIDENTIFIER, 
			BranchName		 	 NVARCHAR(250) COLLATE ARABIC_CI_AI 
		)
	INSERT INTO #Result
		(
			DistributorGuid		 , 
			DistributorCode		 , 
			DistributorName		 , 
			DistributorTargetQty , 
			TotalTargetPrice 	 , 
			BranchGUID 			 , 
			BranchName		 	  
		)
		SELECT 
			d.GUID, 
			d.Code,
			d.Name,
			ISNULL(SUM(t.TotalCustTarget), 0),
			ISNULL(SUM(t.TotalCustTarget), 0),
			ISNULL(b.Guid, 0x0),
			ISNULL(b.Name, '')
		FROM 
			vbDistributor AS d
			LEFT JOIN distcusttarget000 AS t ON d.Guid = t.DistGuid
			INNER JOIN vwcu AS cu ON cu.cuGuid = t.CustGuid
			INNER JOIN vwac AS ac ON ac.acGuid = cu.cuAccount
			LEFT JOIN vbbr 	AS b  ON d.branchMask = b.branchMask
		WHERE ((d.branchMask & @BranchMask <> 0 AND acBranchMask & @BranchMask <> 0 AND @brEnabled = 1) OR @brEnabled <> 1) AND
				t.PeriodGuid = @PeriodGuid
		GROUP BY
			d.Guid,
			d.Code,
			d.Name,
			b.Guid,
			b.Name

	Select * from #Result

/*
Exec prcConnections_Add2 "„œÌ—"	
Exec  repDistributorTarget '47e64183-1b63-407c-9366-91e1e24be22b', 0, 0, 64, '27392dbb-44c7-4d0d-899f-b23671c92171', 1.000000, 1, 1, 0 
*/
###########################
#END