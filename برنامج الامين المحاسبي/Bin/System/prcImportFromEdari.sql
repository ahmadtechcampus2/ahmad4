###########################################################
CREATE PROC prcImportFromEdari @FDate DATETIME
AS 
/* 
	must create proc in data contain edari table and execute it in this database

	amndb079 data Ameen
	

	File11n - Ac000
	File17n - My000
	File13n - Mt000
	FileAGrp - Gr000
	File12n - Ce000
	File12n - En000
	File15n - Bu000
	File14n - Bi000
*/
	if exists (select * from dbo.sysobjects where id = object_id(N'#ac_e') )
	drop table #ac_e
	
	
	CREATE TABLE #ac_e
	(
		[Number] [float],
		[Name] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
		[Code] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
		[CDate] [datetime] DEFAULT ('1/1/1980'),
		[NSons] [int]  DEFAULT (0),
		[Debit] [float] DEFAULT (0),
		[Credit] [float] DEFAULT (0),
		[InitDebit] [float] DEFAULT (0),
		[InitCredit] [float] DEFAULT (0),
		[UseFlag] [int] DEFAULT (0),
		[MaxDebit] [float] DEFAULT (0),
		[Notes] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
		[CurrencyVal] [float] DEFAULT (1),
		[Warn] [float] DEFAULT (0),
		[CheckDate] [datetime] DEFAULT ('1/1/1980'),
		[Security] [int] DEFAULT (1),
		[DebitOrCredit] [int] DEFAULT (0),
		[Type] [int] DEFAULT (0),
		[State] [int] DEFAULT (0),
		[Num1] [float] DEFAULT (0),
		[Num2] [float] DEFAULT (0),
		[LatinName] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
		[GUID]  uniqueidentifier ROWGUIDCOL  DEFAULT (newid()),
		[ParentGUID] [uniqueidentifier] DEFAULT (0x0),
		[FinalGUID] [uniqueidentifier] DEFAULT (0x0),
		[CurrencyGUID] [uniqueidentifier] DEFAULT (0x0),
		[BranchGUID] [uniqueidentifier] DEFAULT (0x0),
		[branchMask] [bigint] DEFAULT (0),
		[ParentNum] FLOAT DEFAULT(0),
		[FinalNum] FLOAT DEFAULT(0),
		[CurrencyNum] INT DEFAULT(1),
		[BeginBal] FLOAT)

	-- select distinct dest from File11n 
	-- 4 „Ì“«‰Ì…
	-- 2 „ «Ã—…
	-- 3 √—»«Õ ÊŒ”«∆—

	 --select * from File11n where dest = 3
	Print 'My000'
	
	ALTER TABLE amndb079..my000 DISABLE TRIGGER ALL
		DELETE FROM amndb079..my000
		INSERT INTO amndb079..my000 ([Number], [Code], [Name], [CurrencyVal], [PartName], [PartPrecision],     [Date], [Security], [LatinName], [LatinPartName],  [GUID], [branchMask])
			SELECT                      1, 'Main', 'Main',             1,         '',              '', '1-1-1980',          1,          '',              '', newid(), 0 

		INSERT INTO amndb079..my000 ([Number], [Code], [Name], [CurrencyVal], [PartName], [PartPrecision],     [Date], [Security], [LatinName], [LatinPartName],  [GUID], [branchMask])
			SELECT                Number , [Code], [Name],         Equal, [PartName],              '', '1-1-1980',          1, [LatinName], [LatinPartName], newid(), 0 
			FROM ( SELECT Curr + 1 AS Number,   CAST( Curr AS NVARCHAR(100)) AS Code, CAST( Curr AS NVARCHAR(100)) AS [Name], Equal, CAST( Curr AS NVARCHAR(100)) [PartName], CAST( Curr AS NVARCHAR(100)) [LatinName], CAST( Curr AS NVARCHAR(100)) [LatinPartName] FROM file17n where Seq = Curr) as rs

	ALTER TABLE amndb079..my000 ENABLE TRIGGER ALL
	declare @DefCurr UNIQUEIDENTIFIER 
	SELECT @DefCurr = Guid FROM amndb079..my000 WHERE Number = 1
	print @DefCurr 
	update amndb079..op000 set Value = @DefCurr, PrevValue = @DefCurr WHERE Name = 'AmnCfg_DefaultCurrency'
	Print 'Ac000'

	ALTER TABLE amndb079..ac000 DISABLE TRIGGER ALL
		DELETE FROM amndb079..ac000

		--update amndb079..ac000 set CheckDate = CDate, CDate = CheckDate

		INSERT INTO #ac_e( 
				[Number],  [Name], [Code],  [CDate],    [NSons], [Debit], [Credit], [InitDebit], [InitCredit], [UseFlag], [MaxDebit], [Notes],                                        [CurrencyVal], [Warn], [CheckDate], [Security], [DebitOrCredit], [Type], [State], [Num1], [Num2], [LatinName],  [GUID], [ParentGUID], [FinalGUID], [CurrencyGUID], [BranchGUID], [branchMask], [ParentNum], [FinalNum], [CurrencyNum], [BeginBal]) 
			SELECT
			 	[Seq]  , [Name1],  [Num], [FixDate], [SubCount],  [Tot1],   [Tot2],           0,            0,         0,    Cieling, Remarks, CASE WHEN ISNULL ( AEqua, 0) = 0 THEN 1 ELSE AEqua END,      0,   '1-1-1980'/*[FixDate]*/,          1,               0,      1,       0,      0,      0,       Name2, newid(),          0x0,         0x0,            0x0,          0x0,            0,      Master,       Dest, CASE WHEN ISNULL( Acur, 0) = 0 THEN 1 ELSE Acur + 1 END, ISNULL( [Bal], 0)
			FROM File11n

		UPDATE 	ac1 SET ac1.ParentGuid = ac2.Guid
		FROM
			#ac_e ac1 INNER JOIN #ac_e ac2 
			ON ac1.ParentNum =ac2.Number


		INSERT INTO #ac_e([Number], [Name], [Code], [CDate], [NSons], [Debit], [Credit], [InitDebit], [InitCredit], [UseFlag], [MaxDebit], [Notes], [CurrencyVal], [Warn], [CheckDate], [Security], [DebitOrCredit], [Type], [State], [Num1], [Num2], [LatinName], [GUID], [ParentGUID], [FinalGUID], [CurrencyGUID], [BranchGUID], [branchMask], [CurrencyNum])
			   VALUES(4, '«·„Ì“«‰Ì…', '00', '1-1-1980', 0,0,0,0,0,0,0,'',1,0,'1-1-1980',1,0,2,0,0,0,'«·„Ì“«‰Ì…', '898FEA9B-DC58-42FC-959E-EE161506FE70', 0x0, 0x0, 0x0, 0x0, 0, 1)
		
		INSERT INTO #ac_e([Number], [Name], [Code], [CDate], [NSons], [Debit], [Credit], [InitDebit], [InitCredit], [UseFlag], [MaxDebit], [Notes], [CurrencyVal], [Warn], [CheckDate], [Security], [DebitOrCredit], [Type], [State], [Num1], [Num2], [LatinName], [GUID], [ParentGUID], [FinalGUID], [CurrencyGUID], [BranchGUID], [branchMask], [CurrencyNum])
			   VALUES(3, '«·√—»«Õ Ê«·Œ”«∆—', '001', '1-1-1980', 0,0,0,0,0,0,0,'',1,0,'1-1-1980',1,0,2,0,0,0,'«·√—»«Õ Ê«·Œ”«∆—', '50A7C0E1-4531-448D-8DBF-88A464008E98', '898FEA9B-DC58-42FC-959E-EE161506FE70', 0x0, 0x0, 0x0, 0, 1)
		
		INSERT INTO #ac_e([Number], [Name], [Code], [CDate], [NSons], [Debit], [Credit], [InitDebit], [InitCredit], [UseFlag], [MaxDebit], [Notes], [CurrencyVal], [Warn], [CheckDate], [Security], [DebitOrCredit], [Type], [State], [Num1], [Num2], [LatinName], [GUID], [ParentGUID], [FinalGUID], [CurrencyGUID], [BranchGUID], [branchMask], [CurrencyNum])
			   VALUES(2, '«·„ «Ã—…', '0011', '1-1-1980', 0,0,0,0,0,0,0,'',1,0,'1-1-1980',1,0,2,0,0,0,'«·„ «Ã—…', 'B3F2311C-0B55-49C9-8274-53CCDFE9615C', '50A7C0E1-4531-448D-8DBF-88A464008E98', 0x0, 0x0, 0x0, 0, 1)

		-- 4 „Ì“«‰Ì…
		-- 2 „ «Ã—…
		-- 3 √—»«Õ ÊŒ”«∆—

		UPDATE 	#ac_e 
			SET FinalGuid = CASE 
						WHEN FinalNum = 4 THEN '898FEA9B-DC58-42FC-959E-EE161506FE70'
						WHEN FinalNum = 2 THEN 'B3F2311C-0B55-49C9-8274-53CCDFE9615C'
						WHEN FinalNum = 3 THEN '50A7C0E1-4531-448D-8DBF-88A464008E98'
					END
	
		UPDATE 	#ac_e SET CurrencyGuid = m.Guid
		FROM
			#ac_e INNER JOIN amndb079..my000 m ON #ac_e.CurrencyNum = m.Number
	
		INSERT INTO amndb079..ac000( [Number], [Name], [Code], [CDate], [NSons], [Debit], [Credit], [InitDebit], [InitCredit], [UseFlag], [MaxDebit], [Notes], [CurrencyVal], [Warn], [CheckDate], [Security], [DebitOrCredit], [Type], [State], [Num1], [Num2], [LatinName], [GUID], [ParentGUID], [FinalGUID], [CurrencyGUID], [BranchGUID], [branchMask])
			              SELECT [Number], [Name], [Code], [CDate], [NSons], [Debit], [Credit], [InitDebit], [InitCredit], [UseFlag], [MaxDebit], [Notes], [CurrencyVal], [Warn], [CheckDate], [Security], [DebitOrCredit], [Type], [State], [Num1], [Num2], [LatinName], [GUID], [ParentGUID], [FinalGUID], [CurrencyGUID], [BranchGUID], [branchMask]
			  FROM #ac_e
	ALTER TABLE amndb079..ac000 ENABLE TRIGGER ALL
	
	-----------------------------------------
	--
	--	material and group
	--
	------------------------------------------
	-- FileAGrp - Gr000
	-- File13n - Mt000
	ALTER TABLE amndb079..gr000 DISABLE TRIGGER ALL
		DELETE FROM amndb079..gr000
		DECLARE @grGuid1 UNIQUEIDENTIFIER, @grGuid2 UNIQUEIDENTIFIER, @grGuid3 UNIQUEIDENTIFIER
		SET @grGuid1 = newid()
		SET @grGuid2 = newid()
		SET @grGuid3 = newid()

		if exists (select * from dbo.sysobjects where id = object_id(N'#gr_e') )
		drop table #gr_e
	
		CREATE TABLE #gr_e(
			[Number] [float] DEFAULT (0),
			[Code] [NVARCHAR] (100) COLLATE Arabic_CI_AI DEFAULT (''),
			[Name] [NVARCHAR] (250) COLLATE Arabic_CI_AI DEFAULT (''),
			[Notes] [NVARCHAR] (250) COLLATE Arabic_CI_AI DEFAULT (''),
			[Security] [int] DEFAULT (0),
			[GUID]  uniqueidentifier ROWGUIDCOL  NOT NULL DEFAULT (newid()),
			[Type] [int] DEFAULT (0),
			[VAT] [float] DEFAULT (0),
			[LatinName] [NVARCHAR] (250) COLLATE Arabic_CI_AI DEFAULT (''),
			[ParentGUID] [uniqueidentifier] DEFAULT (0x00),
			[branchMask] [bigint] DEFAULT (0))
	Print 'Gr000'	
	
		INSERT INTO #gr_e 
			([Number],       [Code],   [Name], [Notes], [Security],  [GUID], [Type], [VAT], [LatinName], [ParentGUID], [branchMask])
			SELECT	1,          '1',   '„Ã„Ê⁄… „ «Ã—…', '', 1,  @grGuid1, 0, 0, '„Ã„Ê⁄… „ «Ã—…', 0x0, 0
		INSERT INTO #gr_e 
			([Number],       [Code],   [Name], [Notes], [Security],  [GUID], [Type], [VAT], [LatinName], [ParentGUID], [branchMask])
			SELECT	2,          '2',   '„Ã„Ê⁄…  ’‰Ì⁄', '', 1,  @grGuid2, 0, 0, '„Ã„Ê⁄…  ’‰Ì⁄', 0x0, 0
		INSERT INTO #gr_e 
			([Number],       [Code],   [Name], [Notes], [Security],  [GUID], [Type], [VAT], [LatinName], [ParentGUID], [branchMask])
			SELECT	3,          '3',   '„Ã„Ê⁄… ·« „Œ“‰Ì…', '', 1,  @grGuid3, 0, 0, '„Ã„Ê⁄… ·« „Œ“‰Ì…', 0x0, 0

		INSERT INTO amndb079..gr000 ([Number],       [Code],   [Name], [Notes], [Security],  [GUID], [Type], [VAT], [LatinName], [ParentGUID], [branchMask])
				   SELECT   [Number],       [Code],   [Name], [Notes], [Security],  [GUID], [Type], [VAT], [LatinName], [ParentGUID], [branchMask]
			FROM #gr_e
	
	ALTER TABLE amndb079..gr000 ENABLE TRIGGER ALL	

	Print 'MT000'
	

	ALTER TABLE amndb079..mt000 DISABLE TRIGGER ALL

		DELETE FROM amndb079..mt000
		if exists (select * from dbo.sysobjects where id = object_id(N'#mt_e') )
		drop table #mt_e
	
		CREATE TABLE #mt_e(
			[Number] [float] DEFAULT (0),
			[Name] [NVARCHAR] (250),
			[Code] [NVARCHAR] (100),
			[LatinName] [NVARCHAR] (250),
			[BarCode] [NVARCHAR] (100),
			[CodedCode] [NVARCHAR] (250),
			[Unity] [NVARCHAR] (100),
			[Spec] [NVARCHAR] (250),
			[Qty] [float] DEFAULT (0),
			[High] [float] DEFAULT (0),
			[Low] [float] DEFAULT (0),
			[Whole] [float] DEFAULT (0),
			[Half] [float] DEFAULT (0),
			[Retail] [float] DEFAULT (0),
			[EndUser] [float] DEFAULT (0),
			[Export] [float] DEFAULT (0),
			[Vendor] [float] DEFAULT (0),
			[MaxPrice] [float] DEFAULT (0),
			[AvgPrice] [float] DEFAULT (0),
			[LastPrice] [float] DEFAULT (0),
			[PriceType] [int] DEFAULT (0),
			[SellType] [int] DEFAULT (0),
			[BonusOne] [float] DEFAULT (0),
			[CurrencyVal] [float] DEFAULT (0),
			[UseFlag] [float] DEFAULT (0),
			[Origin] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[Company] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[Type] [int] DEFAULT (0),
			[Security] [int] DEFAULT (1),
			[LastPriceDate] [datetime] DEFAULT ('1/1/1980'),
			[Bonus] [float] DEFAULT (0),
			[Unit2] [NVARCHAR] (100) COLLATE Arabic_CI_AI,
			[Unit2Fact] [float] DEFAULT (0),
			[Unit3] [NVARCHAR] (100) COLLATE Arabic_CI_AI,
			[Unit3Fact] [float] DEFAULT (0),
			[Flag] [float] DEFAULT (0),
			[Pos] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[Dim] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[ExpireFlag] [bit] DEFAULT (0),
			[ProductionFlag] [bit] DEFAULT (0),
			[Unit2FactFlag] [bit] DEFAULT (0),
			[Unit3FactFlag] [bit] DEFAULT (0),
			[BarCode2] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[BarCode3] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[SNFlag] [bit] DEFAULT (0),
			[ForceInSN] [bit] DEFAULT (0),
			[ForceOutSN] [bit] DEFAULT (0),
			[VAT] [float] DEFAULT (0),
			[Color] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[Provenance] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[Quality] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[Model] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[Whole2] [float] DEFAULT (0),
			[Half2] [float] DEFAULT (0),
			[Retail2] [float] DEFAULT (0),
			[EndUser2] [float] DEFAULT (0),
			[Export2] [float] DEFAULT (0),
			[Vendor2] [float] DEFAULT (0),
			[MaxPrice2] [float] DEFAULT (0),
			[LastPrice2] [float] DEFAULT (0),
			[Whole3] [float] DEFAULT (0),
			[Half3] [float] DEFAULT (0),
			[Retail3] [float] DEFAULT (0),
			[EndUser3] [float] DEFAULT (0),
			[Export3] [float] DEFAULT (0),
			[Vendor3] [float] DEFAULT (0),
			[MaxPrice3] [float] DEFAULT (0),
			[LastPrice3] [float] DEFAULT (0),
			[GUID]  uniqueidentifier DEFAULT (newid()),
			[GroupGUID] [uniqueidentifier] DEFAULT (0x00),
			[PictureGUID] [uniqueidentifier] DEFAULT (0x00),
			[CurrencyGUID] [uniqueidentifier]DEFAULT (0x00),
			[DefUnit] [int] DEFAULT (1),
			[bHide] [bit] DEFAULT (0),
			[branchMask] [bigint] DEFAULT (0),
			[OldGUID] [uniqueidentifier] DEFAULT (0x00),
			[NewGUID] [uniqueidentifier] DEFAULT (0x00),
			[Assemble] [bit] DEFAULT (0)
		)

		INSERT INTO #mt_e 
			([Number], [Name], [Code], [LatinName], [BarCode], [CodedCode], [Unity],  [Spec], [Qty], [High], [Low], [Whole],  [Half], [Retail], [EndUser], [Export], [Vendor], [MaxPrice], [AvgPrice], [LastPrice], [PriceType]																									 , [BonusOne], 								               [CurrencyVal], [UseFlag], [Origin], [Company], [Type], [Security], [LastPriceDate], [Bonus], [Unit2], [Unit2Fact], [Unit3], [Unit3Fact], [Flag], [Pos], [Dim], [ExpireFlag], [ProductionFlag], [Unit2FactFlag], [Unit3FactFlag], [BarCode2], [BarCode3], [SNFlag], [ForceInSN], [ForceOutSN], [VAT], [Color], [Provenance], [Quality], [Model],            [Whole2],            [Half2],           [Retail2],           [EndUser2], [Export2],          [Vendor2], [MaxPrice2], [LastPrice2],             [Whole3],            [Half3],           [Retail3],           [EndUser3], [Export3],          [Vendor3], [MaxPrice3], [LastPrice3],  [GUID],  										   [GroupGUID], [PictureGUID], 								               [CurrencyGUID],    	      [DefUnit], [bHide], [branchMask], [OldGUID], [NewGUID], [Assemble])
		SELECT        Seq,  Name1,    Num,       Name2,  Barcode ,          '',    Unt1, Remarks,     0,      0,     0, SellPr1, SellPr2,  SellPr3,   SellPr4,        0, Sellpr5,           0,          0,           0, CASE WHEN (SellType1 = 1) OR ( SellType1 = 5) THEN 15 WHEN ( SellType1 = 2) OR ( SellType1 = 6) THEN 121 WHEN ( SellType1 = 3)OR( SellType1 = 7) THEN 122  WHEN ( SellType1 = 4) OR ( SellType1 = 8) THEN 120 END,      Bonus, (select CurrencyVal from amndb079..my000 my WHERE Number = ISNULL( f.MatCurr, 0) + 1),         0,   CatNum,   CustNum,      0,          1,     '1-1-1980',        0,    Unt2,    UFactor2,    Unt3,    UFactor3,      0,     0,     0,            0,                0,               0,   		 0, 	    '',         '',        0,           0,            0,   VAT,      '',           '',        '',      '',  SellPr1 * UFactor2, SellPr2 * UFactor2,  SellPr3 * UFactor2,   SellPr4 * UFactor2,         0, Sellpr5 * UFactor2,           0,            0,   SellPr1 * UFactor3, SellPr2 * UFactor3,  SellPr3 * UFactor3,   SellPr4 * UFactor3,         0, Sellpr5 * UFactor3,           0,            0, newid(), CASE WHEN Dest = 1 THEN @grGuid1 WHEN Dest = 2 THEN @grGuid2 WHEN Dest = 3 THEN @grGuid3 END ,           0x0, (select Guid from amndb079..my000 my WHERE Number = ISNULL( f.MatCurr, 0) + 1),  ISNULL( DefUnit, 0) + 1,       0,            0,       0x0,       0x0, 0
		FROM File13n f

			INSERT INTO amndb079..mt000 ([Number], [Name], [Code], [LatinName], [BarCode], [CodedCode], [Unity], [Spec], [Qty], [High], [Low], [Whole], [Half], [Retail], [EndUser], [Export], [Vendor], [MaxPrice], [AvgPrice], [LastPrice], [PriceType], [SellType], [BonusOne], [CurrencyVal], [UseFlag], [Origin], [Company], [Type], [Security], [LastPriceDate], [Bonus], [Unit2], [Unit2Fact], [Unit3], [Unit3Fact], [Flag], [Pos], [Dim], [ExpireFlag], [ProductionFlag], [Unit2FactFlag], [Unit3FactFlag], [BarCode2], [BarCode3], [SNFlag], [ForceInSN], [ForceOutSN], [VAT], [Color], [Provenance], [Quality], [Model], [Whole2], [Half2], [Retail2], [EndUser2], [Export2], [Vendor2], [MaxPrice2], [LastPrice2], [Whole3], [Half3], [Retail3], [EndUser3], [Export3], [Vendor3], [MaxPrice3], [LastPrice3], [GUID], [GroupGUID], [PictureGUID], [CurrencyGUID], [DefUnit], [bHide], [branchMask], [OldGUID], [NewGUID], [Assemble] )
				            SELECT   [Number], [Name], [Code], [LatinName], [BarCode], [CodedCode], [Unity], [Spec], [Qty], [High], [Low], [Whole], [Half], [Retail], [EndUser], [Export], [Vendor], [MaxPrice], [AvgPrice], [LastPrice], [PriceType], [SellType], [BonusOne], [CurrencyVal], [UseFlag], [Origin], [Company], [Type], [Security], [LastPriceDate], [Bonus], [Unit2], [Unit2Fact], [Unit3], [Unit3Fact], [Flag], [Pos], [Dim], [ExpireFlag], [ProductionFlag], [Unit2FactFlag], [Unit3FactFlag], [BarCode2], [BarCode3], [SNFlag], [ForceInSN], [ForceOutSN], [VAT], [Color], [Provenance], [Quality], [Model], [Whole2], [Half2], [Retail2], [EndUser2], [Export2], [Vendor2], [MaxPrice2], [LastPrice2], [Whole3], [Half3], [Retail3], [EndUser3], [Export3], [Vendor3], [MaxPrice3], [LastPrice3], [GUID], [GroupGUID], [PictureGUID], [CurrencyGUID], [DefUnit], [bHide], [branchMask], [OldGUID], [NewGUID], [Assemble]
			FROM #mt_e
	
	ALTER TABLE amndb079..mt000 ENABLE TRIGGER ALL
	-----------------------------------------------------------------
	--
	--	Enty ce000 and en000 File12n
	--
	------------------------------------------------------------------
	Print 'ce000'
	
	ALTER TABLE amndb079..ce000 DISABLE TRIGGER ALL
	ALTER TABLE amndb079..en000 DISABLE TRIGGER ALL

		DELETE FROM amndb079..en000 WHERE ParentGuid IN ( SELECT Guid FROM amndb079..ce000 WHERE TypeGuid = 0x0)
		DELETE FROM amndb079..ce000 WHERE TypeGuid = 0x0

		CREATE TABLE #ce_e(
			[Type] [int] ,
			[Number] [float] ,
			[Date] [datetime] ,
			[Debit] [float] ,
			[Credit] [float],
			[Notes] [NVARCHAR] (250) COLLATE Arabic_CI_AI ,
			[CurrencyVal] [float] ,
			[IsPosted] [int] ,
			[State] [int] ,
			[Security] [int] ,
			[Num1] [float] ,
			[Num2] [float] ,
			[Branch] [uniqueidentifier] ,
			[GUID]  uniqueidentifier DEFAULT (newid()),
			[CurrencyGUID] [uniqueidentifier] ,
			[TypeGUID] [uniqueidentifier])
		DECLARE @FEGuid UNIQUEIDENTIFIER
		SET @FEGuid = newId()

		INSERT INTO #ce_e ([Type], [Number], [Date], [Debit],[Credit],           [Notes], [CurrencyVal], [IsPosted], [State], [Security], [Num1], [Num2], [Branch],  [GUID], [CurrencyGUID], [TypeGUID])
			     SELECT     1,        1, @FDate,       0,       0,  '«·ﬁÌœ «·«›  «ÕÌ',             1,          1,      '',          1,      0,      0,      0x0, @FEGuid, (select Guid from amndb079..my000 my WHERE Number = 1), 0x0

		INSERT INTO #ce_e ([Type], [Number], [Date], [Debit],[Credit],    [Notes], [CurrencyVal], [IsPosted], [State], [Security], [Num1], [Num2], [Branch],  [GUID], [CurrencyGUID], [TypeGUID])
			SELECT          1,      Num,   Date,       0,       0,         '',             1,          1,      '',          1,      0,      0,      0x0, newid(), (select Guid from amndb079..my000 my WHERE Number = 1), 0x0
			FROM File12n f
			WHERE
				/*UnPosted = 0 AND */ ISNULL( ForBill, 0) = 0
			GROUP BY
				Num, 
				Date
				
			

		INSERT INTO amndb079..ce000 ([Type], [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted], [State], [Security], [Num1], [Num2], [Branch], [GUID], [CurrencyGUID], [TypeGUID])
				      SELECT [Type], [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted], [State], [Security], [Num1], [Num2], [Branch], [GUID], [CurrencyGUID], [TypeGUID]
			FROM #ce_e

	Print 'en000'
	
		-------------------------------------------------------------
		CREATE TABLE #en_e (
			[Number] [int],
			[Date] [datetime],
			[Debit] [float],
			[Credit] [float],
			[Notes] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
			[CurrencyVal] [float],
			[Class] [float],
			[Num1] [float],
			[Num2] [float],
			[Vendor] [float],
			[SalesMan] [float],
			[GUID]  uniqueidentifier DEFAULT (newid()),
			[ParentGUID] [uniqueidentifier],
			[AccountGUID] [uniqueidentifier],
			[CurrencyGUID] [uniqueidentifier],
			[CostGUID] [uniqueidentifier],
			[ContraAccGUID] [uniqueidentifier],
			[ParentNum] [FLOAT],
			[AccountNum] [FLOAT])


		INSERT INTO #en_e( [Number], [Date],                                                   [Debit],                                                 [Credit], [Notes],     [CurrencyVal], [Class], [Num1], [Num2], [Vendor], [SalesMan],  [GUID], [ParentGUID], [AccountGUID],                                                              [CurrencyGUID], [CostGUID], [ContraAccGUID], [ParentNum], [AccountNum])
			SELECT          Seq, [Date], CASE WHEN Dept = 1 THEN Am * CASE WHEN ISNULL( Equal, 1) = 0 THEN 1 ELSE ISNULL( Equal, 1) END ELSE 0 END, CASE WHEN Dept = 0 THEN Am * CASE WHEN ISNULL( Equal, 1) = 0 THEN 1 ELSE ISNULL( Equal, 1) END ELSE 0 END,    Exp1, ISNULL( Equal, 0),       0,      0,      0,        0,          0, Newid(),          0x0,           0x0, (select Guid from amndb079..my000 my WHERE Number = ISNULL( f.Curr, 0) + 1),        0x0,             0x0,         Num,          Acc 
			FROM File12n f
			WHERE
				/*UnPosted = 0 AND */ ISNULL( ForBill, 0) = 0

		UPDATE en SET ParentGuid = ce.Guid
		FROM 
			#en_e en 
			INNER JOIN #ce_e ce ON ce.Number = en.ParentNum

		UPDATE en SET AccountGuid = ac.Guid
		FROM 
			#en_e en INNER JOIN #ac_e ac ON en.AccountNum = ac.Number AND ac.Type = 1
			
		INSERT INTO #en_e( [Number], [Date],                                              [Debit],                                            [Credit],           [Notes], [CurrencyVal], [Class], [Num1], [Num2], [Vendor], [SalesMan],  [GUID], [ParentGUID], [AccountGUID],                                         [CurrencyGUID], [CostGUID], [ContraAccGUID], [ParentNum], [AccountNum])
			SELECT       Number, @FDate, CASE WHEN  [BeginBal] > 0 THEN Abs( [BeginBal]) ELSE 0 END, CASE WHEN [BeginBal] < 0 THEN Abs( [BeginBal]) ELSE 0 END,  '«·ﬁÌœ «·«›  «ÕÌ',             1,       0,      0,      0,        0,          0, Newid(),      @FEGuid,          Guid, (select Guid from amndb079..my000 my WHERE Number = 1),        0x0,             0x0,           0,      Number
			FROM #ac_e e 
		WHERE [BeginBal] <> 0 AND Type =1 AND [NSons] = 0


		INSERT INTO amndb079..en000 ( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Num1], [Num2], [Vendor], [SalesMan], [GUID], [ParentGUID], [AccountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID])
			               SELECT [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Num1], [Num2], [Vendor], [SalesMan], [GUID], [ParentGUID], [AccountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID]
			FROM #en_e

	ALTER TABLE amndb079..ce000 ENABLE TRIGGER ALL
	ALTER TABLE amndb079..en000 ENABLE TRIGGER ALL
	-------------------------------------------------------------------
	--
	-- Store
	--
	-------------------------------------------------------------------
	ALTER TABLE amndb079..st000 DISABLE TRIGGER ALL
		DELETE FROM amndb079..st000
		DECLARE @StoreCnt INT, @s INT
		SELECT @StoreCnt = StoresCnt FROM File16n
		SET @s = @StoreCnt
		WHILE @s <> 0
		BEGIN
			INSERT INTO amndb079..st000 ( [Number],                    [Code],                                [Name], [Notes], [Address], [Keeper], [Security],                          [LatinName],  [GUID], [ParentGUID], [AccountGUID], [Type], [branchMask])
					     SELECT         @s, CAST( @s AS NVARCHAR(100)), '„” Êœ⁄ ' + CAST( @s AS NVARCHAR(100)),      '',        '',       '',          1, 'Store ' + CAST( @s AS NVARCHAR(100)), newid(),          0x0,           0x0,      0, 0
			SET @s = @s - 1
		END
	ALTER TABLE amndb079..st000 ENABLE TRIGGER ALL
	--------------------------------------------------------
	--
	-- Bill   file15n -> bu000
	--
	--------------------------------------------------------
	/*
	kind 1  '„‘ —Ì« '
	kind 2  '„— Ã⁄ „‘ —Ì« '
	kind 3  '≈œŒ«·'
	kind 4  '„»Ì⁄« '
	kind 5  '„— Ã⁄ „»Ì⁄« '
	Kind 6  '≈Œ—«Ã'
	*/
	ALTER TABLE amndb079..bu000 disable TRIGGER ALL
	ALTER TABLE amndb079..bi000 disable TRIGGER ALL
	ALTER TABLE amndb079..di000 disable TRIGGER ALL	
	ALTER TABLE amndb079..cu000 disable TRIGGER ALL	

	DELETE FROM amndb079..bu000
	DELETE FROM amndb079..bi000
	DELETE FROM amndb079..di000
	DELETE FROM amndb079..cu000

	if exists (select * from dbo.sysobjects where id = object_id(N'#bu_e') )
	drop table #bu_e

	CREATE TABLE #bu_e(
		[Number] [float],
		[Cust_Name] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
		[Date] [datetime],
		[CurrencyVal] [float],
		[Notes] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
		[Total] [float],
		[PayType] [int],
		[TotalDisc] [float],
		[TotalExtra] [float],
		[ItemsDisc] [float],
		[BonusDisc] [float],
		[FirstPay] [float],
		[Profits] [float],
		[IsPosted] [int],
		[Security] [int],
		[Vendor] [float],
		[SalesManPtr] [float],
		[Branch] [uniqueidentifier],
		[VAT] [float],
		[GUID]  uniqueidentifier DEFAULT (newid()),
		[TypeGUID] [uniqueidentifier] ,
		[CustGUID] [uniqueidentifier],
		[CurrencyGUID] [uniqueidentifier],
		[StoreGUID] [uniqueidentifier],
		[CustAccGUID] [uniqueidentifier],
		[MatAccGUID] [uniqueidentifier],
		[ItemsDiscAccGUID] [uniqueidentifier],
		[BonusDiscAccGUID] [uniqueidentifier],
		[FPayAccGUID] [uniqueidentifier],
		[CostGUID] [uniqueidentifier],
		[UserGUID] [uniqueidentifier],
		[CheckTypeGUID] [uniqueidentifier],
		[TextFld1] [NVARCHAR] (100) COLLATE Arabic_CI_AI,
		[TextFld2] [NVARCHAR] (100) COLLATE Arabic_CI_AI,
		[TextFld3] [NVARCHAR] (100) COLLATE Arabic_CI_AI,
		[TextFld4] [NVARCHAR] (100) COLLATE Arabic_CI_AI,
		[RecState] [int],
		[ItemsExtra] [float] ,
		[ItemsExtraAccGUID] [uniqueidentifier],
		BillId FLOAT)

	  INSERT INTO #bu_e( [Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [TotalDisc], [TotalExtra], [ItemsDisc], [BonusDisc], [FirstPay], [Profits], [IsPosted], [Security], [Vendor], [SalesManPtr], [Branch], [VAT],  [GUID], [TypeGUID], [CustGUID],                                              [CurrencyGUID],                                         [StoreGUID], [CustAccGUID], [MatAccGUID],     [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID], [CheckTypeGUID], [TextFld1], [TextFld2], [TextFld3], [TextFld4], [RecState], [ItemsExtra], [ItemsExtraAccGUID], BillId)
		   SELECT	  Num,          '', [Date],          Equa, remarks,       0,         1,      DisCnt,            0,           0,           0,          0,         0,          1,          1,        0,             0,      0x0,     0, newid(),    bt.Guid,        0x0, (select top 1 Guid from amndb079..my000 my WHERE Number = cast( isnull( curr,0) as int) +1), (select Guid from amndb079..st000 where Number = 1),       ac.Guid,     acm.Guid, ISNULL( acd.Guid, 0x0),                0x0,           0x0,        0x0,        0x0,             0x0,         '',         '',         '',         '',          0,            0,                 0x0, Seq
		   FROM file15n f
		/*
		SELECT ac.* FROM file15n as f 
		inner join amndb079..AC000 ac on f.DKindRecNo = ac.Number
		where ac.Type = 1
		*/
		INNER JOIN amndb079..ac000 ac ON f.Two = ac.Number
		INNER join amndb079..AC000 acm on f.DKindRecNo = acm.Number
		LEFT JOIN amndb079..ac000 acd ON f.DDiscntR = acd.Number
		INNER join amndb079..bt000 bt 
		on CASE WHEN f.Kind = 1 THEN '„‘ —Ì« '
			WHEN f.Kind = 2 THEN '„— Ã⁄ „‘ —Ì« '
			WHEN f.Kind = 3 THEN '≈œŒ«·'
			WHEN f.Kind = 4 THEN '„»Ì⁄« '
			WHEN f.Kind = 5 THEN '„— Ã⁄ „»Ì⁄« '
			WHEN f.Kind = 6 THEN '≈Œ—«Ã' END = bt.[Name]
	
	INSERT INTO amndb079..bu000([Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [TotalDisc], [TotalExtra], [ItemsDisc], [BonusDisc], [FirstPay], [Profits], [IsPosted], [Security], [Vendor], [SalesManPtr], [Branch], [VAT], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID], [MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID], [CheckTypeGUID], [TextFld1], [TextFld2], [TextFld3], [TextFld4], [RecState], [ItemsExtra], [ItemsExtraAccGUID])
			     SELECT [Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [TotalDisc], [TotalExtra], [ItemsDisc], [BonusDisc], [FirstPay], [Profits], [IsPosted], [Security], [Vendor], [SalesManPtr], [Branch], [VAT], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID], [MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID], [CheckTypeGUID], [TextFld1], [TextFld2], [TextFld3], [TextFld4], [RecState], [ItemsExtra], [ItemsExtraAccGUID] 
			FROM #bu_e
	
	INSERT INTO amndb079..di000( Number,     Discount, Extra,    CurrencyVal, Notes, flag,    Guid, ClassPtr, ParentGuid,         AccountGuid,    CurrencyGuid, CostGuid,  ContraAccGuid)
			      SELECT      1, bu.TotalDisc,     0, bu.CurrencyVal,    '',    0, newid(),        0,    bu.Guid, bu.ItemsDiscAccGUID, bu.CurrencyGuid,      0x0, bu.CustAccGUID
			      FROM #bu_e bu WHERE bu.TotalDisc <> 0 AND ISNULL( bu.ItemsDiscAccGUID, 0x0) <> 0x0
	---------------------------------------------
	-- bi000
	---------------------------------------------
	CREATE TABLE #bi_e(
		[Number] [float],
		[Qty] [float] ,
		[Order] [float],
		[OrderQnt] [float],
		[Unity] [float],
		[Price] [float],
		[BonusQnt] [float],
		[Discount] [float],
		[BonusDisc] [float],
		[Extra] [float],
		[CurrencyVal] [float],
		[Notes] [NVARCHAR] (250) COLLATE Arabic_CI_AI,
		[Profits] [float],
		[Num1] [float],
		[Num2] [float],
		[Qty2] [float],
		[Qty3] [float],
		[ClassPtr] [float],
		[ExpireDate] [datetime],
		[ProductionDate] [datetime],
		[Length] [float],
		[Width] [float],
		[Height] [float],
		[GUID]  uniqueidentifier,
		[VAT] [float],
		[VATRatio] [float],
		[ParentGUID] [uniqueidentifier],
		[MatGUID] [uniqueidentifier],
		[CurrencyGUID] [uniqueidentifier],
		[StoreGUID] [uniqueidentifier],
		[CostGUID] [uniqueidentifier],
		[SOType] [int],
		[SOGuid] [uniqueidentifier])

	INSERT INTO #bi_e([Number],   [Qty], [Order], [OrderQnt], [Unity], [Price], [BonusQnt], [Discount], [BonusDisc], [Extra], [CurrencyVal], [Notes], [Profits], [Num1], [Num2], [Qty2], [Qty3], [ClassPtr], [ExpireDate], [ProductionDate], [Length], [Width], [Height],  [GUID], [VAT], [VATRatio], [ParentGUID], [MatGUID],                                                 [CurrencyGUID],                                         [StoreGUID], [CostGUID], [SOType], [SOGuid])
		SELECT         Seq, [Quant],       0,          0,       1, [Price] * bu.[CurrencyVal],     OBonus,          0,           0,       0,          Equa, MatName,         0,      0,      0,      0,      0,          0,   '1-1-1980',       '1-1-1980',        0,       0,        0, newId(),     0,          0,      bu.Guid,   mt.GUID, (select Guid from amndb079..my000 my WHERE my.Number = curr+1), (select Guid from amndb079..st000 where Number = 1),        0x0,        0,     0x0
		FROM 
			File14n f 
			INNER JOIN #bu_e bu ON f.BillSeq = bu.BillId
			INNER JOIN amndb079..mt000 mt on mt.Number = f.Mat

	INSERT INTO amndb079..bi000([Number],   [Qty], [Order], [OrderQnt], [Unity], [Price], [BonusQnt], [Discount], [BonusDisc], [Extra], [CurrencyVal], [Notes], [Profits], [Num1], [Num2], [Qty2], [Qty3], [ClassPtr], [ExpireDate], [ProductionDate], [Length], [Width], [Height],  [GUID], [VAT], [VATRatio], [ParentGUID], [MatGUID],                                                 [CurrencyGUID],                                         [StoreGUID], [CostGUID], [SOType], [SOGuid])
			     SELECT [Number],   [Qty], [Order], [OrderQnt], [Unity], [Price], [BonusQnt], [Discount], [BonusDisc], [Extra], [CurrencyVal], [Notes], [Profits], [Num1], [Num2], [Qty2], [Qty3], [ClassPtr], [ExpireDate], [ProductionDate], [Length], [Width], [Height],  [GUID], [VAT], [VATRatio], [ParentGUID], [MatGUID],                                                 [CurrencyGUID],                                         [StoreGUID], [CostGUID], [SOType], [SOGuid]
			FROM #bi_e

	CREATE TABLE #cu_e( Name NVARCHAR(255) COLLATE Arabic_CI_AI, AccGuid UNIQUEIDENTIFIER, Guid UNIQUEIDENTIFIER DEFAULT newid(), Number INT identity(1,1))
	INSERT INTO #cu_e ( Name, AccGuid)
	SELECT ac.Name, bu.CustAccGuid
	FROM 
		amndb079..bu000 bu inner join amndb079..ac000 ac ON bu.CustAccGuid = ac.Guid
	GROUP BY 
		ac.Name, bu.CustAccGuid

	INSERT INTO amndb079..cu000(Number, CustomerName, AccountGuid, Guid)
			SELECT      Number, Name, AccGuid, Guid FROM #cu_e

	UPDATE bu SET CustGuid = cu.Guid
	FROM 
		amndb079..bu000 bu inner join amndb079..cu000 cu 
		on bu.CustAccGuid = cu.AccountGuid

	ALTER TABLE amndb079..bu000 enable TRIGGER ALL
	ALTER TABLE amndb079..bi000 enable TRIGGER ALL
	ALTER TABLE amndb079..di000 enable TRIGGER ALL
	ALTER TABLE amndb079..cu000 enable TRIGGER ALL
###########################################################
#END