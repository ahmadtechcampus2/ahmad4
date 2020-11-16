###############################################################################
CREATE PROC prcSO_GetBillContracts
	@BillDate			DATETIME,
	@BillTypeGuid		UNIQUEIDENTIFIER,
	@BillCostGuid		UNIQUEIDENTIFIER,
	@BillCustGuid		UNIQUEIDENTIFIER,
	@BillAccGuid		UNIQUEIDENTIFIER
AS
	-- Check if there are any contract offers may be applied on the bill
	-- 
	SET NOCOUNT ON

	CREATE TABLE #BillOffers(SOGuid	UNIQUEIDENTIFIER)
	IF ISNULL(@BillCustGuid, 0x0) = 0x0
	BEGIN 
		SELECT * FROM #BillOffers
		RETURN 
	END

	DECLARE @CustAccGUID UNIQUEIDENTIFIER 
	SET @CustAccGUID = ISNULL((SELECT AccountGUID FROM cu000 WHERE [GUID] = @BillCustGuid), 0x0)
	IF ISNULL(@CustAccGUID, 0x0) = 0x0
	BEGIN 
		SELECT * FROM #BillOffers
		RETURN 
	END 

	DECLARE @C					CURSOR,
			@SOGuid				UNIQUEIDENTIFIER,
			@SOAccountGuid		UNIQUEIDENTIFIER,
			@SOCustCondGuid		UNIQUEIDENTIFIER,
			@IsFound			BIT
	
			
	SET @C = CURSOR FAST_FORWARD FOR
		SELECT DISTINCT 
			so.Guid, AccountGuid, CustCondGuid
		FROM
			vwSpecialOffers	AS so
			-- INNER JOIN SOItems000 soi ON so.[GUID] = soi.SpecialOfferGUID
			LEFT JOIN SOBillTypes000		AS bt ON bt.SpecialOfferGuid = so.Guid
		WHERE 
			so.Type = 3			
			AND
			so.IsActive = 1		
			AND
			(@BillDate BETWEEN StartDate AND EndDate)		
			AND
			(so.IsAllBillTypes = 1 OR ISNULL(bt.BillTypeGuid, 0x00) = @BillTypeGuid)	
			AND
			(so.CostGuid = 0x00 OR CostGuid = @BillCostGuid)							
	
	OPEN @C FETCH FROM @C INTO @SOGuid, @SOAccountGuid, @SOCustCondGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @IsFound = 0
		
		IF @SOCustCondGuid <> 0x00
			EXEC @IsFound = prcIsCustCondVerified @SOCustCondGuid, @BillCustGuid
		ELSE IF @SOAccountGuid <> 0x00
		BEGIN
			IF @SOAccountGuid = @CustAccGUID
				SET @IsFound = 1
			ELSE 
				IF @SOAccountGuid = (SELECT ParentGUID FROM ac000 WHERE guid = @CustAccGUID)
					SET @IsFound = 1
				ELSE IF EXISTS(SELECT [GUID] FROM [dbo].[fnGetAccountsList](@SOAccountGuid, DEFAULT) WHERE Guid = @CustAccGUID)
					SET @IsFound = 1 
		END  
		ELSE
			SET @IsFound = 1 
			
		IF @IsFound = 1
			INSERT INTO #BillOffers( SOGuid) VALUES (@SOGuid)
		
		FETCH FROM @C INTO @SOGuid, @SOAccountGuid, @SOCustCondGuid		
	END
	CLOSE @C DEALLOCATE @C				
	
	SELECT * FROM #BillOffers

/*
EXEC prcConnections_Add2 '„œÌ—'
EXEC prcSO_GetBillContracts '03-05-2011', 'ECDD9382-1BFA-42E2-8616-FBA223989577', 0x00, 'D37EF9BF-E83E-4001-94E6-0FE76F62E0AA', 0x00
*/

################################################################################
#END
