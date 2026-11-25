WITH
  -- Revenue per continent, split by device
  revenue_usd AS (
    SELECT
      sp.continent,
      SUM(p.price) AS revenue,
      SUM(CASE WHEN device = 'mobile' THEN p.price END) AS revenue_from_mobile,
      SUM(CASE WHEN device = 'desktop' THEN p.price END) AS revenue_from_desktop
    FROM
      `DA.order` o
    JOIN
      `DA.product` p
      ON o.item_id = p.item_id
    JOIN
      `DA.session_params` sp
      ON o.ga_session_id = sp.ga_session_id
    GROUP BY
      sp.continent
  ),

  -- Total and verified accounts per continent
  account_count AS (
    SELECT
      sp.continent,
      COUNT(DISTINCT acs.account_id) AS account_cnt,
      COUNT(DISTINCT CASE WHEN a.is_verified = 1 THEN acs.account_id END) AS verified_account_cnt
    FROM
      `DA.session_params` sp
    LEFT JOIN
      `DA.account_session` acs
      ON sp.ga_session_id = acs.ga_session_id
    JOIN
      `DA.account` a
      ON a.id = acs.account_id
    GROUP BY
      sp.continent
  ),

  -- Number of sessions per continent
  session_count AS (
    SELECT
      sp.continent,
      COUNT(DISTINCT sp.ga_session_id) AS session_cnt
    FROM
      `DA.session_params` sp
    GROUP BY
      sp.continent
  )

-- Combine all metrics by continent and calculate each continent's share of total revenue (%)
SELECT
  account_count.continent,
  revenue_usd.revenue,
  revenue_usd.revenue_from_mobile,
  revenue_usd.revenue_from_desktop,
  revenue_usd.revenue / SUM(revenue_usd.revenue) OVER () * 100 AS per_cent_of_total_revenue,
  account_count.account_cnt,
  account_count.verified_account_cnt,
  session_count.session_cnt
FROM
  account_count
LEFT JOIN
  revenue_usd
  ON account_count.continent = revenue_usd.continent
LEFT JOIN
  session_count
  ON account_count.continent = session_count.continent
ORDER BY
  revenue_usd.revenue DESC
