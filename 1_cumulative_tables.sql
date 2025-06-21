-- DIMENSIONAL MODELING [CUMULATIVE TABLES & COMPLEX DATA TYPES]


--  First we create type `season_stats` and `players_dim`
Create type season_stats AS (season INTEGER,
                             gp INTEGER,
                             pts REAL,
                             reb REAL,
                             ast REAL);

CREATE TABLE players_dim (
    player_name TEXT,
    height TEXT,
    college TEXT,
    country TEXT,
    draft_year TEXT,
    draft_round TEXT,
    draft_number TEXT,
    season_stats season_stats[],
    current_season INTEGER,
    PRIMARY KEY (player_name, current_season)
    );


-- QUERY: 1
INSERT INTO players_dim
WITH yesterday AS (select *
                   FROM players_dim
                   where current_season = 2002),
     today AS (SELECT *
               FROM player_seasons
               where season = 2003)

select
    -- THESE ARE THE FIELDS THAT DO NOT CHANGE FROM SEASON TO SEASON
    -- Why do we coalesce? - because we can have players that "yesterday" were active
    -- but not "today" and players that "yesterday" did not exist, but "today" they exist.
    COALESCE(t.player_name, y.player_name)   as player_name,
    COALESCE(t.height, y.height)             as height,
    COALESCE(t.college, y.college)           as college,
    COALESCE(t.country, y.country)           as country,
    COALESCE(t.draft_year, y.draft_year)     as draft_year,
    COALESCE(t.draft_round, y.draft_round)   as draft_round,
    COALESCE(t.draft_number, y.draft_number) as draft_number,

    -- THIS FILLS THE SEASON stats
    CASE
        WHEN y.season_stats is NULL -- Player was not active yesterday
            THEN ARRAY [ROW (
            t.season,
            t.gp,
            t.pts,
            t.reb,
            t.ast
            )::season_stats]
        WHEN t.season is not null then y.season_stats || ARRAY [ROW ( -- Player was active last season
            t.season,
            t.gp,
            t.pts,
            t.reb,
            t.ast
            )::season_stats]
        ELSE y.season_stats -- Player no longer active
        END                                  as season_stats,

    COALESCE(t.season, y.current_season + 1) as current_season

from today t
         FULL OUTER JOIN yesterday y ON t.player_name = y.player_name;


-- After iterating between 1995 to 2003 we can see the break he had
SELECT *
FROM players_dim
where player_name like '%Michael Jordan%'
order by current_season;



Select player_name, (unnest(players_dim.season_stats)::season_stats).*
FROM players_dim
where player_name like '%Michael Jordan%'
-- and current_season = 2001


--QUERY 2: Enriching with scoring_class and
CREATE TYPE scoring_class AS ENUM ('star', 'good', 'average', 'bad');
CREATE TABLE players_dim_enriched
(
    player_name                    TEXT,
    height                         TEXT,
    college                        TEXT,
    country                        TEXT,
    draft_year                     TEXT,
    draft_round                    TEXT,
    draft_number                   TEXT,
    season_stats                   season_stats[],
    scoring_class                  scoring_class,
    years_since_last_active_season INTEGER,
    current_season                 INTEGER,
    PRIMARY KEY (player_name, current_season)
);


INSERT INTO players_dim_enriched
WITH yesterday AS (select *
                   FROM players_dim_enriched
                   where current_season = 2003),
     today AS (SELECT *
               FROM player_seasons
               where season = 2003)

select
    -- THESE ARE THE FIELDS THAT DO NOT CHANGE FROM SEASON TO SEASON
    -- Why do we coalesce? - because we can have players that "yesterday" were active
    -- but not "today" and players that "yesterday" did not exist, but "today" they exist.
    COALESCE(t.player_name, y.player_name)            as player_name,
    COALESCE(t.height, y.height)                      as height,
    COALESCE(t.college, y.college)                    as college,
    COALESCE(t.country, y.country)                    as country,
    COALESCE(t.draft_year, y.draft_year)              as draft_year,
    COALESCE(t.draft_round, y.draft_round)            as draft_round,
    COALESCE(t.draft_number, y.draft_number)          as draft_number,

    -- THIS FILLS THE SEASON stats
    CASE
        WHEN y.season_stats is NULL -- Player was not active yesterday
            THEN ARRAY [ROW (
            t.season,
            t.gp,
            t.pts,
            t.reb,
            t.ast
            )::season_stats]
        WHEN t.season is not null then y.season_stats || ARRAY [ROW ( -- Player was active last season
            t.season,
            t.gp,
            t.pts,
            t.reb,
            t.ast
            )::season_stats]
        ELSE y.season_stats -- Player no longer active
        END                                           as season_stats,

    CASE
        WHEN t.season IS NOT NULL THEN
            CASE
                WHEN t.pts > 20 THEN 'star'
                WHEN t.pts > 15 THEN 'good'
                WHEN t.pts > 10 THEN 'average'
                ELSE 'bad'
                END::scoring_class
        ELSE y.scoring_class
        END,


    CASE
        WHEN t.season IS NOT NULL THEN 0
        ELSE y.years_since_last_active_season + 1 END AS years_since_last_active_season,
    COALESCE(t.season, y.current_season + 1)          as current_season

from today t
         FULL OUTER JOIN yesterday y ON t.player_name = y.player_name;


Select *
from players_dim_enriched
where current_season = 1997
  and player_name = 'Michael Jordan'


Select player_name,
       (season_stats[1]::season_stats).pts AS first_season,
    (season_stats[CARDINALITY(season_stats)]::season_stats).pts as latest_season,
    Round((season_stats[CARDINALITY(season_stats)]::season_stats).pts - (season_stats[1]::season_stats).pts) as improvement
from players_dim_enriched
where current_season = 2001
order by improvement desc