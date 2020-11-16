CREATE PROCEDURE CopyDrugCompositions 
@MaterialGuid UNIQUEIDENTIFIER
AS 

DECLARE @str NVARCHAR(MAX);
SELECT @str = spec FROM mt000 WHERE GUID = @MaterialGuid
SELECT * FROM fnString_Split(@str,CHAR(13))