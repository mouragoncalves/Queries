DECLARE @MainEntityCode VARCHAR(20) = '101122', @EntitiesCode VARCHAR(MAX) = '101122,101223,101225,101226,102122,103122,104122,105122,106122,107122,112122,113122', @RelatedYear INT = 2025, @RelatedMonth INT = 7;

WITH
    EventsData
    AS
    (
        SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
        FROM Event e
            INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<descFolha>', c.Content) > 0
        WHERE e.EventTypeEnum = 8
            AND e.EntityCode IN (SELECT CAST(value AS varchar) FROM STRING_SPLIT(@EntitiesCode, ','))
            AND e.RelatedYear = @RelatedYear
            AND e.RelatedMonth = @RelatedMonth
            AND e.EventStatusEnum <= 7
    ),
    BusinessKeysData
    AS
    (
        SELECT DISTINCT BusinessKey
        FROM EventsData
    ),
    EventsDataXml
    AS
    (
        SELECT
            EventId,
            RelatedYear,
            RelatedMonth,
            EntityCode,
            t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') CPF,
            t.n.value('(../../matricula)[1]', 'varchar(50)') Matricula,
            t.n.value('(../../../nrInsc)[1]', 'varchar(14)') Estabelecimento,
            t.n.value('(../codRubr)[1]', 'varchar(10)') CodigoRubrica,
            t.n.value('(../vrRubr)[1]', 'decimal(15,2)') ValorRubrica,
            t.n.value('(instFinanc)[1]', 'varchar(10)') InstituicaoFinanceira,
            t.n.value('(nrDoc)[1]', 'varchar(50)') NumeroContrato,
            -- t.n.value('(cnpjDescFolha)[1]', 'varchar(14)') CNPJDescFolha,
            t.n.value('(tpDesc)[1]', 'varchar(5)') TipoDesconto,
            t.n.value('(observacao)[1]', 'varchar(255)') Observacao
        FROM EventsData
    CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
    ), WorkerCreditData AS (
        SELECT 
            * 
        FROM WorkerCredit w
            LEFT JOIN BusinessKeysData b ON w.Matricula = b.BusinessKey
        WHERE w.MainEntityCode = @MainEntityCode
    ), WorkerCreditCompare AS (
    SELECT 
        e.EventId, w.MainEntityCode, e.EntityCode, e.RelatedYear, e.RelatedMonth, 
        e.CPF, e.Matricula,
        
        -- Dados para comparação
        w.IfConcessoraCodigo A_Financeira, w.Contrato A_Contrato, w.ValorParcela A_Parcela,
        e.InstituicaoFinanceira E_Financeira, e.NumeroContrato E_Contrato, e.ValorRubrica E_Parcela,
        
        -- Validações individuais
        CASE 
            WHEN w.IfConcessoraCodigo = e.InstituicaoFinanceira THEN 'OK'
            WHEN w.IfConcessoraCodigo IS NULL THEN 'Consignado sem financeira'
            WHEN e.InstituicaoFinanceira IS NULL THEN 'eSocial sem financeira'
            ELSE 'DIVERGENTE'
        END ValidaFinanceira_Status,
        
        CASE 
            WHEN w.Contrato = e.NumeroContrato THEN 'OK'
            WHEN w.Contrato IS NULL THEN 'Consignado sem contrato'
            WHEN e.NumeroContrato IS NULL THEN 'eSocial sem contrato'
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
        
    FROM EventsDataXml e
    FULL OUTER JOIN WorkerCreditData w ON 
        w.Matricula = e.Matricula 
        AND w.Contrato = e.NumeroContrato
        -- AND w.MainEntityCode = '5111'
    WHERE w.[Year] = e.RelatedYear 
        AND w.[Month] = e.RelatedMonth 
        -- AND w.MainEntityCode = '3151' OR w.MainEntityCode IS NULL
)

-- Query final para análise
SELECT 
    *,
    CASE 
        WHEN EventId IS NULL THEN 'Consignado não enviado ao eSocial'
        WHEN C_Contrato IS NULL THEN 'Desconto no eSocial sem consignado'
        WHEN ValidaFinanceira_Status = 'OK' AND ValidaContrato_Status = 'OK' AND ValidaParcela_Status = 'OK' 
            THEN 'CORRETO'
        ELSE 'CONFERIR'
    END StatusGeral
FROM WorkerCreditCompare
-- WHERE ValidaFinanceira_Status != 'OK' 
--    OR ValidaContrato_Status != 'OK' 
--    OR ValidaParcela_Status != 'OK'
--    OR EventId IS NULL 
--    OR C_Contrato IS NULL
ORDER BY Matricula;
