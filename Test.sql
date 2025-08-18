DECLARE @TagXML VARCHAR(40), @MainEntityCode VARCHAR(20) = '101122', @EntityCode VARCHAR(20) = '101223', @EntitiesCode VARCHAR(MAX) = '101122,101223,101225,101226,102122,103122,104122,105122,106122,107122,112122,113122', @RelatedYear INT = 2025, @RelatedMonth INT = 7, @EventTypeEnum INT = 8;

SET @TagXML = CASE 
    WHEN @EventTypeEnum = 8 THEN '<descFolha>'
    WHEN @EventTypeEnum = 47 THEN '<eConsignado>'
    ELSE NULL
END;

WITH WorkerCreditsData AS (
    SELECT
        MainEntityCode, Matricula, FORMAT(IfConcessoraCodigo, '000') Financeira, Contrato, ValorParcela
    FROM WorkerCredit 
    WHERE MainEntityCode = @MainEntityCode 
        AND [Year] = @RelatedYear 
        AND [Month] = @RelatedMonth
), EventsData AS (
    SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
    FROM Event e
        INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX(@TagXML, c.Content) > 0
    WHERE e.EventTypeEnum = @EventTypeEnum
        AND e.BusinessKey IN (SELECT DISTINCT Matricula FROM WorkerCreditsData)
        -- AND e.EntityCode IN (SELECT CAST(value AS varchar) FROM STRING_SPLIT(@EntitiesCode, ','))
        -- AND e.EntityCode = @EntityCode
        AND e.RelatedYear = @RelatedYear
        AND e.RelatedMonth = @RelatedMonth
        AND e.EventStatusEnum IN (0, 6, 7)
), EventXmlsData AS (
    SELECT
        EventId,
        RelatedYear,
        RelatedMonth,
        EntityCode,
        t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') CPF,
        t.n.value('(../../matricula)[1]', 'varchar(50)') Matricula,
        t.n.value('(../../../nrInsc)[1]', 'varchar(14)') Estabelecimento,
        t.n.value('(../codRubr)[1]', 'varchar(10)') Rubrica,
        t.n.value('(../vrRubr)[1]', 'decimal(15,2)') ValorRubrica,
        t.n.value('(instFinanc)[1]', 'varchar(10)') Financeira,
        t.n.value('(nrDoc)[1]', 'varchar(50)') Contrato,
        -- t.n.value('(cnpjDescFolha)[1]', 'varchar(14)') CNPJDescFolha,
        -- t.n.value('(tpDesc)[1]', 'varchar(5)') TipoDesconto,
        t.n.value('(observacao)[1]', 'varchar(255)') Observacao
    FROM EventsData
    CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
)
-- SELECT * FROM WorkerCreditsData e 
-- FULL OUTER JOIN WorkerCreditsData w ON e.E_Matricula = w.Matricula AND e.E_Contrato = w.Contrato

    SELECT 
        e.EventId, w.MainEntityCode, e.EntityCode, e.RelatedYear, e.RelatedMonth, 
        e.CPF, e.Matricula,
        
        -- Dados para comparação
        w.Financeira C_Financeira, w.Contrato C_Contrato, w.ValorParcela C_Parcela,
        e.Financeira E_Financeira, e.Contrato E_Contrato, e.ValorRubrica E_Parcela,
        
        -- Validações individuais
        CASE 
            WHEN w.Financeira = e.Financeira THEN 'OK'
            WHEN w.Financeira IS NULL THEN 'Consignado sem financeira'
            WHEN e.Financeira IS NULL THEN 'eSocial sem financeira'
            ELSE 'DIVERGENTE'
        END ValidaFinanceira_Status,
        
        CASE 
            WHEN w.Contrato = e.Contrato THEN 'OK'
            WHEN w.Contrato IS NULL THEN 'Consignado sem contrato'
            WHEN e.Contrato IS NULL THEN 'eSocial sem contrato'
            ELSE 'DIVERGENTE'
        END ValidaContrato_Status,
        
        CASE 
            WHEN ABS(w.ValorParcela - e.ValorRubrica) <= 0.01 THEN 'OK' -- Tolerância de centavos
            WHEN w.ValorParcela IS NULL THEN 'Consignado sem valor'
            WHEN e.ValorRubrica IS NULL THEN 'eSocial sem valor'
            WHEN w.ValorParcela > e.ValorRubrica THEN 'Valor maior no consignado'
            WHEN w.ValorParcela < e.ValorRubrica THEN 'Valor maior no eSocial'
            ELSE 'DIVERGENTE'
        END ValidaParcela_Status,
        
        -- Diferença monetária
        (e.ValorRubrica - w.ValorParcela) DiferencaValor
        
    FROM EventXmlsData e
    FULL OUTER JOIN WorkerCreditsData w ON 
        w.Matricula = e.Matricula 
        AND w.Contrato = e.Contrato

-- SELECT LEFT(l.Document, 8), * FROM LegalEntity l
-- JOIN Entity e ON e.AossLegalHierarchyId = l.AossLegalHierarchyId
-- WHERE e.Code IN (SELECT CAST(value AS varchar) FROM STRING_SPLIT(@EntitiesCode, ','))
--     AND e.Deleted = 0
--     AND IIF(l.AossLegalHierarchyId = e.AossLegalHierarchyId, 1, 0) = 1

-- SELECT * FROM LegalEntity WHERE AossLegalHierarchyId = '63081c27-ab7e-4087-ad5e-24d1a9296779'

-- SELECT iif(COUNT(*) OVER (PARTITION BY CPF, year, month ORDER BY (SELECT NULL)) = COUNT(*) OVER (PARTITION BY CPF, Matricula, year, month ORDER BY (SELECT NULL)), 1, 0) Dif , * FROM WorkerCredit WHERE year = 2025 AND month = 7


-- SELECT * FROM Event WHERE BusinessKey IN ('AES_EDUC22042009R0038','AES06052019R114210') AND RelatedYear = 2025 AND RelatedMonth = 7
-- SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
-- FROM Event e
--     INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<eConsignado>', c.Content) > 0
-- WHERE e.EventTypeEnum = 47
--     -- AND e.EntityCode IN (SELECT CAST(value AS varchar) FROM STRING_SPLIT(@EntitiesCode, ','))
--     AND e.RelatedYear = @RelatedYear
--     AND e.RelatedMonth = @RelatedMonth
--     AND e.EventStatusEnum <= 7


-- SELECT *
-- FROM Event e
--     INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<eConsignado>', c.Content) > 0
-- WHERE RelatedYear = 2025
--     AND RelatedMonth = 7
--     AND EntityCode = '102122'
--     AND EventTypeEnum = 47
--     AND BusinessKey = 'AP-EDUC01052024R974310'

-- SELECT * FROM XMLContent WHERE ReferenceId = 18205097



-- SELECT * FROM Entity WHERE AossLegalHierarchyId = '5afa35fa-e314-4fe1-9179-ab5ee3799cdc'

-- SELECT * FROM WorkerCredit

-- SELECT * FROM XMLContent WHERE ReferenceId = 18158260