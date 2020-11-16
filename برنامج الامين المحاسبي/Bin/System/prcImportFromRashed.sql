###################################################################################
## exec prcImportFromRashed 'E:\Tigo\2003.mdb', '1/1/2003'
###################################################################################
CREATE PROC prcImportFromRashed @FilePath AS NVARCHAR(1000), @FirstDate AS DATETIME
AS 
	BEGIN Tran

	declare @Path AS NVARCHAR(1000) , @User AS NVARCHAR(1000) , @PW AS NVARCHAR(1000)
	--DECLARE @FilePath AS NVARCHAR(1000)	
	--SET @FilePath = 'c:\Rashed\D2000.mdb'
	
	SET @Path = ''''+ @FilePath+''''
	SET @User = '''admin'''
	SET @PW = ''''''
	
	
	DECLARE @SqlStr_Acc AS NVARCHAR(1000)
	------------------------------------------------------------
	SET @SqlStr_Acc = 	
		'SELECT
			CASE WHEN a.Ref IS NULL THEN 2 ELSE 1 END,
			NEWID(),
			0x0,
			a.Num2,
			0,
			a.Num,
			a.Name,
			a.Name2,
			0,
			CASE WHEN a.Ref IS NULL THEN 0 ELSE a.Ref + 1 END
		FROM 
			OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW +', Accounts) AS a 
		ORDER BY 
			Num'
	
	--print @SqlStr_Acc
	CREATE  TABLE  #Acc ( Type INT DEFAULT 1, GUID UNIQUEIDENTIFIER, ParentGUID UNIQUEIDENTIFIER, Number INT, Parent INT default 0, Code NVARCHAR(255) COLLATE Arabic_CI_AI , Name NVARCHAR(255) COLLATE Arabic_CI_AI , LatinName NVARCHAR(255) COLLATE Arabic_CI_AI , ParentID INT,Id INT identity(1,1), FinalAcc INT DEFAULT 0)
	INSERT INTO #Acc exec ( @SqlStr_Acc)

	--------------------------------------------------------
	DECLARE @SqlStr_Set AS NVARCHAR(1000)
	SET @SqlStr_Set = 	
		'SELECT
			a.Name,
			a.Value
		FROM
			OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path + ';'+ @User +';' + @PW + ',[set]) AS a'
	--print @SqlStr_Set
	CREATE  TABLE  #Set ( Name NVARCHAR(1000) COLLATE Arabic_CI_AI ,Val NVARCHAR(1000) COLLATE Arabic_CI_AI )
	INSERT INTO #Set exec ( @SqlStr_Set)

	-----------------------------------------------------------
	DECLARE @SqlStr_Mat AS NVARCHAR(1000)
	SET @SqlStr_Mat = 	
		'SELECT
			0,
			NEWID(),
			0x0,
			a.Num2,
			a.Num,
			0,
			CAST ( a.Code AS NVARCHAR(255))COLLATE Arabic_CI_AI,
			a.Name,
			a.Name2,
			0
		FROM
			OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path + ';'+ @User +';' + @PW + ',Mat) AS a'
	--print @SqlStr_Mat
	CREATE  TABLE  #Mat ( IsMat bit default 0 , GUID UNIQUEIDENTIFIER, ParentGUID UNIQUEIDENTIFIER, Number INT, MtCode NVARCHAR(255) COLLATE Arabic_CI_AI , Parent INT, Code NVARCHAR(255) COLLATE Arabic_CI_AI , Name NVARCHAR(255) COLLATE Arabic_CI_AI , LatinName NVARCHAR(255) COLLATE Arabic_CI_AI , ParentID INT,Id INT identity(1,1))
	INSERT INTO #Mat exec ( @SqlStr_Mat)
	
	UPDATE #Mat SET IsMat = 1 where Len( MtCode) > 5
	-----------------------------------------------------------
	DECLARE @SqlStr_Cust AS NVARCHAR(1000)
	--CONVERT( NVARCHAR(256), a.Memo),
	--CONVERT( NVARCHAR(256), b.Memo),
	SET @SqlStr_Cust = 	
		'SELECT
			NEWID(),
			0x0,
			a.Num,
			a.Name,
			a.Address,
			a.Phone,
			
			0
		FROM
			OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path + ';'+ @User +';' + @PW + ',Suplyers) AS a
		UNION
		SELECT
			NEWID(),
			0x0,
			b.Num,
			b.Name,
			b.Address,
			b.Phone,

			0
		FROM
			OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path + ';'+ @User +';' + @PW + ',Custmers) AS b'
	
	--print @SqlStr_Cust


	CREATE  TABLE  #Cust ( GUID UNIQUEIDENTIFIER, AccGUID UNIQUEIDENTIFIER, AccCode NVARCHAR(256) COLLATE Arabic_CI_AI , Name NVARCHAR(255) COLLATE Arabic_CI_AI , Address NVARCHAR(255) COLLATE Arabic_CI_AI , Phone NVARCHAR(255) COLLATE Arabic_CI_AI , /*Memo NVARCHAR(256),*/ AccountID INT,Id INT identity(1,1))
	INSERT INTO #Cust exec ( @SqlStr_Cust)
	
	UPDATE Cust SET 
		Cust.AccGUID = Acc.GUID,
		Cust.AccountID = Acc.Id
	FROM
		#Cust AS Cust INNER JOIN #Acc AS Acc
		ON Cust.AccCode = Acc.Code
		
	-----------------------------------------------------------
	-----------------------------------------------------------
	declare @AccLevelCount AS INT
	declare @MatLevelCount AS INT
	
	SELECT @AccLevelCount = count(*) from #SET WHERE left( Name, 6) = 'AccLvl'
	SELECT @MatLevelCount = count(*) from #SET WHERE left( Name, 6) = 'MatLvl'
	
	print '@AccLevelCount = ' + CAST ( @AccLevelCount AS NVARCHAR(100))
	print '@MatLevelCount = ' + CAST ( @MatLevelCount AS NVARCHAR(100))

	-----------------------------------------------------------------------
	-- prepare the account table ( Number and guid ) and parents
	-----------------------------------------------------------------------
	declare @i AS int 
	set @i = 0
	UPDATE #Acc SET Parent = 55555555

	declare @accLvl int, @accLvlTemp int

	SET @accLvl = 0
	SET @accLvlTemp = 0

	WHILE @i <= @AccLevelCount
	BEGIN
		SELECT @accLvlTemp = Val FROM #SET WHERE Name = 'AccLvl_' + cast( @i AS NVARCHAR(10))COLLATE Arabic_CI_AI 
		SET @accLvl = @accLvl + @accLvlTemp
		print '@accLvl = ' + cast( @accLvl as NVARCHAR(10))COLLATE Arabic_CI_AI 
		if @i = 0
			UPDATE #Acc SET Parent = 0 WHERE len( Code) =  @accLvl
		else
		begin
			UPDATE Ac
				SET 
				Ac.Parent = AcP.Number,
				Ac.ParentId = AcP.Id,
				Ac.ParentGUID = AcP.GUID
			FROM 
				#Acc AS Ac INNER JOIN
				( SELECT Id, GUID, Number, Code FROM #Acc WHERE len( Code) =  @accLvl - @accLvlTemp)AS AcP 
				ON AcP.Code = Left( Ac.Code, @accLvl - @accLvlTemp)
			WHERE 
				len( Ac.Code) =  @accLvl
		end
		SET @i = @i + 1
		print 'acc i = ' + cast( @i as NVARCHAR(10))COLLATE Arabic_CI_AI 
	end

	----------------------------------------------------------------------
	-- 
	-- prepare the mat table ( Number and guid ) and parents
	--
	-----------------------------------------------------------------------
	declare @g AS int 
	set @g = 0
	UPDATE #Mat SET Parent = 55555555

	declare @MatLvl int, @MatLvlTemp int

	SET @MatLvl = 0
	SET @MatLvlTemp = 0

	while @g <= @MatLevelCount
	begin
		select @MatLvlTemp = Val from #SET where Name = 'MatLvl_' + cast( @g as NVARCHAR(10))COLLATE Arabic_CI_AI 
		SET @MatLvl = @MatLvl + @MatLvlTemp
		print '@MatLvl = ' + cast( @MatLvl as NVARCHAR(10))COLLATE Arabic_CI_AI 
		if @g = 0
			UPDATE #Mat SET Parent = 0 WHERE len( MtCode) =  @MatLvl
		else
		begin
			UPDATE Mt
				SET 
				Mt.Parent = MtP.Number,
				Mt.ParentId = MtP.Id,
				Mt.ParentGUID = MtP.GUID
			FROM 
				#Mat AS Mt INNER JOIN
				( SELECT Id, GUID, Number, MtCode FROM #Mat WHERE len( MtCode) =  @MatLvl - @MatLvlTemp)AS MtP
				ON MtP.MtCode = Left( Mt.MtCode, @MatLvl - @MatLvlTemp)
			WHERE 
				len( Mt.MtCode) =  @MatLvl
		end
		SET @g = @g + 1
		print 'Mat g = ' + cast( @g as NVARCHAR(10))COLLATE Arabic_CI_AI 
	end
	--------------------------------------------------------
	-- insert the currency table
	--------------------------------------------------------
	PRINT 'Currency'

	
	EXEC prcDisableTriggers 'my000'
	DELETE FROM my000 --WHERE Type <> 2
	ALTER TABLE my000 ENABLE TRIGGER ALL  
	
	DECLARE @SQL_My_str NVARCHAR( 1000)
	SET @SQL_My_str = 'SELECT Num, CAST( Name AS NVARCHAR(255)) COLLATE Arabic_CI_AI, CAST( Name AS NVARCHAR(255)) COLLATE Arabic_CI_AI, Price, CAST( Num AS NVARCHAR(255)), 100, ''1-1-1980'', 1, CAST( Name AS NVARCHAR(255)) COLLATE Arabic_CI_AI, CAST( Num AS NVARCHAR(255)), newid()'
		+ ' FROM OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW +', [Currency])AS Cur WHERE Name IS NOT NULL'
			   	--OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ', ''E:\Tigo\2003.mdb''; ''admin'';'''', Currency)AS Cur


	INSERT INTO My000 EXEC( @SQL_My_str)

	/*
	DECLARE @CurrencyPtr AS INT, @CurrencyVal AS FLOAT
	SELECT @CurrencyPtr = Number, @CurrencyVal = CurrencyVal FROM My000 where Number = 2
	print @CurrencyPtr 
	print @CurrencyVal
	*/
	----------------------------------------------------------
	PRINT 'Store'

	EXEC prcDisableTriggers 'st000'
	DELETE FROM st000
	ALTER TABLE st000 ENABLE TRIGGER ALL  
	
	INSERT INTO st000 
		SELECT 
			1, --Number
			0, --Parent
			'1', --Code
			'General Store', --Name
			'Rashed',--Notes
			'',--Address
			'',--Keeper
			0,--Account
			1,--Security
			'General Store', --LatinName
			newid()
	---------------------------------------------------------
	--
	--	Insert records in accounts table
	--
	-----------------------------------------------------------
	-- DELETE FROM #Acc WHERE Number = 0 OR Number = 1 OR Number = 2 OR Number = 3 
	PRINT 'Account'

	
	EXEC prcDisableTriggers 'ac000' 
	DELETE FROM Ac000 --WHERE Type <> 2
	ALTER TABLE Ac000 ENABLE TRIGGER ALL  
	
	INSERT INTO Ac000(
		[Number], 
		[Name], 
		[Code], 
		[CDate], 
		[Parent], 
		[Final], 
		[NSons], 
		[Debit], 
		[Credit], 
		[InitDebit], 
		[InitCredit], 
		[UseFlag], 
		[MaxDebit], 
		[Notes], 
		[CurrencyVal], 
		[CurrencyPtr], 
		[Warn], 
		[CheckDate], 
		[Security], 
		[DebitOrCredit], 
		[Type], 
		[State], 
		[Branch], 
		[Num1], 
		[Num2], 
		[LatinName], 
		[GUID] )
	SELECT
		Id,
		Name, 
		Code, 
		@FirstDate, 	-- CDate
		ParentId, 	-- Parent
		FinalAcc, 	-- Final
		0, 		-- NSons
		0, 		-- Debit
		0, 		-- Credit
		0, 		-- InitDebit
		0, 		-- InitCredit
		0, 		-- UseFlag
		0, 		-- MaxDebit
		'', 		-- Notes
		1, 		-- CurrencyVal
		1, 		-- CurrencyPtr
		0, 		-- Warn
		@FirstDate, 	-- CheckDate
		1, 		-- Security
		0, 		-- DebitOrCredit
		Type,  		--Type
		0, 		-- State
		0, 		-- Branch
		0, 		-- Num1
		Number, 	-- Num2
		ISNULL( LatinName, ''), 	-- LatinName
		GUID		-- GUID 
	FROM
		#Acc

	--------------------------------------------------------------------------------------------
	--
	--	Insert The Customer Card In Table Cu000
	--
	--------------------------------------------------------------------------------------------
	PRINT 'Customer'

	
	EXEC prcDisableTriggers 'cu000'
	DELETE FROM cu000
	ALTER TABLE cu000 ENABLE TRIGGER ALL  

	INSERT INTO Cu000(
		[Number], 
		[CustomerName], 
		[Nationality], 
		[Address], 
		[Phone1], 
		[Phone2], 
		[FAX], 
		[TELEX], 
		--[Notes], 
		[UseFlag], 
		[Picture], 
		[Account], 
		[CheckDate], 
		[Security], 
		[Type], 
		[DiscRatio], 
		[DefPrice], 
		[State], 
		[LatinName], 
		[EMail], 
		[HomePage], 
		[Prefix], 
		[Suffix], 
		[GPSX], 
		[GPSY], 
		[GPSZ], 
		[Area], 
		[City], 
		[Street], 
		[POBox], 
		[ZipCode], 
		[Mobile], 
		[Pager], 
		[GUID], 
		[Country], 
		[Hoppies], 
		[Gender], 
		[Certificate], 
		[DateOfBirth], 
		[Job], 
		[JobCategory], 
		[UserFld1], 
		[UserFld2], 
		[UserFld3], 
		[UserFld4])
	SELECT
		id, 
		Name, 
		'',		--[Nationality] 
		Address, 
		Phone, 		--[Phone1]
		'', 		--[Phone2]
		'',		--[FAX] 
		'',		--[TELEX] 
		--Memo, 		--[Notes]
		0,		--[UseFlag] 
		0,		--[Picture] 
		AccountID,	--[Account] 
		@FirstDate,	--[CheckDate] 
		1,		--[Security] 
		0,		--[Type] 
		0,		--[DiscRatio] 
		5,		--[DefPrice]		 
		0,		--[State] 
		Name,		--[LatinName] 
		'',		--[EMail] 
		'',		--[HomePage] 
		'',		--[Prefix] 
		'',		--[Suffix] 
		0, 		--[GPSX]
		0,		--[GPSY] 
		0,		--[GPSZ] 
		'',		--[Area] 
		'',		--[City] 
		'',		--[Street] 
		'',		--[POBox] 
		'',		--[ZipCode] 
		'',		--[Mobile]
		'',		--[Pager]
		GUID, 
		'',		--[Country] 
		'',		--[Hoppies] 
		'',		--[Gender] 
		'',		--[Certificate] 
		'1/1/1980', 	--[DateOfBirth]
		'',		--[Job] 
		'',	 	--[JobCategory]
		'',		--[UserFld1] 
		'',		--[UserFld2] 
		'',		--[UserFld3] 
		'' 		--[UserFld4]
	FROM
		#Cust
	---------------------------------------------------------
	--
	--	Insert records in Groups table
	--
	-----------------------------------------------------------
	PRINT 'Group'

	 
	EXEC prcDisableTriggers 'gr000'
	DELETE FROM gr000 
	ALTER TABLE gr000 ENABLE TRIGGER ALL  

	EXEC prcDisableTriggers  'mt000'
	DELETE FROM mt000
	ALTER TABLE mt000 ENABLE TRIGGER ALL  

	INSERT INTO gr000
		([Number], 
		[Parent], 
		[Code], 
		[Name], 
		[Notes], 
		[Security], 
		[GUID], 
		[Type], 
		[VAT], 
		[LatinName])
	SELECT 
		id, 
		ParentId,	--Parent
		MtCode, 	--Code
		Name, 		--Name
		'', 		--Notes
		1, 		--Security
		GUID, 
		0, 
		0, 
		LatinName
	FROM 
		#Mat
	WHERE
		IsMat = 0
	
	---------------------------------------------------------
	--
	--	Insert records in Materials table
	--
	-----------------------------------------------------------
	PRINT 'Mat'

	INSERT INTO MT000 (
		[Number], 
		[Name], 
		[Code], 
		[LatinName], 
		[BarCode], 
		[CodedCode], 
		[Group], 
		[Unity], 
		[Spec], 
		[Qty], 
		[High], 
		[Low], 
		[Whole], 
		[Half], 
		[Retail], 
		[EndUser], 
		[Export], 
		[Vendor], 
		[MaxPrice], 
		[AvgPrice], 
		[LastPrice], 
		[PriceType], 
		[SellType], 
		[BonusOne], 
		[Picture], 
		[CurrencyVal], 
		[CurrencyPtr], 
		[UseFlag], 
		[Origin], 
		[Company], 
		[Type], 
		[Security], 
		[LastPriceDate], 
		[Bonus], 
		[Unit2], 
		[Unit2Fact], 
		[Unit3], 
		[Unit3Fact], 
		[Flag], 
		[Pos], 
		[Dim], 
		[ExpireFlag], 
		[ProductionFlag], 
		[Unit2FactFlag], 
		[Unit3FactFlag], 
		[BarCode2], 
		[BarCode3], 
		[SNFlag], 
		[ForceInSN], 
		[ForceOutSN], 
		[VAT], 
		[Color], 
		[Provenance], 
		[Quality], 
		[Model], 
		[Whole2], 
		[Half2], 
		[Retail2], 
		[EndUser2], 
		[Export2], 
		[Vendor2], 
		[MaxPrice2], 
		[LastPrice2], 
		[Whole3], 
		[Half3], 
		[Retail3], 
		[EndUser3], 
		[Export3], 
		[Vendor3], 
		[MaxPrice3], 
		[LastPrice3], 
		[GUID]) 

	SELECT 
		id, 
		Name, 
		Code, 
		LatinName, 
		'',		--BarCode 
		'', 		--[CodedCode]
		ParentId, 	--[Group]
		'',		--[Unity]
		'', 		--[Spec]
		0, 		--[Qty]
		0, 		--[High]
		0, 		--[Low]
		0,		--[Whole] 
		0, 		--[Half]
		0, 		--[Retail]
		0, 		--[EndUser]
		0, 		--[Export]
		0, 		--[Vendor]
		0, 		--[MaxPrice]
		0, 		--[AvgPrice]
		0,		--[LastPrice] 
		15,		--[PriceType] 
		0,		--[SellType] 
		0,		--[BonusOne] 
		0, 		--[Picture]
		1,		--[CurrencyVal] 
		1,		--[CurrencyPtr] 
		0,		--[UseFlag] 
		'',		--[Origin] 
		'',		--[Company] 
		0,		--[Type] 
		1,		--[Security] 
		@FirstDate, 	--[LastPriceDate]
		0,		--[Bonus]
		'',		--[Unit2] 
		0,		--[Unit2Fact] 
		'',		--[Unit3] 
		0,		--[Unit3Fact] 
		0,		--[Flag] 
		'', 		--[Pos]
		'',		--[Dim] 
		0,		--[ExpireFlag] 
		0,		--[ProductionFlag] 
		0,		--[Unit2FactFlag] 
		0,		--[Unit3FactFlag] 
		'',		--[BarCode2] 
		'',		--[BarCode3] 
		0,		--[SNFlag] 
		0,		--[ForceInSN] 
		0,		--[ForceOutSN] 
		Number,		--[VAT] 
		'',		--[Color] 
		'',		--[Provenance] 
		'',		--[Quality] 
		'',		--[Model] 
		0,		--[Whole2] 
		0,		--[Half2] 
		0,		--[Retail2] 
		0,		--[EndUser2] 
		0,		--[Export2] 
		0,		--[Vendor2] 
		0,		--[MaxPrice2] 
		0,		--[LastPrice2] 
		0,		--[Whole3] 
		0,		--[Half3]
		0,		--[Retail3] 
		0,		--[EndUser3] 
		0,		--[Export3] 
		0,		--[Vendor3] 
		0,		--[MaxPrice3] 
		0,		--[LastPrice3] 
		GUID
	FROM
		#Mat
	WHERE
		IsMat = 1
	--select * from #Acc 
	--select * from #Set
	--select * from #Mat order by Code
	---------------------------------------------------------------------------
	-- insert bill	
	---------------------------------------------------------------------------
	PRINT 'bill'
	
	EXEC prcDisableTriggers 'bu000'
	DELETE FROM bu000
	ALTER TABLE bu000 enable TRIGGER ALL  

	
	EXEC prcDisableTriggers 'bi000' 
	DELETE FROM bi000
	ALTER TABLE bi000 enable TRIGGER ALL  
	DECLARE @BuyType AS int
	DECLARE @SaleType AS int
	SELECT @BuyType = Number FROM BT000 WHERE Type = 1 AND Number = 1
	SELECT @SaleType = Number FROM BT000 WHERE Type = 1 AND Number = 2
	
	PRINT 'Buy bill'
	-- Insert Buy Bills
	DECLARE @Buy_Bill_str NVARCHAR(max)
	SET @Buy_Bill_str = '
	SELECT ' + CAST( @BuyType AS NVARCHAR(40)) + ',
		Num,
		0.0,
		'''',
		bu.[Date],
		Currency,
		my.CurrencyVal,
		Document,
		LocalTot,
		1,
		0,
		acCredit.Number,
		acDebit.Number,
		0,
		Rate,
		0,
		0,
		acCredit.Number,
		0,
		acCredit.Number,
		0,
		0,
		0,
		0,
		0,
		0,
		1,
		0,
		0,
		0,
		0,
		0x0,
		0,
		newID()
	FROM
		OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW +', MoveBayBill)AS Bu
		INNER JOIN my000 AS my ON bu.Currency = my.Number
		INNER JOIN Ac000 AS acDebit ON acDebit.Num2 = bu.Debt
		INNER JOIN Ac000 AS acCredit ON acCredit.Num2 = bu.Credit'

	INSERT INTO BU000 EXEC( @Buy_Bill_str)

	-- Insert Detail
	PRINT 'Buy Details'
	DECLARE @Detail_Buy_Bill_str NVARCHAR(max)
	SET @Detail_Buy_Bill_str = 
		'SELECT ' + CAST( @BuyType AS NVARCHAR(40)) + ','
		+' SERNRI, [Order], mt.Number, SQUANT, 0, 0, 1, SPRICE, 0, 0, 0, 0, 1, 1, 1, SNDOC, 0, 0, 0, 0, 0, 0, 0, ''1-1-1980'', ''1-1-1980'', 0, 0, 0, newID(), 0, 0'
		+' FROM'
		+' OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW +', [Move]) AS mv'
		+' INNER JOIN bu000 AS bu ON bu.Type = ' + CAST( @BuyType AS NVARCHAR(40)) + ' and bu.Number = mv.SERNRI'
		+' INNER JOIN mt000 AS mt ON mv.[SACC-NR] = mt.VAT'
		+' WHERE SERNRI > 0'

	INSERT INTO BI000 EXEC ( @Detail_Buy_Bill_str)

	-- Insert Sale Bills
	PRINT 'Sale Bill'
	DECLARE @Sale_Bill_str NVARCHAR(max)
	SET @Sale_Bill_str = 
		'SELECT ' + CAST( @SaleType AS NVARCHAR(40)) + ','
		+' Num,	0.0, '''', bu.[Date], Currency, my.CurrencyVal,	Document, LocalTot, 1, 0, acDebit.Number, acCredit.Number, 0, Rate, 0, 0, acDebit.Number, 0, acDebit.Number, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0x0, 0, newID()'
		+' FROM'
		+' OPENROWSET( ''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW +', MoveSaleBill)AS Bu'
		+' INNER JOIN my000 AS my ON bu.Currency = my.Number'
		+' INNER JOIN Ac000 AS acDebit ON acDebit.Num2 = bu.Debt'
		+' INNER JOIN Ac000 AS acCredit ON acCredit.Num2 = bu.Credit'
	INSERT INTO BU000 EXEC ( @Sale_Bill_str)
	----------------------------
	PRINT 'Sale Details'
	DECLARE @Detail_Sale_Bill_str NVARCHAR(max)
	SET @Detail_Sale_Bill_str = 
		'SELECT ' + CAST( @SaleType AS NVARCHAR(40)) + ','
		+' SERNRO, [Order], mt.Number, SQUANT, 0, 0, 1, SPRICE, 0, 0, 0, 0, 1, 1, 1, SNDOC, 0, 0, 0, 0,	0, 0, 0, ''1-1-1980'',''1-1-1980'', 0, 0, 0, newID(), 0, 0'
		+' FROM'
		+' OPENROWSET( ''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW +', [Move]) AS mv'
		+' INNER JOIN bu000 AS bu ON bu.Type = '+ CAST( @SaleType AS NVARCHAR(40)) + ' and bu.Number = mv.SERNRO'
		+' INNER JOIN mt000 AS mt ON mv.[SACC-NR] = mt.VAT'
		+' WHERE SERNRO > 0'

	INSERT INTO Bi000 EXEC ( @Detail_Sale_Bill_str)
	------------------------------------------------------------------
	UPDATE BI000
	SET
		Discount = bu.TotalDisc * 100 / CASE (Price * Qty) WHEN 0 THEN 1 ELSE (Price * Qty) END
	FROM
		Bi000 AS bi INNER JOIN BU000 AS bu 
		ON bi.Type = bu.type AND bi.Parent = bu.Number
	WHERE
		bu.TotalDisc <> 0 
		AND bi.Number = 1
	---------------------------------------------------------------------------
	-- insert entry
	---------------------------------------------------------------------------
	PRINT 'Centry'
	EXEC prcDisableTriggers 'CE000'  
	DELETE FROM CE000
	ALTER TABLE CE000 enable TRIGGER ALL  

	EXEC prcDisableTriggers 'EN000'
	DELETE FROM EN000
	ALTER TABLE EN000 enable TRIGGER ALL
	
	DECLARE @SQL_CE_str AS NVARCHAR(max)
	SET @SQL_CE_str = 
		'SELECT 1, Nbrrec, tch.[Date], Sum(Summ), Sum(Summ), 0,	0, '''', max(my.CurrencyVal), Max(Currency), 0, 0, 1, 0, 0, 0x0, newid() FROM'
		+' OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW + ' , TEATCHER) AS Tch INNER JOIN my000 AS my ON my.Number = Tch.Currency'
		+' WHERE Way = 1 AND SERNR is null'
		+' GROUP BY Nbrrec, tch.[Date] '

	INSERT INTO CE000 EXEC ( @SQL_CE_str)
	PRINT 'Entry en 1'

	DECLARE @SQL_EN_str AS NVARCHAR(max)
	SET @SQL_EN_str = '
	SELECT
		1,
		Nbrrec,
		[ID],
		ac.Number,
		Tch.[Date],
		summ,
		0,
		Cast(Docum AS NVARCHAR(1000)),
		Currency,
		my.CurrencyVal,
		0,
		0,
		0,
		0,
		0,
		0,
		newid(),
		0x0
	FROM
		OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW +', TEATCHER) AS Tch
		INNER JOIN my000 AS my ON my.Number = Tch.Currency
		INNER JOIN Ac000 AS ac ON ac.Num2 = Tch.Acc_nr
	WHERE
		Way = 1 AND
		SERNR is null'

	INSERT INTO EN000 EXEC ( @SQL_EN_str)
	
	PRINT 'Entry en 2'
	SET @SQL_EN_str =
	'SELECT
		1,
		Nbrrec,
		[ID],
		ac.Number,
		Tch.[Date],
		0,
		summ,
		Cast(Docum AS NVARCHAR),
		Currency,
		my.CurrencyVal,
		0,
		0,
		0,
		0,
		0,
		0,
		newid(),
		0x0
	FROM
		OPENROWSET(''Microsoft.Jet.OLEDB.4.0''' + ',' + @Path +';'+ @User +';' + @PW +', TEATCHER) AS Tch
		INNER JOIN my000 AS my ON my.Number = Tch.Currency
		INNER JOIN Ac000 AS ac ON ac.Num2 = Tch.Acc_nr
	WHERE
		Way = 2 AND
		SERNR is null'

	INSERT INTO EN000 EXEC ( @SQL_EN_str)
	---- Assigne Contra
	EXEC prcAutoAssignContraAcc
	---------------------------------------------------------------------------
	drop table #Acc 
	drop table #Set
	drop table #Mat

	COMMIT Tran
###################################################################################
#END