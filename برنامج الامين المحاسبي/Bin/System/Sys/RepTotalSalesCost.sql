########################################################
CREATE PROC RepTotalSalesCost
		 @RawMatsAccGuid					UNIQUEIDENTIFIER = 0x0
		,@IndustrialCostAccGuid				UNIQUEIDENTIFIER = 0x0 
		,@SalesCostAccGuid					UNIQUEIDENTIFIER = 0x0 
		,@CostCenter						UNIQUEIDENTIFIER = 0x0 
		,@GroupGuid							UNIQUEIDENTIFIER = 0x0  
		,@number							INT
		,@CurrencyGuid						UNIQUEIDENTIFIER = 0x0 
		,@RepSrcs							UNIQUEIDENTIFIER = 0x0 
		,@CurVal							FLOAT
		,@FromDate							DATETIME		 = '1-1-1980'
		,@ToDate							DATETIME		 = '1-1-2100'
		,@IndustrialCostDistributionType	INT				 = 0
		,@SalesCostDistributionType			INT				 = 0
	AS 
BEGIN
	SET NOCOUNT ON  
	DECLARE @ISNUMERIC [BIT]
	SET @ISNUMERIC = 1
	

CREATE TABLE #T (
	MatGuid UNIQUEIDENTIFIER,	
	Name	NVARCHAR(50),
	Qty	    float,
	QtyFirstUnit float,
	uint	NVARCHAR(100),
	Value	float,
	SumQty	float,
	AvgQty	float
	)
		
insert into #t
	(	MatGuid,
		Name,
		Qty,
		QtyFirstUnit,
		uint,
		Value,
		Sumqty,
		AvgQty
	) 

	
select	
		MT.GUID,
		Mt.Name,
		ISNull ( (SUM( BI.QTY  /( CASE 
                            WHEN @number = 1 OR 
							(@number= 3 AND Mt.DefUnit = 2) THEN 
							CASE Mt.Unit2Fact 
							WHEN 0 THEN 1 
							ELSE Mt.Unit2Fact end
                            WHEN @number = 2 OR (@number= 3 AND Mt.DefUnit = 3) THEN 
							CASE Mt.Unit3Fact WHEN 0 THEN 1 ELSE Mt.Unit3Fact end
                            ELSE 1
						END  
						) * CASE BT.BILLTYPE  WHEN 3 THEN 1 Else -1 END)*-1
			), 0 )  as ProductedQty ,

			ISNull ( (SUM( BI.QTY  * CASE BT.BILLTYPE  WHEN 3 THEN 1 Else -1 END)*-1), 0 ) as ProductedQtyFirstUnit ,
	
		      CASE 
                       WHEN @number = 1  THEN  Mt.Unit2
                       WHEN @number = 2  THEN  Mt.Unit3 
                       ELSE Mt.Unity
			END ,         
		SUM( CASE BT.BILLTYPE
				   WHEN 1 THEN BI.QTY * Bi.Price
				   WHEN 3 THEN -BI.QTY * Bi.Price
			  ELSE 0 END) as    ProductedPrice
	   ,isnull((select ( SUM(EN.Debit) - SUM(EN.Credit))/@CurVal 
				from 
					en000 En
				where 
					(AccountGuid in ( SELECT Guid FROM fnGetAccountsList(@SalesCostAccGuid, 0))
					AND (ISNULL(@CostCenter, 0x0) = 0x0 )
					OR (CostGUID in (SELECT Guid FROM [dbo].[fnGetCostsList](@CostCenter)))
					
					AND (En.Date >= @FromDate )
					AND (En.Date <= @ToDate ))),0) 
           ,MT.AvgPrice
from 
		Bu000 Bu  INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid 
			 INNER JOIN Bi000 Bi ON Bi.ParentGuid = Bu.Guid
			 INNER JOIN Mt000 Mt ON Mt.Guid = Bi.MatGuid
		inner join gr000 gr on  Mt.GroupGuid =gr.GUID
			 INNER JOIN RepSrcs rs ON rs.idType = bu.TypeGUID 
		inner join my000 my on bu.CurrencyGUID =my.GUID
					WHERE
		idTbl = @RepSrcs
		AND BU.DATE <= @ToDate
		AND BU.DATE >= @FromDate
		AND (ISNULL(@GroupGuid, 0x0) = 0x0 OR GroupGuid IN (SELECT Guid FROM fnGetGroupsList(@GroupGuid)))
		AND (ISNULL(@CostCenter, 0x0) = 0x0 
		OR CASE bi.CostGuid WHEN 0x0 then bu.CostGUID 
		ELSE  bi.CostGuid 
		END
		in  (SELECT Guid FROM [dbo].[fnGetCostsList](@CostCenter))
		
			  )
		
group by 
		Mt.Name,
		MT.GUID,
		MT.AvgPrice,
		Mt.Unity,Mt.Unit3 ,Mt.Unit2


declare @a int 
select  @a= sum(Qty)
from	#t


Create Table #result
( 	MatGuid UNIQUEIDENTIFIER,	
	Name	NVARCHAR(50),
	Qty		float,
	QtyFirstUnit float,  
	Unit	NVARCHAR(100),
	Value	float,
	SumDC	float,
	Sumqty  float,
	SumDistrubtionFld float,
	SumQtyFirstUnit float,
	AvgQty	float,
	dis		float,
	IsNum   [BIT]
	)



insert into #result (MatGuid, Name, Qty,QtyFirstUnit, Unit, Value, SumDC,Sumqty, AvgQty, dis)
select 
	 MatGuid,
	 t.Name,
	 t.Qty,
	 t.QtyFirstUnit,
	 t.Uint,
	 Value,
	 Sumqty,
	 @a  as SumDC,
	
	
	-- Sum(Value) as SumDistrubtionFld,
	 AvgQty,
	 CASE @SalesCostDistributionType
		  WHEN 0 then t.Qty
		  WHEN 1 then Value
		  WHEN 2 THEN case isnumeric(Mt.Whole)
							when 1 then avg(Mt.Whole)*t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 3 THEN  case isnumeric(Mt.Half)
							when 1 then avg(Mt.Half) *t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 4 THEN case  isnumeric(Mt.Vendor)
						when 1 then avg(Mt.Vendor)	*t.Qty
						when 0 then (SELECT IsNum=0 FROM #result)
						 end 
		  WHEN 5 THEN case isnumeric(Mt.Export)
							when 1 then avg(Mt.Export) *t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 6 THEN  case isnumeric(Mt.Retail) 
						when 1 then avg(Mt.Retail) *t.Qty
						when 0 then (SELECT IsNum=0 FROM #result)
					   end
		  WHEN 7 THEN  case isnumeric (Mt.EndUser)
							when 1 then avg(Mt.EndUser)*t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 8 THEN  case isnumeric (Mt.Dim )
							when 1 then  Mt.Dim *t.Qty
								when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 9 THEN  case isnumeric (Mt.Origin )
		  					when 1 then Mt.Origin*t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 10 THEN  case isnumeric( Mt.Pos )
		  					when 1 then Mt.Pos*t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 11 THEN  case isnumeric( Mt.Company )
		  					when 1 then Mt.Company *t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 12 THEN  case isnumeric( Mt.Color )
		  					when 1 then  Mt.Color*t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 13 THEN  case isnumeric( Mt.Provenance )
		  					when 1 then  Mt.Provenance*t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 14 THEN  case isnumeric (Mt.Quality )
		  					when 1 then Mt.Quality*t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  WHEN 15 THEN  case isnumeric (Mt.Model)
		  					when 1 then Mt.Model*t.Qty
							when 0 then (SELECT IsNum=0 FROM #result)
						end
		  ELSE 0 END 
	
from #t t inner join mt000 Mt on
t.MatGuid=MT.GUID
GROUP BY 
	 MatGuid,
	 t.Name,
	 t.Qty,
	 t.QtyFirstUnit,
	 t.Uint,
	 Value,
	 Sumqty,
	 --SumQtyFirstUnit,
	  AvgQty,
	  Mt.Whole,Value,Mt.Half,Mt.Vendor,Mt.Export,Mt.Retail,Mt.EndUser,Mt.Dim,Mt.Origin,Mt.Company,Mt.Pos,Mt.Provenance
	 ,Mt.Quality,Mt.Model,Mt.Color
	
	

	UPDATE #result 
	SET dis = 0
	FROM #result res
	WHERE (ISNULL(res.dis, 0 ) = 0 AND @SalesCostDistributionType >= 2 )
	
	UPDATE #result 
	SET IsNum = 0
	FROM #result res
	WHERE (dis = 0 AND @SalesCostDistributionType >= 2) 
	
	UPDATE #result 
    SET IsNum = 1
	FROM #result res
	WHERE @SalesCostDistributionType = 0 OR  @SalesCostDistributionType = 1
	OR (ISNULL(res.dis, 0 ) <> 0 AND @SalesCostDistributionType >= 2 )
	
	
UPDATE #result 
SET SumDistrubtionFld  =( SELECT SUM(dis) FROM #result)
			
	
UPDATE #result 
SET SumQtyFirstUnit  =( SELECT SUM(QtyFirstUnit) FROM #result) 
	
select * from #result
END
	/*UPDATE #Result SET IndustrialDistributionPer = d.IndustrialDistributionPer
						, MatsCosts = d.MatsCosts
						, MatUnitPrice = d.MatUnitPrice
						, IndustrialCosts = d.IndustrialCosts
						, IndustrialUnitCost = d.IndustrialUnitCost
						, TotalIndustrialCost = d.TotalIndustrialCost
						, ProductionUnitPrice = d.ProductionUnitPrice
						, SalesDistributionPer = d.SalesDistributionPer
						, SalesCost = d.SalesCost
						, SalesUnitCost = d.SalesUnitCost
						, UnitTotalCost = d.SalesUnitCost + d.IndustrialUnitCost + d.MatUnitPrice
						, SalesTotalCost = (d.SalesUnitCost + d.IndustrialUnitCost + d.MatUnitPrice) * d.SalesQty
						, Profit = d.SalesPrice - ((d.SalesUnitCost + d.IndustrialUnitCost + d.MatUnitPrice) * d.SalesQty)
	FROM #Result r INNER JOIN 
	(
		SELECT c.Guid, c.IndustrialDistributionPer, c.MatsCosts, c.IndustrialCosts, c.MatUnitPrice, c.IndustrialUnitCost, c.TotalIndustrialCost, c.ProductionUnitPrice, c.SalesDistributionPer SalesDistributionPer
		, c.SalesCost SalesCost
		, CASE WHEN (SELECT SUM(SalesQty) FROM #Result) = 0 THEN 0 ELSE c.SalesCost / (SELECT SUM(SalesQty) FROM #Result) END SalesUnitCost
		, c.SalesQty SalesQty
		, c.SalesPrice SalesPrice
		FROM
		(
			SELECT b.Guid, b.IndustrialDistributionPer, b.MatsCosts, b.IndustrialCosts, CASE ProductedQty WHEN 0 THEN 0 ELSE MatsCosts / ProductedQty END MatUnitPrice
				   , CASE WHEN ProductedQty = 0 THEN 0 ELSE IndustrialCosts / ProductedQty END IndustrialUnitCost
				   , MatsCosts + IndustrialCosts TotalIndustrialCost
				   , CASE WHEN ProductedQty = 0 THEN 0 ELSE (MatsCosts + IndustrialCosts) / ProductedQty END ProductionUnitPrice
				   , b.SalesDistributionPer SalesDistributionPer
				   , @SalesCostAccBalance * b.SalesDistributionPer SalesCost
				   , b.SalesQty SalesQty
				   , b.SalesPrice SalesPrice
			FROM 
			(
				SELECT a.Guid, a.IndustrialDistributionPer, a.ProductedQty, @RawMatsAccBalance * a.IndustrialDistributionPer MatsCosts, @IndustrialCostAccBalance * IndustrialDistributionPer IndustrialCosts, a.SalesDistributionPer SalesDistributionPer, a.SalesQty SalesQty, a.SalesPrice SalesPrice
				FROM
				(
					SELECT Guid, ProductedQty, CASE @IndustrialCostDistributionType WHEN 0 THEN ProductedQty / (SELECT SUM(ProductedQty) FROM #Result) WHEN 1 THEN ProductedPrice / (SELECT SUM(ProductedPrice) FROM #Result) ELSE CASE WHEN (SELECT SUM(ProductedQty * IndustrialCostDistributionVal) FROM #Result)=0 THEN 0 ELSE ProductedQty * IndustrialCostDistributionVal / (SELECT SUM(ProductedQty * IndustrialCostDistributionVal) FROM #Result)END END IndustrialDistributionPer
						   , CASE @SalesCostDistributionType WHEN 0 THEN CASE WHEN (SELECT SUM(SalesQty) FROM #Result) = 0 THEN 0 ELSE SalesQty / (SELECT SUM(SalesQty) FROM #Result) END WHEN 1 THEN CASE WHEN (SELECT SUM(SalesPrice) FROM #Result) = 0 THEN 0 ELSE SalesPrice / (SELECT SUM(SalesPrice) FROM #Result) END ELSE CASE WHEN ( SELECT SUM(SalesCostDistributionVal * SalesQty) FROM #Result) = 0 THEN 0 ELSE SalesCostDistributionVal * SalesQty / ( SELECT SUM(SalesCostDistributionVal * SalesQty) FROM #Result) END END SalesDistributionPer
						   , SalesQty
						   , SalesPrice
					FROM #Result
				)a
			)b 
		)c
	)d ON d.Guid = r.Guid
	UPDATE #Result SET MatUnitPricePer = CASE WHEN (SELECT SUM(MatUnitPrice) FROM #Result)= 0 THEN 0 ELSE MatUnitPrice * 100 / (SELECT SUM(MatUnitPrice) FROM #Result)END
					   ,IndustrialUnitCostPer = CASE WHEN (SELECT SUM(IndustrialUnitCost) FROM #Result) = 0 THEN 0 ELSE IndustrialUnitCost * 100 / (SELECT SUM(IndustrialUnitCost) FROM #Result) END
					   ,SalesUnitCostPer = CASE WHEN ( SELECT SUM(SalesUnitCost) FROM #Result ) = 0 THEN 0 ELSE SalesUnitCost * 100 / ( SELECT SUM(SalesUnitCost) FROM #Result ) END
					   ,ProfitPer = CASE WHEN SalesTotalCost = 0 THEN 0 ELSE (Profit / SalesTotalCost)*100 END
	SELECT * FROM #Result
	*/
########################################################
#END    