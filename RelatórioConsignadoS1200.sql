DECLARE @MainEntityCode VARCHAR(20) = '', @EntitiesCode VARCHAR(MAX) = '104122,101111', @RelatedYear INT = 2025, @RelatedMonth INT = 7;

WITH
    EventsData
    AS
    (
        SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, CONVERT(XML, c.Content) ContentXML
        FROM Event e
            INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<descFolha>', c.Content) > 0
        WHERE e.EventTypeEnum = 8
            -- AND e.EntityCode IN (SELECT CAST(value AS varchar) FROM STRING_SPLIT(@EntitiesCode, ','))
            AND e.RelatedYear = @RelatedYear
            AND e.RelatedMonth = @RelatedMonth
            AND e.EventStatusEnum <= 7
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
        SELECT e.EventId, w.MainEntityCode, e.EntityCode, e.RelatedYear, e.RelatedMonth, e.Matricula, 
            w.IfConcessoraCodigo C_Financeira, w.Contrato C_Contrato, w.ValorParcela C_Parcela, 
            e.InstituicaoFinanceira E_Financeira, e.NumeroContrato E_Contrato, e.ValorRubrica E_Parcela,
            IIF(w.IfConcessoraCodigo = e.InstituicaoFinanceira, 1, 0) ValidaFinanceira,
            -- IIF(w.Contrato = e.NumeroContrato, 1, 0) ValidaContrato,
            IIF(w.ValorParcela = e.ValorRubrica, 1, 0) ValidaParcela
        FROM EventsDataXml e
        JOIN WorkerCredit w ON w.[Year] = e.RelatedYear AND w.[Month] = e.RelatedMonth AND w.Matricula = e.Matricula AND w.Contrato = e.NumeroContrato
    )
SELECT *
FROM WorkerCreditData
