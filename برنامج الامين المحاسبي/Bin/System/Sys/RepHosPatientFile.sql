################################################################
create proc RepHosPatientFile
	@FileGuid uniqueidentifier
AS
SET NOCOUNT ON 

CREATE TABLE #Result
	(
		ParentType		int,
		subtype			int DEFAULT  0, 
		Guid			uniqueidentifier, 
		[Description]	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[NAME]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Extra_Desc]	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Date]			DateTime,
		[DateOut]		DateTime,
		[Cost]			Float,
		[Discount]		float,
		unit			NVARCHAR(250) COLLATE ARABIC_CI_AI, -- æÍÏÉ ÇáãÇÏÉ
		Qty				float, -- ÇáßãíÉ 
		price			float, -- ÇáÓÚÑ  
		[Notes]			NVARCHAR(250) COLLATE ARABIC_CI_AI
	)

-------- General Data   0
INSERT INTO #Result
	(ParentType, Guid , [Description], [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	SELECT
	0, 
	Guid,
	'', -- description
	[Name],
	[Code],
	[DateIn],
	[DateOut],
	0, -- cost 
	0, -- discount	
	''	
	FROM 	vwhosfile
	WHERE Guid = @FileGuid

-------- Clinical Test  1
DECLARE @UserPerm INT, @UserGUID UNIQUEIDENTIFIER, @RecPerm int 
SET @UserGUID = dbo.fnGetCurrentUserGUID() 
SELECT @UserPerm = [dbo].[fnGetUserSec](@UserGUID, 0x8000D000  + 0x0570, 0x0, 1, 1 ) -- @PermType
select @RecPerm = ClinicalTestSecurity from hospfile000 where guid = @FileGuid
if (@UserPerm >= IsNull(@RecPerm,4))
begin
		
	insert into #Result
	(ParentType, subtype, cost , qty)
		select
		1,
		-1,
		0,
		count(*)
		FROM fnHosMiniCard(2) as fn
		inner join HosClinicalTests000 as CT ON	CT.TestGuid  = fn.Guid	
		inner join vwHosDoctor as doc on doc.guid = ct.doctorguid
		where ct.fileguid = @FileGuid
	
	insert into #Result
	(ParentType, Guid , [Description], [Name], [Extra_Desc], [Notes] )
		select
		1,
		ct.Guid,
		fn.[Name] + ', ÇáØÈíÈ ' + doc.[Name] + ' ,' + ct.Result ,
		fn.[Name],
		doc.[Name], --extra
		ct.Result
		FROM fnHosMiniCard(2) as fn
		inner join HosClinicalTests000 as CT ON	CT.TestGuid  = fn.Guid	
		inner join vwHosDoctor as doc on doc.guid = ct.doctorguid
		where ct.fileguid = @FileGuid
end		

DECLARE @DefCurGuid	UNIQUEIDENTIFIER   
DECLARE @DefCurVal	FLOAT   
SELECT @DefCurGuid =  Value from op000 where name = 'AmnCfg_DefaultCurrency'    
SELECT @DefCurVal = CurrencyVal from my000 where Guid = @DefCurGuid   

-- add Stay 2				
SELECT @UserPerm = [dbo].[fnGetUserSec](@UserGUID, 2147549376, 0x0, 1, 1 ) -- @PermType
insert into #Result 
	(ParentType, subtype, cost , qty)
	select 
	2,
	-1,
	sum((StayCost - StayDiscount) * StayCurrencyVal/@DefCurVal),
	count(*)
	from VwHosStay
	where StayfileGuid = @FileGuid   AND @UserPerm >= StaySecurity


DECLARE @Str 	  NVARCHAR(200)   
SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'site : ' ELSE 'ÇáãæÞÚ : ' END   
insert into #Result
	(ParentType, Guid , [Description], [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	2,
	StayGuid,
	@Str +
	CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  [SiteLatinName] ELSE [SiteName]  END ,
	CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  [SiteLatinName] ELSE [SiteName]  END ,
	SiteTypeName,
	StayStartDate,
	StayEndDate,
	StayCost * StayCurrencyVal/@DefCurVal,
	StayDiscount * StayCurrencyVal/@DefCurVal,
	StayNotes
	from VwHosStay
	where 
	StayfileGuid = @FileGuid AND @UserPerm >= StaySecurity

-- General Test 3
SELECT @UserPerm = [dbo].[fnGetUserSec](@UserGUID, 2147549584, 0x0, 1, 1 ) 
insert into #Result 
	(ParentType, subtype, cost , qty)
	select 
	3,
	-1,
	sum((Cost - discount)* CurrencyVal/@DefCurVal),
	count(*)
	from vwHosGeneralTest
	where fileGuid = @FileGuid AND @UserPerm >= Security

SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Operation : ' ELSE 'ÇáÚãá : ' END   
insert into #Result
	(ParentType, Guid , [Description], [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	3,
	Guid,
	@Str +
	CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  [OpLatinName] ELSE [OpName]  END ,
	CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  [OpLatinName] ELSE [OpName]  END ,
	'',
	[Date],
	'',
	cost * CurrencyVal/@DefCurVal,
	discount * CurrencyVal/@DefCurVal,
	Notes
	from vwHosGeneralTest
	where fileGuid = @FileGuid  AND @UserPerm >= Security
-- surgery 4 
--SELECT @UserPerm = [dbo].[fnGetUserSec](@UserGUID, 2147549280, 0x0, 1, 1 ) -- @PermType
insert into #Result
	(ParentType,subtype, cost , qty)
	select 
	4,
	-1,
	sum(Totalcost),
	count(*)
	From 
	fnHosGetSurgeryCost(@FileGuid)

SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Operation : ' ELSE 'ÇáÌÑÇÍÉ : ' END   
	insert into #Result	
	(ParentType,Guid,subtype,[Description],[Name],Extra_Desc,[Date],[DateOut],Cost,DisCount, unit, Qty, price,[Notes] )
	select 
		4,
		Guid,
		type,
		@Str +	[name],
		[name],
		'',
		[Date],
		[Dateout],
		cost,
		0,
		unit,
		qty,
		price,
		Notes
		from fnRepSurgeryDetailes(@FileGuid) AS SurDetailes 
-- CONSULTATION 5 
insert into #Result
	(ParentType,subtype, cost , qty)
	select 
	5,
	-1,
	sum(cost),
	count(*)
	From 	hoscons000
	where fileGuid = @FileGuid

SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Doctor : ' ELSE 'ÇáØÈíÈ ÇáãÓÊÔÇÑ : ' END   
insert into #Result
	(ParentType, Guid , [Description], [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	5,
	c.Guid,
	@Str +	doc.[Name],
	doc.[Name],
	'',	
	[Date],'',
	Cost,
	0,
	Notes
	from hoscons000 as c 
	inner join vwHosDoctor as doc on doc.guid = c.doctorguid
	where fileGuid = @FileGuid

-- DoctorFollowing 6 doctor
insert into #Result
	(ParentType,subtype, qty)
	select 
	6,
	-1,
	count(*)
	From 	hosFDailyFollowing000
	where fileGuid = @FileGuid
		AND TYPE = 0

SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Doctor Following: ' ELSE 'ãÊÇÈÚÉ ÇáØÈíÈ '  END   
insert into #Result
	(ParentType, Guid , [Description], [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	6,	
	c.Guid,
	@Str +	doc.[Name],
	doc.[Name],
	'',
	[Date],'',
	0,0,	
	therapy
	from hosFDailyFollowing000 as c 
	inner join vwHosDoctor as doc on doc.guid = c.WorkerGuid
	where fileGuid = @FileGuid
		AND c.TYPE = 0

-- NurceFollowing 7 doctor
insert into #Result
	(ParentType, subtype, qty)
	select 
	7,
	-1,
	count(*)
	From 	hosFDailyFollowing000
	where fileGuid = @FileGuid
		AND TYPE = 1

SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Nurce Following: ' ELSE 'ãÊÇÈÚÉ ÇáããÑÖÉ '  END   
insert into #Result
(ParentType, Guid , [Description], [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	7,
	c.Guid,
	@Str + e.[Name],
	e.[Name],
	'',
	[Date],'',
	0,0,therapy
	from hosFDailyFollowing000 as c 
	inner join vwHosEmployee as e on e.guid = c.WorkerGuid
	where fileGuid = @FileGuid
		AND c.TYPE = 1

-- consumes 8
SELECT @UserPerm = [dbo].[fnGetUserSec](@UserGUID, 2147549664, 0x0, 1, 1) -- @PermType
	INSERT INTO #Result(ParentType, Subtype, Cost, Qty)
	SELECT 
		8,
		-1,
		SUM(bi.Price * bi.Qty),
		COUNT(DISTINCT bu.GUID)
 	FROM 
		hosConsumedMaster000 as c 
		JOIN bu000 as bu on bu.guid = c.billguid 
		JOIN bi000 AS bi ON bu.GUID = bi.ParentGUID
	WHERE 
		c.fileGuid = @FileGuid and @UserPerm >= c.security  

INSERT INTO #Result(ParentType,Guid , [Description], [Name], [Extra_Desc], [Date], [Cost], [DisCount], unit, Qty, price, [Notes] )
	SELECT 
	8,
	Guid,
	Notes,
	matName,
	'', --extra_desc
	[Date],
	total,
	0, -- discount
	unit,
	qty,
	price,
	NOTES -- notes
	From FnVwHosConsumedDetaild(@FileGuid)

-- radio 9
SELECT @UserPerm = [dbo].[fnGetUserSec](@UserGUID, 2147549776, 0x0, 1, 1 ) -- @PermType
insert into #Result
	(ParentType, subtype,cost, qty)
	select 
		9,
		-1,
		SUM(det.price),-- - ISNULL(det.discount,0)),
		count(*)
	from HosRadioGraphyOrderDetail000 as det
	inner join HosRadioGraphyOrder000 as ord on ord.guid = det.parentguid 
	WHERE ord.fileGuid = @FileGuid and @UserPerm >= ord.security  

insert into #Result
(ParentType, Guid, [Description], [Name], [Extra_Desc], [Date], [Cost], [DisCount], [Notes])
	select 
	9,
	ord.Guid,
	r.[name],						
	r.[name],
	det.result, --extra_desc
	ord.[Date],
	det.price,
	det.discount,
	det.NOTES -- notes
	from HosRadioGraphyOrderDetail000 as det
	inner join HosRadioGraphyOrder000 as ord on ord.guid = det.parentguid 
	inner join HosRadioGraphy000 as r on r.guid = det. RadioGraphyGuid 
	WHERE ord.fileGuid = @FileGuid	
	order by ord.[date], det.number
	

select * from #Result
	order by parentType , [Date]
############################################################
#END