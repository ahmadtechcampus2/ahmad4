###########################
CREATE PROCEDURE prcGenerateCostBillsTypes
	@InName NVARCHAR(250),
	@InAbbrev NVARCHAR(200),
	@OutName NVARCHAR(250),
	@OutAbbrev NVARCHAR(200)
AS
	SET NOCOUNT ON
	
	DECLARE 
		@InTypeGuid UNIQUEIDENTIFIER = NEWID(),
		@OutTypeGuid UNIQUEIDENTIFIER = NEWID()
	
	INSERT INTO bt000
	(
		[Type], 
		[GUID], 
		Name, 
		Abbrev, 
		LatinName,
		LatinAbbrev,
		bIsInput, 
		bIsOutput, 
		bAffectCostPrice, 
		bAffectLastPrice, 
		bNoEntry, 
		bNoPost, 
		bAutoPost, 
		BillType,
		BranchMask
	)
	VALUES
	(
		3, 
		@InTypeGuid, 
		@InName, 
		@InAbbrev, 
		N'Cost Input',
		N'Cost.In',
		1 /*IsInput*/, 
		0 /*IsOutput*/, 
		1 /*AffectCostPrice*/, 
		1 /*AffectLastPrice*/, 
		1 /*NoEntry*/, 
		0 /*NoPost*/, 
		1 /*AutoPost*/, 
		4 /*BillType*/,
		9223372036854775807
	)
	
	INSERT INTO bt000
	(
		[Type], 
		[GUID], 
		Name, 
		Abbrev, 
		LatinName,
		LatinAbbrev,
		bIsInput, 
		bIsOutput, 
		bAffectCostPrice, 
		bNoEntry, 
		bNoPost, 
		bAutoPost, 
		BillType,
		BranchMask
	)
	VALUES
	(
		3, 
		@OutTypeGuid, 
		@OutName, 
		@OutAbbrev, 
		N'Cost Output',
		N'Cost.Out',
		0 /*IsInput*/, 
		1 /*IsOutput*/, 
		0 /*AffectCostPrice*/, 
		1 /*NoEntry*/, 
		0 /*NoPost*/, 
		1 /*AutoPost*/, 
		5 /*BillType*/,
		9223372036854775807
	)
	
	SELECT @InTypeGuid AS InTypeGuid, @OutTypeGuid AS OutTypeGuid
############################################################################################################
CREATE FUNCTION fnGetCostBillTypes()
RETURNS @result TABLE
(
	InBillGuid uniqueidentifier,
	OutBillGuid uniqueidentifier
)
AS
BEGIN
	INSERT INTO @result(InBillGuid) SELECT ISNULL([GUID], 0x0) FROM bt000 WHERE LatinAbbrev = N'Cost.In'
	UPDATE @result SET OutBillGuid = (SELECT ISNULL([GUID], 0x0) FROM bt000 WHERE LatinAbbrev = N'Cost.Out')

	return
END
############################################################################################################
#END