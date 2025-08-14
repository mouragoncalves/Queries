DECLARE @EventTypeEnum INT, @EventId INT = 0;
SELECT @EventTypeEnum = EventTypeEnum FROM Event WHERE Id = @EventId AND EventStatusEnum = 7
IF(@EventTypeEnum IS NOT NULL)
BEGIN
    IF(@EventTypeEnum = 8)
    BEGIN
        EXEC sp_ProcessarEventosXML @EventIds = @EventId
    END
    DELETE XMLContent WHERE ReferenceId = @EventId AND ContentReferenceEnum <> 0
    UPDATE Event SET EventStatusEnum = 0 WHERE Id = @EventId
END