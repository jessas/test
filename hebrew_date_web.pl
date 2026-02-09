#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);
use IO::Socket::INET;

my $PORT = $ARGV[0] || 8080;

# ============================================================
# Hebrew calendar conversion logic (from hebrew_date.pl)
# ============================================================

my @HEBREW_MONTHS = (
    "Tishrei", "Cheshvan", "Kislev", "Tevet", "Shevat", "Adar",
    "Adar II", "Nisan", "Iyar", "Sivan", "Tammuz", "Av", "Elul"
);

my @HEBREW_MONTHS_LEAP = (
    "Tishrei", "Cheshvan", "Kislev", "Tevet", "Shevat", "Adar I",
    "Adar II", "Nisan", "Iyar", "Sivan", "Tammuz", "Av", "Elul"
);

sub is_hebrew_leap_year {
    my ($year) = @_;
    my $mod = $year % 19;
    return ($mod == 3 || $mod == 6 || $mod == 8 || $mod == 11 ||
            $mod == 14 || $mod == 17 || $mod == 0) ? 1 : 0;
}

sub hebrew_elapsed_months {
    my ($year) = @_;
    my $full_cycles = floor(($year - 1) / 19);
    my $remaining = ($year - 1) % 19;
    return $full_cycles * 235 + floor(($remaining * 7 + 1) / 19) + $remaining * 12;
}

sub hebrew_year_start {
    my ($year) = @_;
    my $months_elapsed = hebrew_elapsed_months($year);
    my $parts = 204 + 793 * $months_elapsed;
    my $hours = 5 + 12 * $months_elapsed + floor($parts / 1080);
    $parts = $parts % 1080;
    my $days = 1 + 29 * $months_elapsed + floor($hours / 24);
    $hours = $hours % 24;
    my $day_of_week = $days % 7;
    my $alt_day = $days;

    if ($day_of_week == 0 || $day_of_week == 3 || $day_of_week == 5) {
        $alt_day = $days + 1;
    }
    if ($hours >= 18) {
        $alt_day = $days + 1;
        my $new_dow = $alt_day % 7;
        if ($new_dow == 0 || $new_dow == 3 || $new_dow == 5) { $alt_day++; }
    }
    if (!is_hebrew_leap_year($year) && $day_of_week == 2 &&
        ($hours > 9 || ($hours == 9 && $parts >= 204))) {
        $alt_day = $days + 2;
    }
    if (is_hebrew_leap_year($year - 1) && $day_of_week == 1 &&
        ($hours > 15 || ($hours == 15 && $parts >= 589))) {
        $alt_day = $days + 1;
    }
    $days = $alt_day if $alt_day > $days;
    return $days;
}

sub days_in_hebrew_year {
    my ($year) = @_;
    return hebrew_year_start($year + 1) - hebrew_year_start($year);
}

sub month_days {
    my ($year) = @_;
    my $year_length = days_in_hebrew_year($year);
    my $leap = is_hebrew_leap_year($year);
    my @days = (30, 0, 0, 29, 30);

    if ($leap) {
        push @days, 30, 29;
    } else {
        push @days, 29;
    }
    push @days, (30, 29, 30, 29, 30, 29);

    my $base = $leap ? 384 : 354;
    if ($year_length == $base - 1) {
        $days[1] = 29; $days[2] = 29;
    } elsif ($year_length == $base) {
        $days[1] = 29; $days[2] = 30;
    } elsif ($year_length == $base + 1) {
        $days[1] = 30; $days[2] = 30;
    } else {
        die "Unexpected year length $year_length for Hebrew year $year\n";
    }
    return @days;
}

sub gregorian_to_jdn {
    my ($year, $month, $day) = @_;
    my $a = floor((14 - $month) / 12);
    my $y = $year + 4800 - $a;
    my $m = $month + 12 * $a - 3;
    return $day + floor((153 * $m + 2) / 5) + 365 * $y +
           floor($y / 4) - floor($y / 100) + floor($y / 400) - 32045;
}

sub hebrew_epoch_jdn { return 347997; }

sub gregorian_to_hebrew {
    my ($gyear, $gmonth, $gday) = @_;
    my $jdn = gregorian_to_jdn($gyear, $gmonth, $gday);
    my $hyear = $gyear + 3761;
    my $start_jdn = hebrew_epoch_jdn() + hebrew_year_start($hyear);

    while ($start_jdn > $jdn) {
        $hyear--;
        $start_jdn = hebrew_epoch_jdn() + hebrew_year_start($hyear);
    }
    my $next_start_jdn = hebrew_epoch_jdn() + hebrew_year_start($hyear + 1);
    while ($next_start_jdn <= $jdn) {
        $hyear++;
        $start_jdn = $next_start_jdn;
        $next_start_jdn = hebrew_epoch_jdn() + hebrew_year_start($hyear + 1);
    }

    my @mdays = month_days($hyear);
    my $remaining = $jdn - $start_jdn;
    my $hmonth = 0;
    my $leap = is_hebrew_leap_year($hyear);

    for my $i (0 .. $#mdays) {
        if ($remaining < $mdays[$i]) {
            $hmonth = $i;
            last;
        }
        $remaining -= $mdays[$i];
    }
    my $hday = $remaining + 1;

    my $month_name;
    if ($leap) {
        $month_name = $HEBREW_MONTHS_LEAP[$hmonth];
    } else {
        if ($hmonth <= 5) {
            $month_name = $HEBREW_MONTHS[$hmonth];
        } else {
            $month_name = $HEBREW_MONTHS[$hmonth + 1];
        }
    }
    return ($hday, $month_name, $hyear);
}

# ============================================================
# Web server
# ============================================================

my $server = IO::Socket::INET->new(
    LocalAddr => '0.0.0.0',
    LocalPort => $PORT,
    Listen    => 5,
    ReuseAddr => 1,
    Proto     => 'tcp',
) or die "Cannot start server on port $PORT: $!\n";

print "Hebrew Date Converter running at http://localhost:$PORT\n";

while (my $client = $server->accept()) {
    my $request = '';
    while (my $line = <$client>) {
        $request .= $line;
        last if $line =~ /^\r?\n$/;
    }

    my ($method, $path) = $request =~ /^(\w+)\s+(\S+)/;
    $method //= 'GET';
    $path   //= '/';

    if ($path =~ m{^/convert\?} && $method eq 'GET') {
        handle_convert($client, $path);
    } else {
        handle_page($client);
    }

    close $client;
}

sub send_response {
    my ($client, $status, $content_type, $body) = @_;
    my $length = length($body);
    print $client "HTTP/1.1 $status\r\n";
    print $client "Content-Type: $content_type\r\n";
    print $client "Content-Length: $length\r\n";
    print $client "Connection: close\r\n";
    print $client "\r\n";
    print $client $body;
}

sub handle_convert {
    my ($client, $path) = @_;

    my ($query) = $path =~ /\?(.+)/;
    my %params;
    for my $pair (split /&/, $query // '') {
        my ($k, $v) = split /=/, $pair, 2;
        $params{$k} = $v // '';
    }

    my $date = $params{date} // '';
    unless ($date =~ /^(\d{4})-(\d{1,2})-(\d{1,2})$/) {
        send_response($client, '400 Bad Request', 'application/json',
            '{"error":"Invalid date format. Use YYYY-MM-DD."}');
        return;
    }
    my ($y, $m, $d) = ($1, $2, $3);
    if ($m < 1 || $m > 12 || $d < 1 || $d > 31) {
        send_response($client, '400 Bad Request', 'application/json',
            '{"error":"Month must be 1-12 and day must be 1-31."}');
        return;
    }

    my ($hday, $hmonth, $hyear) = gregorian_to_hebrew($y, $m, $d);
    my $json = sprintf('{"day":%d,"month":"%s","year":%d,"formatted":"%d %s %d"}',
        $hday, $hmonth, $hyear, $hday, $hmonth, $hyear);
    send_response($client, '200 OK', 'application/json', $json);
}

sub handle_page {
    my ($client) = @_;
    my $html = <<'HTML';
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Gregorian to Hebrew Date Converter</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }

  body {
    font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
    color: #e0e0e0;
  }

  .card {
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 20px;
    padding: 48px;
    width: 460px;
    max-width: 90vw;
    text-align: center;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  }

  h1 {
    font-size: 1.6rem;
    font-weight: 600;
    margin-bottom: 8px;
    background: linear-gradient(90deg, #a78bfa, #60a5fa);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .subtitle {
    font-size: 0.85rem;
    color: #888;
    margin-bottom: 36px;
  }

  label {
    display: block;
    text-align: left;
    font-size: 0.8rem;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: #999;
    margin-bottom: 8px;
  }

  input[type="date"] {
    width: 100%;
    padding: 14px 16px;
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.07);
    color: #e0e0e0;
    font-size: 1.1rem;
    outline: none;
    transition: border-color 0.2s, box-shadow 0.2s;
  }
  input[type="date"]:focus {
    border-color: #a78bfa;
    box-shadow: 0 0 0 3px rgba(167, 139, 250, 0.2);
  }
  input[type="date"]::-webkit-calendar-picker-indicator {
    filter: invert(0.7);
    cursor: pointer;
  }

  button {
    width: 100%;
    margin-top: 20px;
    padding: 14px;
    border: none;
    border-radius: 12px;
    background: linear-gradient(135deg, #7c3aed, #3b82f6);
    color: #fff;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.2s, transform 0.1s;
  }
  button:hover { opacity: 0.9; }
  button:active { transform: scale(0.98); }

  .result {
    margin-top: 32px;
    padding: 24px;
    border-radius: 14px;
    background: rgba(167, 139, 250, 0.08);
    border: 1px solid rgba(167, 139, 250, 0.2);
    display: none;
  }
  .result.visible { display: block; }

  .result .label {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: #888;
    margin-bottom: 8px;
  }

  .result .hebrew-date {
    font-size: 1.8rem;
    font-weight: 700;
    background: linear-gradient(90deg, #c084fc, #60a5fa);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .result .details {
    margin-top: 14px;
    display: flex;
    justify-content: center;
    gap: 24px;
    font-size: 0.85rem;
    color: #aaa;
  }
  .result .details span {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
  }
  .result .details .val {
    color: #d4d4d4;
    font-weight: 600;
    font-size: 1rem;
  }

  .error {
    margin-top: 20px;
    padding: 12px;
    border-radius: 10px;
    background: rgba(239, 68, 68, 0.1);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #f87171;
    font-size: 0.9rem;
    display: none;
  }
  .error.visible { display: block; }
</style>
</head>
<body>

<div class="card">
  <h1>Gregorian to Hebrew Date</h1>
  <p class="subtitle">Convert any date to the Hebrew calendar</p>

  <label for="gdate">Gregorian Date</label>
  <input type="date" id="gdate">

  <button onclick="convert()">Convert</button>

  <div class="error" id="error"></div>

  <div class="result" id="result">
    <div class="label">Hebrew Date</div>
    <div class="hebrew-date" id="hebrewDate"></div>
    <div class="details">
      <span><span class="val" id="hDay"></span>Day</span>
      <span><span class="val" id="hMonth"></span>Month</span>
      <span><span class="val" id="hYear"></span>Year</span>
    </div>
  </div>
</div>

<script>
  // Default to today
  document.getElementById('gdate').valueAsDate = new Date();

  async function convert() {
    var dateVal = document.getElementById('gdate').value;
    var errEl = document.getElementById('error');
    var resEl = document.getElementById('result');

    errEl.className = 'error';
    resEl.className = 'result';

    if (!dateVal) {
      errEl.textContent = 'Please select a date.';
      errEl.className = 'error visible';
      return;
    }

    try {
      var resp = await fetch('/convert?date=' + encodeURIComponent(dateVal));
      var data = await resp.json();

      if (data.error) {
        errEl.textContent = data.error;
        errEl.className = 'error visible';
        return;
      }

      document.getElementById('hebrewDate').textContent = data.formatted;
      document.getElementById('hDay').textContent = data.day;
      document.getElementById('hMonth').textContent = data.month;
      document.getElementById('hYear').textContent = data.year;
      resEl.className = 'result visible';
    } catch (e) {
      errEl.textContent = 'Something went wrong. Please try again.';
      errEl.className = 'error visible';
    }
  }
</script>

</body>
</html>
HTML
    send_response($client, '200 OK', 'text/html; charset=utf-8', $html);
}
