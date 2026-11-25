-- Step 1: daily revenue view
CREATE VIEW `Students.v_revenue_daily`
AS
SELECT
  s.date AS date,
  SUM(p.price) AS revenue,
  0 AS predict
FROM
  `DA.product` p
JOIN
  `DA.order` o
  ON
    o.item_id = p.item_id
JOIN
  `DA.session` s
  ON
    s.ga_session_id = o.ga_session_id
GROUP BY
  s.date;

-- Step 2: compare cumulative revenue with cumulative predict
WITH
  revenue_union_predict AS (
    SELECT
      *
    FROM
      `Students.v_revenue_daily`
    UNION ALL
    SELECT
      rp.date AS date,
      0 AS revenue,
      SUM(rp.predict) AS predict
    FROM
      `DA.revenue_predict` rp
    GROUP BY
      rp.date
  ),
  revenue_and_predict AS (
    SELECT
      date,
      SUM(revenue) AS revenue,
      SUM(predict) AS predict
    FROM
      revenue_union_predict
    GROUP BY
      date
  )
SELECT
  date,
  revenue,
  predict,
  SUM(revenue)
    OVER (ORDER BY date) / SUM(predict) OVER (ORDER BY date) * 100 AS per_cent
FROM
  revenue_and_predict
