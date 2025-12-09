BEGIN TRANSACTION;

-- DECLARE @XML XML, @EventId INT, @BusinessKey VARCHAR(100) = 'IAPE_EDUC14022025R285740', @Year INT = 2025, @Month INT = 11, @StatusEnum INT = 7;
-- DECLARE @XML XML, @EventId INT, @BusinessKey VARCHAR(100) = 'IAPE_EDUC09012024R813121', @Year INT = 2025, @Month INT = 11, @StatusEnum INT = 7;
-- DECLARE @XML XML, @EventId INT, @BusinessKey VARCHAR(100) = 'IAPE_EDUC04102024R235915', @Year INT = 2025, @Month INT = 11, @StatusEnum INT = 7;
-- DECLARE @XML XML, @EventId INT, @BusinessKey VARCHAR(100) = 'IAPE_EDUC03112020R084648', @Year INT = 2025, @Month INT = 11, @StatusEnum INT = 7;
DECLARE @XML XML, @EventId INT, @BusinessKey VARCHAR(100) = 'IAPE_EDUC05052023R392734', @Year INT = 2025, @Month INT = 11, @StatusEnum INT = 7;

SELECT @XML = TRY_CAST(c.Content AS XML), @EventId = e.Id
FROM Event e
JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0
WHERE e.BusinessKey = @BusinessKey
    AND e.EventTypeEnum = 8 
    AND e.RelatedYear = @Year
    AND e.RelatedMonth = @Month
    AND e.EventStatusEnum = @StatusEnum;

SET @XML.modify('
        delete /eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/*/descFolha[position() > 1]
    ');

SELECT @XML;

UPDATE c
SET c.Content = TRY_CAST(@XML AS VARCHAR(MAX))
FROM Event e
JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0
WHERE e.BusinessKey = @BusinessKey
    AND e.EventTypeEnum = 8 
    AND e.RelatedYear = @Year
    AND e.RelatedMonth = @Month
    AND e.EventStatusEnum = @StatusEnum;

DELETE XMLContent WHERE ReferenceId = @EventId AND ContentReferenceEnum <> 0

UPDATE Event SET EventStatusEnum = 0 WHERE Id = @EventId;

ROLLBACK;