#########################################################
CREATE PROCEDURE prcAddingRawMats
	@Guid 				[UNIQUEIDENTIFIER],   
	@MatGuid 			[UNIQUEIDENTIFIER],   
	@Unity 				[INT],   
	@Qty1 				[FLOAT],   
	@Qty2 				[FLOAT],   
	@Qty3 				[FLOAT], 
	@Price 				[FLOAT],   
	@StoreGuid 			[UNIQUEIDENTIFIER],   
	@ParentForm		[UNIQUEIDENTIFIER], 
	@IsUsed 			[INT],
	@GroupingNumber		[INT],
	@Note				[NVARCHAR](256)
AS
INSERT INTO Man_Form_RawMat000 VALUES
             (  @Guid,
			    @MatGuid,
			    @Unity,
				@Qty1,
				@Qty2,
				@Qty3,
				@Price,
				@StoreGuid,
				@ParentForm,
				@IsUsed,
				@GroupingNumber,
				@Note 
			  )
#########################################################	                      
#END