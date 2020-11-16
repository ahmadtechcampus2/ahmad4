#############################################
CREATE proc  RepHosDevicePatientFile
	@FileCode	NVARCHAR(100),
	@UserName	NVARCHAR(100)
AS
	SET NOCOUNT ON 
exec prcconnections_add2 @UserNAme

declare @FileGuid uniqueidentifier
select @FileGuid = guid from hospfile000 where code = @FileCode

create table #Result 
	(
		ParentType int DEFAULT (0), 
		subtype int DEFAULT  0, 
		[NAME] NVARCHAR(250) DEFAULT '',
		[Extra_Desc] NVARCHAR(250)DEFAULT '',
		[Date] DateTime,
		[DateOut] DateTime,
		[Cost] Float DEFAULT 0,
		[Discount] float DEFAULT '',
		unit NVARCHAR (200) DEFAULT '', -- ÊÕœ… «·„«œ…
		Qty float DEFAULT 0,  -- «·ﬂ„Ì… 
		price float DEFAULT 0, -- «·”⁄—  
		[Notes]	NVARCHAR(250) DEFAULT ''
	)

-------- General Data   0
insert into #Result
	(ParentType,  [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select
	0, 
	[Name],
	[Code],
	[DateIn],
	[DateOut],
	0, -- cost 
	0, -- discount	
	''	
	from 	vwhosfile
	where Guid = @FileGuid

-------- Clinical Test  1
	
	insert into #Result
	(ParentType, [Name], [Extra_Desc], [Notes] )
		select
		1,
		fn.[Name],
		doc.[Name], --extra
		ct.Result
		FROM fnHosMiniCard(2) as fn
		inner join HosClinicalTests000 as CT ON	CT.TestGuid  = fn.Guid	
		inner join vwHosDoctor as doc on doc.guid = ct.doctorguid
		where ct.fileguid = @FileGuid


DECLARE @DefCurGuid	UNIQUEIDENTIFIER   
DECLARE @DefCurVal	FLOAT   
SELECT @DefCurGuid =  Value from op000 where name = 'AmnCfg_DefaultCurrency'    
SELECT @DefCurVal = CurrencyVal from my000 where Guid = @DefCurGuid   

-- add Stay 2				

insert into #Result
	(ParentType, [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	2,
	CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  [SiteLatinName] ELSE [SiteName]  END ,
	SiteTypeName,
	StayStartDate,
	StayEndDate,
	StayCost * StayCurrencyVal/@DefCurVal,
	StayDiscount * StayCurrencyVal/@DefCurVal,
	StayNotes
	from VwHosStay
	where 
	StayfileGuid = @FileGuid 

-- General Test 3

insert into #Result
	( [ParentType], [Name], [Date], [Cost], [DisCount], [Notes] )
	select 
	3,
	CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  [OpLatinName] ELSE [OpName]  END ,
	[Date],
	cost * CurrencyVal/@DefCurVal,
	discount * CurrencyVal/@DefCurVal,
	Notes
	from vwHosGeneralTest
	where fileGuid = @FileGuid 
-- surgery 4 
--SELECT @UserPerm = [dbo].[fnGetUserSec](@UserGUID, 2147549280, 0x0, 1, 1 ) -- @PermType

	insert into #Result	
	(ParentType,subtype, [Name],Extra_Desc,[Date],[DateOut],Cost,DisCount, unit, Qty, price,[Notes] )
	select 
		4,
		type,
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
	(ParentType, [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	5,
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
	(ParentType, [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	6,	
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
(ParentType, [Name], [Extra_Desc], [Date], [DateOut], [Cost], [DisCount], [Notes] )
	select 
	7,
	e.[Name],
	'',
	[Date],'',
	0,0,therapy
	from hosFDailyFollowing000 as c 
	inner join vwHosEmployee as e on e.guid = c.WorkerGuid
	where fileGuid = @FileGuid
		AND c.TYPE = 1

-- consumes 8

insert into #Result
(ParentType, [Name], [Extra_Desc], [Date], [Cost], [DisCount], unit, Qty, price, [Notes] )
	select 
	8,
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

insert into #Result
(ParentType, [Name], [Extra_Desc], [Date], [Cost], [DisCount], [Notes])
	select 
	9,
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
	

	select * from #Result	order by parentType , [Date]
/*
	exec RepHosDevicePatientFile '1', '„œÌ—'
	exec RepHosDevicePatientFile '1069', '„œÌ—'
*/
#######################################
#END