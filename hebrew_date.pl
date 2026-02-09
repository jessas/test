#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);

# Gregorian to Hebrew Date Converter
#
# Implements the full Hebrew calendar algorithm including:
# - 19-year Metonic cycle for leap years
# - Molad (new moon) calculation
# - Postponement rules (dehiyot)
# - Variable month lengths

# Hebrew month names
my @HEBREW_MONTHS = (
    "Tishrei", "Cheshvan", "Kislev", "Tevet", "Shevat", "Adar",
    "Adar II", "Nisan", "Iyar", "Sivan", "Tammuz", "Av", "Elul"
);

my @HEBREW_MONTHS_LEAP = (
    "Tishrei", "Cheshvan", "Kislev", "Tevet", "Shevat", "Adar I",
    "Adar II", "Nisan", "Iyar", "Sivan", "Tammuz", "Av", "Elul"
);

# --- Core Hebrew calendar functions ---

# Returns 1 if the Hebrew year is a leap year (has 13 months)
sub is_hebrew_leap_year {
    my ($year) = @_;
    my $mod = $year % 19;
    return ($mod == 3 || $mod == 6 || $mod == 8 || $mod == 11 ||
            $mod == 14 || $mod == 17 || $mod == 0) ? 1 : 0;
}

# Calculate the number of months in a Hebrew year
sub months_in_hebrew_year {
    my ($year) = @_;
    return is_hebrew_leap_year($year) ? 13 : 12;
}

# Calculate the molad (mean conjunction) for a given Hebrew month
# Returns the molad as days from the epoch (Monday, 7 October 3761 BCE)
# The molad of Tishrei year 1 is: day 1, 5 hours, 204 parts (halakim)
# Each month = 29 days, 12 hours, 793 parts
sub hebrew_elapsed_months {
    my ($year) = @_;
    my $months = 0;
    my $full_cycles = floor(($year - 1) / 19);
    $months += $full_cycles * 235;

    my $remaining = ($year - 1) % 19;
    $months += floor(($remaining * 7 + 1) / 19);
    $months += $remaining * 12;

    return $months;
}

# Calculate the number of elapsed days from the Hebrew epoch to
# the beginning (1 Tishrei) of a given Hebrew year
sub hebrew_year_start {
    my ($year) = @_;

    my $months_elapsed = hebrew_elapsed_months($year);

    # Calculate the molad in parts (1 day = 24 hours = 25920 parts)
    # Molad of creation: 1d 5h 204p
    my $parts = 204 + 793 * $months_elapsed;
    my $hours = 5 + 12 * $months_elapsed + floor($parts / 1080);
    $parts = $parts % 1080;
    my $days = 1 + 29 * $months_elapsed + floor($hours / 24);
    $hours = $hours % 24;

    # Apply postponement rules (dehiyot)
    my $day_of_week = $days % 7; # 0=Sunday, 1=Monday, etc.

    my $alt_day = $days;

    # Dehiya 1: If molad falls on Sun, Wed, or Fri, postpone by 1 day
    if ($day_of_week == 0 || $day_of_week == 3 || $day_of_week == 5) {
        $alt_day = $days + 1;
    }

    # Dehiya 2: If molad is >= 18 hours (noon), postpone by 1 day
    # (and if that lands on Sun/Wed/Fri, postpone again)
    if ($hours >= 18) {
        $alt_day = $days + 1;
        my $new_dow = $alt_day % 7;
        if ($new_dow == 0 || $new_dow == 3 || $new_dow == 5) {
            $alt_day++;
        }
    }

    # Dehiya 3: If molad of non-leap year falls on Tuesday at >= 9h 204p,
    # postpone to Thursday
    if (!is_hebrew_leap_year($year) &&
        $day_of_week == 2 &&
        ($hours > 9 || ($hours == 9 && $parts >= 204))) {
        $alt_day = $days + 2;
    }

    # Dehiya 4: If molad in year following a leap year falls on Monday
    # at >= 15h 589p, postpone to Tuesday
    if (is_hebrew_leap_year($year - 1) &&
        $day_of_week == 1 &&
        ($hours > 15 || ($hours == 15 && $parts >= 589))) {
        $alt_day = $days + 1;
    }

    # Use the postponed day if it's later
    $days = $alt_day if $alt_day > $days;

    return $days;
}

# Calculate the number of days in a Hebrew year
sub days_in_hebrew_year {
    my ($year) = @_;
    return hebrew_year_start($year + 1) - hebrew_year_start($year);
}

# Get the number of days in each month for a given Hebrew year
sub month_days {
    my ($year) = @_;
    my $year_length = days_in_hebrew_year($year);
    my $leap = is_hebrew_leap_year($year);

    # Standard month lengths
    my @days = (
        30,  # Tishrei
        0,   # Cheshvan (29 or 30, determined below)
        0,   # Kislev (29 or 30, determined below)
        29,  # Tevet
        30,  # Shevat
    );

    if ($leap) {
        push @days, 30;  # Adar I
        push @days, 29;  # Adar II
    } else {
        push @days, 29;  # Adar
        # No Adar II for non-leap years; we handle indexing below
    }

    push @days, (
        30,  # Nisan
        29,  # Iyar
        30,  # Sivan
        29,  # Tammuz
        30,  # Av
        29,  # Elul
    );

    # Determine Cheshvan and Kislev lengths based on year length
    # Regular year: 354 (non-leap) or 384 (leap)
    # Deficient:    353 or 383 — Kislev has 29
    # Complete:     355 or 385 — Cheshvan has 30
    my $base = $leap ? 384 : 354;

    if ($year_length == $base - 1) {
        # Deficient
        $days[1] = 29;  # Cheshvan
        $days[2] = 29;  # Kislev
    } elsif ($year_length == $base) {
        # Regular
        $days[1] = 29;  # Cheshvan
        $days[2] = 30;  # Kislev
    } elsif ($year_length == $base + 1) {
        # Complete
        $days[1] = 30;  # Cheshvan
        $days[2] = 30;  # Kislev
    } else {
        die "Unexpected year length $year_length for Hebrew year $year\n";
    }

    return @days;
}

# --- Gregorian calendar functions ---

sub is_gregorian_leap_year {
    my ($year) = @_;
    return ($year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0)) ? 1 : 0;
}

# Convert Gregorian date to Julian Day Number (JDN)
sub gregorian_to_jdn {
    my ($year, $month, $day) = @_;

    my $a = floor((14 - $month) / 12);
    my $y = $year + 4800 - $a;
    my $m = $month + 12 * $a - 3;

    return $day + floor((153 * $m + 2) / 5) + 365 * $y +
           floor($y / 4) - floor($y / 100) + floor($y / 400) - 32045;
}

# Hebrew epoch in Julian Day Number terms
# 1 Tishrei 1 = JDN 347997 (Monday, 7 October 3761 BCE, proleptic Julian)
sub hebrew_epoch_jdn {
    return 347997;
}

# Convert a Gregorian date to a Hebrew date
sub gregorian_to_hebrew {
    my ($gyear, $gmonth, $gday) = @_;

    # Get Julian Day Number for the Gregorian date
    my $jdn = gregorian_to_jdn($gyear, $gmonth, $gday);

    # Estimate the Hebrew year
    # Hebrew year is roughly Gregorian year + 3761
    my $hyear = $gyear + 3761;

    # Calculate the JDN of 1 Tishrei of the estimated year
    my $start_jdn = hebrew_epoch_jdn() + hebrew_year_start($hyear);

    # Adjust if needed — the Gregorian date might fall in the previous Hebrew year
    # (this happens for dates before Rosh Hashanah)
    while ($start_jdn > $jdn) {
        $hyear--;
        $start_jdn = hebrew_epoch_jdn() + hebrew_year_start($hyear);
    }

    # Also check if we need to move forward
    my $next_start_jdn = hebrew_epoch_jdn() + hebrew_year_start($hyear + 1);
    while ($next_start_jdn <= $jdn) {
        $hyear++;
        $start_jdn = $next_start_jdn;
        $next_start_jdn = hebrew_epoch_jdn() + hebrew_year_start($hyear + 1);
    }

    # Now find the month and day
    my @mdays = month_days($hyear);
    my $remaining = $jdn - $start_jdn;

    my $hmonth = 0;
    my $leap = is_hebrew_leap_year($hyear);
    my $num_months = $leap ? 13 : 12;

    # For non-leap years, we skip the Adar II slot (index 6 in the 13-month layout)
    # Our month_days returns the right count based on leap status

    for my $i (0 .. $#mdays) {
        if ($remaining < $mdays[$i]) {
            $hmonth = $i;
            last;
        }
        $remaining -= $mdays[$i];
    }

    my $hday = $remaining + 1;

    # Get month name
    my $month_name;
    if ($leap) {
        $month_name = $HEBREW_MONTHS_LEAP[$hmonth];
    } else {
        # Non-leap: months 0-5 map normally, then skip Adar II
        if ($hmonth <= 5) {
            $month_name = $HEBREW_MONTHS[$hmonth];
        } else {
            # Index 6 and beyond in non-leap: shift by 1 (skip Adar II)
            $month_name = $HEBREW_MONTHS[$hmonth + 1];
        }
    }

    return ($hday, $month_name, $hyear);
}

# --- Main program ---

sub usage {
    print "Usage: perl hebrew_date.pl YYYY-MM-DD\n";
    print "       perl hebrew_date.pl YYYY MM DD\n";
    print "\nConverts a Gregorian date to a Hebrew date.\n";
    exit 1;
}

my ($year, $month, $day);

if (@ARGV == 1) {
    if ($ARGV[0] =~ /^(\d{4})-(\d{1,2})-(\d{1,2})$/) {
        ($year, $month, $day) = ($1, $2, $3);
    } else {
        usage();
    }
} elsif (@ARGV == 3) {
    ($year, $month, $day) = @ARGV;
} else {
    usage();
}

# Validate input
if ($month < 1 || $month > 12) {
    die "Error: Month must be between 1 and 12.\n";
}
if ($day < 1 || $day > 31) {
    die "Error: Day must be between 1 and 31.\n";
}

my ($hday, $hmonth_name, $hyear) = gregorian_to_hebrew($year, $month, $day);

printf("Gregorian: %04d-%02d-%02d\n", $year, $month, $day);
printf("Hebrew:    %d %s %d\n", $hday, $hmonth_name, $hyear);
