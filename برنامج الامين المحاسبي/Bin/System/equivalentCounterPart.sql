CREATE PROC UpdateEquivalentCounterPart(@currentRowGuid  UNIQUEIDENTIFIER,  @NewEquivalent  UNIQUEIDENTIFIER)
AS
BEGIN
DECLARE @RowGuid UNIQUEIDENTIFIER
,@CounterPartGuid UNIQUEIDENTIFIER
,@MatGuid UNIQUEIDENTIFIER
,@EquivalentGuid UNIQUEIDENTIFIER



	SELECT @MatGuid = matguid, @EquivalentGuid = EquivalentGuid FROM drugequivalents000 WHERE GUID = @currentRowGuid 
	SELECT @CounterPartGuid = GUID FROM drugequivalents000 WHERE matguid = @EquivalentGuid  and equivalentGuid =@MatGuid

	UPDATE drugequivalents000
	SET 
	matguid = @NewEquivalent
	,equivalentGuid = @MatGuid 
	WHERE GUID = @CounterPartGuid

	UPDATE drugequivalents000
	SET 
	equivalentGuid = @NewEquivalent
	WHERE GUID = @currentRowGuid

END