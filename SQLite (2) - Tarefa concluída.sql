WITH media_trimestre AS (
    SELECT
        Trimestre,
        AVG(CAST(NULLIF(ValorDespesas,'') AS REAL)) AS media_geral
    FROM consolidado_enriquecido
    WHERE ValorDespesas IS NOT NULL
    GROUP BY Trimestre
),
comparacao AS (
    SELECT
        c.RegistroANS,
        c.Trimestre,
        CASE
            WHEN CAST(NULLIF(c.ValorDespesas,'') AS REAL) > m.media_geral THEN 1
            ELSE 0
        END AS acima_media
    FROM consolidado_enriquecido c
    JOIN media_trimestre m
      ON c.Trimestre = m.Trimestre
)
SELECT
    COUNT(*) AS qtd_operadoras
FROM (
    SELECT
        RegistroANS
    FROM comparacao
    GROUP BY RegistroANS
    HAVING SUM(acima_media) >= 2
);
