##########################################################################
CREATE PROC prcDistInitDiscDetailOfDistributor
		@DistributorGUID uniqueidentifier
AS
	SET NOCOUNT ON       
	DELETE DistDeviceDiscDetail000 WHERE DistributorGUID = @DistributorGUID  
	DELETE DistDeviceCtd000 WHERE DistributorGuid = @DistributorGuid AND ObjectType = 1 -- Discounts 
	---------------------------------  
	DECLARE    
		@DiscCursor		CURSOR,  
		@templateGUID	[UNIQUEIDENTIFIER],   
		@MatCondGuid	[UNIQUEIDENTIFIER],   
		@grGUID			[UNIQUEIDENTIFIER],   
		@mtGUID			[UNIQUEIDENTIFIER],   
		@dGUID			[UNIQUEIDENTIFIER]    
	
	CREATE TABLE #MatCond ([MatGuid] uniqueidentifier, [Security] INT)
		
	SET @DiscCursor = CURSOR FAST_FORWARD FOR    
	SELECT 
		[Guid], 
		[GroupGuid], 
		[MatGuid], 
		[MatTemplateGuid], 
		[MatCondGuid] 
	FROM 
		DistDisc000
	--WHERE 
		--CalcType = 3 OR CalcType = 4  
	
	OPEN @DiscCursor 
	
	FETCH FROM @DiscCursor INTO @dGuid, @grGUID, @mtGUID, @templateGuid, @MatCondGuid
	
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		IF ISNULL(@grGUID, 0x0) <> 0x0  --  ÕœÌœ „Ã„Ê⁄… «·Õ”„
		BEGIN
			--print '1'
			INSERT INTO DistDeviceDiscDetail000(DistributorGUID, DiscGUID, MatGUID, MatTemplateGuid) 
			SELECT @DistributorGUID, @dGuid, mtGuid, @templateGuid FROM fnGetMatsOfGroups (@GrGuid)  
		END
		ELSE IF ISNULL(@mtGuid, 0x0) <> 0x0  --  ÕœÌœ „«œ… «·Õ”„
		BEGIN
			--print '2'
			INSERT INTO DistDeviceDiscDetail000
			(DistributorGUID, DiscGUID, MatGUID, MatTemplateGuid) 
			VALUES 
			(@DistributorGUID, @dGuid, @mtGuid, @templateGuid)  
		END
		ELSE IF ISNULL(@MatCondGuid, 0x0) <> 0x0  --  ÕœÌœ ‘—ÿ „Ê«œ «·Õ”„
		BEGIN			
			--print '3'
			DELETE #MatCond 
			
			INSERT INTO #MatCond EXEC PrcGetMatsList 0x0, 0x0, -1, @MatCondGuid
			
			INSERT INTO DistDeviceDiscDetail000(DistributorGUID, DiscGUID, MatGUID, MatTemplateGuid) 
			SELECT @DistributorGUID, @dGuid, MatGuid, @templateGuid FROM  #MatCond
		END
		
		FETCH FROM @DiscCursor INTO @dGUID, @grGuid, @mtGUID, @templateGuid , @MatCondGuid
	END
	
	CLOSE @DiscCursor 
	DEALLOCATE @DiscCursor  		   
	---------------------------------  
	INSERT INTO DistDeviceCtd000( 
		DistributorGUID, 
		ParentGUID, 
		Number, 
		ObjectGUID, 
		ObjectType	-- ! For Discount	2 For Promotions 
	) 
	SELECT 
		@DistributorGUID, 
		DistCtd000.ParentGUID, 
		Number, 
		DiscountGUID, 
		1	-- Discounts 
	FROM  
		DistCtd000
		INNER JOIN DistDiscDistributor000 ON DistCtd000.DiscountGUID=DistDiscDistributor000.ParentGUID
		WHERE DistDiscDistributor000.DistGuid=@DistributorGUID and DistDiscDistributor000.Value=1

##########################################################################
##END