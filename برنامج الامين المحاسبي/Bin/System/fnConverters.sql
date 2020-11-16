#########################################################
CREATE FUNCTION TryConvertUniqueidentifier
(
  @value nvarchar(4000)
)
RETURNS uniqueidentifier
AS
BEGIN
  RETURN (SELECT CONVERT(uniqueidentifier,
    CASE WHEN LEN(@value) = 36 THEN
    CASE WHEN @value LIKE
       '[A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
    +  '[A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
    + '-[A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
    + '-[A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
    + '-[A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
    + '-[A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
    +  '[A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
    +  '[A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
    THEN @value END
    END)
  );
END
#########################################################
#END