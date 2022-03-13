--Schema
/*
DROP TABLE IF EXISTS OLYMPICS_HISTORY;
CREATE TABLE IF NOT EXISTS OLYMPICS_HISTORY
(
    id          INT,
    name        VARCHAR,
    sex         VARCHAR,
    age         VARCHAR,
    height      VARCHAR,
    weight      VARCHAR,
    team        VARCHAR,
    noc         VARCHAR,
    games       VARCHAR,
    year        INT,
    season      VARCHAR,
    city        VARCHAR,
    sport       VARCHAR,
    event       VARCHAR,
    medal       VARCHAR
);

DROP TABLE IF EXISTS OLYMPICS_HISTORY_NOC_REGIONS;
CREATE TABLE IF NOT EXISTS OLYMPICS_HISTORY_NOC_REGIONS
(
    noc         VARCHAR,
    region      VARCHAR,
    notes       VARCHAR
);
*/

-- Ile olimpiad się już odbyło? 51
SELECT count(DISTINCT games) FROM olympics_history;

-- Wylistuj wszystkie olimiady do tej pory.
SELECT DISTINCT year, season, city FROM olympics_history
	ORDER BY year;

-- Całkowita liczba narodów która uczestniczyła w każdej olimpiadzie

CREATE VIEW countries_per_games AS
(
SELECT games, COUNT(region) nations_count FROM
(
	SELECT DISTINCT games, region FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnc ON oh.noc = ohnc.noc
) src
GROUP BY games
	ORDER BY games
);

-- W ktorym roku najwięcej krajów uczestniczyło w olimpiadzie a w którym najmniej?
SELECT
(SELECT games || ' - ' || nations_count min_nations FROM countries_per_games
	WHERE nations_count = (SELECT MIN(nations_count) FROM countries_per_games)
),
(SELECT games || ' - ' || nations_count max_nations FROM countries_per_games
	WHERE nations_count = (SELECT MAX(nations_count) FROM countries_per_games)
);

-- Który z krajów uczestniczył we wszystkich igrzyskach?
SELECT * FROM 
(
	SELECT DISTINCT region, COUNT(games) OVER(PARTITION BY region) nation_games FROM
	(
		SELECT DISTINCT region, games FROM olympics_history t1
		JOIN
		(SELECT * FROM olympics_history_noc_regions) t2
		ON t1.noc = t2.noc
	) src
) src
WHERE nation_games = (SELECT COUNT(DISTINCT games) FROM olympics_history);

--Który sport był grany na wszystkich letnich igrzyskach?
SELECT * FROM
(
	SELECT sport, count(games) games_cnt FROM
	(
		SELECT DISTINCT sport, games FROM olympics_history
		WHERE season = 'Summer'
	) src
GROUP BY  sport
) src
WHERE games_cnt = (SELECT  COUNT(DISTINCT games) FROM olympics_history WHERE season = 'Summer');

--Który sport był grany na igrzyskach tylko raz?
SELECT * FROM
(
	SELECT sport, count(games) games_cnt FROM
	(
		SELECT DISTINCT games, sport FROM olympics_history
	) src
	GROUP BY sport
)src_2
WHERE games_cnt = 1
	ORDER BY sport;
	
-- Podaj całkowitą liczbę sportów rozegranych na każdych igrzyskach
SELECT games, COUNT(sport) as sport_cnt FROM
(
SELECT DISTINCT games, sport FROM olympics_history
) src
GROUP BY games
ORDER BY games;

-- Który atleta był najstarszy kiedy zdobył złoty medal?
SELECT * FROM olympics_history
WHERE medal = 'Gold' AND age = (SELECT MAX(age) FROM olympics_history WHERE medal = 'Gold' AND age != 'NA');

-- Znajdź stosunek meżczyzn do kobiet ze wszystkich olimpiad
SELECT '1 : ' || ROUND(males::numeric/females::numeric, 2) ratio FROM
(
	SELECT 
	(SELECT COUNT(sex) females FROM olympics_history
		WHERE sex = 'F'),
	(SELECT COUNT(sex) males FROM olympics_history
		WHERE sex = 'M')
) src;

-- Znajdź 5 atletów którzy zdobyli najwięcej złotych medali
SELECT name, COUNT(medal) FROM olympics_history
	WHERE medal = 'Gold'
		GROUP BY name
			ORDER BY count(medal) desc
				LIMIT 5;
				
-- Znajdź 5 atletów którzy zdobyli najwięcej wszystkich medali
SELECT name, COUNT(medal) FROM olympics_history
	WHERE medal != 'NA'
		GROUP BY name
			ORDER BY count(medal) desc
				LIMIT 5;

-- Znajdź 5 krajów które zdobyły najwięcej medali.
SELECT *, RANK() OVER(ORDER BY count) FROM 
(
SELECT region, COUNT(medal) FROM olympics_history oh
JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr ON ohnr.noc = oh.noc
	WHERE medal != 'NA'
		GROUP BY region
			ORDER BY COUNT(medal) desc
				LIMIT 5
) src;

-- Wyciagnij wszystkie złote, srebrne i brązowe medale uzyskane przez każdy kraj
SELECT region_b as region, gold, silver, bronze FROM
(
	SELECT * FROM
	(
	SELECT region as region_g, COUNT(medal) gold FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr ON ohnr.noc = oh.noc
		WHERE medal = 'Gold'
			GROUP BY region_g
	) gold
	JOIN 
	(
	SELECT region as region_s, COUNT(medal) silver FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr ON ohnr.noc = oh.noc
		WHERE medal = 'Silver'
			GROUP BY region_s
	) silver
	ON gold.region_g = silver.region_s
	JOIN
	(
	SELECT region as region_b, COUNT(medal) bronze FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr ON ohnr.noc = oh.noc
		WHERE medal = 'Bronze'
			GROUP BY region_b
	) bronze
	ON silver.region_s = bronze.region_b
) main_src
ORDER BY gold desc, silver desc, bronze desc;
-- Wyciagnij wszystkie złote, srebrne i brązowe medale uzyskane przez każdy kraj Z select case

SELECT region,
SUM(CASE WHEN medal = 'Gold' THEN 1 ELSE 0 END) gold,
SUM(CASE WHEN medal = 'Silver' THEN 1 ELSE 0 END) silver,
SUM(CASE WHEN medal = 'Bronze' THEN 1 ELSE 0 END) bronze

FROM 
(
	SELECT region, games, medal FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr ON ohnr.noc = oh.noc
	WHERE medal != 'NA'
) src
GROUP BY region
ORDER BY gold desc, silver desc, bronze desc;

--Wylistuj ilosc złotych, srebrnych i brazowych medali z podziałem na każde igrzyska
SELECT region_g as region, games_g as games, COALESCE(gold,0) gold, COALESCE(silver,0) silver, COALESCE(bronze,0) bronze FROM 
(
	SELECT region region_g, games games_g, count(medal) as gold FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr 
	ON oh.noc = ohnr.noc
	WHERE medal = 'Gold'
	GROUP BY region_g, games_g
) gold
FULL JOIN
(
	SELECT region region_s, games games_s, count(medal) as silver FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr 
	ON oh.noc = ohnr.noc
	WHERE medal = 'Silver'
	GROUP BY region_s, games_s
) silver
ON gold.region_g = silver.region_s AND gold.games_g = silver.games_s
FULL JOIN
(
	SELECT region region_b, games games_b, count(medal) as bronze FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr 
	ON oh.noc = ohnr.noc
	WHERE medal = 'Bronze'
	GROUP BY region_b, games_b
) bronze
ON silver.region_s = bronze.region_b AND silver.games_s = bronze.games_b
ORDER BY games, region, gold desc, silver desc, bronze desc;

-- Które państwo wygrało najwięcej zł,sr i br medali na każdych igrzyskach. 

CREATE VIEW gsb_rank AS(
SELECT *,
RANK() OVER(PARTITION BY games ORDER BY gold desc ) gold_rank,
RANK() OVER(PARTITION BY games ORDER BY silver desc ) silver_rank,
RANK() OVER(PARTITION BY games ORDER BY bronze desc ) bronze_rank
FROM
(
	SELECT games, region, SUM(gold) gold, SUM(silver) silver, SUM(bronze) bronze FROM
	(
		SELECT games, region,
			CASE WHEN medal = 'Gold' THEN 1 ELSE 0 END gold,
			CASE WHEN medal = 'Silver' THEN 1 ELSE 0 END silver,
			CASE WHEN medal = 'Bronze' THEN 1 ELSE 0 END bronze
		FROM
		(
			SELECT games,region, medal FROM olympics_history oh
			JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr 
			ON oh.noc = ohnr.noc 
			WHERE medal != 'NA'
		) src
	) src
	GROUP BY  games, region
) src
ORDER BY games, gold desc)
-- End view


SELECT tab_a.games, gold, silver, bronze, gsb_sum FROM
(
SELECT games, region || ' - ' || gold as gold from gsb_rank
	WHERE gold_rank = 1
) tab_a
JOIN 
(SELECT games, region || ' - ' || silver as silver from gsb_rank
	WHERE silver_rank = 1) tab_b
ON tab_a.games = tab_b.games
JOIN
(SELECT games, region || ' - ' || bronze as bronze from gsb_rank
	WHERE bronze_rank = 1) tab_c
ON tab_a.games = tab_c.games

-- Które państwo miało sumarycznie najwięcej
JOIN
(
	SELECT games, region || ' - ' || gsb_sum gsb_sum FROM
	(
		SELECT games, region,gsb_sum,  RANK() OVER(PARTITION BY games ORDER BY gsb_sum desc) gsb_rank FROM
		(
			SELECT games, region, gold + silver + bronze as gsb_sum FROM gsb_rank
		) src
	) src
	WHERE gsb_rank = 1
) tab_d
ON tab_a.games = tab_d.games;

--Które kraje nigdy nie zdobyły złota ale zdobyły srebro lub braz?
SELECT * FROM
(
	SELECT region, 
	SUM(CASE WHEN medal = 'Gold' THEN 1 ELSE 0 END) gold,
	SUM(CASE WHEN medal = 'Silver' THEN 1 ELSE 0 END) silver,
	SUM(CASE WHEN medal = 'Bronze' THEN 1 ELSE 0 END) bronze
	FROM
	(
		SELECT region, medal FROM olympics_history oh
		JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr
		ON oh.noc = ohnr.noc
	) src
	GROUP BY region
) src
WHERE gold = 0 AND (silver > 0 OR bronze > 0)
ORDER BY silver desc, bronze desc;

-- W którym sporcie indie zdobyły najwięcej medali?
WITH max_medals AS
(
	SELECT sport, COUNT(medal) medals_cnt FROM olympics_history oh
	JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr
	ON oh.noc = ohnr.noc
		WHERE medal != 'NA' AND region = 'India'
			GROUP BY sport
)
SELECT sport, medals_cnt FROM max_medals
	WHERE medals_cnt = (SELECT MAX(medals_cnt) FROM max_medals);

--Pokaż wszystkie igrzyska gdzie indie zdobyły złoto z hokeja z podziałem na konkretne igrzyska
SELECT games, COUNT(medal) medals_cnt FROM olympics_history oh
JOIN OLYMPICS_HISTORY_NOC_REGIONS ohnr
ON oh.noc = ohnr.noc
WHERE medal != 'NA' AND region = 'India' AND sport = 'Hockey'
GROUP BY games;


