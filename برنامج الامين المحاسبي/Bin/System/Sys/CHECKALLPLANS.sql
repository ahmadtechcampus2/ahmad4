#########################################################
CREATE PROC CHECKALLPLANS 
	@PS_GUID UNIQUEIDENTIFIER = 0x00,
	@PSI_GUID UNIQUEIDENTIFIER = 0x00,
	@IsMultiPlanView		BIT = 0
AS 
SET NOCOUNT ON 
--steps 
	--1 get all plans and store them in #ps(Guid,code,state,security, branchGuid)
	CREATE TABLE #Ps (
			 [GUID] UNIQUEIDENTIFIER ,
             		 [Code] NVARCHAR(100) ,
			 [StartDate] DATETIME ,
			 [EndDate] DATETIME ,
			 [State] INT ,
			 [Security] INT ,
			 [BranchGuid] UNIQUEIDENTIFIER 
			)
	--Check wether a client pass a ps guid to procedure and fill temp table depending on this
	-- value 
	SET @PS_GUID = IsNull(@PS_GUID,0x00)		
	IF @PS_GUID 	<> 0x00
		INSERT INTO #Ps
		SELECT guid , Code , startDate , endDate , state , security , branchguid 
		FROM mnps000
		WHERE guid = @PS_GUID
		
	ELSE
		INSERT INTO #Ps
		SELECT guid , code , startDate , endDate , state , security , branchguid 
		FROM mnps000

	---2 define a hash table #psi that will hold all children of each #ps record 
		CREATE TABLE #PSI ( 
		[Guid] UNIQUEIDENTIFIER ,
		[Code] NVARCHAR(100) ,
		[StartDate]  DATETIME ,
		[EndDate] DATETIME ,
		[Qty] FLOAT(53)	,
		[FormGuid] UNIQUEIDENTIFIER ,
		[priority] INT ,
		[StoreGuid] UNIQUEIDENTIFIER ,
		--0 fixed , 1 completed , 2  delayed 
		[State] SMALLINT ,
		[ParentGuid] UNIQUEIDENTIFIER 				
		)
		--Check wether a client pass a psi guid to procedure and fill temp table depending on this
		-- value 
		SET @PSI_GUID = ISNULL(@PSI_GUID,0x00)
		IF 	@PSI_GUID <> 0x00
			INSERT INTO #PSI
			SELECT guid , code , startdate , enddate , qty , formguid , priority , storeguid , state , parentguid
			FROM psi000
			WHERE GUID = @PSI_GUID AND [State] = 0 AND parentguid in (SELECT GUID FROM #ps )
		ELSE
			INSERT INTO #PSI
			SELECT guid , code , startdate , enddate , qty , formguid , priority , storeguid , state , parentguid
			FROM psi000
			WHERE [State] = 0 AND parentguid in ( SELECT GUID FROM #ps ) 
		
		

	---3 #psiMatRawList(MatGUID ,MatName ,MatCode,FormGUID,miQty ,MatDefUnit ,MatDefUnitFact ,MsMatQty)
	-- a table that will hold mat lack list for specified formGuid
	-- this table is filled as result of call to function :
	--	repGetLakeRawMatList @vFormGuid , @vStoreGuid
	CREATE TABLE #psiMatRawList
	(
		MatGUID UNIQUEIDENTIFIER,
		MatName NVARCHAR(250) COLLATE ARABIC_CI_AI ,
		MatCode NVARCHAR(250) ,
		FormGUID UNIQUEIDENTIFIER,
		miQty FLOAT,
		MatDefUnit NVARCHAR(150),
		MatDefUnitFact FLOAT,
		MsMatQty FLOAT
	)
	

--a temp table that join psi000 with it's mat lack list with it's parent
-- ps000
CREATE TABLE #PS_PSI_MatRawList(
	--ps000 fields 
	[psGuid] UNIQUEIDENTIFIER ,
    [psCode] NVARCHAR(100) ,
	[psStartDate] DATETIME ,
	[psEndDate] DATETIME ,
	[psState] INT , 
	[psSecurity] INT ,
	[psBranchGuid] UNIQUEIDENTIFIER ,
	
	--psi000 fields 
	[psiGuid] UNIQUEIDENTIFIER ,
	[psiCode] NVARCHAR(100) ,
	[psiStartDate]  DATETIME ,
	[psiEndDate] DATETIME ,
	[psiQty] FLOAT(53)	,
	[psiFormGuid] UNIQUEIDENTIFIER ,
	[psipriority] INT ,
	[psiStoreGuid] UNIQUEIDENTIFIER ,
	[psiState] SMALLINT ,
	[psiParentGuid] UNIQUEIDENTIFIER,		
	
-- mat lack list for forms in psi's
	[MatGUID] UNIQUEIDENTIFIER,
	[MatName] NVARCHAR(250) COLLATE ARABIC_CI_AI,
	[MatCode] NVARCHAR(250) COLLATE ARABIC_CI_AI,
	[miQty] FLOAT,
	[MatDefUnit] NVARCHAR(150) COLLATE ARABIC_CI_AI,
	[MatDefUnitFact] FLOAT,
	[MsMatQty] FLOAT,
	[Lack ] FLOAT 
)

-- #ps record variables 
DECLARE	 @psGUID UNIQUEIDENTIFIER ,
         @psCode NVARCHAR(100) ,
		 @psStartDate DATETIME ,
		 @psEndDate DATETIME ,
		 @psState INT ,
		 @psSecurity INT ,
		 @psBranchGuid UNIQUEIDENTIFIER

-- #psi table variables 		
DECLARE		@vGuid    UNIQUEIDENTIFIER ,
			@vCode   NVARCHAR(100),
			@vStartDate  DATETIME ,
			@vEndDate DATETIME  ,
			@vQty  FLOAT(53) ,
			@vFormGuid UNIQUEIDENTIFIER ,
			@vpriority  INT ,
			@vStoreGuid UNIQUEIDENTIFIER,
			@vState INT ,
			@vparentguid UNIQUEIDENTIFIER 
		
--Debug section-------------------------------------------------------

----------------------------------------------------------------------

--Define a cursor for ps000 table , act as parent for PSICORSOR
DECLARE PSCURSOR CURSOR FORWARD_ONLY FOR 
SELECT * FROM #PS
OPEN PSCURSOR


FETCH NEXT FROM PSCURSOR INTO 
@psGuid , @psCode , @psStartDate , @psEndDate , @psState , @psSecurity ,@psBranchGuid

--loop throght ps(PSCURSOR) cursor
WHILE @@FETCH_STATUS = 0 
BEGIN 
	
	--psi cursor for current PSCURSOR record 
	DECLARE PSICURSOR CURSOR FORWARD_ONLY FOR 
	SELECT * 
	FROM #PSI
	WHERE ParentGuid = @psGuid
	
	OPEN PSICURSOR
	
	-- fetch current ps children(psi) and store result in psi variables 
	FETCH NEXT FROM PSICURSOR
	INTO @vGuid ,@vCode,@vStartDate,@vEndDate,@vQty,@vFormGuid,
		 @vpriority,@vStoreGuid,@vState,@vParentGuid
		--psi cursor
		-- for each psi record call repGetLakeRawMatList @vFormGuid , @vStoreGuid
		-- and store result in #GetPSIRawMatListResult
		--#GetPSIRawMatListResult will hold 
		--  psi000 fields + (matGuid , avaliable , required , Lake)
		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			INSERT INTO #psiMatRawList 
			EXEC repGetLakeRawMatList @vFormGuid , @vStoreGuid
		
			INSERT INTO  #PS_PSI_MatRawList
			SELECT  @psGUID , @psCode , @psStartDate , @psEndDate , @psState , @psSecurity 
					, @psBranchGuid,@vGuid ,@vCode,@vStartDate,@vEndDate,@vQty,@vFormGuid,
					@vpriority,@vStoreGuid,@vState,@vParentGuid,RawMat.MatGUID ,RawMat.MatName ,
					RawMat.MatCode ,RawMat.miQty * @vQty/*form count*/ AS miQty --required
				       ,RawMat.MatDefUnit ,RawMat.MatDefUnitFact ,RawMat.MsMatQty, -- store Qty
					--lack = store Qty - required
					CASE  WHEN MsMatQty-miQty< 0  THEN 
						 ABS(RawMat.MsMatQty-miQty) ELSE 0 END	AS  Lack  
			FROM #psiMatRawList AS RawMat
--Debug section-------------------------------------------------------	
					
--Debug section-------------------------------------------------------	
					
			-- empty the matarial Lake table(#psiMatRawList) to be used for
			-- another psi00 item 
			DELETE FROM #psiMatRawList 

			--get the next psi000 item  of current ps 
			--and get it's matarial lake list and so on...
			FETCH NEXT FROM PSICURSOR
			INTO @vGuid ,@vCode,@vStartDate,@vEndDate,@vQty,@vFormGuid,
			@vpriority,@vStoreGuid,@vState,@vParentGuid
			
		END
		

	--empty the #PSI table of current #PS to allow it to be refilled 
	--by another #PS children 
	--DELETE FROM #PSI
	
	--delete the psi cursor , will be reallocated with another  restlt set 
	--on next iteration
	CLOSE PSICURSOR
	DEALLOCATE PSICURSOR
	


--get next plan(ps000) from cursor to begin next iteration
FETCH NEXT FROM PSCURSOR INTO 
@psGUID , @psCode , @psStartDate , @psEndDate , @psState , @psSecurity , @psBranchGuid



END

--deallocate ps000 cursor 
CLOSE PSCURSOR 
DEALLOCATE PSCURSOR
 
	
	--4 define a new temp table #ResultSet
	-- same as #PS_PSI_MatRawListbu just with added sort(identitiy) field to sort ps 
	--	depending on reservation priority 
	-- reservation priority first to psStartDate , psState , psiStartDate
	-- then psiState
CREATE TABLE #ResultSet(
	--sort is identity column allowes inserting in sequence 1,2,3..
	--depending on reservation priority stated perviously.
	[Sort] INT IDENTITY(1,1) ,
	
	--ps000 fields 
	[psGuid] UNIQUEIDENTIFIER ,
    [psCode] NVARCHAR(100) ,
	[psStartDate] DATETIME ,
	[psEndDate] DATETIME ,
	[psState] INT ,
	[psSecurity] INT ,
	[psBranchGuid] UNIQUEIDENTIFIER ,
	
	--psi000 fields 
	[psiGuid] UNIQUEIDENTIFIER ,
	[psiCode]	NVARCHAR(100),
	[psiStartDate]	DATETIME ,
	[psiEndDate]	DATETIME ,
	[psiQty]	Float(53),
	[FormGuid] UNIQUEIDENTIFIER ,
	[priority] INT ,	
	[StoreGuid] UNIQUEIDENTIFIER,
	[psiState] SMALLINT ,
	[ParentGuid] UNIQUEIDENTIFIER ,
	
	--mat lack table from forms in psi 
	[MatGUID] UNIQUEIDENTIFIER,
	[MatName] NVARCHAR(250) COLLATE ARABIC_CI_AI,
	[MatCode] NVARCHAR(250) COLLATE ARABIC_CI_AI,
	--Qty required for 1 form * form count
	[miQty] FLOAT,
	[MatDefUnit] NVARCHAR(150) COLLATE ARABIC_CI_AI,
	[MatDefUnitFact] FLOAT,
	--store Qty of specified Mat 
	[MsMatQty] FLOAT,
	--Mat Lack = MsMatQty - miQty 
	[Lack] FLOAT 
	)

-- sort column take it's value automatically in squence 
INSERT INTO #ResultSet([psGuid] ,[psCode] ,	[psStartDate],	[psEndDate] ,
	[psState] ,	[psSecurity] ,	[psBranchGuid] ,
	[psiGuid] ,	[psiCode],[psiStartDate],[psiEndDate],[psiQty],[FormGuid] ,
	[priority] ,[StoreGuid] ,	[psiState] ,[ParentGuid],
	[MatGUID] ,	[MatName] ,	[MatCode] ,[miQty] ,[MatDefUnit] ,
	[MatDefUnitFact] ,	[MsMatQty] ,[Lack] )
SELECT *
FROM  #PS_PSI_MatRawList
ORDER BY psState , psStartDate , psiState , psiStartDate, psipriority, psiCode


--a curosr for storing preserved Qty in #ResultSet table 
DECLARE  ResultSet_CURSOR CURSOR  SCROLL_LOCKS FOR  
SELECT * 
FROM #ResultSet
Order by psState , psStartDate , psiState , psiStartDate, [priority]
OPEN ResultSet_CURSOR 
			

			
-- variable for ResultSet_CURSOR
DECLARE 					
	@r_sort INT,
	@r_psGuid UNIQUEIDENTIFIER,
	@r_psCode NVARCHAR(100),
	@r_psStartDate DATETIME,
	@r_psEndDate DATETIME,
	@r_psState SMALLINT,
	@r_psSecurity INT,
	@r_psBranchGuid UNIQUEIDENTIFIER,
	
	@r_psiGuid UNIQUEIDENTIFIER,
	@r_psiCode	NVARCHAR(100),
	@r_psiStartDate	DATETIME ,
	@r_psiEndDate	DATETIME ,
	@r_psiQty	Float(53),
	@r_FormGuid UNIQUEIDENTIFIER,
	@r_StoreGuid UNIQUEIDENTIFIER,
	@r_priority INT,
	@r_State SMALLINT,
	@r_ParentGuid UNIQUEIDENTIFIER,
	
	@r_MatGUID UNIQUEIDENTIFIER,
	@r_MatName NVARCHAR(250),
	@r_MatCode NVARCHAR(250),
	@r_miQty FLOAT(53),
	@r_MatDefUnit NVARCHAR(150),
	@r_MatDefUnitFact FLOAT(53),
	@r_MsMatQty FLOAT(53),
	@r_Lack  FLOAT(53)
		 
	
FETCH NEXT FROM ResultSet_CURSOR 
INTO
	@r_sort ,
	@r_psGuid ,
	@r_psCode ,
	@r_psStartDate ,
	@r_psEndDate ,
	@r_psState ,
	@r_psSecurity ,
	@r_psBranchGuid ,
	@r_psiGuid ,
	@r_psiCode	,
	@r_psiStartDate	,
	@r_psiEndDate,
	@r_psiQty,
	@r_FormGuid ,
	@r_priority ,
	@r_StoreGuid ,	
	@r_State ,
	@r_ParentGuid ,
	@r_MatGUID ,
	@r_MatName ,
	@r_MatCode ,
	@r_miQty ,
	@r_MatDefUnit ,
	@r_MatDefUnitFact,
	@r_MsMatQty ,
	@r_Lack  
	
---5 for each plan(ps) in the ResultSet_CURSOR
Declare @x float 
WHILE @@FETCH_STATUS = 0 
BEGIN 
-- test ps.state == 0 //fixed 
					-- test psi.state == 0 //fixed 
					-- Available(MsMatQty) = Available(MsMatQty)- required(miQty)
					-- if(Available<0)  Lake = abs(Available) otherwise 0 
					-- update all later record(that it's state is fixed) of same (matGuid,storeGuid)
					-- and set MsMatQty = Available(MsMatQty)//calculated above
					-- taking in mind that update  record will consider the state of ps and psi 
					-- otherwise leave the Qty as it's
			
	IF 	@r_psState = 0 
	BEGIN 		
		IF	@r_State = 0 
		BEGIN 
					
			declare @prev float(53) 
			declare @currentMsQty float(53) 
			-- @prev variable store preivous Qty of same mat in same store
			--that is just preivous current record or get ms Qty from bi table in case of 
			-- currrent record is the first record in table 
			SELECT @prev = MsMatQty 
			FROM #ResultSet
			WHERE @r_sort > sort and 
			      MatGUID = @r_MatGUID and 
		 	      StoreGuid = @r_StoreGuid and 
			      psstate = 0 and 
			      psistate = 0
			order by sort ASC
			
			
			--bring a store Qty from bi and take in account the bounsQty and direction 
			-- in or out bill 
			IF @@rowcount = 0 
			BEGIN 
				SELECT @currentMsQty = SUM(([biQty]+[biBonusQnt]) * buDirection)
				FROM vwbubi
				WHERE [biStorePtr] = @r_StoreGuid and [biMatPtr] = @r_MatGUID and buisposted = 1 
				--if prev value not avaliable table the value from bi store 
				SET @prev =  ISNULL(@currentMsQty,0)
			END 
				
			
			 SET @r_MsMatQty = @prev
			 -- avaliable =  avaliable - required 
			  SET @x=ISNULL((SELECT Top 1 miQty From #ResultSet  WHERE  sort < @r_sort and MatGUID = @r_MatGUID order by sort DESC ),0)
			 SET @r_MsMatQty -=  @x
			
			 
             IF(@r_MsMatQty < 0)
					SET @r_Lack  = ABS(@r_MsMatQty) 
			 ELSE
					SET @r_Lack  = 0
			
			--update current record 
			UPDATE #ResultSet 
			SET    MsMatQty = @r_MsMatQty , Lack  = @r_Lack  
			WHERE  sort = @r_sort 
						
			--update all later record for same matarial in same store 
			UPDATE #ResultSet 
			SET   MsMatQty =  @r_MsMatQty  
			WHERE MatGUID = @r_MatGUID 	  and StoreGuid = @r_StoreGuid 
				  and sort > @r_sort
		
		END
	
	ELSE
		--state of psi is delayed or completed 
			
			--define a  @previousMsMatQty  variable that will hold previous Qty 
			-- for same mat in same store that preserve Qty (state=fixed)	
		BEGIN
				--get the previous MsMatQty for same matarial in same store 
				--that just previous current record and preserve Quantities
				DECLARE @previousMsMatQty FLOAT(53)
	
				SELECT @previousMsMatQty = MsMatQty 
				FROM #ResultSet 
				WHERE    psstate = 0 and
					 psistate=0 and 
					 MatGUID = @r_MatGUID and 
					 StoreGuid = @r_StoreGuid and 
					 sort < @r_sort 
				order by sort asc
									
				
				if @@rowcount = 0 
				begin 
				SELECT @currentMsQty = SUM(([biQty]+[biBonusQnt]) * buDirection)
				FROM vwbubi
				WHERE [biStorePtr] = @r_StoreGuid and [biMatPtr] = @r_MatGUID and buisposted = 1 
				SET @previousMsMatQty = ISNULL(@currentMsQty,0)
				end 
				SET @r_MsMatQty = @previousMsMatQty
				SET @r_MsMatQty = @r_MsMatQty - @r_miQty
								
				-- previously calculated MsMatQty become a base for 
				-- all later store Qty for same matarial .
				
				--Qty not enough to complete current psi get the absolute value of msQty
				IF @r_MsMatQty < 0
						SET @r_Lack  =  ABS(@r_MsMatQty)
				ELSE
						SET @r_Lack  = 0
				-- update just current record because state not fixed and
				-- plan dosn't preserve Qty 
				UPDATE #ResultSet 
				SET    MsMatQty = @r_MsMatQty ,  Lack  = @r_Lack  
				WHERE  sort = @r_sort 
	
			END	
		END	
		ELSE --ps state is not fixed , just as state of psi if not fixed 
			BEGIN 
				
				SELECT @previousMsMatQty = MsMatQty
				FROM #ResultSet
				WHERE psstate=0 and
					  psistate=0
					  and sort < @r_sort 
					  and MatGUID = @r_MatGUID
			 	      and StoreGuid = @r_StoreGuid 
				order by sort asc
					
				
				if @@rowcount = 0 
				begin 
				SELECT @currentMsQty = sum(([biQty]+[biBonusQnt]) * buDirection)	
				FROM vwbubi
				WHERE [biStorePtr] = @r_StoreGuid and [biMatPtr] = @r_MatGUID and buisposted = 1 
				set @previousMsMatQty =  isNull(@currentMsQty,0)
				end 
				
				SET @r_MsMatQty = @previousMsMatQty
				SET @r_MsMatQty = @r_MsMatQty - @r_miQty
								
				-- previously calculated MsMatQty become a base for 
				-- all later store Qty for same matarial .
				IF @r_MsMatQty < 0
						SET @r_Lack  =  ABS(@r_MsMatQty)
				ELSE
						SET @r_Lack  = 0
				-- update just current record because state not fixed and
				-- plan dosn't preserve Qty 
				UPDATE #ResultSet 
				SET    MsMatQty = @r_MsMatQty ,  Lack  = @r_Lack  
				WHERE  sort = @r_sort 
			END 
	
	FETCH NEXT FROM ResultSet_CURSOR 
	INTO  @r_sort ,	@r_psGuid ,	@r_psCode ,	@r_psStartDate ,	@r_psEndDate ,	@r_psState ,	@r_psSecurity ,
	@r_psBranchGuid ,	@r_psiGuid  , @r_psiCode ,	@r_psiStartDate	,	@r_psiEndDate	,@r_psiQty,
	@r_FormGuid ,	@r_priority , @r_StoreGuid , @r_State ,	@r_ParentGuid ,
	@r_MatGUID ,	@r_MatName ,	@r_MatCode ,@r_miQty ,	@r_MatDefUnit ,	@r_MatDefUnitFact,	@r_MsMatQty ,
	@r_Lack  
END
CLOSE ResultSet_CURSOR 
DEALLOCATE ResultSet_CURSOR 
-- for performance resons we 
-- add FormCode ,FormName , StoreCode , StoreName to our result set
CREATE TABLE #AllResult(
	psGuid			UNIQUEIDENTIFIER ,
	psCode			NVARCHAR(100) ,
	psStartDate		DATETIME ,
	psEndDate		DATETIME ,
	psState			INT ,
	psSecurity		INT ,
	psBranchGuid	UNIQUEIDENTIFIER ,
	psiGuid			UNIQUEIDENTIFIER ,
	psiCode			NVARCHAR(100) ,
	psiStartDate	DATETIME ,
	psiEndDate		DATETIME ,
	psiQty			FLOAT,
	FormGuid		UNIQUEIDENTIFIER ,
	FormCode		NVARCHAR(100) ,
	FormName		NVARCHAR(100) ,
	FormLatinName		NVARCHAR(100) ,
	StoreGuid		UNIQUEIDENTIFIER ,
	StoreCode		NVARCHAR(100) ,
	StoreName		NVARCHAR(100) ,
	StoreLatinName		NVARCHAR(100) ,
	priority		INT ,
	psiState		INT ,
	ParentGuid		UNIQUEIDENTIFIER ,
	MatGUID			UNIQUEIDENTIFIER ,
	MatName			NVARCHAR(100) ,
	MatCode			NVARCHAR(100) ,
	miQty			FLOAT,
	MatDefUnit		NVARCHAR(100) ,
	MatDefUnitFact	INT ,
	MsMatQty		FLOAT,
	Lack			FLOAT,
	Date			DATETIME 
			)

INSERT INTO #AllResult
SELECT	DISTINCT R.[psGuid] ,R.[psCode] ,R.[psStartDate],R.[psEndDate] ,
	R.[psState] ,R.[psSecurity] ,R.[psBranchGuid] ,
	R.[psiGuid] ,R.[psiCode],R.[psiStartDate],R.[psiEndDate],R.[psiQty],
	R.[FormGuid] ,	fm.Code  FormCode , fm.Name  FormName,fm.LatinName  FormLatinName,
	R.[StoreGuid] ,	st.code StoreCode ,	st.Name StoreName ,st.LatinName StoreLatinName ,
	R.[priority] ,R.[psiState] ,R.[ParentGuid],
	R.[MatGUID] ,R.[MatName] ,	R.[MatCode] ,R.[miQty] ,R.[MatDefUnit] ,
	R.[MatDefUnitFact] ,R.[MsMatQty] ,R.[Lack] ,mn.Date
FROM	#ResultSet AS R inner join fm000  AS fm ON 
		R.FormGUID  = fm.GUID inner join st000 AS st 
		ON R.storeguid = st.GUID 
	    INNER JOIN MI000 mi ON R.MatGUID = mi.MatGUID
		INNER JOIN MN000 mn ON mn.FormGUID = fm.GUID
		WHERE	 mi.Type = 1 AND mn.Qty = 0 
		ORDER BY   psiStartDate, R.priority,psiCode 

IF @IsMultiPlanView = 1 
BEGIN
		SELECT  
		MIN(psiGuid) AS psiGuid, 
		MIN(psGuid) AS psGuid,
		MIN(psState) AS psState, 
		MIN(psCode) AS psCode,
		MIN(psStartDate) AS psStartDate,
		MIN(psEndDate) AS psEndDate
	FROM #AllResult 
	GROUP BY psGuid
	ORDER BY  MIN(psiStartDate) ,MIN(priority),MIN(psiCode)
END 
-- Master Result
SELECT DISTINCT 
	MIN(psiGuid) AS psiGuid, 
	MIN(psGuid) AS psGuid,
	MIN(priority) AS priority, 
	MIN(psiCode) AS psiCode,
	MIN(psCode) AS psCode,
	MIN(psStartDate) AS psStartDate,
	MIN(psEndDate) AS psEndDate,
	MIN(psiStartDate) AS psiStartDate,
	MIN(psiEndDate) AS psiEndDate,
	MIN(psiQty) AS psiQty,
	MIN(psiState) AS psiState,
	MIN(StoreGuid) AS StoreGuid,
	MIN(StoreName) AS StoreName,
	MIN(StoreLatinName) AS StoreLatinName,
	MIN(StoreCode) AS StoreCode,
	MIN(FormGuid) AS FormGuid,
	MIN(FormName) AS FormName,
	MIN(FormLatinName) AS FormLatinName,
	MIN(FormCode) AS FormCode 
FROM #AllResult 
GROUP BY psiGuid
ORDER BY  MIN(psiStartDate) ,MIN(priority),MIN(psiCode)
---- Details Result

SELECT * ,
	(CASE WHEN MsMatQty >= miQty THEN 0 ELSE miQty- MsMatQty END )AS TotalLack
FROM #AllResult
ORDER BY  psiStartDate ,priority,psiCode
#########################################################
CREATE PROCEDURE RepCheckTotalRawMatQty
      @StoreGuid		UNIQUEIDENTIFIER = 0x0, 
      @RawGroupGuid		UNIQUEIDENTIFIER= 0x0, 
	  @ReadyGroupGuid	UNIQUEIDENTIFIER= 0x0, 
      @MatGuid			UNIQUEIDENTIFIER = 0x0, 
	  @FromDate			DATETIME = '1-1-2008', 
      @ToDate			DATETIME = '12-1-2008', 
      @Unit				INT = 0, 
      @ShowStoreDetails INT = 1 ,
      @DismantlingOfSemiManufMat INT,
      @MatCondGuid UNIQUEIDENTIFIER =0x0 
	  
AS 
      SET NOCOUNT ON 
	   --///////////////////////////////////////////////////////////////////////////////
	  CREATE TABLE #Mat ( mtNumber UNIQUEIDENTIFIER, mtSecurity INT) 
	  CREATE TABLE #StoreTbl ( StoreGuid UNIQUEIDENTIFIER, m_Security INT )
	  CREATE Table #MatConditionTb ( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	  CREATE TABLE #RawMat ( MatGuid UNIQUEIDENTIFIER ,FormGuid UNIQUEIDENTIFIER , StoreGuid UNIQUEIDENTIFIER,QtyForm FLOAT ,  mtSecurity INT)                   
	  CREATE TABLE #psiMatRawList
							(
							   MatGUID  UNIQUEIDENTIFIER,
							   MatName  NVARCHAR(MAX),
	                           mnFormGUID UNIQUEIDENTIFIER, 
							   MatUnit NVARCHAR(MAX),
							   GroupGUID UNIQUEIDENTIFIER,
							   GroupName NVARCHAR(MAX),
							   StoreGuid UNIQUEIDENTIFIER, 
							   StoreName NVARCHAR(MAX),
							   miQty FLOAT, 
							   MatDefUnitFact FLOAT, 
							   MsMatQty  FLOAT, 
							   IsReadyMat  BIT
                            )

	  INSERT INTO #Mat EXEC  prcGetMatsList @MatGuid, @RawGroupGuid 
	  INSERT INTO #StoreTbl  EXEC [prcGetStoresList]  @StoreGUID
	  INSERT INTO #MatConditionTb  EXEC [prcGetMatsList] 		@MatGuid, @RawGroupGuid, -1,@MatCondGuid
	  --///For RawGroup And ReadyGroup /////
	   
	  INSERT INTO #RawMat  
	    SELECT 
		         distinct mi2.MatGUID as MatGuid,
				 tt.FormGuid as FormGuid ,
				 st.Guid as StoreGuid,
				sum( psi.Qty * mi2.Qty) as QtyForm,
				1 
				
		  FROM 
		  ( SELECT 
					fm.Guid AS FormGuid,
					fm.Number as FormNumber,mi.MatGuid as MatGuid, 
			        RANK () OVER (PARTITION BY mi.MatGuid ORDER BY fm.Number DESC) as Irank
			FROM  MI000 mi INNER JOIN MN000 mn on mi.Parentguid = mn.Guid 
						   INNER JOIN FM000 fm ON fm.Guid = mn.FormGuid 		
						   INNER JOIN MT000 mt ON mt.Guid = mi.MatGuid
						   INNER JOIN GR000 gr ON gr.Guid = mt.GroupGUID
						   INNER JOIN PSI000 psi ON psi.formGuid = fm.Guid 
						   
			WHERE  
					mi.type = 0
					AND 
					mn.Type = 0 
					AND 
					psi.startDate BETWEEN  @FromDate AND @ToDate
					AND 
					psi.State = 0 
					 AND 
				    mt.GroupGuid = (CASE mi.type WHEN 0 THEN  
						                            (CASE @ReadyGroupGuid WHEN 0x0 THEN mt.GroupGuid ELSE @ReadyGroupGuid END ) 
									END )
					OR 
					gr.parentGuid = (CASE mi.type WHEN 0 THEN  
			               			                 (CASE @ReadyGroupGuid WHEN 0x0 THEN gr.parentGuid ELSE @ReadyGroupGuid END ) 
										END )
			GROUP BY  fm.Guid ,mi.MatGuid ,fm.Number
			)tt   INNER JOIN FM000 fm on fm.Guid = tt.FormGuid
			      INNER JOIN MN000 mn on mn.FormGuid = tt.FormGuid 
				  INNER JOIN Mi000 mi2 ON mi2.Parentguid = mn.Guid 
				  INNER JOIN MT000 mt ON mt.Guid = tt.MatGuid 
				  INNER JOIN GR000 gr ON gr.Guid = mt.GroupGUID
				  INNER JOIN PSI000 psi ON psi.formGuid = tt.FormGuid 
				  INNER JOIN st000 st ON st.GUID = psi.StoreGuid
				  INNER JOIN #StoreTbl StoreTb ON StoreTb.StoreGuid = ST.Guid 
				 
			WHERE 
					 tt.Irank = 1  
					 AND 
					 psi.State = 0 
					 AND
					  mi2.Type = 1 AND mn.type = 0 
					 AND 
					 psi.startDate BETWEEN  @FromDate AND @ToDate

			GROUP BY tt.FormGuid,tt.MatGuid, mi2.MatGuid ,st.GUID

			
 INSERT INTO #psiMatRawList
		SELECT distinct mi.miMatGUID AS  MatGuid,  
			   CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN mi.mtName ELSE (CASE mi.mtLatinName WHEN '''' THEN mi.mtName ELSE mi.mtLatinName END) END AS MatName, 
               mi.mnFormGUID,
			   CASE @Unit  WHEN 1 THEN mat.Unity
                           WHEN 2 THEN CASE mat.Unit2 WHEN  '' THEN mtV.mtDefUnitName  ELSE mat.Unit2 END
                           WHEN 3 THEN CASE mat.Unit3 WHEN  '' THEN mtV.mtDefUnitName ELSE mat.Unit3 END 
                           ELSE mtV.mtDefUnitName    
                END  as Matunit ,  
			    gr.Guid GroupGuid, 
                CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN Gr.Name ELSE (CASE Gr.LatinName WHEN '''' THEN Gr.Name ELSE Gr.LatinName END) END AS GroupName, 
                st.Guid As StoreGuid, 
			    CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN st.Name ELSE (CASE st.LatinName WHEN '''' THEN st.Name ELSE st.LatinName END) END AS StoreName,--st.Code + '-'+ 
		        (Case @Unit WHEN  0 THEN  
                     CASE mi.mtDefUnit  
                          WHEN 1 THEN ISNULL( MAX(mt.QtyForm), 0)  
                          WHEN 2 THEN ISNULL( MAX(mt.QtyForm), 0) / ISNULL( CASE mi.mtUnit2Fact WHEN 0 THEN 1 ELSE mi.mtUnit2Fact END,1)   
                          WHEN 3 THEN ISNULL( MAX(mt.QtyForm), 0) / ISNULL( CASE mi.mtUnit3Fact WHEN 0 THEN 1 ELSE mi.mtUnit3Fact END,1)   
                      END  
                 WHEN 1 THEN ISNULL( MAX(mt.QtyForm), 0) 
                 WHEN 2 THEN ISNULL( MAX(mt.QtyForm), 0) / ISNULL( CASE mi.mtUnit2Fact WHEN 0 THEN 1 ELSE mi.mtUnit2Fact END,1) 
                 WHEN 3 THEN ISNULL( MAX(mt.QtyForm), 0) / ISNULL( CASE mi.mtUnit3Fact WHEN 0 THEN 1 ELSE mi.mtUnit3Fact END,1)   
                END ) AS miQty,  
		 
				mi.mtDefUnitFact As MatDefUnitFact,  
				0 AS MsMatQty,
				0 AS IsReadyMat
         FROM  
              vwMnMiMt AS mi  INNER JOIN MI000 AS DefMI ON DefMI.GUID = mi.miGUID   
							  INNER JOIN PSI000 AS psi ON (psi.StoreGuid = mi.mnInStore OR psi.StoreGuid = mi.mnOutStore) 
							  AND psi.FormGuid = mi.mnFormGUID 
							  INNER JOIN #RawMat mt ON mt.MatGuid = mi.miMatGuid AND mt.FormGuid = mi.mnFormGUID
							  LEFT JOIN st000 st On st.Guid = psi.StoreGuid 
							  AND (st.Guid = mi.mnInStore OR st.Guid = mi.mnOutStore) 
							  INNER JOIN mt000 Mat On Mat.Guid = mt.MatGuid AND Mat.Guid = mi.miMatGuid 
							  INNER JOIN gr000 gr On gr.Guid = Mat.GroupGuid 
							  INNER JOIN vwmt mtV ON mi.miMatGUID = mtV.mtGuid 
							  INNER JOIN FM000 fm on fm.GUID = psi.FormGuid 
							   INNER JOIN #StoreTbl StoreTb ON StoreTb.StoreGuid = ST.Guid
		 WHERE  
              mi.mnType = 0  
			  AND 
			  psi.State = 0   /*ÇáÎØÉ ãËÈÊÉ */
              AND 
			  miType = 1  /*ÇáãÇÏÉ ÃæáíÉ */ 
        GROUP BY mi.miMatGUID,
				mi.mtName,
				mi.mtLatinName,
				st.Guid,
				st.Name, 
				st.LatinName ,
				gr.Guid,
				Gr.Name, 
				Gr.LatinName,
				mi.mnFormGUID,
				mi.mtUnit3Fact,
				mi.mtUnit2Fact , 
				mat.Unity,
                mat.Unit2, 
				mtV.mtDefUnitName , 
				mat.Unit3 , 
                mi.mtDefUnitFact,
				mi.mtDefUnit
          
  
      INSERT INTO #psiMatRawList 
      SELECT      
			distinct PsiMatRawList.MatGuid, 
			PsiMatRawList.MatName, 
			PsiMatRawList.mnFormGUID, 
			PsiMatRawList.MatUnit,
			PsiMatRawList.GroupGUID, 
			PsiMatRawList.GroupName, 
			ms.msStorePtr AS StoreGuid,  
			st.Name AS StoreName , 
			0,
			PsiMatRawList.MatDefUnitFact AS MatDefUnitFact,
			(Case @Unit WHEN  0 THEN  
                  CASE mat.DefUnit
                        WHEN 1 THEN ISNULL( ms.msQty, 0)  
                        WHEN 2 THEN ISNULL( ms.msQty, 0) / ISNULL( CASE mat.Unit2Fact WHEN 0 THEN 1 ELSE mat.Unit2Fact END,1)   
                        WHEN 3 THEN ISNULL( ms.msQty, 0) / ISNULL( CASE mat.Unit3Fact WHEN 0 THEN 1 ELSE mat.Unit3Fact END,1)   
                        END
            WHEN 1 THEN ISNULL( ms.msQty, 0) 
            WHEN 2 THEN ISNULL( ms.msQty, 0) / ISNULL( CASE mat.Unit2Fact WHEN 0 THEN 1 ELSE mat.Unit2Fact END,1) 
            WHEN 3 THEN ISNULL( ms.msQty, 0) / ISNULL( CASE mat.Unit3Fact WHEN 0 THEN 1 ELSE mat.Unit3Fact END,1)   
            END) / PsiMatRawList.MatDefUnitFact AS MsMatQty, 
			0 AS IsReadyMat   
       FROM  #psiMatRawList PsiMatRawList INNER JOIN vwMs AS ms ON ms.msMatPtr = PsiMatRawList.MatGUID
										  INNER JOIN #RawMat mt ON mt.MatGuid = PsiMatRawList.MatGUID 
										  LEFT JOIN st000 st   ON ms.msStorePtr = st.Guid 
										  INNER JOIN mt000 Mat  ON Mat.Guid = mt.MatGuid 
										  INNER JOIN gr000 gr   ON gr.Guid = Mat.GroupGuid 
										  INNER JOIN vwmt mtV   ON mat.Guid = mtV.mtGuid AND  PsiMatRawList.MatGUID = mtV.mtGuid
										  INNER JOIN #StoreTbl StoreTb ON StoreTb.StoreGuid = ms.msStorePtr  
	   WHERE   (PsiMatRawList.MatGUID = @MatGuid OR @MatGuid = 0x0 )
	   
	  
	   
	SELECT  R.MatGUID as MatGuid ,
			R.MatName, 
			R.MatUnit, 
			R.GroupGUID, 
			R.GroupName, 
			R.StoreGuid, 
			R.StoreName, 
			SUM(R.miQty ) AS MnQty, 
			SUM(R.MsMatQty) StoreQty, 
			SUM(MsMatQty) - SUM(R.miQty )  AS  LackQty,  
			R.IsReadyMat,
			@Unit AS UnitIndex
		INTO #ResultForTotalRawMatQty 
		FROM #psiMatRawList AS R 
	GROUP BY  R.MatGUID, R.MatName, R.MatUnit , R.GroupGUID, R.GroupName,R.StoreGUID, R.StoreName ,R.IsReadyMat
	ORDER BY R.MatName 
	
  
	/* ÊÝßíß ÇáãæÇÏ äÕÝ ÇáãÕäÚÉ */
	IF(@DismantlingOfSemiManufMat = 1)
	BEGIN 
            EXEC GetRawMatQty
			
			
	END	
    --//// CREATE TABLE #StoresDetailsResult ////
	SELECT  res.MatGuid, 
            res.MatName, 
            res.MatUnit,
            res.GroupName, 
            ISNULL(st.stName, 0x0)  AS StoreName,
            (Case @Unit WHEN  0 THEN  
                  CASE mt.mtDefUnit
                        WHEN 1 THEN ISNULL( ms.msQty, 0)  
                        WHEN 2 THEN ISNULL( ms.msQty, 0) / ISNULL( CASE mt.mtUnit2Fact WHEN 0 THEN 1 ELSE mt.mtUnit2Fact END,1)   
                        WHEN 3 THEN ISNULL( ms.msQty, 0) / ISNULL( CASE mt.mtUnit3Fact WHEN 0 THEN 1 ELSE mt.mtUnit3Fact END,1)   
                        END
            WHEN 1 THEN ISNULL( ms.msQty, 0) 
            WHEN 2 THEN ISNULL( ms.msQty, 0) / ISNULL( CASE mt.mtUnit2Fact WHEN 0 THEN 1 ELSE mt.mtUnit2Fact END,1) 
            WHEN 3 THEN ISNULL( ms.msQty, 0) / ISNULL( CASE mt.mtUnit3Fact WHEN 0 THEN 1 ELSE mt.mtUnit3Fact END,1)   
            END)   As StoreQty 
	  INTO #StoresDetailsResult
	  FROM #ResultForTotalRawMatQty Res  INNER JOIN vwMt mt ON mt.mtGUID = Res.MatGUID
							   INNER JOIN vwGr gr ON gr.grGUID = mt.mtGroup
							   LEFT JOIN vwMs ms ON ms.msMatPtr = mt.mtGUID
							   INNER JOIN #StoreTbl Store ON Store.StoreGuid = ms.msStorePtr
							   LEFT JOIN vwSt st ON st.stGUID = Store.StoreGuid
	 GROUP BY Res.MatGUID,Res.MatName,res.MatUnit,res.GroupName,mt.mtGroup,mt.mtDefUnit,ms.msQty,mt.mtUnit2Fact,mt.mtUnit3Fact,ms.msStorePtr ,st.stName 
	 
	
	   /*ÚÑÖ ÊÝÕíá ÇáãÓÊæÏÚÇÊ*/
       IF (@ShowStoreDetails = 1)  
        BEGIN 
	        SELECT 
				distinct res1.MatGuid as MatGuid, 
				res1.MatName, 
				res1.MatUnit,
				res1.GroupName, 
				SUM(res1.MnQty) AS MnQty ,  
				SUM(res1.StoreQty) As StoreQty ,
				SUM(res1.StoreQty) - SUM(res1.MnQty) AS LackQty 
             FROM #ResultForTotalRawMatQty  res1 
             GROUP BY 
                        res1.MatGuid,
                        res1.MatName,
                        res1.MatUnit,
                        res1.GroupName



		  SELECT 
				distinct res1.MatGuid as MatGuid, 
				res1.MatName, 
				res1.MatUnit,
				res1.GroupName, 
				(case res1.StoreName when 0x0 then '' else res1.StoreName end) AS StoreName,
				MAX(res1.MnQty) AS MnQty ,  
				MAX(res1.StoreQty) As StoreQty ,
				MAX(res1.StoreQty) - Max(res1.MnQty) AS LackQty 
               FROM #ResultForTotalRawMatQty  res1 
												 
			GROUP BY 
                        res1.MatGuid,
                        res1.MatName,
                        res1.MatUnit,
                        res1.GroupName, 
                        res1.StoreName
		END
     
      ELSE 
      BEGIN 
	
      SELECT 
            res1.MatGuid as MatGuid, 
            res1.MatName, 
            res1.MatUnit,
            res1.GroupName, 
            MAX(StoreRes.StoreName) AS StoreName,
            MAX(res1.MnQty) AS MnQty ,  
            SUM(StoreRes.StoreQty) As StoreQty ,
		  SUM(StoreRes.StoreQty) - Max(res1.MnQty) AS LackQty 
       INTO #new1
       FROM #ResultForTotalRawMatQty  res1 LEFT JOIN #StoresDetailsResult StoreRes ON StoreRes.MatGuid = res1.MatGuid
	   GROUP BY res1.MatGuid,
                res1.MatName,
                res1.MatUnit,
                res1.GroupName
                    
	    ;WITH StMatTb AS 
		(SELECT res.MatGuid AS SMatGuid,SUM(res.StoreQty)  AS MStoreQty 
		  FROM #StoresDetailsResult res
		 GROUP BY res.Matguid 
		)
				
		UPDATE #NEW1 
		SET StoreQty = ( 
						SELECT tb.MStoreQty 
						FROM StMatTb tb
						WHERE tb.SMatGuid =MatGuid 
						)
						
		;WITH ReqMatTb AS 
		(SELECT  SUM(N.MNQTY) AS NMnQty, N.MatGuid AS NMatGuid 
		 FROM #ResultForTotalRawMatQty N 
		 GROUP By N.MatGuid
		)
												
					

		UPDATE #NEW1 
		SET MnQty = ( 
					  SELECT NMnQty 
					  FROM ReqMatTb tb 
					  WHERE tb.NMatGuid = MatGuid 
				    )
								
		UPDATE #NEW1 
		SET LackQty = STOREQTY - MnQty 

        SELECT 
			res1.MatGuid AS MatGuid, 
            res1.MatName AS MatName, 
            res1.MatUnit AS MatUnit,
            res1.GroupName AS GroupNAme, 
            res1.StoreName AS StoreName,
            res1.MnQty AS MnQty ,  
            res1.StoreQty As StoreQty ,
			res1.LackQty AS LackQty 
		 FROM #NEW1 res1 
		   INNER JOIN #Mat mat on res1.MatGuid = mat.mtNumber
     END 
#########################################################
CREATE PROCEDURE GetRawMatQty 
AS  
 SET NOCOUNT ON 
 ---------------------------------------------------------
 	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	--///////////////////////////////////////////////////////////////////////////////      
	CREATE Table #RowMat(
		SelectedGuid UNIQUEIDENTIFIER, 
                     Guid UNIQUEIDENTIFIER, 
                     ParentGuid UNIQUEIDENTIFIER,
					 ParentParentGUID UNIQUEIDENTIFIER,
                     ClassPtr NVARCHAR(255),
                     FormName NVARCHAR(255), 
                     MatGuid UNIQUEIDENTIFIER,   
	                 MatName NVARCHAR(255), 
	                 Qty Float, 
	                 QtyInForm Float, 
	                 [Path] NVARCHAR(1000),
					 [ParentPath] NVARCHAR(1000), 
	                 Unit int, 
	                 IsSemiReadyMat int, 
					 G int default 0,
					 NeededFormsCount FLOAT,
					 [IsResultOfFormWithMoreThanOneProducedMaterial] BIT )  
	CREATE Table #RowMat2(
		SelectedGuid UNIQUEIDENTIFIER, 
                     Guid UNIQUEIDENTIFIER, 
                     ParentGuid UNIQUEIDENTIFIER, 
					 ParentParentGUID UNIQUEIDENTIFIER,
                     ClassPtr NVARCHAR(255),
                     FormName NVARCHAR(255), 
                     MatGuid UNIQUEIDENTIFIER,   
	                 MatName NVARCHAR(255), 
	                 Qty Float, 
	                 QtyInForm Float, 
	                 [Path] NVARCHAR(1000), 
					 [ParentPath] NVARCHAR(1000),
	                 Unit int, 
	                 IsSemiReadyMat int, 
					 G int default 0,
					 NeededFormsCount FLOAT,
					 [IsResultOfFormWithMoreThanOneProducedMaterial] BIT )
	CREATE TABLE #RowMat3(
		MatGUID UNIQUEIDENTIFIER,
		MatName	NVARCHAR(255),
		MatLatinName NVARCHAR(255),
		MatCode	NVARCHAR(255),
		Qty0 FLOAT,
		CurUnit INT
	) 
	CREATE Table #Result(
				SelectedGuid UNIQUEIDENTIFIER, 
				[Guid] UNIQUEIDENTIFIER, 
				ParentGuid UNIQUEIDENTIFIER,
				ParentParentGUID UNIQUEIDENTIFIER, --Parent Form GUID
				ClassPtr NVARCHAR(255),
				FormName NVARCHAR(255), 
				MatGuid UNIQUEIDENTIFIER,   
				MatName NVARCHAR(255), 
				Qty Float, 
				QtyInForm Float, 
				[Path] NVARCHAR(1000), 
				[ParentPath] NVARCHAR(1000),
				Unit INT, 
				IsSemiReadyMat INT, 
				G INT DEFAULT 0,
				NeededFormsCount FLOAT,
				[IsResultOfFormWithMoreThanOneProducedMaterial] BIT) 
	CREATE Table #Result2(
				SelectedGuid UNIQUEIDENTIFIER, 
				[Guid] UNIQUEIDENTIFIER, 
				ParentGuid UNIQUEIDENTIFIER,
				ParentParentGUID UNIQUEIDENTIFIER, 
				ClassPtr NVARCHAR(255),
				FormName NVARCHAR(255), 
				MatGuid UNIQUEIDENTIFIER,   
				MatName NVARCHAR(255), 
				Qty Float, 
				QtyInForm Float, 
				[Path] NVARCHAR(1000), 
				[ParentPath] NVARCHAR(1000),
				Unit INT, 
				IsSemiReadyMat INT, 
				G INT DEFAULT 0,
				NeededFormsCount FLOAT,
				[IsResultOfFormWithMoreThanOneProducedMaterial] BIT) 

				
	DECLARE 
		@c CURSOR,    
		@M_GUID UNIQUEIDENTIFIER,   
		@M_Qty FLOAT,
		@Unit INT

	SET @c = CURSOR FAST_FORWARD FOR SELECT MatGuid, MnQty, UnitIndex FROM #ResultForTotalRawMatQty 
	OPEN @c FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		INSERT INTO #Result(SelectedGuid, Guid, ParentGuid, ParentParentGUID, ClassPtr, FormName, MatGuid, MatName, Qty, QtyInForm, [Path], ParentPath, Unit, IsSemiReadyMat, NeededFormsCount, [IsResultOfFormWithMoreThanOneProducedMaterial])  
		EXEC prcGetManufacMaterialTree @M_GUID

		UPDATE #Result 
		SET Qty = @M_Qty * Qty 
		
		IF (SELECT COUNT(*) FROM #Result) > 0 
		BEGIN 
			INSERT INTO #RowMat 
				SELECT * 
				FROM #Result
				WHERE IsSemiReadyMat = 0
			
			UPDATE #RowMat 
			SET	G = 1
				,NeededFormsCount =( Qty / QtyInForm) 
			WHERE 
				G = 0 
				AND 
				SelectedGuid = @M_GUID 

			INSERT INTO #Result2
			SELECT * 
			FROM #RESULT
			WHERE IsSemiReadyMat = 1

			UPDATE
				#Result2
			SET
				NeededFormsCount = (Qty / QtyInForm)
			WHERE SelectedGuid = @M_GUID
		END 
		ELSE 
		BEGIN 
			DECLARE @mtName AS NVARCHAR(50) 
			
			INSERT INTO #RowMat(SelectedGuid, Guid, ParentGuid, ParentParentGUID, ClassPtr, FormName, MatGuid, MatName, Qty, QtyInForm, [Path], [ParentPath], Unit, IsSemiReadyMat, NeededFormsCount, [IsResultOfFormWithMoreThanOneProducedMaterial])
			VALUES (@M_GUID, 0x0, 0x0, 0x0, '', '', @M_GUID, (SELECT mtName FROM vwMt WHERE [mtGUID] = @M_GUID), @M_Qty, 0, '', '', @Unit, 0, 0, 0) 
		END 
		
		DELETE #Result 
		FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	END      
	CLOSE @c DEALLOCATE @c    

	-- Mixing Both ways
	-- Mark raw mats those are result of a form with more than one (ready/ semi ready) materials to apply MAX to them
	-- then apply the SUM
	

	INSERT INTO #RowMat2
	SELECT
		*
	FROM
		#RowMat
	WHERE
		[IsResultOfFormWithMoreThanOneProducedMaterial] = 0
		AND
		[IsSemiReadyMat] = 0

		
   UPDATE #RowMat2
		SET Unit = 1 

		if (( SELECT COUNT(R.COUNTER) FROM (
				SELECT COUNT(ParentGuid) COUNTER 
				FROM #RowMat2 
					WHERE ParentParentGuid = 0x0 
				GROUP BY ParentGuid 
				)R ) > 1 ) 
	BEGIN 
		UPDATE #RowMat2
		SET Qty = RR.Qty FROM (SELECT SUM(R.QTY) Qty , R.MatGuid MatGuid
					 FROM #RowMat2 R  
					 group by R.MatGuid 
					)RR
					WHERE  RR.MatGuid = #RowMat2.MatGuid
		END 

	DELETE FROM #RowMat
	WHERE
		[IsResultOfFormWithMoreThanOneProducedMaterial] = 0
		AND
		[IsSemiReadyMat] = 0

	INSERT INTO #RowMat3
	SELECT
		X.MatGuid,
		X.MatName,
		Mt.mtLatinName,
		Mt.mtCode,
		X.QtyInForm * X.MaxNeededFormsCount,
		X.Unit
	FROM
	(
		SELECT
			MatGuid,
			MatName,
			[Path],
			QtyInForm,
			Unit,
			Max(NeededFormsCount) MaxNeededFormsCount
		FROM 
			#RowMat
		WHERE
			[ParentParentGUID] = 0x00
		GROUP BY
			MatGuid,
			MatName,
			[Path],
			QtyInForm,
			Unit	
	) X INNER JOIN vwMt Mt ON Mt.[mtGUID] = X.MatGuid



	DELETE FROM #RowMat
	WHERE
		[ParentParentGUID] = 0x00



	INSERT INTO #RowMat3
	SELECT
		R2.MatGuid,
		R2.MatName AS MatName,
		MT.LatinName AS MatLatinName,
		MT.Code AS MatCode,
		MAX(R2.QtyInForm * R2.NeededFormsCount) As Qty0,
		R2.Unit AS CurUnit
	FROM
	(
		SELECT
			rm.MatGUID,
			rm.MatName,
			rm.Unit,
			rm.QtyInForm,
			res2.MaxSumMaxMax NeededFormsCount
		FROM 
			#RowMat rm 
			INNER JOIN 
			(
				SELECT
					Form,
					MAX(SumMaxNeededFormsCount) MaxSumMaxMax
				FROM
				(
					SELECT
						MatGuid,
						MatName,
						Form,
						QtyInForm,
						SUM(MaxNeededFormsCount) SumMaxNeededFormsCount
					FROM
					(
						SELECT
							MatGuid,
							MatName,
							Form,
							ParentParentGUID,
							QtyInForm,
							MAX(MaxNeededFormsCount) MaxNeededFormsCount
						FROM
						(
							SELECT
								MatGuid,
								MatName,
								ParentGUID AS Form,
								ParentParentGUID,
								[Path],
								[ParentPath],
								QtyInForm,
								MAX(NeededFormsCount) as MaxNeededFormsCount
							FROM 
								#Result2
							GROUP BY
								MatGuid,
								MatName,
								ParentGUID,
								ParentParentGUID,
								[Path],
								[ParentPath]
								,QtyInForm
						) H
						GROUP BY
							MatGuid,
							MatName,
							Form,
							ParentParentGUID,
							QtyInForm
					) H2
					GROUP BY
						MatGuid,
						MatName,
						Form,
						QtyInForm
				) H3
				GROUP BY
					Form
					
			) res2 ON res2.Form = rm.ParentParentGUID 
		WHERE 
			[IsResultOfFormWithMoreThanOneProducedMaterial] = 1
		GROUP BY
			rm.MatGUID,
			rm.MatName,
			rm.QtyInForm,
			rm.Unit,
			res2.MaxSumMaxMax
	) R2
		INNER JOIN Mt000 MT ON R2.MatGUID = MT.[GUID]
	GROUP BY
		R2.MatGUID,
		R2.MatName,
		MT.LatinName,
		MT.Code,
		R2.Unit

	INSERT INTO #RowMat3
	SELECT
		R2.MatGUID,
		MT.Name AS MatName,
		MT.LatinName AS MatLatinName,
		MT.Code AS MatCode,
		MAX(R2.Qty) AS Qty0,
		R2.Unit AS CurUnit
	FROM
		#RowMat2 R2
		INNER JOIN MT000 MT ON R2.MatGUID = MT.[GUID]
	GROUP BY
		R2.MatGUID,
		MT.Name,
		MT.LatinName,
		MT.Code,
		R2.Unit


	
	SELECT 
		r3.MatGuid, 
		r3.MatName, 
		r3.MatLatinName, 
		r3.MatCode,
		SUM(r3.Qty0) AS Qty, 
		r3.CurUnit
	INTO #RowTable	   
	FROM 
		#RowMat3 r3  
	GROUP BY
		r3.MatGuid, 
		r3.MatName, 
		r3.MatLatinName, 
		r3.MatCode,
		r3.CurUnit
	ORDER BY
		r3.MatName
		
	UPDATE #RowTable 
   SET Qty = 
			(
				SELECT SUM(RowTb.Qty) 
				FROM 
					#RowTable RowTb
					WHERE  RowTb.MatGuid = #RowTable.MatGuid
					GROUP BY RowTb.MatGUID
					
				)

	
	DECLARE @UseUnit INT
	SET @UseUnit =( SELECT distinct UnitIndex FROM #ResultForTotalRawMatQty )
	 delete from #ResultForTotalRawMatQty

	INSERT INTO #ResultForTotalRawMatQty 
	SELECT RowTb.MatGUID
		   ,CASE WHEN @Lang > 0 THEN CASE WHEN mt.mtLatinName = '' THEN  mt.mtName ELSE mt.mtLatinName END ELSE mt.mtName END
		   ,CASE @UseUnit  
						  WHEN 1 THEN 
						  CASE mt.mtUnity
							WHEN '' THEN mt.mtDefUnitName
							ELSE mt.mtUnity
						END
						  WHEN 2 THEN 
						   CASE mt.mtUnit2
							WHEN '' THEN mt.mtDefUnitName
							ELSE mt.mtUnit2
						  END 
						  WHEN 3 THEN
						    CASE mt.mtUnit3
							WHEN '' THEN mt.mtDefUnitName
							ELSE mt.mtUnit3
							END 
            ELSE  mt.mtDefUnitName
			END  as MatUnit , 
		   mt.mtGroup AS GroupGuid
		   ,CASE WHEN @Lang > 0 THEN CASE WHEN gr.grLatinName = '' THEN  gr.grName ELSE gr.grLatinName END ELSE gr.grName END AS GroupName
		   ,0x0
		   ,0x0
		   ,MAX(RowTb.Qty) AS MnQty
		   ,SUM(ms.msQty) AS StoreQty
		   ,SUM(ms.msQty) - MAX(RowTb.Qty) AS LackQty
		   ,1
		   ,0
    FROM 
	     #RowTable RowTb  INNER JOIN vwMt mt ON mt.mtGUID = RowTb.MatGUID
		  INNER JOIN vwGr gr ON gr.grGUID = mt.mtGroup
		  LEFT JOIN vwMs ms ON ms.msMatPtr = mt.mtGUID
	GROUP BY RowTb.MatGUID,CASE WHEN @Lang > 0 THEN CASE WHEN mt.mtLatinName = '' THEN  mt.mtName ELSE mt.mtLatinName END ELSE mt.mtName END,mt.mtDefUnitName,mt.mtGroup,CASE WHEN @Lang > 0 THEN CASE WHEN gr.grLatinName = '' THEN  gr.grName ELSE gr.grLatinName END ELSE gr.grName END, mt.mtDefUnitName,mt.mtUnit2 , mt.mtUnit3 , mt.mtUnity
#########################################################
CREATE PROCEDURE prcPlanItemsDelete		@PlanGuid	[UNIQUEIDENTIFIER]
AS
DELETE FROM PSI000 WHERE [parentGuid] = @PlanGuid
DELETE FROM MNPS000 WHERE [Guid] = @PlanGuid
DELETE FROM ManOperationNumInPlan000 WHERE [PlanGuid] = @PlanGuid
#########################################################
CREATE PROCEDURE prcGetPlansWithDevReasons
	@StoreGuid 	UNIQUEIDENTIFIER = 0x0,
	@FormGuid	UNIQUEIDENTIFIER = 0x0, 
	@StartDate  DATETIME = '1-1-1980', 
	@EndDate   	DATETIME = '1-1-2070', 
	@State		NVARCHAR(255),
	@OrderGuid  UNIQUEIDENTIFIER = 0x0,
	@PlanGuid UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	DECLARE @Temp Table ( [Data] SQL_VARIANT)    
    INSERT INTO @Temp SELECT * FROM [dbo].[fnTextToRows](@State)    
------------------------------ TEMP TABLE TO HOLD THE PLANS WITH THIER ITEMS-------------------------------
CREATE TABLE #PlansWithItems (
					  ParentGuid UNIQUEIDENTIFIER,ParentCode VARCHAR(100) COLLATE ARABIC_CI_AI, PlanStartDate DATETIME, PlanEndDate DATETIME,  
					  PlanItemGuid UNIQUEIDENTIFIER,PlanItemCode VARCHAR(50) COLLATE ARABIC_CI_AI,  
					  StartDate DATETIME, EndDate DATETIME, Qty FLOAT, FormName VARCHAR(100) COLLATE ARABIC_CI_AI,  
					  FormCode VARCHAR(100) COLLATE ARABIC_CI_AI, StoreName VARCHAR(100) COLLATE ARABIC_CI_AI, 
					  StoreCode VARCHAR(100) COLLATE ARABIC_CI_AI, Priority INT, State INT, 
					  Done FLOAT, Deviation FLOAT, Note VARCHAR(150) COLLATE ARABIC_CI_AI, OrderNo VARCHAR(150) COLLATE ARABIC_CI_AI
					 )
------------------------------- FILL TEMP TABLE ------------------------------------------------------------
IF (@OrderGuid =0x0 AND @PlanGuid = 0x0 )
BEGIN
INSERT INTO #PlansWithItems(
					         ParentGuid, ParentCode, PlanStartDate, PlanEndDate, PlanItemGuid, PlanItemCode, StartDate, EndDate, Qty, FormName, 
					         FormCode, StoreName,StoreCode, Priority, State, Done, Deviation, Note , OrderNo
					       )
SELECT Mnps.Guid, 
	   Mnps.Code,
	   Mnps.StartDate,
	   Mnps.EndDate, 
	   Psi.Guid,
	   Psi.Code, 
	   Psi.StartDate,
	   Psi.EndDate,
	   Psi.Qty,
	   CASE WHEN @Lang > 0 THEN CASE WHEN fm.LatinName ='' THEN Fm.Name ELSE fm.LatinName END ELSE Fm.Name END,
	   Fm.Code,
	   CASE WHEN @Lang > 0 THEN CASE WHEN st.LatinName ='' THEN st.Name ELSE st.LatinName END ELSE st.Name END,
	   St.Code,
	   Psi.Priority,
	   Psi.State, 
	   Psi.Done,
	   Psi.Deviation,
	   Psi.Notes,
	   CASE WHEN @Lang > 0 THEN bt.LatinName ELSE bt.Name END + ' - ' + CAST (bu.Number AS nvarchar(20))
FROM MNPS000 AS Mnps INNER JOIN PSI000 AS Psi ON Psi.ParentGuid = Mnps.Guid
					 INNER JOIN FM000  AS Fm  ON Psi.FormGuid = Fm.Guid   
					 INNER JOIN ST000  AS St  ON Psi.StoreGuid = St.Guid	
					 LEFT JOIN bu000 AS bu ON bu.GUID = psi.OrderNumGuid
					 LEFT JOIN bt000 AS bt ON bt.GUID = bu.TypeGUID 
WHERE (Mnps.Guid = @PlanGuid OR @PlanGuid = 0x0)
	AND Psi.StartDate BETWEEN @StartDate AND  @EndDate
	AND  (Psi.State      IN (SELECT CONVERT(int, Data) FROM @Temp) )-- @State	   OR @State = 4) 
	AND  (Psi.StoreGuid  =  @StoreGuid OR @StoreGuid = 0x0)
	AND  (Psi.FormGuid   =  @FormGuid  OR @FormGuid  = 0x0)
	AND  (Psi.orderNumGuid = @OrderGuid OR @OrderGuid = 0x0)
ORDER BY Psi.Code
END
ELSE
BEGIN
INSERT INTO #PlansWithItems(
					         ParentGuid, ParentCode, PlanStartDate, PlanEndDate, PlanItemGuid, PlanItemCode, StartDate, EndDate, Qty, FormName, 
					         FormCode, StoreName,StoreCode, Priority, State, Done, Deviation, Note , OrderNo
					       )
SELECT Mnps.Guid, 
	   Mnps.Code,
	   Mnps.StartDate,
	   Mnps.EndDate, 
	   Psi.Guid,
	   Psi.Code, 
	   Psi.StartDate,
	   Psi.EndDate,
	   Psi.Qty,
	   CASE WHEN @Lang > 0 THEN CASE WHEN fm.LatinName ='' THEN Fm.Name ELSE fm.LatinName END ELSE Fm.Name END,
	   Fm.Code,
	   CASE WHEN @Lang > 0 THEN CASE WHEN st.LatinName ='' THEN st.Name ELSE st.LatinName END ELSE st.Name END,
	   St.Code,
	   Psi.Priority,
	   Psi.State, 
	   Psi.Done,
	   Psi.Deviation,
	   Psi.Notes,
	   CASE WHEN @Lang > 0 THEN bt.LatinName ELSE bt.Name END + ' - ' + CAST (bu.Number AS nvarchar(20))
FROM MNPS000 AS Mnps INNER JOIN PSI000 AS Psi ON Psi.ParentGuid = Mnps.Guid
					 INNER JOIN FM000  AS Fm  ON Psi.FormGuid = Fm.Guid   
					 INNER JOIN ST000  AS St  ON Psi.StoreGuid = St.Guid	
				     LEFT JOIN bu000 AS bu ON bu.GUID = psi.OrderNumGuid
					 LEFT JOIN bt000 AS bt ON bt.GUID = bu.TypeGUID
WHERE (Mnps.Guid = @PlanGuid OR @PlanGuid = 0x0) 
	AND  (Psi.State      IN (SELECT CONVERT(int, Data) FROM @Temp) )-- @State	   OR @State = 4) 
	AND  (Psi.StoreGuid  =  @StoreGuid OR @StoreGuid = 0x0)
	AND  (Psi.FormGuid   =  @FormGuid  OR @FormGuid  = 0x0)
	AND  (Psi.orderNumGuid = @OrderGuid OR @OrderGuid = 0x0)
ORDER BY Psi.Code
END
------------------------------------------ Return The Result To the Caller(including The Deviation Reasons) ---------------------
DECLARE @Cur	CURSOR
DECLARE @name	NVARCHAR(255)
DECLARE @num	NVARCHAR(255)
DECLARE @pGuid	UNIQUEIDENTIFIER
DECLARE @prevGuid  	UNIQUEIDENTIFIER
DECLARE @Temp1 Table ( [PItemGuid] UNIQUEIDENTIFIER ,[Data] SQL_VARIANT)    
SET @Cur = CURSOR FAST_FORWARD FOR 
SELECT
		DISTINCT PSI000.GUID,
		mn.Number as Number
FROM PSI000 
INNER JOIN ManOperationNumInPlan000 AS MNO ON PSI000.GUID = MNO.planitemguid
INNER JOIN MN000 as MN on MN.guid = MNO.mnguid

OPEN @Cur FETCH FROM @Cur INTO 
	@pGuid,
	@num
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF (@prevGuid != @pGuid)
			SET @name = ''
		SET @name =  ISNULL(@name,'') + ', '+ Convert(nvarchar(50), ISNULL(@num, ''))
		SET @prevGuid = @pGuid
		INSERT INTO @Temp1 SELECT @pGuid, @name
	
	FETCH FROM @Cur INTO 
		@pGuid,
		@num
	END
	CLOSE @Cur	DEALLOCATE @Cur 
	DECLARE @Temp2 Table ([PItemGuid] UNIQUEIDENTIFIER , [Data] SQL_VARIANT)    
    INSERT INTO @Temp2 SELECT PItemGuid, max(Data) FROM @Temp1 group by PItemGuid

SELECT DISTINCT item.ParentGuid  PlanGuid,item.ParentCode PlanCode,item.PlanStartDate,item.PlanEndDate  FROM #PlansWithItems item

SELECT
		DISTINCT #PlansWithItems.*,
		CAST(ISNULL(T.data,'')AS NVARCHAR (MAX)) AS ManNumber
FROM #PlansWithItems 
LEFT JOIN @Temp2 AS T ON #PlansWithItems.PlanItemGuid = T.PItemGuid
ORDER BY #PlansWithItems.parentCode ,#PlansWithItems.PlanItemCode

SELECT dr.PlanItemGuid , dr.DeviationReason FROM deviationreasons000  dr WHERE dr.PlanItemGuid in (SELECT item.PlanItemGuid FROM #PlansWithItems item)
------------------------------------------ DROP THE TEMP TABLE -------------------------
DROP TABLE #PlansWithItems
#########################################################
CREATE PROCEDURE  PrcCheckMatQtys
		@Materials 				UNIQUEIDENTIFIER,  
		@Store					UNIQUEIDENTIFIER 
AS  
SET NOCOUNT ON   
SELECT  
	Mt.Guid MatGuid 
	, Mt.low 
	, Mt.high
	, Mt.OrderLimit
	, Mt.Name 
	, Mt.LatinName 
	, SUM(ISNULL((Bi.Qty * CASE Bt.BillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END) , 0)) Stock  
FROM Mt000 Mt  
	INNER JOIN [RepSrcs] AS [r] ON Mt.Guid = [r].[IdType]  
	LEFT JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid AND Bi.StoreGuid = @Store
	LEFT JOIN Bu000 Bu on Bu.Guid = Bi.ParentGuid  
	LEFT JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid  
WHERE   
 [IdTbl] = @Materials  
GROUP BY  
	Mt.Guid ,Mt.low, Mt.high, Mt.OrderLimit, Mt.Name, Mt.LatinName
#########################################################
CREATE FUNCTION fnGetOrdersInPlan (@PlanGuid UNIQUEIDENTIFIER = 0x0)
RETURNS TABLE
AS
RETURN
(
	SELECT 
		distinct VO.BtGuid,
		VO.guid,
		VO.BuNumber,
		VO.BuNotes,
		VO.BtName,
		VO.BtType,
		VO.Security,
		VO.CustomerName
	FROM 
		VWORDERS AS VO
		INNER JOIN PSI000 AS PSI ON PSI.orderNumGuid = VO.Guid
		INNER JOIN ORADDINFO000 AS INFO ON INFO.ParentGuid = VO.Guid
	WHERE
		(PSI.ParentGuid = @PlanGuid OR @PlanGuid = 0x0)
		AND INFO.Finished = 0
		AND INFO.Add1 = 0
)
#########################################################
CREATE FUNCTION fnGetActiveOrders (@OrderTypeGUID UNIQUEIDENTIFIER = 0x0)
RETURNS TABLE
AS
RETURN
(
	SELECT
		Orders.BtGuid,
		Orders.Guid,
		Orders.BuNumber,
		Orders.BuNotes,
		Orders.BtName,
		Orders.BtType,
		Orders.Security,
		Orders.CustomerName
	FROM
		vwOrders AS Orders
		INNER JOIN ORADDINFO000 AS INFO ON INFO.ParentGuid = Orders.Guid
	WHERE
		(Orders.BtGuid = @OrderTypeGUID OR @OrderTypeGUID = 0x0)
		AND ISNULL(Info.Finished, 0 ) = 0
		AND ISNULL(INFO.Add1, 0) = 0
)
#########################################################
CREATE FUNCTION fnGetManOpNotInPlan (@FormGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN
(
SELECT 
		DISTINCT (CAST (MN.Number AS NVARCHAR)) AS Number,
		Qty,
		Mn.GUID
FROM
	Mn000 AS MN
		LEFT JOIN (SELECT DISTINCT (MnGuid) AS MnGuid FROM ManOperationNumInPlan000 )  AS MOP ON Mn.Guid = MOP.MnGuid 
	
WHERE 
		Mn.FormGUID = @FormGuid
		AND Number NOT IN (	SELECT 
								Mn.Number		
							FROM Mn000 AS Mn
							
							INNER JOIN (select distinct(MnGuid) as MnGuid FROM ManOperationNumInPlan000 ) MP ON Mn.Guid = MP.MnGuid
							
							WHERE MN.Type =1  AND Mn.FormGUID = @FormGuid
							)
		AND Mn.Type = 1

)
#########################################################
CREATE PROCEDURE GetOperationMan (@PlanItemGuid UNIQUEIDENTIFIER)
AS
SET NOCOUNT ON   
SELECT	MN.Number, MN.Qty 
FROM (SELECT distinct (MnGuid) as MnGuid  FROM ManOperationNumInPlan000 MOP WHERE  MOp.PlanItemGuid = @PlanItemGuid ) MP 
			 INNER JOIN MN000 AS MN ON MN.guid = MP.MnGuid
WHERE  MN.Type = 1 
ORDER BY MN.Number
#########################################################
CREATE  FUNCTION fnFindManOperation (@PlanGuid UNIQUEIDENTIFIER, @PlanItemGuid UNIQUEIDENTIFIER,@ManOperationGuid UNIQUEIDENTIFIER )
RETURNS INT
AS 
BEGIN
	RETURN (
			SELECT COUNT(MnGuid ) 
				FROM  ManOperationNumInPlan000
			WHERE PlanGuid = @PlanGuid AND PlanItemGuid = @PlanItemGuid
					AND MnGuid = @ManOperationGuid
			)
END 
#########################################################
CREATE PROCEDURE prcUpdateDoneAndDeviation(@Done FLOAT, @PlanGuid UNIQUEIDENTIFIER, @PlanItemGuid UNIQUEIDENTIFIER, @Deviation FLOAT)
AS 
SET NOCOUNT ON   
UPDATE PSI000
SET Done =  @Done , Deviation =  @Deviation
WHERE PSI000.Guid = @PlanItemGuid AND PSI000.ParentGuid = @PlanGuid 
#########################################################
CREATE PROCEDURE prcDeleteDoneAndDeviation(@PlanGuid UNIQUEIDENTIFIER, @PlanItemGuid UNIQUEIDENTIFIER)
AS 
SET NOCOUNT ON   
UPDATE PSI000
SET Done = 0 , Deviation = -PSI000.Qty
WHERE PSI000.Guid = @PlanItemGuid AND PSI000.ParentGuid = @PlanGuid 
#########################################################
CREATE PROCEDURE prcUpdateState(@PlanGuid UNIQUEIDENTIFIER, @PlanItemGuid UNIQUEIDENTIFIER)
AS 
SET NOCOUNT ON   
UPDATE PSI000
SET  State = 1 
WHERE PSI000.Guid = @PlanItemGuid AND PSI000.ParentGuid = @PlanGuid 
#########################################################
CREATE PROCEDURE prcDeleteState(@PlanGuid UNIQUEIDENTIFIER, @PlanItemGuid UNIQUEIDENTIFIER)
AS 
SET NOCOUNT ON   
UPDATE PSI000
SET State = 0 
WHERE PSI000.Guid = @PlanItemGuid AND PSI000.ParentGuid = @PlanGuid
#########################################################
#END
