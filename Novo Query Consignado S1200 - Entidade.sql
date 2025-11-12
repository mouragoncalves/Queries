SELECT * FROM WorkerCredit WHERE MainEntityCode = '1141'
SELECT ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) N, * FROM Event WHERE EntityCode = '1141' AND EventTypeEnum = 0

DECLARE @EntityCode VARCHAR(20) = '1141', @Year INT = 2025, @Month INT = 9, @LegalEntityDocument VARCHAR(40), @IsMatrix BIT;

DECLARE @TableS1005 TABLE (
    [Id] [bigint] NOT NULL,
	[ClientReceivedDate] [datetime] NOT NULL,
	[EntityCode] [nvarchar](10) NOT NULL,
	[BusinessKey] [nvarchar](500) NULL,
	[LegalEntityDocument] [varchar](50) NULL,
	[OriginLegalDocument] [varchar](14) NULL,
    [Number] INT)

SELECT @IsMatrix = IsMatrix,  @LegalEntityDocument = LegalEntityDocument
FROM (
    SELECT Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument, IIF(LegalEntityDocument = OriginLegalDocument, 1, 0) IsMatrix, ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
    FROM Event
    WHERE EntityCode = @EntityCode
        AND EventTypeEnum = 0
        AND EventStatusEnum = 6
    ) e
WHERE Number = 1 AND IsMatrix = 1

--INSERT INTO @TableS1005
SELECT 
    Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
    ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
FROM Event 
WHERE EventTypeEnum = 1 AND EventStatusEnum = 6
AND CASE WHEN @IsMatrix = 1 THEN LegalEntityDocument ELSE EntityCode END = CASE WHEN @IsMatrix = 1 THEN @LegalEntityDocument ELSE @EntityCode END;

-- SELECT 
--     Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
--     ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
-- FROM Event 
-- WHERE CASE WHEN @IsMatrix = 1 THEN LegalEntityDocument ELSE EntityCode END = CASE WHEN @IsMatrix = 1 THEN @LegalEntityDocument ELSE @EntityCode END
-- AND EventTypeEnum = 1 AND EventStatusEnum = 6

-- WITH S1005 AS (
--     SELECT 
--         Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
--         ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
--     FROM Event 
--     WHERE LegalEntityDocument = @LegalEntityDocument 
--     AND EventTypeEnum = 1 AND EventStatusEnum = 6
-- )

-- SELECT 
--     * --CAST(CAST(BusinessKey AS BIGINT) AS VARCHAR(20)) LegalEntityDocument, EntityCode, ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
-- FROM Event 
-- WHERE EventTypeEnum = 1 AND EventStatusEnum = 6 AND EntityCode = @EntityCode
-- DECLARE @LegalEntityDocument VARCHAR(20) = '43586122016207';
-- SELECT DISTINCT
--     @EntityCode = EntityCode 
-- FROM Event 
-- WHERE EventTypeEnum = 1 AND EventStatusEnum = 6 AND BusinessKey = @LegalEntityDocument

WITH 
-- LegalEntityDocumentList AS (
--     -- SELECT 
--     --     CAST(CAST(BusinessKey AS BIGINT) AS VARCHAR(20)) LegalEntityDocument, EntityCode, ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
--     -- FROM Event 
--     -- WHERE EventTypeEnum = 1 AND EventStatusEnum = 6 AND EntityCode = @EntityCode
--     SELECT 
--         Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
--         ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
--     FROM Event 
--     WHERE EventTypeEnum = 1 AND EventStatusEnum = 6
--     AND CASE WHEN @IsMatrix = 1 THEN LegalEntityDocument ELSE EntityCode END = CASE WHEN @IsMatrix = 1 THEN @LegalEntityDocument ELSE @EntityCode END
-- ), 
WorkerCreditData AS (
    SELECT 
        MainEntityCode, NomeTrabalhador, RIGHT('00000000000' + Cpf, 11) Cpf, Matricula, FORMAT(IfConcessoraCodigo, '000') Financeira, Contrato, ValorParcela, [Year], [Month] 
    FROM WorkerCredit 
    WHERE Year = @Year AND Month = @Month 
        AND NumeroInscricaoEstabelecimento IN (SELECT CAST(CAST(BusinessKey AS BIGINT) AS VARCHAR(20)) FROM @TableS1005 WHERE Number = 1)
), S1200 AS (
    SELECT
    e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
    FROM Event e
    INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 -- AND CHARINDEX('<descFolha>', c.Content) > 0
    -- LEFT JOIN WorkerCreditData w ON e.BusinessKey = w.Matricula
    WHERE e.EventTypeEnum = 8
        --AND e.EntityCode = @EntityCode
        AND e.RelatedYear = @Year
        AND e.RelatedMonth = @Month
        AND e.EventStatusEnum <= 7
        AND e.BusinessKey IN (SELECT DISTINCT Matricula FROM WorkerCreditData)
), EventXmlsDataS1200 AS (
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
        t.n.value('(observacao)[1]', 'varchar(255)') Observacao
    FROM S1200
    CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
), S2299 AS (
    SELECT 
        e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey
    FROM Event e
    WHERE e.EventTypeEnum = 25
        AND e.EntityCode = @EntityCode
        AND e.EventStatusEnum = 6
        AND e.BusinessKey IN (SELECT DISTINCT Matricula FROM WorkerCreditData)
), Events AS (
    SELECT 
        p.*, 
        CASE 
            WHEN d.EventId IS NULL THEN ''
            WHEN CONCAT(d.RelatedMonth, d.RelatedYear) >= CONCAT(p.RelatedMonth, p.RelatedYear) THEN ''
            ELSE CONCAT('Inativo desde: ', RIGHT('00' + CAST(d.RelatedMonth AS VARCHAR(2)), 2), '/', d.RelatedYear) 
        END S2299 
    FROM EventXmlsDataS1200 p 
    LEFT JOIN S2299 d ON d.BusinessKey = p.Matricula
), Events2 AS (
    SELECT 
        p.*, 
        CASE 
            WHEN d.EventId IS NULL THEN ''
            WHEN CONCAT(d.RelatedMonth, d.RelatedYear) >= CONCAT(p.Month, p.Year) THEN ''
            ELSE CONCAT('Inativo desde: ', RIGHT('00' + CAST(d.RelatedMonth AS VARCHAR(2)), 2), '/', d.RelatedYear) 
        END S2299 
    FROM WorkerCreditData p 
    LEFT JOIN S2299 d ON d.BusinessKey = p.Matricula
) --SELECT * FROM Events
SELECT 
    e.EventId, w.MainEntityCode, e.EntityCode, 
    IIF(e.RelatedYear IS NULL, w.Year, e.RelatedYear) RelatedYear, 
    IIF(e.RelatedMonth IS NULL, w.Month, e.RelatedMonth) RelatedMonth, 
    w.NomeTrabalhador,
    IIF(e.CPF IS NULL, w.Cpf, E.CPF) EmployeeDocument, 
    IIF(e.Matricula IS NULL, w.Matricula, E.Matricula) BusinessKey, 
    w.Rubrica,
    w.Financeira C_Financeira, w.Contrato C_Contrato, w.ValorParcela C_Parcela,
    e.Financeira E_Financeira, e.Contrato E_Contrato, e.ValorRubrica E_Parcela,
    CASE 
        -- WHEN e.RelatedMonth < @RelatedMonth OR e.RelatedYear < @RelatedYear  THEN CONCAT('Inativo desde: ', e.RelatedMonth, '/', e.RelatedYear)
        WHEN w.S2299 <> '' THEN w.S2299
        WHEN w.Financeira = e.Financeira THEN 'OK'
        WHEN w.Financeira IS NULL THEN 'Consignado sem financeira'
        WHEN e.Financeira IS NULL THEN 'eSocial sem financeira'
        ELSE 'DIVERGENTE'
    END ValidaFinanceira_Status,
    CASE 
        -- WHEN e.RelatedMonth < @RelatedMonth OR e.RelatedYear < @RelatedYear  THEN CONCAT('Inativo desde: ', e.RelatedMonth, '/', e.RelatedYear)
        WHEN w.S2299 <> '' THEN w.S2299
        WHEN w.Contrato = e.Contrato THEN 'OK'
        WHEN w.Contrato IS NULL THEN 'Consignado sem contrato'
        WHEN e.Contrato IS NULL THEN 'eSocial sem contrato'
        ELSE 'DIVERGENTE'
    END ValidaContrato_Status,
    CASE 
        -- WHEN e.RelatedMonth < @RelatedMonth OR e.RelatedYear < @RelatedYear  THEN CONCAT('Inativo desde: ', e.RelatedMonth, '/', e.RelatedYear)
        WHEN w.S2299 <> '' THEN w.S2299
        WHEN ABS(w.ValorParcela - e.ValorRubrica) <= 0.01 THEN 'OK'
        WHEN w.ValorParcela IS NULL THEN 'Consignado sem valor'
        WHEN e.ValorRubrica IS NULL THEN 'eSocial sem valor'
        WHEN w.ValorParcela > e.ValorRubrica THEN 'Valor maior no consignado'
        WHEN w.ValorParcela < e.ValorRubrica THEN 'Valor maior no eSocial'
        ELSE 'DIVERGENTE'
    END ValidaParcela_Status,
    (e.ValorRubrica - w.ValorParcela) DiferencaValor,
    e.Observacao
FROM Events e
FULL OUTER JOIN Events2 w ON w.Matricula = e.Matricula AND w.Contrato = e.Contrato