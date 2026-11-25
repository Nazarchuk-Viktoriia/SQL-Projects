WITH
  -- Count emails and find send dates per account and month
  msg_infos AS (
    SELECT
      DATE_TRUNC(DATE_ADD(s.date, INTERVAL es.sent_date DAY), MONTH)
        AS sent_month,
      COUNT(es.id_message)
        OVER (
          PARTITION BY
            id_account,
            DATE_TRUNC(DATE_ADD(s.date, INTERVAL es.sent_date DAY), MONTH)
        ) AS message_count_by_account,
      COUNT(es.id_message)
        OVER (
          PARTITION BY
            DATE_TRUNC(DATE_ADD(s.date, INTERVAL es.sent_date DAY), MONTH)
        ) AS message_count,
      MIN(DATE_ADD(s.date, INTERVAL es.sent_date DAY))
        OVER (
          PARTITION BY
            es.id_account,
            DATE_TRUNC(DATE_ADD(s.date, INTERVAL es.sent_date DAY), MONTH)
        ) AS first_sent_date,
      MAX(DATE_ADD(s.date, INTERVAL es.sent_date DAY))
        OVER (
          PARTITION BY
            es.id_account,
            DATE_TRUNC(DATE_ADD(s.date, INTERVAL es.sent_date DAY), MONTH)
        ) AS last_sent_date,
      es.id_account AS id_account
    FROM
      `data-analytics-mate.DA.email_sent` AS es
    JOIN
      `DA.account` AS ac
      ON ac.id = es.id_account
    JOIN
      `data-analytics-mate.DA.account_session` AS acs
      ON acs.account_id = ac.id
    JOIN
      `data-analytics-mate.DA.session` AS s
      ON s.ga_session_id = acs.ga_session_id
  )

-- Remove duplicates and calculate the account's share of monthly emails (%)
SELECT DISTINCT
  sent_month,
  id_account,
  message_count_by_account / message_count * 100
    AS sent_msg_percent_from_this_month,
  first_sent_date,
  last_sent_date
FROM msg_infos
