#!/bin/bash

source "$(dirname "$0")/config.env"

# === CONFIGURATION ===
EMAIL_TO="theskilledelites@gmail.com"      # Replace with your email
EMAIL_SUBJECT="Weekly System Security & Health Digest"
REPORT_FILE="/tmp/weekly_report.html"
GEOIP_DB="/usr/share/GeoIP/GeoLite2-City.mmdb"  # Adjust if needed

# === COLLECT SYSTEM DATA ===
now=$(date)
uptime_info=$(uptime -p)
disk_usage=$(df -h)
mem_info=$(free -h)
cpu_top=$(top -bn1 | head -n 20)

# === SSH LOGIN REPORT ===
SSH_LOG=$(journalctl _COMM=sshd --since "7 days ago")
SUCCESSFUL_LOGINS=$(echo "$SSH_LOG" | grep "Accepted")
FAILED_LOGINS=$(echo "$SSH_LOG" | grep "Failed")

# First and last login timestamps
first_login=$(echo "$SSH_LOG" | grep "Accepted" | head -n 1)
last_login=$(echo "$SSH_LOG" | grep "Accepted" | tail -n 1)

# Top failed IPs and users
TOP_FAILED_IPS=$(echo "$FAILED_LOGINS" | grep -oP 'from \K[0-9.]*' | sort | uniq -c | sort -nr | head -10)
TOP_FAILED_USERS=$(echo "$FAILED_LOGINS" | grep -oP 'invalid user \K\S+' | sort | uniq -c | sort -nr | head -10)

# GeoIP Lookups (optional, limited to top 5 IPs)
command -v geoiplookup > /dev/null && {
  GEOIP_REPORT="<ul>"
  for ip in $(echo "$FAILED_LOGINS" | grep -oP 'from \K[0-9.]*' | sort | uniq -c | sort -nr | head -5 | awk '{print $2}'); do
    loc=$(geoiplookup "$ip")
    GEOIP_REPORT+="<li><b>$ip</b>: $loc</li>"
  done
  GEOIP_REPORT+="</ul>"
} || GEOIP_REPORT="<p><i>geoiplookup not found</i></p>"

# SSH Hardening Tips
read -r -d '' HARDENING_TIPS << EOT
<ul>
  <li>Disable root login: <code>PermitRootLogin no</code></li>
  <li>Use key-based authentication instead of passwords</li>
  <li>Limit users who can SSH: <code>AllowUsers</code></li>
  <li>Change default SSH port from 22</li>
  <li>Use fail2ban to block brute-force attempts</li>
</ul>
EOT

# === GENERATE HTML REPORT ===
cat <<EOF > "$REPORT_FILE"
<html>
<head><title>Weekly System Report</title></head>
<body style="font-family: sans-serif;">
<h2>🖥️ System Report - $now</h2>

<h3>✅ System Uptime</h3>
<p>$uptime_info</p>

<h3>💾 Disk Usage</h3>
<pre>$disk_usage</pre>

<h3>🧠 Memory Info</h3>
<pre>$mem_info</pre>

<h3>📊 CPU Top Processes</h3>
<pre>$cpu_top</pre>

<h3>🔐 SSH Successful Logins (Past 7 Days)</h3>
<pre>$SUCCESSFUL_LOGINS</pre>

<h3>❌ Failed SSH Login Attempts (Past 7 Days)</h3>
<pre>$FAILED_LOGINS</pre>

<h3>📌 Top Failed IPs</h3>
<pre>$TOP_FAILED_IPS</pre>

<h3>👤 Top Failed Usernames</h3>
<pre>$TOP_FAILED_USERS</pre>

<h3>🌍 GeoIP Lookup (Top 5)</h3>
$GEOIP_REPORT

<h3>📅 First SSH Login</h3>
<pre>$first_login</pre>

<h3>📅 Last SSH Login</h3>
<pre>$last_login</pre>

<h3>🔒 SSH Hardening Tips</h3>
$HARDENING_TIPS

<p><i>Report generated by security digest script.</i></p>
</body>
</html>
EOF

# === EMAIL REPORT ===
cat "$REPORT_FILE" | msmtp --from=default -t <<EOF
To: $EMAIL_TO
Subject: $EMAIL_SUBJECT
Content-Type: text/html

$(cat "$REPORT_FILE")
EOF

# === DONE ===
echo "Report saved to $REPORT_FILE and emailed to $EMAIL_TO"

