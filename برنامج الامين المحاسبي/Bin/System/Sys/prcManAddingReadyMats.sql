########################################################
CREATE PROCEDURE prcAddingReadyMats
	@Guid 				[UNIQUEIDENTIFIER],   
	@MatGuid 			[UNIQUEIDENTIFIER],   
	@Unity 				[INT],   
	@Qty1 				[FLOAT],   
	@Qty2 				[FLOAT],   
	@Qty3 				[FLOAT], 
	@Price 				[FLOAT],   
	@StoreGuid 			[UNIQUEIDENTIFIER],   
	@ParentForm			[UNIQUEIDENTIFIER], 
	@Note				[NVARCHAR](256),
	@DivPercent			[FLOAT],
	@DivPercentType		[INT]
AS
	INSERT INTO ManManafucturedMats000 VALUES
             ( 
				@Guid,
			    @MatGuid,
			    @Unity,
				@Qty1,
				@Qty2,
				@Qty3,
				@Price,
				@StoreGuid,
				@ParentForm,
				@Note,
				@DivPercent,
				@DivPercentType 
			  )
#########################################################	                      
#END			  