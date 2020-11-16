########################
CREATE PROCEDURE prcGetMaxMinAnalysis
	@ItemGuid	UNIQUEIDENTIFIER,
	@OrderGUID  UNIQUEIDENTIFIER
AS
SET NOCOUNT ON 
select dbo.fnHosGetUnitMaxMinAnalysis ( @ItemGuid, @OrderGUID, 2, GetDAte()) AS MaxAnal , dbo.fnHosGetUnitMaxMinAnalysis( @ItemGuid, @OrderGUID, 3, GetDAte()) AS MinAnal

/*

exec prcGetMaxMinAnalysis
'C9435361-CD78-4187-BE38-F7216BF5A8A6',
'3062FBBA-63F3-4D27-9DAC-8B4FC3D56FDB'

*/
###########################
#END