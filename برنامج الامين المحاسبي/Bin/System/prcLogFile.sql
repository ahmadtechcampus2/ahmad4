###########################################################################
CREATE PROC SaveFileLog
	@UserGuid UNIQUEIDENTIFIER,
	@Computer NVARCHAR(250),
	@Operation INT,
	@OperationType INT,
	@RecGUID UNIQUEIDENTIFIER,
	@OperationTime DATETIME,
	@RecNumber BIGINT,
	@TypeGUID UNIQUEIDENTIFIER,
	@Notes NVARCHAR(MAX),
	@DrvRID BIGINT,
	@RecQuery NVARCHAR(MAX) = ''
AS

DECLARE @sqlCommand NVARCHAR(MAX)
DECLARE @RecContent NVARCHAR(MAX) = ''

IF(@RecQuery <> '')
	BEGIN
		SET @sqlCommand = N'SET @result =  (' + @RecQuery + ')  '
		EXECUTE SP_EXECUTESQL @sqlCommand, N'@result NVARCHAR(MAX) OUTPUT',  @result = @RecContent OUTPUT
	END

INSERT INTO [log000]
           ([Guid]
           ,[LogTime]
           ,[UserGUID]
           ,[Computer]
           ,[Operation]
           ,[OperationType]
           ,[RecGUID]
           ,[OperationTime]
		   ,[RecNum]
		   ,[TypeGUID]
		   ,[Notes]
		   ,[DrvRID]
           ,[RecContent])
     VALUES
           (NEWID()
           ,GETDATE()
           ,@UserGuid
           ,@Computer
           ,@Operation
           ,@OperationType
           ,@RecGUID
           ,@OperationTime
		   ,@RecNumber
		   ,@TypeGUID
		   ,@Notes
		   ,@DrvRID
           ,@RecContent)
###########################################################################
CREATE PROC GetPrevLog
	@Guid UNIQUEIDENTIFIER
AS
SET NOCOUNT OFF
DECLARE
	@RecGuid UNIQUEIDENTIFIER,
	@LTime DATETIME,
	@Time DATETIME
	SET @RecGuid = (SELECT RecGUID From log000 WHERE Guid = @Guid)
	SET @LTime = (SELECT LogTime From log000 WHERE Guid = @Guid)
	SET @Time =  (SELECT MAX(LogTime) FROM log000 WHERE RecGUID = @RecGuid AND GUID <> @Guid AND LogTime < @LTime)

SELECT * FROM log000 WHERE RecGUID = @RecGuid AND LogTime = @Time AND OperationType = 100
###########################################################################
CREATE FUNCTION fnLogBu( @Guid UNIQUEIDENTIFIER )
	RETURNS NVARCHAR(MAX)
AS
	BEGIN
		RETURN (SELECT bu000.*, cu000.CustomerName, my000.Name AS myName, st000.Code + '-' + st000.Name AS stName, accu000.Code + '-' + accu000.Name AS cuAccName, co000.Code + '-' + co000.Name AS coName, br000.Code + '-' + br000.Name AS brName, nt000.Name AS ntName,
				(SELECT di000.*, my000.Name AS myName, co000.Code + '-' + co000.Name AS coName, aca000.Code + '-' + aca000.Name AS AccName, acc000.Code + '-' +acc000.Name AS acContraName
					FROM di000 
					LEFT JOIN my000 ON di000.CurrencyGUID = my000.GUID
					LEFT JOIN co000 ON di000.CostGUID = co000.GUID
					LEFT JOIN ac000 AS aca000 ON di000.AccountGUID = aca000.GUID
					LEFT JOIN ac000 AS acc000 ON di000.ContraAccGUID = acc000.GUID
					WHERE di000.ParentGUID = bu000.GUID FOR XML PATH('di'), TYPE) AS 'di000',
				(SELECT bi000.*, mt000.Code + '-' + mt000.Name AS mtName, mt000.Unity AS Unit1, mt000.Unit2, mt000.Unit3, mt000.Unit2Fact, mt000.Unit3Fact, st000.Code + '-' + st000.Name AS stName, my000.Name AS myName, co000.Code + '-' + co000.Name AS coName
					FROM bi000
					INNER JOIN mt000 ON bi000.MatGUID = mt000.GUID
					LEFT JOIN st000 ON bi000.StoreGUID = st000.GUID
					LEFT JOIN my000 ON bi000.CurrencyGUID = my000.GUID
					LEFT JOIN co000 ON bi000.CostGUID = co000.GUID
					WHERE bi000.ParentGUID = bu000.GUID FOR XML PATH('bi'), TYPE) AS 'bi000'
				FROM bu000
				LEFT JOIN cu000 ON bu000.CustGUID = cu000.GUID
				LEFT JOIN my000 ON bu000.CurrencyGUID = my000.GUID
				LEFT JOIN st000 ON bu000.StoreGUID = st000.GUID
				LEFT JOIN ac000 AS accu000 ON bu000.CustAccGUID = accu000.GUID
				LEFT JOIN co000 ON bu000.CostGUID = co000.GUID
				LEFT JOIN br000 ON bu000.Branch = br000.GUID
				LEFT JOIN nt000 ON bu000.CheckTypeGUID = nt000.GUID
				WHERE bu000.GUID =  @Guid FOR XML PATH('bu000'), ROOT('root'))
	END
###########################################################################
CREATE FUNCTION fnLogCe( @Guid UNIQUEIDENTIFIER )
	RETURNS NVARCHAR(MAX)
AS
	BEGIN
		RETURN (SELECT ce000.*,my000.Name AS myName,  br000.Name AS brName,
			
				(SELECT en000.*, my000.Code AS myName,co.code as coCode, co.Name AS coName,ac.code as acCode,ac.name as acName,ac2.Code as ac2Code,ac2.Name as ac2Name ,cu.GUID as CustomerGuid
					FROM en000
					INNER JOIN ac000 ac ON en000.AccountGUID=ac.guid
					LEFT JOIN ac000 ac2 ON en000.ContraAccGUID=ac2.guid
					LEFT JOIN my000 ON en000.CurrencyGUID = my000.GUID
					LEFT JOIN co000 co  ON en000.CostGuid = co.GUID
					LEFT JOIn cu000 cu ON en000.CustomerGUID = cu.GUID
					WHERE en000.ParentGUID = ce000.GUID FOR XML PATH('en'), TYPE) AS 'en000'
				FROM ce000
			
				LEFT JOIN my000 ON ce000.CurrencyGUID = my000.GUID
			
				LEFT JOIN br000 ON ce000.Branch = br000.GUID
				
				WHERE ce000.GUID = @Guid FOR XML PATH('ce000'), ROOT('root'))
	END
###########################################################################
CREATE VIEW vwEt000 
AS
	SELECT 
		Guid
		,sortNum
		,Name
		,LatinName
		,Abbrev
		,LatinAbbrev 
	FROM et000
	UNION
	SELECT 0x0,0,N'سند قيد', N'Entry',N'سند قيد', N'Entry'
###########################################################################
CREATE FUNCTION SaveReportLog
(
	@AccGUID UNIQUEIDENTIFIER,
	@CustGUID UNIQUEIDENTIFIER,
	@MatGUID UNIQUEIDENTIFIER,
	@GrpGUID UNIQUEIDENTIFIER,
	@StoreGUID UNIQUEIDENTIFIER,
	@CostGUID UNIQUEIDENTIFIER,
	@CurGUID UNIQUEIDENTIFIER,
	@CurVal FLOAT,
	@BranchGUID UNIQUEIDENTIFIER,
	@StartDate DATETIME,
	@EndDate DATETIME
)
	RETURNS NVARCHAR(MAX) 
AS
BEGIN
     RETURN (SELECT * from  (SELECT @AccGUID AccGUID ,
					@CustGUID CustGUID ,
					@MatGUID MatGUID ,
					@GrpGUID GrpGUID ,
					@StoreGUID StoreGUID ,
					@CostGUID CostGUID ,
					@CurGUID CurGUID ,
					@CurVal CurVal ,
					@BranchGUID BranchGUID ,
					@StartDate StartDate ,
					@EndDate EndDate
					)as report  FOR XML PATH('report'), ROOT('root'))
					
END
############################################################################
CREATE FUNCTION fnLogCh( @Guid UNIQUEIDENTIFIER )
	RETURNS NVARCHAR(MAX)
AS
	BEGIN
	RETURN(SELECT ch.*, tfac.Name TakeFromAccount, my.Name CurrancyName, ac.Name Account, tfco.Name TakeFromCost, acco.Name AccountCost,
			 br.Name Brunch, bk.BankName Bank, anac.Name EndorseAccount ,cu.Guid CustomerGuid
	FROM ch000 ch
		INNER JOIN ac000 tfac ON ch.AccountGUID = tfac.GUID
		INNER JOIN my000 my ON ch.CurrencyGUID = my.GUID
		INNER JOIN ac000 ac ON ch.Account2GUID = ac.GUID
		LEFT JOIN co000 tfco ON ch.Cost1GUID = tfco.GUID
		LEFT JOIN co000 acco ON ch.Cost2GUID = acco.GUID
		LEFT JOIN br000 br ON ch.BranchGUID = br.GUID
		LEFT JOIN Bank000 bk ON ch.BankGUID = bk.GUID
		LEFT JOIN ac000	anac ON ch.EndorseAccGUID = anac.GUID
		LEFT JOIN cu000 cu ON ch.customerGuid = cu.Guid 
			WHERE ch.GUID =  @Guid FOR XML PATH('ch000'), ROOT('root'))
	END
############################################################################
CREATE FUNCTION fnLogMain( @Guid UNIQUEIDENTIFIER )
	RETURNS NVARCHAR(MAX)
AS
	BEGIN
		RETURN(select 'MainLog' as Name, (SELECT *
				FROM MaintenanceLogItem000 mainLog
				WHERE ParentGUID = @Guid FOR XML PATH('itemlog'),type) as item
				FOR XML PATH('MainLog'), ROOT('root'))
	END
#############################################################################
CREATE FUNCTION fnLogMt( @Guid UNIQUEIDENTIFIER )
	RETURNS NVARCHAR(MAX)
AS
	BEGIN
		RETURN (SELECT (mt.High) AS High,
				       (mt.OrderLimit) AS OrderLimit,
					   (mt.Low) AS Low, 
					   (my.Name) AS Name,
					   CASE (mt.PriceType) 
					   		WHEN 15 THEN dbo.fnStrings_get('AmnTools\PriceType\RealPrice', DEFAULT)
					   		WHEN 120 THEN dbo.fnStrings_get('AmnTools\PriceType\MaxPrice', DEFAULT)
					   		WHEN 121 THEN dbo.fnStrings_get('AmnTools\PriceType\AvgPrice', DEFAULT)
					   		WHEN 122 THEN dbo.fnStrings_get('AmnTools\PriceType\LastPrice', DEFAULT)
					   		WHEN 128 THEN dbo.fnStrings_get('AmnTools\PriceType\DefaultPrice', DEFAULT)
					   END AS PriceType,
					   (mt.VAT) AS VAT,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Whole / my.CurrencyVal) ELSE mt.Whole END AS Whole,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Half / my.CurrencyVal) ELSE mt.Half END AS Half,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Vendor / my.CurrencyVal) ELSE mt.Vendor END AS Vendor,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Export / my.CurrencyVal) ELSE mt.Export END AS Export,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Retail / my.CurrencyVal) ELSE mt.Retail END AS Retail,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.EndUser / my.CurrencyVal) ELSE mt.EndUser END AS EndUser, 
					   (mt.LastPrice / my.CurrencyVal) AS LastPrice,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Whole2 / my.CurrencyVal) ELSE mt.Whole2 END AS Whole2,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Half2 / my.CurrencyVal) ELSE mt.Half2 END AS Half2,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Vendor2 / my.CurrencyVal) ELSE mt.Vendor2 END AS Vendor2,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Export2 / my.CurrencyVal) ELSE mt.Export2 END AS Export2,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Retail2 / my.CurrencyVal) ELSE mt.Retail2 END AS Retail2,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.EndUser2 / my.CurrencyVal) ELSE mt.EndUser2 END AS EndUser2,
					   (mt.LastPrice2 / my.CurrencyVal) AS LastPrice2,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Whole3 / my.CurrencyVal) ELSE mt.Whole3 END AS Whole3,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Half3 / my.CurrencyVal) ELSE mt.Half3 END AS Half3,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Vendor3 / my.CurrencyVal) ELSE mt.Vendor3 END AS Vendor3,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Export3 / my.CurrencyVal) ELSE mt.Export3 END AS Export3,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.Retail3 / my.CurrencyVal) ELSE mt.Retail3 END AS Retail3,
					   CASE (mt.PriceType) WHEN 15 THEN (mt.EndUser3 / my.CurrencyVal) ELSE mt.EndUser3 END AS EndUser3,
		               (mt.LastPrice3 / my.CurrencyVal) AS LastPrice3
				 FROM my000 my
				 INNER JOIN mt000 mt ON mt.CurrencyGUID = my.GUID  
				 WHERE mt.GUID = @Guid FOR XML PATH('mty000'), ROOT('root'))
	END
#############################################################################
#END
