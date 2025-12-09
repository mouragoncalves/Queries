SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER proc [dbo].[sp_GetCompareConsignadoS5003]
    @MainEntityCode VARCHAR(20), @EntityCode VARCHAR(20), @Year INT, @Month INT

AS
BEGIN

    -- DECLARE @MainEntityCode VARCHAR(20), @EntityCode VARCHAR(20), @Year INT = 2025, @Month INT = 10;

    -- SET @MainEntityCode = '5111';
    -- SET @EntityCode = '5692';

    WITH WorkerCreditData AS (
        SELECT
            w.Id WorkerCreditId, w.MainEntityCode, RIGHT('00000000000000' + w.NumeroInscricaoEstabelecimento, 14) CnpjCno, w.[Year] RelatedYear, w.[Month] RelatedMonth, w.Competencia, 
            w.Matricula BusinessKey, RIGHT('00000000000' + w.Cpf, 11) Cpf, w.NomeTrabalhador, w.Rubrica,
            FORMAT(w.IfConcessoraCodigo, '000') Financeira, w.Contrato, w.ValorParcela
        FROM WorkerCredit w
        WHERE w.[Year] = @Year
            AND w.[Month] = @Month
            AND CASE WHEN LEN(@MainEntityCode) > 0 THEN w.MainEntityCode ELSE 1 END = CASE WHEN LEN(@MainEntityCode) > 0 THEN @MainEntityCode ELSE 1 END
    ), EntityCodeByOriginLegalDocument AS (
        SELECT EntityCode, CnpjCno FROM (
            SELECT DISTINCT
                e.EntityCode, RIGHT('00000000000000' + e.BusinessKey, 14) CnpjCno, ROW_NUMBER() OVER (PARTITION BY e.BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
            FROM Event e
            WHERE e.EventTypeEnum = 1 
                AND e.EventStatusEnum = 6 
            ) V
        WHERE Number = 1
    ), WorkerCreditByEntityCode AS (
        SELECT * FROM (
            SELECT 
                w.WorkerCreditId, w.MainEntityCode, e.EntityCode, w.CnpjCno, w.RelatedYear, w.RelatedMonth, w.Competencia, w.BusinessKey, w.Cpf, w.NomeTrabalhador, w.Rubrica,
                w.Financeira, w.Contrato, w.ValorParcela
            FROM WorkerCreditData w
            JOIN EntityCodeByOriginLegalDocument e ON e.CnpjCno = w.CnpjCno
        ) V
        WHERE CASE 
            WHEN LEN(@EntityCode) > 0 THEN 
                CASE WHEN EntityCode = @EntityCode OR EntityCode IS NULL THEN 1 ELSE 0 END
            ELSE 1 
        END = 1
    ), S2299 AS (
        SELECT 
            e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey
        FROM Event e
        WHERE e.EventTypeEnum = 25
            AND e.EventStatusEnum = 6
            AND e.EntityCode IN (SELECT DISTINCT EntityCode FROM WorkerCreditByEntityCode)
            -- AND e.BusinessKey IN (SELECT DISTINCT BusinessKey FROM WorkerCreditByEntityCode)
    ), S2299X AS (
        SELECT 
            e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
        FROM Event e
        INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND (CHARINDEX('<descFolha>', c.Content) > 0 OR CHARINDEX('<sucessaoVinc>', c.Content) > 0)
        WHERE e.EventTypeEnum = 25
            AND e.RelatedYear = @Year
            AND e.RelatedMonth = @Month
            AND e.EventStatusEnum = 6
            AND e.EntityCode IN (SELECT DISTINCT EntityCode FROM WorkerCreditByEntityCode)
            -- AND e.BusinessKey IN (SELECT DISTINCT BusinessKey FROM WorkerCreditByEntityCode)
    ), S5003 AS (
        SELECT 
            e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML, 
            ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
        FROM Event e
        INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 --AND CHARINDEX('<eConsignado>', c.Content) > 0
        WHERE e.EventTypeEnum = 47
            AND e.RelatedYear = @Year
            AND e.RelatedMonth = @Month
            AND e.EventStatusEnum = 6 
            AND e.EntityCode IN (SELECT DISTINCT EntityCode FROM WorkerCreditByEntityCode)
            -- AND e.BusinessKey IN (SELECT DISTINCT BusinessKey FROM WorkerCreditByEntityCode)
    ), EventXmlsDataS5003 AS (
        SELECT
            EventId,
            RelatedYear,
            RelatedMonth,
            EntityCode,
            t.n.value('(../../../../../*[local-name()="ideTrabalhador"]/*[local-name()="cpfTrab"])[1]', 'varchar(11)') AS Cpf,
            t.n.value('(../*[local-name()="matricula"])[1]', 'varchar(50)') AS BusinessKey,
            t.n.value('(../../../*[local-name()="nrInsc"])[1]', 'varchar(14)') AS CnpjCno,
            '' AS Rubrica,
            t.n.value('(*[local-name()="vreConsignado"])[1]', 'decimal(15,2)') AS ValorParcela,
            t.n.value('(*[local-name()="instFinanc"])[1]', 'varchar(10)') AS Financeira,
            t.n.value('(*[local-name()="nrContrato"])[1]', 'varchar(50)') AS Contrato,
            '' AS Observacao
        FROM S5003
        CROSS APPLY ContentXML.nodes('/*[local-name()="eSocial"]/*[local-name()="evtBasesFGTS"]/*[local-name()="infoFGTS"]/*[local-name()="ideEstab"]/*[local-name()="ideLotacao"]/*[local-name()="infoTrabFGTS"]/*[local-name()="eConsignado"]') AS t(n)
        WHERE [Number] = 1
    ), EventXmlsDataS2299 AS (
        SELECT
            EventId,
            RelatedYear,
            RelatedMonth,
            EntityCode,
            t.n.value('(../../../../../../ideVinculo/cpfTrab)[1]', 'varchar(11)') AS Cpf,
            t.n.value('(../../../../../../ideVinculo/matricula)[1]', 'varchar(50)') AS BusinessKey,
            t.n.value('(../nrInsc)[1]', 'varchar(14)') AS CnpjCno,
            t.n.value('(codRubr)[1]', 'varchar(10)') AS Rubrica,
            t.n.value('(vrRubr)[1]', 'decimal(15,2)') AS ValorParcela,
            t.n.value('(descFolha/instFinanc)[1]', 'varchar(10)') AS Financeira,
            t.n.value('(descFolha/nrDoc)[1]', 'varchar(50)') AS Contrato,
            '' Observacao
        FROM S2299X
        CROSS APPLY ContentXML.nodes('/eSocial/evtDeslig/infoDeslig/verbasResc/dmDev/infoPerApur/ideEstabLot/detVerbas') AS t(n)
        WHERE t.n.value('(codRubr)[1]', 'varchar(10)') IN ('16965', '16966', '16967', '16968', '16969', '16975', '16976', '16977', '16978')
    ), WorkerCreditByEntityCodeS2299 AS (
        SELECT 
            w.WorkerCreditId, w.MainEntityCode, W.EntityCode, w.CnpjCno, w.RelatedYear, w.RelatedMonth, w.Competencia, w.BusinessKey, w.Cpf, w.NomeTrabalhador, w.Rubrica, w.Financeira, w.Contrato, w.ValorParcela, 
            CASE 
                    WHEN s.EventId IS NULL THEN NULL
                    WHEN CAST(CONCAT(CAST(s.RelatedMonth AS INT), CAST(s.RelatedYear AS INT)) AS INT) >= CAST(CONCAT(CAST(w.RelatedMonth AS INT), CAST(w.RelatedYear AS INT)) AS INT) THEN NULL
                    ELSE CONCAT('Inativo desde: ', RIGHT('00' + CAST(s.RelatedMonth AS VARCHAR(2)), 2), '/', s.RelatedYear) 
            END Desligamento 
        FROM WorkerCreditByEntityCode w
        LEFT JOIN S2299 s ON s.BusinessKey = w.BusinessKey
    ), EventsData AS (
        SELECT * FROM EventXmlsDataS5003
        UNION ALL 
        SELECT * FROM EventXmlsDataS2299
    )

    SELECT 
        e.EventId, w.MainEntityCode, w.EntityCode, 
        IIF(e.RelatedYear IS NULL, w.RelatedYear, e.RelatedYear) RelatedYear, 
        IIF(e.RelatedMonth IS NULL, w.RelatedMonth, e.RelatedMonth) RelatedMonth, 
        w.NomeTrabalhador,
        IIF(e.CPF IS NULL, w.Cpf, E.CPF) EmployeeDocument, 
        IIF(e.BusinessKey IS NULL, w.BusinessKey, E.BusinessKey) BusinessKey, 
        w.Rubrica,
        w.Financeira A_Financeira, w.Contrato A_Contrato, w.ValorParcela A_Parcela,
        e.Financeira E_Financeira, e.Contrato E_Contrato, e.ValorParcela E_Parcela,
        (e.ValorParcela - w.ValorParcela) DiferencaValor,
        CASE 
            WHEN EXISTS (
                    SELECT 1 FROM S2299X sx WHERE sx.BusinessKey = w.BusinessKey AND sx.ContentXML.exist('//sucessaoVinc')  > 0
                ) THEN 'Inativo – Transferência'
            WHEN e.EventId IS NULL THEN
                CASE 
                    WHEN LEN(w.[Desligamento]) > 0 THEN w.Desligamento
                    ELSE 'Sem informação do APS'
                END
            WHEN w.Financeira = e.Financeira 
                AND w.Contrato = e.Contrato 
                AND ABS(w.ValorParcela - e.ValorParcela) <= 0.01 THEN 'OK'
            WHEN w.Financeira = e.Financeira 
                AND w.Contrato = e.Contrato 
                AND w.ValorParcela > e.ValorParcela THEN 'OK com diferença de valor'
            WHEN w.Financeira = e.Financeira 
                AND w.Contrato = e.Contrato 
                AND w.ValorParcela < e.ValorParcela THEN 'Erro no valor parcela'
            ELSE 
                'Dados Divergente'
        END AS [Status]
    FROM EventsData e
    FULL OUTER JOIN WorkerCreditByEntityCodeS2299 w ON w.BusinessKey = e.BusinessKey AND w.Contrato = e.Contrato
    ORDER BY EmployeeDocument

END
GO
