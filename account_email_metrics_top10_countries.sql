WITH
  -- Calculate the primary metric per account across 5 categories
  account_metrics AS (
    SELECT
      s.date,
      sp.country,
      acc.send_interval,
      acc.is_verified,
      acc.is_unsubscribed,
      COUNT(DISTINCT acc.id) AS account_cnt
    FROM
      `DA.account` acc
    JOIN `DA.account_session` acs
      ON acc.id = acs.account_id
    JOIN `DA.session` s
      ON s.ga_session_id = acs.ga_session_id
    JOIN `DA.session_params` sp
      ON sp.ga_session_id = s.ga_session_id
    GROUP BY
      s.date, sp.country, acc.send_interval, acc.is_verified,
      acc.is_unsubscribed
  ),
  -- Calculate the three primary metrics per email across 5 categories
  email_metrics AS (
    SELECT
      DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS date,
      sp.country,
      acc.send_interval,
      acc.is_verified,
      acc.is_unsubscribed,
      COUNT(DISTINCT es.id_message) AS sent_msg,
      COUNT(DISTINCT eo.id_message) AS open_msg,
      COUNT(DISTINCT ev.id_message) AS visit_msg
    FROM
      `DA.email_sent` es
    LEFT JOIN `DA.email_open` eo
      ON eo.id_message = es.id_message
    LEFT JOIN `DA.email_visit` ev
      ON ev.id_message = es.id_message
    JOIN `DA.account` acc
      ON es.id_account = acc.id
    JOIN `DA.account_session` acs
      ON acc.id = acs.account_id
    JOIN `DA.session` s
      ON s.ga_session_id = acs.ga_session_id
    JOIN `DA.session_params` sp
      ON sp.ga_session_id = s.ga_session_id
    GROUP BY
      date, sp.country, acc.send_interval, acc.is_verified, acc.is_unsubscribed
  ),
  -- Combine account-level and email-level metrics using UNION ALL
  union_all AS (
    SELECT
      am.date,
      am.country,
      am.send_interval,
      am.is_verified,
      am.is_unsubscribed,
      am.account_cnt,
      0 AS sent_msg,
      0 AS open_msg,
      0 AS visit_msg
    FROM account_metrics am
    UNION ALL
    SELECT
      em.date,
      em.country,
      em.send_interval,
      em.is_verified,
      em.is_unsubscribed,
      0 AS account_cnt,
      em.sent_msg,
      em.open_msg,
      em.visit_msg
    FROM email_metrics em
  ),
  -- Aggregate the combined results across 5 categories
  aggregated_unions AS (
    SELECT
      date,
      country,
      send_interval,
      is_verified,
      is_unsubscribed,
      SUM(account_cnt) AS account_cnt,
      SUM(sent_msg) AS sent_msg,
      SUM(open_msg) AS open_msg,
      SUM(visit_msg) AS visit_msg
    FROM union_all
    GROUP BY date, country, send_interval, is_verified, is_unsubscribed
  ),
  -- Calculate overall metrics for each country based on the aggregated metrics using window functions
  total_country
  AS (
    SELECT
      *,
      SUM(account_cnt) OVER (PARTITION BY country) AS total_country_account_cnt,
      SUM(sent_msg) OVER (PARTITION BY country) AS total_country_sent_cnt
    FROM aggregated_unions
  ),
  -- Rank countries by the number of accounts and emails sent in descending order using DENSE_RANK()
  ranked AS (
    SELECT
      *,
      DENSE_RANK()
        OVER (ORDER BY total_country_account_cnt DESC)
        AS rank_total_country_account_cnt,
      DENSE_RANK()
        OVER (ORDER BY total_country_sent_cnt DESC)
        AS rank_total_country_sent_cnt
    FROM total_country
  )
-- Return results only for countries ranked in the top 10 by either the number of accounts or the number of emails sent
SELECT *
FROM ranked
WHERE
  rank_total_country_account_cnt <= 10
  OR rank_total_country_sent_cnt <= 10
