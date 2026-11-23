# Check whether version `ver` appears as a bounded token (optionally preceded by `v`) in `url`,
# rejecting partial dotted-version matches such as `0.7` or `7.6` inside `0.7.6`.
BEGIN {
  vlen = length(ver)
  ulen = length(url)
  if (vlen == 0 || ulen == 0) {
    exit 1
  }
  idx = 1
  while (idx <= ulen) {
    pos = index(substr(url, idx), ver)
    if (pos == 0) {
      exit 1
    }
    abs_pos = idx + pos - 1
    prev_ch = (abs_pos > 1) ? substr(url, abs_pos - 1, 1) : ""
    prev2_ch = (abs_pos > 2) ? substr(url, abs_pos - 2, 1) : ""
    next_ch = (abs_pos + vlen <= ulen) ? substr(url, abs_pos + vlen, 1) : ""
    next2_ch = (abs_pos + vlen + 1 <= ulen) ? substr(url, abs_pos + vlen + 1, 1) : ""

    left_dot_digit = (prev_ch == "." && prev2_ch ~ /[0-9]/)
    right_dot_digit = (next_ch == "." && next2_ch ~ /[0-9]/)
    left_ok = !left_dot_digit && (prev_ch == "" || prev_ch !~ /[0-9A-Za-z]/ || (prev_ch == "v" && (prev2_ch == "" || prev2_ch !~ /[0-9A-Za-z]/)))
    right_ok = !right_dot_digit && (next_ch == "" || next_ch !~ /[0-9A-Za-z]/)

    if (left_ok && right_ok) {
      exit 0
    }
    idx = abs_pos + 1
  }
  exit 1
}
