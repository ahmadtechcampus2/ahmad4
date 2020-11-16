CREATE FUNCTION FindDrug
( 
	@SearchStrParam [NVARCHAR](1000) 
	,@CriteriaParam  INT  -- 1: exactly contain, 2: includes one of  4: contains at least all the string 
	,@DetailTypeParam  INT --0 // used when search in composition and 1 // used when search in indication 
	,@OrderBy [NVARCHAR](100)
	)  
RETURNS @RESULT TABLE  
( 
DrugGuid UNIQUEIDENTIFIER, 
Code [NVARCHAR](100),--ÑãÒ ÇáÏæÇÁ 
Name [NVARCHAR](250),--	ÇÓã ÇáÏæÇÁ 
Latinname [NVARCHAR](250)	,--ÇáÇÓã ÇááÇÊíäí 
Barcode [NVARCHAR](100),--ÑãÒ ÇáÈÇÑßæÏ 
Kind int,--äæÚ ÇáÏæÇÁ 
Composition [NVARCHAR](1000) ,--ÇáÊÑßíÈ ÇáßíãíÇÆí 
Classification [NVARCHAR](100),--	ÇáÊÕäíÝ  
Gauge [NVARCHAR](100),--ÇáÚíÇÑ 
Shape [NVARCHAR](100),--ÇáÔßá 
Company [NVARCHAR](100),--	ÇáÔÑßÉ ÇáãÕäÚÉ	 
[Group] [NVARCHAR](100),--	ÇáãÌãæÚÉ 
Color [NVARCHAR](100),--Çááæä  
Origin [NVARCHAR](100),--	ÈáÏ ÇáãäÔÃ 
Quality [NVARCHAR](100),--ÇáäæÚíÉ  
Model [NVARCHAR](100)--ÇáØÑÇÒ 
)  
BEGIN  
-- check the DetailTypeParam to determine the search fields  0 // used when search in composition and 1 // used when search in indication 
-- if search in composition use SQL string functions to find the searchstr in Composition field in talble DurgComposition join mt000 
-- be sure to use the suitable SQL function corresponding to CriteriaParam 
-- store the result in result table 
-- return 
-- if  DetailTypeParam is Indication  use SQL string functions to find the Indication in Indication field in talble DurgIndication join mt000 
--store the result in result table 
-- return 
-- befor return order the table according to the order fileds which are : 
-- NONE	= 0 MATCODE	 = 1,MATNAME = 2,LATINNAMEFLD = 3, MATTYPEFLD	= 4 ,SPECFLD = 5 ,COLORFLD = 6 ,ORIGINFLD =7,SIZEFLD = 8,COMPANYFLD	= 9,BARCODEFLD	= 10	 
DECLARE @searchTable TABLE (MatGuid UNIQUEIDENTIFIER ,string NVARCHAR(max)) 
DECLARE @SingleDrugTable TABLE(string NVARCHAR(max)) 
DECLARE @verifiedGuidsTable TABLE(MatGuid UNIQUEIDENTIFIER) 
DECLARE @tempCompositionTable  TABLE ([MatGuid] [uniqueidentifier] ,[Composition] [NVARCHAR](1000)) 
DECLARE @IntersectResult  TABLE(string NVARCHAR(max)) 
DECLARE @c cursor 
DECLARE	@intersectCount INT, 
		@splitCount INT, 
		@tableCount INT, 
		@cursorGuid UNIQUEIDENTIFIER 
DECLARE @CompositionsStr NVARCHAR(max) 
 IF @DetailTypeParam = 1 
	 BEGIN 
	 SET @c = CURSOR FAST_FORWARD FOR  SELECT DISTINCT MatGuid FROM drugCompositions000 
	  insert into @searchTable select MatGuid, composition FROM  drugCompositions000  
	  END 
 ELSE  
	 BEGIN 
	 SET @c =  CURSOR FAST_FORWARD FOR  SELECT DISTINCT MatGuid FROM drugIndications000 
	 INSERT INTO @searchTable SELECT MatGuid, indication FROM  drugIndications000  
	 END 
OPEN @c  
FETCH FROM @c INTO @cursorGuid 
	WHILE @@fetch_status = 0 
	BEGIN 
			INSERT INTO @SingleDrugTable 
			SELECT string FROM @searchTable WHERE matguid = @cursorGuid 
			 
			INSERT INTO @IntersectResult  
			SELECT RTRIM(LTRIM(substr)) STRING FROM dbo.fnString_Split(@SearchStrParam,',') 
			INTERSECT 
			SELECT RTRIM(LTRIM(STRING)) FROM @SingleDrugTable 
				SELECT @intersectCount = COUNT(*) FROM @IntersectResult  
				SELECT @splitCount = COUNT(*)   FROM dbo.fnString_Split(@SearchStrParam,',') 
				SELECT @tableCount = COUNT(*)  FROM @SingleDrugTable 
			IF  (@intersectCount= @tableCount) AND (@intersectCount = @splitCount) AND (@CriteriaParam = 1) 
					INSERT INTO @verifiedGuidsTable SELECT @cursorGuid 
			IF (@intersectCount > 0) AND (@CriteriaParam = 2) 
					INSERT INTO @verifiedGuidsTable SELECT @cursorGuid 
			IF (@splitCount <= @intersectCount)  AND (@CriteriaParam = 4) 
					INSERT INTO @verifiedGuidsTable SELECT @cursorGuid 
					 
		DELETE  FROM @IntersectResult 
		DELETE  FROM @SingleDrugTable 
		 
		INSERT INTO @tempCompositionTable select @cursorGuid,dbo.drugDetailsAsString(@cursorGuid,@DetailTypeParam) 
		FETCH NEXT FROM @c  INTO @cursorGuid   
		END -- cursor 
		CLOSE @c
		DEALLOCATE @c
		INSERT INTO @RESULT 
		SELECT  
			ver.matguid , 
			mt000.Code ,--ÑãÒ ÇáÏæÇÁ 
			mt000.Name ,--	ÇÓã ÇáÏæÇÁ 
			mt000.Latinname 	,--ÇáÇÓã ÇááÇÊíäí 
			Barcode ,--ÑãÒ ÇáÈÇÑßæÏ 
			mt000.type ,--äæÚ ÇáÏæÇÁ 
			Composition ,--ÇáÊÑßíÈ ÇáßíãíÇÆí 
			dim ,--	ÇáÊÕäíÝ   = ÇáÞíÇÓ
			origin,--ÇáÚíÇÑ  = ÇáãÕÏÑ
			pos ,--ÇáÔßá  = ãßÇä ÇáÊæÇÌÏ 
			Company ,--	ÇáÔÑßÉ ÇáãÕäÚÉ	 
			gr000.name ,--	ÇáãÌãæÚÉ 
			Color ,--Çááæä  
			provenance ,--	ÈáÏ ÇáãäÔÃ 
			Quality ,--ÇáäæÚíÉ  
			Model --ÇáØÑÇÒ 
		FROM 
			mt000 JOIN @verifiedGuidsTable ver ON ver.matguid = mt000.guid 
			JOIN @tempCompositionTable comp ON comp.matguid = ver.matguid 
			JOIN gr000 ON mt000.groupguid  = gr000.guid 
RETURN 
END -- end0 
#########################################################
CREATE FUNCTION DrugEquivalentsFunction
(@drugGuid as UNIQUEIDENTIFIER) 
RETURNS  @result TABLE(
			number int,
			Name nvarchar(250) ,
			Code nvarchar(100),	
			LatinName nvarchar(250),
		    barcode nvarchar(250),
		    codedcode nvarchar(250),
		    unity nvarchar(100),
		    spec nvarchar(1000),
		    qty float,
		    high float,
		    low float,
		    whole float,
		    half float,
		    retail float,
		    enduser float,
		    export float,
		    vendor float,
		    maxprice float,
		    avgprice float,
		    lastprice float,
		    pricetype int,
		    selltype int,
		    bonusone float,
		    currencyval float,
		    useflag float,
		    origin nvarchar(250),
		    company nvarchar(250),
		    type int,
		    security int,
		    lastpricedate datetime,
		    bonus float,
		    unit2 nvarchar(100),
		    unit2fact float,
		    unit3 nvarchar(100),
		    unit3fact float,
		    flag float,
		    pos nvarchar(250),
		    dim nvarchar(250),
		    expireFlag bit,
		    productionflag bit,
		    unit2factflag bit,
		    unit3factflag bit,
		    barcode2 nvarchar(250),
		    barcode3 nvarchar(250),
		    snflag bit,
		    forceinsn bit,
		    forceoutsn bit,
		    vat float,
		    color nvarchar(250),
		    provenance nvarchar(250),
		    quality nvarchar(250),
		    model nvarchar(250),
		    whole2 float,
		    half2 float,
		    retail2 float,
		    enduser2 float,
		    export2 float,
		    vendor2 float,
		    maxprice2 float,
		    lastprice2 float,
		    whole3 float,
		    half3 float,
		    retail3 float,
		    enduser3 float,
		    export3 float,
		    vendor3 float,
		    maxprice3 float,
		    lastprice3 float,
		    guid uniqueidentifier,
		    groupguid uniqueidentifier,
		    pictureguid uniqueidentifier,
		    currencyguid uniqueidentifier,
		    defunit int,
		    bhide bit,
		    branchmask bigint,
		    oldguid uniqueidentifier,
		    newguid uniqueidentifier,
		    assemble bit,
		    orderlimit float,
		    calpricefromdetail bit,
		    forceinexpire bit,
		    forceoutexpire bit,
		    createdate datetime,
		    isintegerquantity bit,
		    grcode nvarchar(100),
		    grname nvarchar(250),
		    grlatinname nvarchar(250),
		    qty0 float
			) 
BEGIN
	INSERT INTO @result 
	SELECT DISTINCT 
	        number int,
			vdmt2.Name ,
			vdmt2.Code ,
			vdmt2.LatinName ,
		    barcode ,
		    codedcode ,
		    unity ,
		    spec ,
		    vdmt2.qty ,
		    high ,
		    low ,
		    whole ,
		    half ,
		    retail ,
		    enduser ,
		    export ,
		    vendor ,
		    maxprice ,
		    avgprice ,
		    lastprice ,
		    pricetype ,
		    selltype ,
		    bonusone ,
		    currencyval ,
		    useflag ,
		    origin ,
		    company ,
		    type ,
		    security ,
		    lastpricedate ,
		    bonus ,
		    unit2 ,
		    unit2fact ,
		    unit3 ,
		    unit3fact ,
		    flag ,
		    pos ,
		    dim ,
		    expireFlag ,
		    productionflag ,
		    unit2factflag ,
		    unit3factflag ,
		    barcode2 ,
		    barcode3 ,
		    snflag ,
		    forceinsn ,
		    forceoutsn ,
		    vat ,
		    color ,
		    provenance ,
		    quality ,
		    model ,
		    whole2 ,
		    half2 ,
		    retail2 ,
		    enduser2 ,
		    export2 ,
		    vendor2 ,
		    maxprice2 ,
		    lastprice2 ,
		    whole3 ,
		    half3 ,
		    retail3 ,
		    enduser3 ,
		    export3 ,
		    vendor3 ,
		    maxprice3 ,
		    lastprice3 ,
		    guid ,
		    groupguid ,
		    pictureguid ,
		    currencyguid ,
		    defunit ,
		    bhide ,
		    branchmask ,
		    oldguid ,
		    newguid ,
		    assemble ,
		    orderlimit ,
		    calpricefromdetail ,
		    forceinexpire ,
		    forceoutexpire ,
		    createdate ,
		    isintegerquantity ,
		    grcode ,
		    grname ,
		    grlatinname,
		    qty0 

	FROM DrugEquivalentsView
	INNER JOIN vdmt2 ON vdmt2.guid = DrugEquivalentsView.equivalentguid
	WHERE Matguid = @drugGuid AND vdmt2.qty > 0
	
RETURN
END
#########################################################
#END