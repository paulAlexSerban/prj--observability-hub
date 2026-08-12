-- Status code breakdown over the last 7 days.

SELECT
  sc_status AS status,
  count() AS requests,
  round(100.0 * count() / sum(count()) OVER (), 2) AS pct
FROM s3(
  '__S3_URL__',
  '__AWS_KEY__',
  '__AWS_SECRET__',
  'TSV',
  'date Date, time String, x_edge_location String, sc_bytes UInt64, c_ip String, cs_method String, cs_host String, cs_uri_stem String, sc_status UInt16, cs_referer String, cs_user_agent String, cs_uri_query String, cs_cookie String, x_edge_result_type String, x_edge_request_id String, x_host_header String, cs_protocol String, cs_bytes UInt64, time_taken Float64, x_forwarded_for String, ssl_protocol String, ssl_cipher String, x_edge_response_result_type String, cs_protocol_version String, fle_status String, fle_encrypted_fields String, c_port UInt16, time_to_first_byte Float64, x_edge_detailed_result_type String, sc_content_type String, sc_content_len Int64, sc_range_start Int64, sc_range_end Int64'
)
WHERE date >= today() - 7
GROUP BY status
ORDER BY requests DESC

SETTINGS
  input_format_allow_errors_num = 10000,
  input_format_allow_errors_ratio = 1

