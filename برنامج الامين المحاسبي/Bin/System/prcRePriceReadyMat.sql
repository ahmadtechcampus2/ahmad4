#########################################################
CREATE PROCEDURE  prcRePriceReadyMat
(
    @MatGuid		UNIQUEIDENTIFIER = 0x0,
    @RawGroupGuid	UNIQUEIDENTIFIER = 0x0 ,
    @CostCenter		UNIQUEIDENTIFIER = 0x0,
    @PriceType		INT = 0
)
AS
SET NOCOUNT ON   

SELECT   Fm.Guid  AS FormGuid , Mn.Guid as MNFormGuid , fm.Number AS FormNumber, mn.OutCostGuid as CostCenter
	INTO #Forms
	FROM FM000 fm INNER JOIN MN000 MN ON MN.FormGuid = fm.Guid AND mn.Type =0 
	GROUP BY fm.Guid , fm.Number , Mn.Guid , mn.OutCostGuid
	ORDER BY fm.Number 


			
	  UPDATE MI000 
	  SET Price = ( 
		SELECT ISNULL((CASE @PriceType WHEN 0 THEN [mt].AvgPrice * mi000.CurrencyVal
									 WHEN 1 THEN [mt].LastPrice * mi000.CurrencyVal
													END), 0)
		 FROM 
			 mt000 mt 
				WHERE mt.Guid = mi000.MatGuid 	
			)   
	  WHERE  MI000.Type =1 
			AND
			(
				(@RawGroupGuid in ( SELECT  mt.GroupGuid FROM MT000 mt WHERE mt.Guid = mi000.MatGuid))
			 OR (@RawGroupGuid in (SELECT gr.ParentGuid FROM GR000 gr INNER JOIN MT000  mt on mt.GroupGuid = gr.Guid 
							WHERE mt.Guid = mi000.MatGuid ))
			 OR  @RawGroupGuid = 0x0
			 )
			 AND
			  (	
				@MatGuid = mi000.MatGuid  
			 OR
				@MatGuid = 0x0 
			  )
			 AND 
			 ( @CostCenter in (SELECT ff.CostCenter FROM #Forms ff WHERE ff.MNFormGuid = MI000.ParentGuid   )
				OR 
				@CostCenter in (SELECT co.ParentGuid 
									FROM co000 co INNER JOIN #Forms ff ON ff.CostCenter = co.Guid OR ff.CostCenter = co.ParentGuid
									WHERE ff.MNFormGuid = MI000.ParentGuid )
				OR @CostCenter = 0x0
			 ) 
#########################################################
#END