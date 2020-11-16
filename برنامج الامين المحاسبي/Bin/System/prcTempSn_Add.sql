#########################################################
CREATE PROCEDURE prcTempSn_Add
	@Id [INT],
	@guid [UNIQUEIDENTIFIER],
	@sn [NVARCHAR](100),
	@MatGUID [UNIQUEIDENTIFIER],
	@StGUID [UNIQUEIDENTIFIER],
	@biGUID [UNIQUEIDENTIFIER]

AS 
	SET NOCOUNT ON 

	INSERT INTO [TempSn](
		[ID], 
		[Guid], 
		[SN], 
		[MatGuid], 
		[stGuid], 
		[biGuid])
	VALUES( 
		@Id,
		@guid,
		@sn,
		@MatGUID,
		@StGUID,
		@biGUID)

#########################################################
#END