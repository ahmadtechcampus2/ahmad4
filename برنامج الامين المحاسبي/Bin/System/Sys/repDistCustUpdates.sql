################################################################################
CREATE PROCEDURE repDistCustUpdates
	@StartDate		DATETIME,
	@EndDate		DATETIME,
	@DistGuid		UNIQUEIDENTIFIER,
	@AccGuid		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON;
	IF @DistGuid = '00000000-0000-0000-0000-000000000000'
	BEGIN
		SELECT dcu.*, ct.Name AS TypeName, ch.Name AS TradeChName, d.Name AS DistName FROM DistCustUpdates000 AS dcu
		LEFT JOIN distct000 AS ct ON ct.Guid = dcu.CustTypeGuid
		LEFT JOIN disttch000 AS ch ON ch.Guid = dcu.TradeChannelGuid
		INNER JOIN distributor000 AS d ON d.Guid = dcu.DistGuid
		WHERE dcu.date BETWEEN @StartDate AND @EndDate
				AND dcu.CustGuid IN (select * from fnGetCustsOfAcc(@AccGuid))
		ORDER BY dcu.CustGuid, dcu.Date
	END
	ELSE
	BEGIN
		SELECT dcu.*, ct.Name AS TypeName, ch.Name AS TradeChName FROM DistCustUpdates000 AS dcu
		LEFT JOIN distct000 AS ct ON ct.Guid = dcu.CustTypeGuid
		LEFT JOIN disttch000 AS ch ON ch.Guid = dcu.TradeChannelGuid
		INNER JOIN distributor000 AS d ON d.Guid = dcu.DistGuid
		WHERE dcu.date BETWEEN @StartDate AND @EndDate
				AND dcu.DistGuid = @DistGuid
				AND dcu.CustGuid IN (select * from fnGetCustsOfAcc(@AccGuid))
		ORDER BY dcu.CustGuid, dcu.Date
	END
	
################################################################################
CREATE PROCEDURE repDistDeleteCustUpdates
	@StartDate		DATETIME,
	@EndDate		DATETIME,
	@DistGuid		UNIQUEIDENTIFIER,
	@AccGuid		UNIQUEIDENTIFIER
AS
	IF @DistGuid = '00000000-0000-0000-0000-000000000000'
	BEGIN
		DELETE dcu FROM DistCustUpdates000 AS dcu
		WHERE dcu.date BETWEEN @StartDate AND @EndDate
				AND dcu.CustGuid IN (select * from fnGetCustsOfAcc(@AccGuid))
	END
	ELSE
	BEGIN
		DELETE dcu FROM DistCustUpdates000 AS dcu
		WHERE dcu.date BETWEEN @StartDate AND @EndDate
				AND dcu.DistGuid = @DistGuid
				AND dcu.CustGuid IN (select * from fnGetCustsOfAcc(@AccGuid))
	END

################################################################################
#END