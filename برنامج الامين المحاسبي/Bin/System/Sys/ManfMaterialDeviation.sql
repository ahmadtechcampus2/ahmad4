################################################################################
CREATE FUNCTION fnGetAltMatQty( @AltMatGuid uniqueidentifier , @MN uniqueidentifier, @Form uniqueidentifier)
     RETURNS FLOAT
    AS
    BEGIN 
       DECLARE 
           @OriginalMatGuid uniqueidentifier ,
           @OriginalMatInALtCardQty float ,  
           @AltMatInALtCardQty float ,
           @OrignalMatInFormCardQty float ,
           @OriginalMatFact float = 1,
           @AltMatFact float = 1,
           @OrignalMatInFormCardFact float = 1,
           @result float = 0,
           @OriginalMatInAltCardUnity int ,
           @AltMatInAltCardUnity int ,
           @OrignalMatInFormCardUnity int;
     -------
	    SELECT @OriginalMatGuid = temp.MainGuid
        FROM MI000 m INNER JOIN AlternativeMatsItems000 alt on alt.MatGUID = m.MatGUID
		INNER JOIN  ( SELECT  alt.AltMatsGuid as alterGuid,mi.MatGUID as MainGuid 
						 FROM MN000 mn INNER JOIN MI000 mi on mi.ParentGUID = mn.guid
							INNER JOIN AlternativeMatsItems000 alt on alt.MatGUID = mi.MatGUID
                         WHERE mn.FormGUID = @Form AND mn.type = 0 ) temp on alt.AltMatsGuid = alterGuid
		WHERE ParentGUID = @MN AND m.MatGUID = @AltMatGuid
     --------   
        SELECT  
           @OriginalMatInAltCardQty = Qty ,  
           @OriginalMatInAltCardUnity = Unity 
        FROM vwAlternativeMatsItems Altmt 
        where MatGUID = @OriginalMatGuid
      -----------  
         SELECT  
           @AltMatInAltCardQty = Qty ,  
           @AltMatInAltCardUnity = Unity 
        FROM vwAlternativeMatsItems Altmt 
        where MatGUID =  @AltMatGuid
     ----------   
        SELECT
          @OrignalMatInFormCardQty = Qty ,  
          @OrignalMatInFormCardUnity = Unity 
        FROM
        mi000
         WHERE ParentGUID  =  
             (  SELECT GUID 
                FROM MN000 
                WHERE FormGUID = @Form 
                AND type = 0 
                    ) AND MatGUID = @OriginalMatGuid
         ---------------------
        IF(@OriginalMatInAltCardUnity <> 1)
        BEGIN
			set @OriginalMatFact = (SELECT CASE @OriginalMatInAltCardUnity WHEN 2 THEN Unit2Fact ELSE Unit3Fact END FROM mt000 WHERE GUID = @OriginalMatGuid)
        END
        IF(@AltMatInAltCardUnity <> 1)
        BEGIN
			set @AltMatFact = (SELECT CASE @AltMatInAltCardUnity WHEN 2 THEN Unit2Fact ELSE Unit3Fact END FROM mt000 WHERE GUID = @AltMatGuid )
        END
        IF(@OrignalMatInFormCardUnity <> 1)
        BEGIN
			set @OrignalMatInFormCardFact = (SELECT CASE @OrignalMatInFormCardUnity WHEN 2 THEN Unit2Fact ELSE Unit3Fact END FROM mt000 WHERE GUID = @OriginalMatGuid)
        END
          SELECT @result = (((@AltMatInALtCardQty * @AltMatFact) / (@OriginalMatInALtCardQty * @OriginalMatFact)  ) * (@OrignalMatInFormCardQty * @OrignalMatInFormCardFact))/ @AltMatFact  
           RETURN ISNULL( @result , 0 
                     ); 
    END; 
################################################################################
CREATE FUNCTION fnGetAltMatPrice( @AltMatGuid uniqueidentifier)
      RETURNS FLOAT
AS
BEGIN
   Declare @result float
      SELECT @result = Price
        FROM vwAlternativeMatsItems Altmt 
         WHERE MatGUID = @AltMatGuid
 
        RETURN ISNULL( @result , 0 
                     ); 
    END; 
################################################################################
CREATE FUNCTION fnGetMatQtyWithUnit( @MatGuid uniqueidentifier ,   @Qty float , @FromUnit int , @ToUnit int )
     RETURNS float
AS
BEGIN

    IF @FromUnit
       = 
       @ToUnit
        BEGIN
            RETURN @Qty;
        END;
    DECLARE
       @result float , 
       @ToUnitFact float , 
       @FromUnitfact float;
    SELECT @ToUnitFact = CASE @ToUnit
                         WHEN 1 THEN 1
                         WHEN 2 THEN Unit2Fact
                         WHEN 3 THEN Unit3Fact
                             ELSE CASE DefUnit
                                  WHEN 1 THEN 1
                                  WHEN 2 THEN Unit2Fact
                                  WHEN 3 THEN Unit3Fact
                                  END
                         END , 
           @FromUnitfact = CASE @FromUnit
                           WHEN 1 THEN 1
                           WHEN 2 THEN Unit2Fact
                           WHEN 3 THEN Unit3Fact
                               ELSE CASE DefUnit
                                    WHEN 1 THEN 1
                                    WHEN 2 THEN Unit2Fact
                                    WHEN 3 THEN Unit3Fact
                                    END
                           END
      FROM mt000
      WHERE guid = @MatGuid;

    IF @FromUnitfact
       = 
       0
        BEGIN
            RETURN 0;
        END;
    SET @result = @Qty *  ( @FromUnitfact / CASE WHEN @ToUnitFact = 0 THEN 1 ELSE @ToUnitFact END );
    RETURN @result;
END;
################################################################################ 
CREATE FUNCTION fnGetMatPriceWithUnit( @MatGuid uniqueidentifier ,   @Price float ,   @FromUnit int ,   @ToUnit int)
	RETURNS FLOAT
AS
BEGIN

    IF @FromUnit
       = 
       @ToUnit
        BEGIN
            RETURN @Price;
        END;

    DECLARE
       @result float , 
       @ToUnitFact float , 
       @FromUnitfact float;
    SELECT @ToUnitFact = CASE @ToUnit
                         WHEN 1 THEN 1
                         WHEN 2 THEN Unit2Fact
                         WHEN 3 THEN Unit3Fact
                             ELSE CASE DefUnit
                                  WHEN 1 THEN 1
                                  WHEN 2 THEN Unit2Fact
                                  WHEN 3 THEN Unit3Fact
                                  END
                         END , 
           @FromUnitfact = CASE @FromUnit
                           WHEN 1 THEN 1
                           WHEN 2 THEN Unit2Fact
                           WHEN 3 THEN Unit3Fact
                               ELSE CASE DefUnit
                                    WHEN 1 THEN 1
                                    WHEN 2 THEN Unit2Fact
                                    WHEN 3 THEN Unit3Fact
                                    END
                           END
      FROM mt000
      WHERE guid = @MatGuid;
    IF @FromUnitfact
       = 
       0
        BEGIN
            RETURN 0;
        END;
    SET @result = @Price * (  @ToUnitFact / CASE WHEN @FromUnitfact = 0 THEN 1 ELSE @FromUnitfact END);
    RETURN @result;
END;
################################################################################
CREATE PROCEDURE  PrcRepManfMstDeviation
	@MatGuid uniqueidentifier = 0x0 , 
	@GroupGuid uniqueidentifier = 0x0 , 
	@FormGuid uniqueidentifier = 0x0 , 
	@CostGuid uniqueidentifier = 0x0 , 
	@MatsType int = 0 , -- „Ê«œ «Ê·Ì…0 - „Ê«œ „’‰⁄… 1  
	@ManfNumber int = 0 , 
	@StartDate date = '1/1/1991' , 
	@EndDate date = '1/1/1991', 
	@Unit int = 1 , 
	@OrderBy int = 0 ,--4 „—ﬂ“ «·ﬂ·›… -- 3 —ﬁ„ ⁄„·Ì… «· ’‰Ì⁄ 0- «· «—ÌŒ  1- «·‰„Ê–Ã 2- «·„«œ… 
	@GroupBy int = 0 -- 3 »œÊ‰ 0- «·‰„Ê–Ã 1- „—ﬂ“ «·ﬂ·›…2 - «·„«œ… 
	
AS
SET NOCOUNT ON

DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();

	CREATE TABLE #MainResult(
		MatGuid UNIQUEIDENTIFIER,
		BIQty FLOAT,
		BIUnit INT, 
		BIPrice FLOAT,
		MnGuid UNIQUEIDENTIFIER, 
		MNQty FLOAT,
		FormGUID UNIQUEIDENTIFIER, 
		CostGuid UNIQUEIDENTIFIER, 
		MnNUmber INT, 
		MnDate DATETIME, 
		FmName NVARCHAR(250), 
		CostName NVARCHAR(250), 
		MatName NVARCHAR(250), 
		MatUnitName NVARCHAR(250));

	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])  

	INSERT INTO #MainResult
	SELECT 
		mt.GUID , 
		bi.Qty , 
		bi.Unity,
		bi.Price,
       MN.GUID,
	   MN.Qty,
       fm.GUID , 
       co.GUID , 
       MN.Number , 
       MN.Date , 
       CASE WHEN @Lang > 0 THEN CASE WHEN  fm.LatinName = '' THEn Fm.Name ELSE fm.LatinName END ELSE fm.Name END  , 
       CASE WHEN @Lang > 0 THEN CASE WHEN  CO.LatinName = '' THEn CO.Name ELSE CO.LatinName END ELSE CO.Name END, 
       CASE WHEN @Lang > 0 THEN CASE WHEN  mt.LatinName = '' THEn mt.Name ELSE mt.LatinName END ELSE mt.Name END, 
       ISNULL (NULLIF ((CASE @Unit
       WHEN 1 THEN mt.Unity
       WHEN 2 THEN mt.Unit2
       WHEN 3 THEN mt.Unit3
           ELSE CASE mt.DefUnit
                WHEN 1 THEN mt.Unity
                WHEN 2 THEN mt.Unit2
                WHEN 3 THEN mt.Unit3
                END
       END),''),mt.Unity)
	 FROM
		bi000 bi 
		INNER JOIN MB000 mb ON mb.BillGUID = bi.ParentGUID 
			AND ((@MatsType = 0 AND mb.Type IN( 0 , 2)) OR (@MatsType = 1 AND mb.Type = 1))
		INNER JOIN MN000 MN ON Mn.GUID = mb.ManGUID
		INNER JOIN FM000 FM ON FM.GUID =  MN.FormGUID
		INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID AND (mt.Guid = @MatGuid OR @MatGuid = 0x0) 
			AND (mt.GroupGuid =  @GroupGuid OR @GroupGuid = 0x0 OR dbo.fnGetFGroupParent(mt.GroupGuid) = @GroupGuid)
		LEFT JOIN co000 CO ON CO.GUID = bi.CostGUID
	 WHERE 
		(FM.GUID =  @FormGuid OR @FormGuid = 0x0)
		AND (bi.CostGUID =  @CostGuid OR @CostGuid = 0x0)
		AND (MN.Number =  @ManfNumber OR @ManfNumber =  0x0)
		AND (MN.[Date] BETWEEN @StartDate AND @EndDate
		   OR (@StartDate = @EndDate AND @StartDate = '1/1/1980'));
	
	EXEC prcCheckSecurity null, 0, 0, '#MainResult'

	CREATE TABLE #MatDeviationinfo(
		MatGuid uniqueidentifier , 
		MnGuid uniqueidentifier , 
		FormGUID uniqueidentifier , 
		CostGuid uniqueidentifier , 
		MnNUmber int, 
		MnDate datetime, 
		FmName NVARCHAR(250) , 
		CostName NVARCHAR(250), 
		MatName NVARCHAR(250),
		MatUnitName NVARCHAR(250),
		StanderQty float, 
		ActualQty float, 
		StanderPrice float, 
		ActualPrice float);

		
	--„⁄«·Ã… „Ã„Ê⁄… «·„Ê«œ «·„ÊÃÊœ »œÊ‰ «·»œ«∆·   
	INSERT INTO #MatDeviationinfo
	SELECT 
		M.MatGuid, 
		M.MnGuid,
		M.FormGUID, 
		M.CostGuid, 
		M.MnNUmber, 
		M.MnDate, 
		M.FmName, 
		M.CostName, 
		M.MatName, 
		M.MatUnitName, 
		dbo.fnGetMatQtyWithUnit(MI.MatGUID, MI.Qty, MI.Unity, @Unit) * M.MNQty,
		dbo.fnGetMatQtyWithUnit(M.MatGUID, M.biQty, M.biUnit, @Unit), 
		dbo.fnGetMatPriceWithUnit(mi.MatGUID, mi.Price, mi.Unity, @Unit), 
		dbo.fnGetMatPriceWithUnit(M.MatGUID, M.BIPrice, M.biUnit, @Unit)
	  FROM
		#MainResult M
		INNER JOIN mi000 MI ON MI.MatGUID = M.MatGUID
		  AND MI.ParentGUID = ( 
				SELECT GUID
				  FROM MN000
				  WHERE FormGUID
						= 
						M.FormGUID
					AND type = 0)
					

              
	
-- „⁄«·Ã… «·»œ«∆·
	INSERT INTO #MatDeviationinfo
	SELECT DISTINCT 
		M.MatGuid, 
		M.MnGuid,
		M.FormGUID, 
		M.CostGuid, 
		M.MnNUmber, 
		M.MnDate, 
		M.FmName, 
		M.CostName, 
		M.MatName, 
		M.MatUnitName, 
		dbo.fnGetMatQtyWithUnit(M.MatGUID, dbo.fnGetAltMatQty(M.MatGUID, M.MNGuid, M.FormGUID), M.BIUnit, @Unit) * M.MNQty, 
		dbo.fnGetMatQtyWithUnit(M.MatGUID, M.biQty, M.biUnit, @Unit), 
		dbo.fnGetMatPriceWithUnit(M.MatGUID, dbo.fnGetAltMatPrice(M.MatGUID), M.biUnit, @Unit),
		dbo.fnGetMatPriceWithUnit(M.MatGUID, M.biPrice, M.biUnit, @Unit)
	  FROM
	    #MainResult M
	    INNER JOIN AlternativeMatsItems000 Altmat ON Altmat.MatGuid = M.MatGuid
		 INNER JOIN mi000 MI ON MI.MatGUID = M.MatGUID 
	  	WHERE M.MatGuid NOT IN(  
                             SELECT MatGUID 
                               FROM MI000 
                               WHERE ParentGUID 
                                     =  
                                     (  
                             SELECT GUID 
                               FROM MN000 
                               WHERE FormGUID 
                                     =  
                                     M.FormGUID 
                                 AND type = 0 
                                     ) 
                           ) 
    
	IF @GroupBy = 0
		BEGIN
			SELECT FinalRes.MnNUmber MnNUmber , 
				   FinalRes.MnGuid MnGuid,
				   FinalRes.MnDate MnDate , 
				   FinalRes.FmName FormName , 
				   ISNULL( FinalRes.CostName , ''
						 )CostName , 
				   FinalRes.MatName , 
				   FinalRes.MatUnitName , 
				   FinalRes.STANDERQTY StanderQty , 
				   FinalRes.ActualQTY ActualQty , 
				   FinalRes.STANDERPRICE StanderPrice , 
				   FinalRes.ACTUALPRICE ActualPrice
			  FROM #MatDeviationinfo FinalRes

			  ORDER BY CASE
					   WHEN @OrderBy = 0 THEN FinalRes.MnNUmber
					   END , CASE
							 WHEN @OrderBy = 1 THEN FinalRes.MnDate
							 END , CASE
								   WHEN @OrderBy = 2 THEN FinalRes.FmName
								   END , CASE
										 WHEN @OrderBy = 3 THEN FinalRes.MatName
										 END ,CASE
											 WHEN @OrderBy = 4 THEN FinalRes.CostName
											 END , FinalRes.MatName
										 
										 END 

			 
	ELSE
		BEGIN
			SELECT CASE
				   WHEN @GroupBy = 1 THEN FinalRes.FmName
				   END FormName , 
					CASE
					 WHEN @GroupBy <> 3 THEN ISNULL( FinalRes.CostName , '') END CostName , 
				   FinalRes.MatName , 
				   FinalRes.MatUnitName , 
				   SUM( FinalRes.StanderQty
					  )StanderQty , 
				   SUM( FinalRes.ActualQty
					  )ActualQTY , 
				   SUM( FinalRes.StanderPrice
					  )StanderPrice , 
				   SUM( FinalRes.ActualPrice
					  )ActualPrice
			  FROM #MatDeviationinfo FinalRes
			  GROUP BY 
					   FinalRes.MatGuid, 
					   CASE
					   WHEN @GroupBy = 1 THEN FinalRes.FormGUID
					   END ,  
					   CASE
					   WHEN @GroupBy = 1 THEN FinalRes.FmName
					   END , 
					   CASE
					   WHEN @GroupBy <> 3 THEN  FinalRes.CostGuid
					   END,
					   CASE
					   WHEN @GroupBy <> 3 THEN ISNULL( FinalRes.CostName , '')
					   END  ,
					   FinalRes.MatName ,  
					   FinalRes.MatUnitName
			    ORDER BY CASE @OrderBy
					   WHEN 2 THEN CASE
								   WHEN @GroupBy = 1 THEN FinalRes.FmName
								   END
					   WHEN 3 THEN FinalRes.MatName
					   END,
					   CASE
					   WHEN @GroupBy <> 3 THEN ISNULL( FinalRes.CostName , '')
					   END ,
					   FinalRes.MatName
					  
		END
################################################################################
#END
