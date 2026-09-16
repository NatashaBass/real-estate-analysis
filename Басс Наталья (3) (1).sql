/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор:Басс Наталья Александровна
 * Дата:11.03.2026
*/


-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
WITH limits AS (
     SELECT  
          PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY f.total_area) AS total_area_limit,
          PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY f.rooms) AS rooms_limit,
          PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY f.balcony) AS balcony_limit,
          PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY f.ceiling_height) AS ceiling_height_limit_h,
          PERCENTILE_DISC(0.01) WITHIN GROUP(ORDER BY f.ceiling_height) AS ceiling_height_limit_l
     FROM real_estate.flats as f
     JOIN real_estate.advertisement AS a ON f.id = a.id),
filtered_id AS (
     SELECT DISTINCT f.id
     FROM real_estate.flats AS f 
     JOIN real_estate.advertisement AS a ON f.id = a.id
     WHERE f.total_area < (SELECT total_area_limit FROM limits)
          AND f.rooms < (SELECT rooms_limit FROM limits)
          AND (f.balcony < (SELECT balcony_limit FROM limits) OR f.balcony IS NULL)
          AND ((f.ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
          AND f.ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR f.ceiling_height IS NULL)),
ads_data AS (
    SELECT
          CASE WHEN f.city_id = (
               SELECT city_id 
               FROM real_estate.city 
               WHERE city = 'Санкт-Петербург')
               THEN 'Санкт-Петербург'
               ELSE 'ЛенОбл'
          END AS region,
          CASE WHEN a.days_exposition IS NULL THEN 'non category'
               WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
               WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
               WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
               WHEN a.days_exposition >= 181 THEN '181+ days'
          END AS activity_category,
          a.last_price/f.total_area AS price_m2,
          f.total_area,
          f.rooms,
          f.balcony,
          f.floor
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    JOIN real_estate.city AS c ON f.city_id = c.city_id
    JOIN real_estate.type AS t ON f.type_id = t.type_id
    JOIN filtered_id AS fi ON a.id = fi.id
    WHERE 
         EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018 and t.type = 'город')
SELECT region AS "Регион",
       activity_category AS "Сегмент активности",
       COUNT(*) AS "Количество объявлений",
       ROUND(COUNT(*) * 1.0/SUM(COUNT(*)) OVER (PARTITION BY region),3) AS "Доля объявлений",
       ROUND(AVG(price_m2)::numeric,2) AS "Средняя стоимость кв. метра",
       ROUND(AVG(total_area)::numeric,2) AS "Средняя площадь",
       PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY rooms) AS "Медиана кол-ва комнат",
       PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY balcony) AS "Медиана кол-ва балконов",
       PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY floor) AS "Медиана этажности"
FROM ads_data
GROUP BY region, activity_category
ORDER BY region,
      CASE activity_category
          WHEN '1-30 days' THEN 1
          WHEN '31-90 days' THEN 2
          WHEN '91-180 days' THEN 3
          WHEN '181+ days' THEN 4
          WHEN 'non category' THEN 5
      END;

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных

WITH limits AS (
     SELECT  
          PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY total_area) AS total_area_limit,
          PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY rooms) AS rooms_limit,
          PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY balcony) AS balcony_limit,
          PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY ceiling_height) AS ceiling_height_limit_h,
          PERCENTILE_DISC(0.01) WITHIN GROUP(ORDER BY ceiling_height) AS ceiling_height_limit_l
     FROM real_estate.flats),
filtered_id AS (
     SELECT id
     FROM real_estate.flats  
     WHERE total_area < (SELECT total_area_limit FROM limits)
         AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
         AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
         AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
         AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)),
ads_data AS (
     SELECT a.id,
            EXTRACT(MONTH FROM a.first_day_exposition) AS month_on,
            EXTRACT(MONTH FROM a.first_day_exposition + (a.days_exposition * INTERVAL '1 day')) AS month_off,
            a.last_price/f.total_area AS price_m2,
            f.total_area
     FROM real_estate.advertisement AS a
     JOIN real_estate.flats AS f ON a.id = f.id
     JOIN real_estate.type AS t ON f.type_id = t.type_id
     JOIN filtered_id fi ON a.id = fi.id
     WHERE EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
           AND t.type = 'город'),
month_names AS (
     SELECT 1 AS month_num, 'Январь' AS month_name UNION ALL
     SELECT 2, 'Февраль' UNION ALL
     SELECT 3, 'Март' UNION ALL
     SELECT 4, 'Апрель' UNION ALL
     SELECT 5, 'Май' UNION ALL
     SELECT 6, 'Июнь' UNION ALL
     SELECT 7, 'Июль' UNION ALL
     SELECT 8, 'Август' UNION ALL
     SELECT 9, 'Сентябрь' UNION ALL
     SELECT 10, 'Октябрь' UNION ALL
     SELECT 11, 'Ноябрь' UNION ALL
     SELECT 12, 'Декабрь'),
publish_on AS (
     SELECT m.month_name,
            m.month_num,
            COUNT(*) AS ads_on,
            ROUND(AVG(price_m2)::numeric,2) AS avg_price_m2,
            ROUND(AVG(total_area)::numeric,2) AS avg_total_area
     FROM ads_data AS ad
     JOIN month_names AS m ON ad.month_on = m.month_num
     GROUP by m.month_name, m.month_num),
publish_off AS (
     SELECT m.month_name,
            m.month_num,
            COUNT(*) AS ads_off,
            ROUND(AVG(ad.price_m2)::numeric, 2) AS avg_price_m2_off,
            ROUND(AVG(ad.total_area)::numeric, 2) AS avg_total_area_off
     FROM ads_data AS ad
     JOIN month_names AS m ON ad.month_off = m.month_num
     WHERE ad.month_off IS NOT NULL
     GROUP BY m.month_name, m.month_num)
SELECT
     COALESCE(p.month_name, poff.month_name) AS "Месяц",
     COALESCE(p.ads_on, 0) AS "Количество опубликованных объявлений",
     p.avg_price_m2 AS "Ср.цена м² (публикация)",
     p.avg_total_area AS "Ср.площадь (публикация)",
     COALESCE(poff.ads_off, 0) AS "Количество снятых объявлений",
     poff.avg_price_m2_off AS "Ср.цена м² (снятие)",
     poff.avg_total_area_off AS "Ср.площадь (снятие)"
FROM publish_on AS p
FULL OUTER JOIN publish_off AS poff ON p.month_name = poff.month_name
ORDER BY
     COALESCE(p.month_num, poff.month_num);

            
