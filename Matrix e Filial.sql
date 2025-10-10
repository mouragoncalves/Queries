DECLARE @MainEntityCode VARCHAR(40) = '101122', @Year INT = 2025, @Month INT = 6, 
    @LegalEntityDocument VARCHAR(40);

SELECT top 1 @LegalEntityDocument = LegalEntityDocument
FROM Event
WHERE EntityCode = @MainEntityCode
    AND EventTypeEnum = 1
    AND EventStatusEnum = 6
ORDER BY ClientReceivedDate DESC;

WITH S1005 AS (
    SELECT 
        Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
        ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
    FROM Event 
    WHERE LegalEntityDocument = @LegalEntityDocument 
    AND EventTypeEnum = 1 AND EventStatusEnum = 6
), BusinessKey AS (
    SELECT DISTINCT
        EntityCode, BusinessKey
    FROM S1005
    WHERE [Number] = 1
), WorkerCreditData AS (
    SELECT
    b.EntityCode, w.*
    FROM WorkerCredit w
    JOIN BusinessKey b ON w.NumeroInscricaoEstabelecimento = RIGHT(b.BusinessKey, LEN(w.NumeroInscricaoEstabelecimento))
    WHERE w.[Year] = @Year AND w.[Month] = @Month
) SELECT * FROM WorkerCreditData



SELECT
    WC.*
FROM (
    SELECT DISTINCT
        -- Id, ClientReceivedDate, 
        EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
        ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) Numero
    FROM Event 
    WHERE LegalEntityDocument = '43586122000114'-- @LegalEntityDocument 
    AND EventTypeEnum = 1 AND EventStatusEnum = 6
    ) Tb
JOIN WorkerCredit WC ON WC.InscricaoEstabelecimentoCodigo = RIGHT(Tb.BusinessKey, LEN(WC.InscricaoEstabelecimentoCodigo))
WHERE Tb.Numero = 1 AND WC.[Year] = 2025 AND WC.[Month] = 8

SELECT * FROM WorkerCredit WHERE MainEntityCode = '101122'

SELECT 
    Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument
FROM Event 
WHERE EntityCode = '101122' AND EventTypeEnum = 1 AND EventStatusEnum = 6
-- GROUP BY BusinessKey



WITH Tb AS (
    SELECT 
        Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
        ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) Numero
    FROM Event 
    WHERE LegalEntityDocument = '43586122000114' 
    AND EventTypeEnum = 1 AND EventStatusEnum = 6
), Tb2 AS (
    SELECT * FROM Tb
    WHERE Numero = 1
) SELECT distinct EntityCode FROM Tb2

SELECT 
    DISTINCT EntityCode, LegalEntityDocument, OriginLegalDocument
    -- Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
    -- ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) Numero
FROM Event 
WHERE EntityCode IN ('101122','101223','101225','101226','102122','103122','104122','105122','106122','107122','112122','113122')
    AND EventTypeEnum = 8 AND EventStatusEnum = 6 AND RelatedYear = 2025 AND RelatedMonth = 7

SELECT
    *
FROM WorkerCredit wc
JOIN Event e ON wc.InscricaoEstabelecimentoCodigo = RIGHT(e.BusinessKey, LEN(wc.InscricaoEstabelecimentoCodigo)) AND e.EventTypeEnum = 1 AND e.EventStatusEnum = 6
WHERE wc.MainEntityCode = '101122' AND wc.[Year] = 2025 AND wc.[Month] = 8